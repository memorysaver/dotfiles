//! Shared protocol and broker implementation for the OpenAB → Herdr bridge.
//!
//! The broker intentionally exposes a small high-level API instead of passing
//! arbitrary Herdr socket methods through to the host.  The JSON contract is
//! kept compatible with the original Python implementation so OpenAB and
//! existing shell workflows do not need to change during the migration.

use chrono::Utc;
use log::{error, info, warn};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, HashSet};
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, Read, Write};
use std::os::unix::fs::{FileTypeExt, PermissionsExt};
use std::os::unix::net::UnixStream as BlockingUnixStream;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader as AsyncBufReader};
use tokio::net::{UnixListener, UnixStream};
use uuid::Uuid;

mod history;

pub const MAX_TIMEOUT_MS: u64 = 3_600_000;
pub const MAX_READ_LINES: i64 = 200;
pub const MAX_PROMPT_BYTES: usize = 200_000;
const MAX_REQUEST_BYTES: usize = 1_000_000;

const ALLOWED_KINDS: &[&str] = &[
    "agy",
    "amp",
    "claude",
    "cline",
    "codex",
    "copilot",
    "cursor",
    "devin",
    "droid",
    "gemini",
    "grok",
    "hermes",
    "kilo",
    "kiro",
    "kimi",
    "maki",
    "mastracode",
    "omp",
    "opencode",
    "pi",
    "qodercli",
    "qwen",
];

/// An expected, user-actionable broker or Herdr error.
#[derive(Debug, Clone)]
pub struct BrokerError {
    pub code: String,
    pub message: String,
}

impl BrokerError {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }

    fn internal(message: impl Into<String>) -> Self {
        Self::new("internal_error", message)
    }
}

impl std::fmt::Display for BrokerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for BrokerError {}

fn now_iso() -> String {
    Utc::now().to_rfc3339()
}

fn safe_text(value: Option<&Value>, field: &str, max_bytes: usize) -> Result<String, BrokerError> {
    let Some(value) = value else {
        return Err(BrokerError::new(
            "invalid_request",
            format!("{field} must be a non-empty string"),
        ));
    };
    let Some(text) = value.as_str() else {
        return Err(BrokerError::new(
            "invalid_request",
            format!("{field} must be a non-empty string"),
        ));
    };
    if text.is_empty() || text.contains('\0') || text.len() > max_bytes {
        return Err(BrokerError::new(
            "invalid_request",
            format!("{field} contains invalid or oversized text"),
        ));
    }
    Ok(text.to_owned())
}

fn safe_id(value: Option<&Value>, field: &str) -> Result<String, BrokerError> {
    let value = safe_text(value, field, 128)?;
    if !value.bytes().enumerate().all(|(index, byte)| match index {
        0 => byte.is_ascii_alphanumeric(),
        _ => byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'.' | b':' | b'-'),
    }) {
        return Err(BrokerError::new(
            "invalid_request",
            format!("{field} is not a valid Herdr identifier"),
        ));
    }
    Ok(value)
}

fn object_id(value: Option<&Value>, primary: &str) -> Option<String> {
    match value {
        Some(Value::String(value)) if !value.is_empty() => Some(value.clone()),
        Some(Value::Object(object)) => [primary, "id"].into_iter().find_map(|key| {
            object
                .get(key)
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(ToOwned::to_owned)
        }),
        _ => None,
    }
}

fn task_slug(task_id: &str) -> String {
    let mut slug = String::with_capacity(task_id.len());
    let mut last_separator = false;
    for byte in task_id.bytes() {
        let lower = byte.to_ascii_lowercase();
        if lower.is_ascii_lowercase() || lower.is_ascii_digit() || matches!(lower, b'_' | b'-') {
            slug.push(lower as char);
            last_separator = false;
        } else if !last_separator && !slug.is_empty() {
            slug.push('-');
            last_separator = true;
        }
    }
    while slug.ends_with('-') || slug.ends_with('_') {
        slug.pop();
    }
    if slug.is_empty() {
        "task".to_owned()
    } else {
        slug
    }
}

fn generated_agent_name(task_id: &str) -> String {
    let suffix = Uuid::new_v4().simple().to_string();
    let suffix = &suffix[..6];
    let prefix = "oa-";
    let room = 32 - prefix.len() - 1 - suffix.len();
    let mut slug = task_slug(task_id);
    slug.truncate(room);
    while slug.ends_with('-') || slug.ends_with('_') {
        slug.pop();
    }
    if slug.is_empty() {
        slug = "task".to_owned();
    }
    format!("{prefix}{slug}-{suffix}")
}

fn bounded_timeout(value: Option<&Value>, field: &str, default: u64) -> Result<u64, BrokerError> {
    let Some(value) = value else {
        return Ok(default);
    };
    if value.is_null() {
        return Ok(default);
    }
    let Some(value) = value.as_u64() else {
        return Err(BrokerError::new(
            "invalid_request",
            format!("{field} must be an integer in milliseconds"),
        ));
    };
    if value > MAX_TIMEOUT_MS {
        return Err(BrokerError::new(
            "invalid_request",
            format!("{field} must be between 0 and {MAX_TIMEOUT_MS} milliseconds"),
        ));
    }
    Ok(value)
}

pub fn expand_user(path: impl AsRef<Path>) -> PathBuf {
    let path = path.as_ref();
    let Some(text) = path.to_str() else {
        return path.to_path_buf();
    };
    let home = std::env::var_os("HOME").map(PathBuf::from);
    match (home, text) {
        (Some(home), "~") => home,
        (Some(home), text) if text.starts_with("~/") => home.join(&text[2..]),
        _ => path.to_path_buf(),
    }
}

fn state_error(path: &Path, error: impl std::fmt::Display) -> BrokerError {
    BrokerError::new(
        "internal_error",
        format!("cannot persist broker state at {}: {error}", path.display()),
    )
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Task {
    pub task_id: String,
    pub agent_name: String,
    pub agent_kind: String,
    pub cwd: String,
    pub workspace_id: String,
    pub tab_id: String,
    pub pane_id: String,
    pub label: String,
    pub layout: String,
    pub state: String,
    pub created_at: String,
    pub updated_at: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parent_task_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub discord_thread_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub discord_message_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error_code: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
}

struct TaskStore {
    state_dir: PathBuf,
    state_file: PathBuf,
    tasks: BTreeMap<String, Task>,
    last_pruned: Option<chrono::NaiveDate>,
}

impl TaskStore {
    fn new(state_dir: PathBuf) -> Result<Self, BrokerError> {
        fs::create_dir_all(&state_dir).map_err(|error| state_error(&state_dir, error))?;
        fs::set_permissions(&state_dir, fs::Permissions::from_mode(0o700))
            .map_err(|error| state_error(&state_dir, error))?;
        let state_file = state_dir.join("tasks.json");
        let tasks = if state_file.exists() {
            let content =
                fs::read_to_string(&state_file).map_err(|error| state_error(&state_file, error))?;
            serde_json::from_str(&content).map_err(|error| state_error(&state_file, error))?
        } else {
            BTreeMap::new()
        };
        Ok(Self {
            state_dir,
            state_file,
            tasks,
            last_pruned: None,
        })
    }

    fn save(&self) -> Result<(), BrokerError> {
        let mut payload = serde_json::to_vec_pretty(&self.tasks)
            .map_err(|error| state_error(&self.state_file, error))?;
        payload.push(b'\n');
        let temp_path = self
            .state_dir
            .join(format!("tasks.{}.tmp", Uuid::new_v4().simple()));
        let result = (|| -> Result<(), BrokerError> {
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&temp_path)
                .map_err(|error| state_error(&temp_path, error))?;
            file.set_permissions(fs::Permissions::from_mode(0o600))
                .map_err(|error| state_error(&temp_path, error))?;
            file.write_all(&payload)
                .map_err(|error| state_error(&temp_path, error))?;
            file.sync_all()
                .map_err(|error| state_error(&temp_path, error))?;
            drop(file);
            fs::rename(&temp_path, &self.state_file)
                .map_err(|error| state_error(&self.state_file, error))?;
            fs::set_permissions(&self.state_file, fs::Permissions::from_mode(0o600))
                .map_err(|error| state_error(&self.state_file, error))?;
            Ok(())
        })();
        if result.is_err() {
            let _ = fs::remove_file(&temp_path);
        }
        result
    }

    fn contains_task(&self, task_id: &str) -> bool {
        self.tasks.contains_key(task_id)
    }

    fn contains_agent(&self, agent_name: &str) -> bool {
        self.tasks
            .values()
            .any(|task| task.agent_name == agent_name)
    }

    fn put(&mut self, task: Task) -> Result<(), BrokerError> {
        self.append_event(&task)?;
        self.tasks.insert(task.task_id.clone(), task);
        self.save()
    }

    fn update<F>(&mut self, task_id: &str, update: F) -> Result<Task, BrokerError>
    where
        F: FnOnce(&mut Task),
    {
        let previous = self.get(task_id)?;
        let mut snapshot = previous.clone();
        update(&mut snapshot);
        if previous.state == snapshot.state && previous.error_code == snapshot.error_code {
            // Polls must not grow the journal or extend retention indefinitely.
            return Ok(previous);
        }
        self.append_event(&snapshot)?;
        self.tasks.insert(task_id.to_owned(), snapshot.clone());
        self.save()?;
        Ok(snapshot)
    }

    fn get(&self, task_id: &str) -> Result<Task, BrokerError> {
        self.tasks.get(task_id).cloned().ok_or_else(|| {
            BrokerError::new("task_not_found", format!("unknown task_id: {task_id}"))
        })
    }

    fn list(&self) -> Vec<Task> {
        self.tasks.values().cloned().collect()
    }
}

#[derive(Clone)]
pub struct HerdrClient {
    socket_path: PathBuf,
}

impl HerdrClient {
    pub fn new(socket_path: PathBuf) -> Self {
        Self { socket_path }
    }

    pub async fn call(
        &self,
        method: &str,
        params: Value,
        timeout: Duration,
    ) -> Result<Value, BrokerError> {
        let socket_path = self.socket_path.clone();
        let request_id = format!("herdr-dispatchd-{}", Uuid::new_v4().simple());
        let method = method.to_owned();
        let timeout_method = method.clone();
        let future = async move {
            let mut stream = UnixStream::connect(&socket_path).await.map_err(|error| {
                if error.kind() == io::ErrorKind::NotFound {
                    BrokerError::new(
                        "herdr_unavailable",
                        format!("Herdr socket is unavailable: {}", socket_path.display()),
                    )
                } else {
                    BrokerError::new(
                        "herdr_unavailable",
                        format!("cannot reach Herdr socket: {error}"),
                    )
                }
            })?;
            let request = json!({
                "id": request_id,
                "method": method,
                "params": params,
            });
            let mut encoded = serde_json::to_vec(&request)
                .map_err(|error| BrokerError::new("herdr_protocol_error", error.to_string()))?;
            encoded.push(b'\n');
            stream.write_all(&encoded).await.map_err(|error| {
                BrokerError::new(
                    "herdr_unavailable",
                    format!("cannot write to Herdr socket: {error}"),
                )
            })?;
            let mut reader = AsyncBufReader::new(stream);
            let mut line = String::new();
            loop {
                line.clear();
                let count = reader.read_line(&mut line).await.map_err(|error| {
                    BrokerError::new(
                        "herdr_unavailable",
                        format!("cannot read Herdr socket: {error}"),
                    )
                })?;
                if count == 0 {
                    return Err(BrokerError::new(
                        "herdr_disconnected",
                        "Herdr closed the API socket",
                    ));
                }
                if line.len() > MAX_REQUEST_BYTES {
                    return Err(BrokerError::new(
                        "herdr_protocol_error",
                        "Herdr returned an oversized response",
                    ));
                }
                let response: Value = serde_json::from_str(&line).map_err(|error| {
                    BrokerError::new(
                        "herdr_protocol_error",
                        format!("Herdr returned invalid JSON: {error}"),
                    )
                })?;
                if response.get("id").and_then(Value::as_str) != Some(request_id.as_str()) {
                    continue;
                }
                if let Some(error) = response.get("error").and_then(Value::as_object) {
                    let code = error
                        .get("code")
                        .and_then(Value::as_str)
                        .unwrap_or("herdr_error");
                    let message = error
                        .get("message")
                        .and_then(Value::as_str)
                        .unwrap_or("Herdr request failed");
                    return Err(BrokerError::new(code, message));
                }
                return response.get("result").cloned().ok_or_else(|| {
                    BrokerError::new("herdr_protocol_error", "Herdr response had no result")
                });
            }
        };
        match tokio::time::timeout(timeout, future).await {
            Ok(result) => result,
            Err(_) => Err(BrokerError::new(
                "timeout",
                format!("Herdr request timed out: {timeout_method}"),
            )),
        }
    }
}

#[derive(Clone)]
struct Layout {
    workspace_id: String,
    tab_id: String,
    pane_id: String,
    label: String,
}

struct DispatchSpec {
    params: serde_json::Map<String, Value>,
    task_id: String,
    kind: String,
    cwd: PathBuf,
    prompt: String,
    agent_name: String,
    agent_args: Vec<String>,
    start_timeout_ms: u64,
}

struct Reservations {
    task_ids: HashSet<String>,
    agent_names: HashSet<String>,
}

impl Reservations {
    fn new() -> Self {
        Self {
            task_ids: HashSet::new(),
            agent_names: HashSet::new(),
        }
    }
}

#[derive(Clone)]
pub struct Broker {
    herdr: HerdrClient,
    store: Arc<Mutex<TaskStore>>,
    allowed_root: PathBuf,
    reservations: Arc<Mutex<Reservations>>,
}

impl Broker {
    pub fn new(
        herdr_socket: PathBuf,
        state_dir: PathBuf,
        allowed_root: PathBuf,
    ) -> Result<Self, BrokerError> {
        let allowed_root = expand_user(allowed_root).canonicalize().map_err(|error| {
            BrokerError::new(
                "path_not_found",
                format!("allowed root is unavailable: {error}"),
            )
        })?;
        let store = TaskStore::new(expand_user(state_dir))?;
        Ok(Self {
            herdr: HerdrClient::new(expand_user(herdr_socket)),
            store: Arc::new(Mutex::new(store)),
            allowed_root,
            reservations: Arc::new(Mutex::new(Reservations::new())),
        })
    }

    fn reserve_ids(&self, task_id: &str, agent_name: &str) -> Result<(), BrokerError> {
        let store = self
            .store
            .lock()
            .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
        let mut reservations = self
            .reservations
            .lock()
            .map_err(|_| BrokerError::internal("reservation lock was poisoned"))?;
        if store.contains_task(task_id) || reservations.task_ids.contains(task_id) {
            return Err(BrokerError::new(
                "task_exists",
                format!("task_id already exists: {task_id}"),
            ));
        }
        if store.contains_agent(agent_name) || reservations.agent_names.contains(agent_name) {
            return Err(BrokerError::new(
                "agent_name_in_use",
                format!("agent_name already belongs to a recorded or pending task: {agent_name}"),
            ));
        }
        reservations.task_ids.insert(task_id.to_owned());
        reservations.agent_names.insert(agent_name.to_owned());
        Ok(())
    }

    fn release_ids(&self, task_id: &str, agent_name: &str) {
        if let Ok(mut reservations) = self.reservations.lock() {
            reservations.task_ids.remove(task_id);
            reservations.agent_names.remove(agent_name);
        }
    }

    fn cwd(&self, value: Option<&Value>) -> Result<PathBuf, BrokerError> {
        let raw = safe_text(value, "cwd", 4096)?;
        let path = expand_user(raw);
        if !path.is_absolute() {
            return Err(BrokerError::new(
                "invalid_request",
                "cwd must be an absolute path",
            ));
        }
        let resolved = path.canonicalize().map_err(|error| {
            BrokerError::new("path_not_found", format!("cwd is unavailable: {error}"))
        })?;
        if resolved.strip_prefix(&self.allowed_root).is_err() {
            return Err(BrokerError::new(
                "path_not_allowed",
                format!(
                    "cwd must remain under the allowed workspace root: {}",
                    self.allowed_root.display()
                ),
            ));
        }
        if !resolved.is_dir() {
            return Err(BrokerError::new(
                "path_not_found",
                format!("cwd is not a directory: {}", resolved.display()),
            ));
        }
        Ok(resolved)
    }

    fn agent_name(&self, value: Option<&Value>, task_id: &str) -> Result<String, BrokerError> {
        let Some(value) = value else {
            return Ok(generated_agent_name(task_id));
        };
        if value.is_null() {
            return Ok(generated_agent_name(task_id));
        }
        let name = safe_text(Some(value), "agent_name", 32)?;
        let valid = name.bytes().enumerate().all(|(index, byte)| match index {
            0 => byte.is_ascii_lowercase(),
            _ => byte.is_ascii_lowercase() || byte.is_ascii_digit() || matches!(byte, b'_' | b'-'),
        });
        if !valid {
            return Err(BrokerError::new(
                "invalid_request",
                "agent_name must match Herdr's lowercase name format",
            ));
        }
        Ok(name)
    }

    fn agent_args(&self, value: Option<&Value>) -> Result<Vec<String>, BrokerError> {
        let Some(value) = value else {
            return Ok(Vec::new());
        };
        if value.is_null() {
            return Ok(Vec::new());
        }
        let Some(values) = value.as_array() else {
            return Err(BrokerError::new(
                "invalid_request",
                "agent_args must be a list of at most 32 strings",
            ));
        };
        if values.len() > 32 {
            return Err(BrokerError::new(
                "invalid_request",
                "agent_args must be a list of at most 32 strings",
            ));
        }
        values
            .iter()
            .enumerate()
            .map(|(index, value)| {
                let value = safe_text(Some(value), &format!("agent_args[{index}]"), 512)?;
                if value.contains(['\n', '\r']) {
                    return Err(BrokerError::new(
                        "invalid_request",
                        "agent_args cannot contain newlines",
                    ));
                }
                Ok(value)
            })
            .collect()
    }

    fn label(&self, value: Option<&Value>, task_id: &str) -> Result<String, BrokerError> {
        let default = {
            let slug = task_slug(task_id);
            let end = slug.len().min(48);
            format!("openab-{}", &slug[..end])
        };
        let Some(value) = value else {
            return Ok(default);
        };
        if value.is_null() {
            return Ok(default);
        }
        let label = safe_text(Some(value), "label", 80)?;
        if label.contains(['\n', '\r']) {
            return Err(BrokerError::new(
                "invalid_request",
                "label cannot contain newlines",
            ));
        }
        Ok(label)
    }

    async fn layout(
        &self,
        params: &Value,
        cwd: &Path,
        task_id: &str,
    ) -> Result<Layout, BrokerError> {
        let object = params
            .as_object()
            .ok_or_else(|| BrokerError::new("invalid_request", "params must be an object"))?;
        let layout_value = object.get("layout");
        let layout = match layout_value {
            None | Some(Value::Null) => "workspace",
            Some(Value::String(value)) => value.as_str(),
            Some(_) => {
                return Err(BrokerError::new(
                    "invalid_request",
                    "layout must be workspace, tab, or pane",
                ))
            }
        };
        if !matches!(layout, "workspace" | "tab" | "pane") {
            return Err(BrokerError::new(
                "invalid_request",
                "layout must be workspace, tab, or pane",
            ));
        }
        let label = self.label(object.get("label"), task_id)?;
        let timeout = Duration::from_secs(30);
        let (workspace_id, tab_id, pane_id) = match layout {
            "workspace" => {
                let result = self
                    .herdr
                    .call(
                        "workspace.create",
                        json!({"cwd": cwd.display().to_string(), "label": label, "focus": false}),
                        timeout,
                    )
                    .await?;
                let workspace = result.get("workspace");
                let tab = result.get("tab");
                let pane = result.get("root_pane");
                (
                    object_id(workspace, "workspace_id")
                        .or_else(|| object_id(Some(&result), "workspace_id")),
                    object_id(tab, "tab_id").or_else(|| object_id(Some(&result), "tab_id")),
                    object_id(pane, "pane_id").or_else(|| object_id(Some(&result), "pane_id")),
                )
            }
            "tab" => {
                let workspace_id = safe_id(object.get("workspace_id"), "workspace_id")?;
                let result = self
                    .herdr
                    .call(
                        "tab.create",
                        json!({
                            "workspace_id": workspace_id,
                            "cwd": cwd.display().to_string(),
                            "label": label,
                            "focus": false
                        }),
                        timeout,
                    )
                    .await?;
                let tab = result.get("tab");
                let pane = result.get("root_pane");
                (
                    Some(workspace_id),
                    object_id(tab, "tab_id").or_else(|| object_id(Some(&result), "tab_id")),
                    object_id(pane, "pane_id").or_else(|| object_id(Some(&result), "pane_id")),
                )
            }
            "pane" => {
                let target_pane_id = safe_id(object.get("target_pane_id"), "target_pane_id")?;
                let direction = match object.get("direction") {
                    None | Some(Value::Null) => "right",
                    Some(Value::String(value)) => value.as_str(),
                    Some(_) => {
                        return Err(BrokerError::new(
                            "invalid_request",
                            "direction must be right or down",
                        ))
                    }
                };
                if !matches!(direction, "right" | "down") {
                    return Err(BrokerError::new(
                        "invalid_request",
                        "direction must be right or down",
                    ));
                }
                let mut split = json!({
                    "target_pane_id": target_pane_id,
                    "direction": direction,
                    "cwd": cwd.display().to_string(),
                    "focus": false,
                });
                if let Some(ratio) = object.get("ratio") {
                    if !ratio.is_null() {
                        let Some(ratio) = ratio.as_f64() else {
                            return Err(BrokerError::new(
                                "invalid_request",
                                "ratio must be a number between 0 and 1",
                            ));
                        };
                        if !(0.0 < ratio && ratio < 1.0) {
                            return Err(BrokerError::new(
                                "invalid_request",
                                "ratio must be a number between 0 and 1",
                            ));
                        }
                        split["ratio"] = json!(ratio);
                    }
                }
                let result = self.herdr.call("pane.split", split, timeout).await?;
                let pane = result.get("pane");
                let pane_id =
                    object_id(pane, "pane_id").or_else(|| object_id(Some(&result), "pane_id"));
                let Some(pane_id) = pane_id else {
                    return Err(BrokerError::new(
                        "herdr_protocol_error",
                        "pane.split did not return a pane id",
                    ));
                };
                let pane_info = self
                    .herdr
                    .call("pane.get", json!({"pane_id": pane_id}), timeout)
                    .await?;
                let pane_record = pane_info.get("pane").unwrap_or(&pane_info);
                (
                    object_id(Some(pane_record), "workspace_id"),
                    object_id(Some(pane_record), "tab_id"),
                    Some(pane_id),
                )
            }
            _ => unreachable!(),
        };
        let (Some(workspace_id), Some(tab_id), Some(pane_id)) = (workspace_id, tab_id, pane_id)
        else {
            return Err(BrokerError::new(
                "herdr_protocol_error",
                "layout operation did not return complete Herdr IDs",
            ));
        };
        Ok(Layout {
            workspace_id,
            tab_id,
            pane_id,
            label,
        })
    }

    async fn wait_for_agent_ready(
        &self,
        agent_name: &str,
        timeout_ms: u64,
    ) -> Result<Value, BrokerError> {
        let deadline = Instant::now() + Duration::from_millis(timeout_ms);
        let mut last_error = "agent has not appeared as a named agent yet".to_owned();
        while Instant::now() < deadline {
            match self
                .herdr
                .call(
                    "agent.get",
                    json!({"target": agent_name}),
                    Duration::from_secs(5),
                )
                .await
            {
                Ok(result) => {
                    if let Some(agent) = result.get("agent") {
                        if agent.get("name").and_then(Value::as_str) == Some(agent_name)
                            && agent.get("interactive_ready") == Some(&Value::Bool(true))
                        {
                            return Ok(agent.clone());
                        }
                        if agent.get("agent_status").and_then(Value::as_str) == Some("blocked") {
                            return Err(BrokerError::new(
                                "agent_blocked",
                                format!(
                                    "agent {agent_name} is blocked before receiving the prompt"
                                ),
                            ));
                        }
                        last_error =
                            "agent is visible but interactive_ready is not true".to_owned();
                    }
                }
                Err(error) if matches!(error.code.as_str(), "not_found" | "agent_not_ready") => {
                    last_error = error.message;
                }
                Err(error) => return Err(error),
            }
            tokio::time::sleep(Duration::from_millis(250)).await;
        }
        Err(BrokerError::new(
            "agent_not_ready",
            format!(
                "agent {agent_name} did not become interactive within {timeout_ms}ms: {last_error}"
            ),
        ))
    }

    async fn dispatch(&self, params: Value) -> Result<Value, BrokerError> {
        let object = params
            .as_object()
            .ok_or_else(|| BrokerError::new("invalid_request", "params must be an object"))?;
        if object.get("confirmed") != Some(&Value::Bool(true)) {
            return Err(BrokerError::new(
                "confirmation_required",
                "dispatch requires explicit user confirmation in the orchestrator",
            ));
        }
        let task_id = safe_text(object.get("task_id"), "task_id", 128)?;
        if task_id
            .bytes()
            .enumerate()
            .any(|(index, byte)| !match index {
                0 => byte.is_ascii_alphanumeric(),
                _ => byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'.' | b':' | b'-'),
            })
        {
            return Err(BrokerError::new(
                "invalid_request",
                "task_id contains unsupported characters",
            ));
        }
        let kind = safe_text(object.get("kind"), "kind", 32)?.to_ascii_lowercase();
        if !ALLOWED_KINDS.contains(&kind.as_str()) {
            return Err(BrokerError::new(
                "invalid_request",
                format!("unsupported Herdr agent kind: {kind}"),
            ));
        }
        let cwd = self.cwd(object.get("cwd"))?;
        let prompt = safe_text(object.get("prompt"), "prompt", MAX_PROMPT_BYTES)?;
        if prompt.trim().is_empty() || prompt.len() > MAX_PROMPT_BYTES {
            return Err(BrokerError::new(
                "invalid_request",
                "prompt is invalid or oversized",
            ));
        }
        let agent_name = self.agent_name(object.get("agent_name"), &task_id)?;
        let agent_args = self.agent_args(object.get("agent_args"))?;
        let start_timeout_ms =
            bounded_timeout(object.get("start_timeout_ms"), "start_timeout_ms", 30_000)?;
        for field in ["parent_task_id", "discord_thread_id", "discord_message_id"] {
            if let Some(value) = object.get(field).filter(|v| !v.is_null()) {
                safe_text(Some(value), field, 128)?;
            }
        }
        if let Some(parent) = object.get("parent_task_id").and_then(Value::as_str) {
            self.store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?
                .get(parent)?;
        }
        self.reserve_ids(&task_id, &agent_name)?;

        let result = self
            .dispatch_reserved(DispatchSpec {
                params: object.clone(),
                task_id: task_id.clone(),
                kind,
                cwd,
                prompt,
                agent_name: agent_name.clone(),
                agent_args,
                start_timeout_ms,
            })
            .await;
        self.release_ids(&task_id, &agent_name);
        result
    }

    async fn dispatch_reserved(&self, spec: DispatchSpec) -> Result<Value, BrokerError> {
        let DispatchSpec {
            params,
            task_id,
            kind,
            cwd,
            prompt,
            agent_name,
            agent_args,
            start_timeout_ms,
        } = spec;
        // Snapshot before mutation so the receipt records the context the
        // orchestrator saw when it dispatched.
        let snapshot = self
            .herdr
            .call("session.snapshot", json!({}), Duration::from_secs(30))
            .await?;
        let layout_name = params
            .get("layout")
            .and_then(Value::as_str)
            .unwrap_or("workspace")
            .to_owned();
        let layout = self
            .layout(&Value::Object(params.clone()), &cwd, &task_id)
            .await?;
        let timestamp = now_iso();
        let task = Task {
            task_id: task_id.clone(),
            agent_name: agent_name.clone(),
            agent_kind: kind.clone(),
            cwd: cwd.display().to_string(),
            workspace_id: layout.workspace_id.clone(),
            tab_id: layout.tab_id.clone(),
            pane_id: layout.pane_id.clone(),
            label: layout.label.clone(),
            layout: layout_name,
            state: "layout_created".to_owned(),
            created_at: timestamp.clone(),
            updated_at: timestamp,
            parent_task_id: params
                .get("parent_task_id")
                .and_then(Value::as_str)
                .map(str::to_owned),
            discord_thread_id: params
                .get("discord_thread_id")
                .and_then(Value::as_str)
                .map(str::to_owned),
            discord_message_id: params
                .get("discord_message_id")
                .and_then(Value::as_str)
                .map(str::to_owned),
            error_code: None,
            error_message: None,
        };
        {
            let mut store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
            store.put(task)?;
        }

        let worker_result = async {
            let start = match self
                .herdr
                .call(
                    "agent.start",
                    json!({
                        "name": agent_name,
                        "kind": kind,
                        "pane_id": layout.pane_id,
                        "args": agent_args,
                        "timeout_ms": start_timeout_ms,
                    }),
                    Duration::from_millis(start_timeout_ms).saturating_add(Duration::from_secs(15)),
                )
                .await
            {
                Ok(value) => value,
                Err(error) if matches!(error.code.as_str(), "agent_not_ready" | "timeout") => {
                    json!({"type": "agent_start_pending", "error_code": error.code})
                }
                Err(error) => return Err(error),
            };
            let ready = self
                .wait_for_agent_ready(&agent_name, start_timeout_ms)
                .await?;
            {
                let mut store = self
                    .store
                    .lock()
                    .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
                store.update(&task_id, |task| {
                    task.state = "agent_started".to_owned();
                    task.updated_at = now_iso();
                })?;
            }
            let prompted = self
                .herdr
                .call(
                    "agent.prompt",
                    json!({"target": agent_name, "text": prompt}),
                    Duration::from_secs(30),
                )
                .await?;
            let task = {
                let mut store = self
                    .store
                    .lock()
                    .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
                store.update(&task_id, |task| {
                    task.state = "working".to_owned();
                    task.updated_at = now_iso();
                })?
            };
            Ok::<(Value, Value, Value, Task), BrokerError>((start, ready, prompted, task))
        }
        .await;

        match worker_result {
            Ok((start, ready, prompted, task)) => Ok(json!({
                "type": "dispatch",
                "task": task,
                "herdr_snapshot_before": snapshot,
                "start": start,
                "ready": ready,
                "prompt": prompted,
            })),
            Err(error) => {
                if let Ok(mut store) = self.store.lock() {
                    let _ = store.update(&task_id, |task| {
                        task.state = "blocked".to_owned();
                        task.error_code = Some(error.code.clone());
                        task.error_message = Some(error.message.clone());
                        task.updated_at = now_iso();
                    });
                }
                Err(BrokerError::new(
                    "dispatch_failed",
                    format!("worker dispatch failed: {}", error.message),
                ))
            }
        }
    }

    async fn task_status(&self, params: &Value) -> Result<Value, BrokerError> {
        let task_id = safe_text(params.get("task_id"), "task_id", 128)?;
        let task = {
            let store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
            store.get(&task_id)?
        };
        let agent_result = self
            .herdr
            .call(
                "agent.get",
                json!({"target": task.agent_name}),
                Duration::from_secs(30),
            )
            .await?;
        let state = agent_result
            .get("agent")
            .and_then(|agent| agent.get("agent_status"))
            .and_then(Value::as_str)
            .map(str::to_owned);
        let task = if let Some(state) = state {
            let mut store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
            store.update(&task_id, |task| {
                task.state = state;
                task.updated_at = now_iso();
            })?
        } else {
            task
        };
        Ok(json!({"type": "task_status", "task": task, "agent": agent_result}))
    }

    async fn task_read(&self, params: &Value) -> Result<Value, BrokerError> {
        let task_id = safe_text(params.get("task_id"), "task_id", 128)?;
        let lines = params.get("lines").and_then(Value::as_i64).unwrap_or(120);
        if !(1..=MAX_READ_LINES).contains(&lines) {
            return Err(BrokerError::new(
                "invalid_request",
                format!("lines must be between 1 and {MAX_READ_LINES}"),
            ));
        }
        let task = {
            let store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
            store.get(&task_id)?
        };
        let result = self
            .herdr
            .call(
                "agent.read",
                json!({
                    "target": task.agent_name,
                    "source": "recent_unwrapped",
                    "lines": lines,
                    "format": "text",
                    "strip_ansi": true,
                }),
                Duration::from_secs(30),
            )
            .await?;
        Ok(json!({"type": "task_read", "task": task, "read": result}))
    }

    async fn task_wait(&self, params: &Value) -> Result<Value, BrokerError> {
        let task_id = safe_text(params.get("task_id"), "task_id", 128)?;
        let timeout_ms = bounded_timeout(params.get("timeout_ms"), "timeout_ms", MAX_TIMEOUT_MS)?;
        let until = match params.get("until") {
            None | Some(Value::Null) => {
                vec!["idle".to_owned(), "done".to_owned(), "blocked".to_owned()]
            }
            Some(Value::Array(values)) if !values.is_empty() => values
                .iter()
                .map(|value| {
                    let value = value.as_str().ok_or_else(|| {
                        BrokerError::new(
                            "invalid_request",
                            "until must contain valid Herdr agent states",
                        )
                    })?;
                    if !matches!(value, "idle" | "working" | "blocked" | "done" | "unknown") {
                        return Err(BrokerError::new(
                            "invalid_request",
                            "until must contain valid Herdr agent states",
                        ));
                    }
                    Ok(value.to_owned())
                })
                .collect::<Result<Vec<_>, BrokerError>>()?,
            Some(_) => {
                return Err(BrokerError::new(
                    "invalid_request",
                    "until must contain valid Herdr agent states",
                ))
            }
        };
        let task = {
            let store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
            store.get(&task_id)?
        };
        let result = self
            .herdr
            .call(
                "agent.wait",
                json!({"target": task.agent_name, "until": until, "timeout_ms": timeout_ms}),
                Duration::from_millis(timeout_ms).saturating_add(Duration::from_secs(15)),
            )
            .await?;
        let state = result
            .get("agent")
            .and_then(|agent| agent.get("agent_status"))
            .and_then(Value::as_str)
            .map(str::to_owned);
        let task = if let Some(state) = state {
            let mut store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
            store.update(&task_id, |task| {
                task.state = state;
                task.updated_at = now_iso();
            })?
        } else {
            task
        };
        Ok(json!({"type": "task_wait", "task": task, "wait": result}))
    }

    pub async fn request(&self, operation: &str, params: Value) -> Result<Value, BrokerError> {
        if !params.is_object() {
            return Err(BrokerError::new(
                "invalid_request",
                "params must be an object",
            ));
        }
        self.prune_history()?;
        match operation {
            "history" => self.history(&params),
            "result" => self.task_result(&params).await,
            "health" => Ok(json!({
                "type": "health",
                "herdr": self.herdr.call("ping", json!({}), Duration::from_secs(30)).await?,
            })),
            "snapshot" => {
                self.herdr
                    .call("session.snapshot", json!({}), Duration::from_secs(30))
                    .await
            }
            "tasks" => {
                let store = self
                    .store
                    .lock()
                    .map_err(|_| BrokerError::internal("task store lock was poisoned"))?;
                Ok(json!({"type": "tasks", "tasks": store.list()}))
            }
            "dispatch" => self.dispatch(params).await,
            "status" => self.task_status(&params).await,
            "read" => self.task_read(&params).await,
            "wait" => self.task_wait(&params).await,
            _ => Err(BrokerError::new(
                "unknown_operation",
                format!("unsupported broker operation: {operation}"),
            )),
        }
    }
}

fn prepare_socket(socket_path: &Path) -> Result<(), BrokerError> {
    if let Some(parent) = socket_path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
        fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
            .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
    }
    if socket_path.exists() || socket_path.is_symlink() {
        let metadata = fs::symlink_metadata(socket_path)
            .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
        if !metadata.file_type().is_socket() {
            return Err(BrokerError::new(
                "internal_error",
                format!(
                    "refusing to replace non-socket path: {}",
                    socket_path.display()
                ),
            ));
        }
        fs::remove_file(socket_path)
            .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
    }
    Ok(())
}

async fn handle_connection(stream: UnixStream, broker: Broker) {
    let mut reader = AsyncBufReader::new(stream);
    let mut line = String::new();
    let response = match reader.read_line(&mut line).await {
        Ok(0) => return,
        Ok(_) if line.len() > MAX_REQUEST_BYTES => json!({
            "id": Value::Null,
            "error": {"code": "invalid_json", "message": "request is oversized"}
        }),
        Ok(_) => process_request(&line, &broker).await,
        Err(error) => json!({
            "id": Value::Null,
            "error": {"code": "invalid_request", "message": error.to_string()}
        }),
    };
    let mut stream = reader.into_inner();
    let mut encoded = match serde_json::to_vec(&response) {
        Ok(value) => value,
        Err(error) => {
            error!("cannot encode broker response: {error}");
            return;
        }
    };
    encoded.push(b'\n');
    if let Err(error) = stream.write_all(&encoded).await {
        warn!("cannot write broker response: {error}");
    }
}

async fn process_request(line: &str, broker: &Broker) -> Value {
    let request: Value = match serde_json::from_str(line) {
        Ok(request) => request,
        Err(error) => {
            return json!({
                "id": Value::Null,
                "error": {"code": "invalid_json", "message": error.to_string()}
            })
        }
    };
    let request_id = request.get("id").cloned().unwrap_or(Value::Null);
    let request_object = match request.as_object() {
        Some(request) => request,
        None => {
            return json!({
                "id": request_id,
                "error": {"code": "invalid_request", "message": "request must be a JSON object"}
            })
        }
    };
    if request_object
        .get("id")
        .and_then(Value::as_str)
        .filter(|id| !id.is_empty())
        .is_none()
    {
        return json!({
            "id": request_id,
            "error": {"code": "invalid_request", "message": "request id is required"}
        });
    }
    let Some(operation) = request_object.get("op").and_then(Value::as_str) else {
        return json!({
            "id": request_id,
            "error": {"code": "invalid_request", "message": "op is required"}
        });
    };
    let params = request_object
        .get("params")
        .cloned()
        .unwrap_or_else(|| json!({}));
    match broker.request(operation, params).await {
        Ok(result) => json!({"id": request_id, "result": result}),
        Err(error) => json!({
            "id": request_id,
            "error": {"code": error.code, "message": error.message}
        }),
    }
}

pub async fn run_daemon(
    socket_path: PathBuf,
    herdr_socket: PathBuf,
    state_dir: PathBuf,
    allowed_root: PathBuf,
) -> Result<(), BrokerError> {
    let socket_path = expand_user(socket_path);
    prepare_socket(&socket_path)?;
    let broker = Broker::new(herdr_socket, state_dir, allowed_root)?;
    broker.prune_history()?;
    let listener = UnixListener::bind(&socket_path).map_err(|error| {
        BrokerError::new(
            "internal_error",
            format!(
                "cannot bind broker socket {}: {error}",
                socket_path.display()
            ),
        )
    })?;
    fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o600))
        .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
    info!("listening on {}", socket_path.display());

    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
    let mut interrupt = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::interrupt())
        .map_err(|error| BrokerError::new("internal_error", error.to_string()))?;
    let mut maintenance = tokio::time::interval(Duration::from_secs(3600));
    loop {
        tokio::select! {
            _ = maintenance.tick() => {
                if let Err(error) = broker.prune_history() { error!("history maintenance failed: {error}"); }
            }
            signal = terminate.recv() => {
                info!("received SIGTERM ({signal:?}); stopping");
                break;
            }
            signal = interrupt.recv() => {
                info!("received SIGINT ({signal:?}); stopping");
                break;
            }
            accepted = listener.accept() => {
                match accepted {
                    Ok((stream, _)) => {
                        let broker = broker.clone();
                        tokio::spawn(async move { handle_connection(stream, broker).await; });
                    }
                    Err(error) => warn!("cannot accept broker connection: {error}"),
                }
            }
        }
    }
    drop(listener);
    if let Err(error) = fs::remove_file(&socket_path) {
        if error.kind() != io::ErrorKind::NotFound {
            warn!(
                "cannot remove broker socket {}: {error}",
                socket_path.display()
            );
        }
    }
    Ok(())
}

/// Synchronous client used by the stable dispatch CLI.
pub fn broker_call(
    socket_path: &Path,
    operation: &str,
    params: Value,
    timeout: Duration,
) -> Result<Value, BrokerError> {
    let request_id = format!("herdr-dispatch-{}", Uuid::new_v4().simple());
    let request = json!({"id": request_id, "op": operation, "params": params});
    let mut stream = BlockingUnixStream::connect(socket_path).map_err(|error| {
        BrokerError::new(
            "broker_unavailable",
            format!(
                "cannot connect to broker {}: {error}",
                socket_path.display()
            ),
        )
    })?;
    stream
        .set_read_timeout(Some(timeout))
        .map_err(|error| BrokerError::new("broker_unavailable", error.to_string()))?;
    stream
        .set_write_timeout(Some(timeout))
        .map_err(|error| BrokerError::new("broker_unavailable", error.to_string()))?;
    let mut encoded = serde_json::to_vec(&request)
        .map_err(|error| BrokerError::new("invalid_request", error.to_string()))?;
    encoded.push(b'\n');
    stream.write_all(&encoded).map_err(|error| {
        BrokerError::new(
            "broker_unavailable",
            format!("cannot write request: {error}"),
        )
    })?;
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line).map_err(|error| {
        BrokerError::new(
            "broker_unavailable",
            format!("cannot read response: {error}"),
        )
    })?;
    if line.is_empty() {
        return Err(BrokerError::new(
            "broker_disconnected",
            "broker closed the socket",
        ));
    }
    let response: Value = serde_json::from_str(&line).map_err(|error| {
        BrokerError::new(
            "invalid_response",
            format!("invalid broker response: {error}"),
        )
    })?;
    if let Some(error) = response.get("error").and_then(Value::as_object) {
        return Err(BrokerError::new(
            error.get("code").and_then(Value::as_str).unwrap_or("error"),
            error
                .get("message")
                .and_then(Value::as_str)
                .unwrap_or("request failed"),
        ));
    }
    Ok(response.get("result").cloned().unwrap_or(response))
}

pub fn read_prompt(
    prompt: Option<String>,
    prompt_file: Option<&Path>,
) -> Result<String, BrokerError> {
    if prompt.is_some() && prompt_file.is_some() {
        return Err(BrokerError::new(
            "invalid_request",
            "use only one of --prompt or --prompt-file",
        ));
    }
    if let Some(prompt) = prompt {
        return Ok(prompt);
    }
    if let Some(path) = prompt_file {
        return fs::read_to_string(path).map_err(|error| {
            BrokerError::new(
                "invalid_request",
                format!("cannot read prompt file: {error}"),
            )
        });
    }
    if !stdin_is_terminal() {
        let mut prompt = String::new();
        io::stdin().read_to_string(&mut prompt).map_err(|error| {
            BrokerError::new(
                "invalid_request",
                format!("cannot read prompt from stdin: {error}"),
            )
        })?;
        return Ok(prompt);
    }
    Err(BrokerError::new(
        "invalid_request",
        "dispatch requires --prompt, --prompt-file, or prompt on stdin",
    ))
}

fn stdin_is_terminal() -> bool {
    use std::os::fd::AsRawFd;
    unsafe { libc::isatty(io::stdin().as_raw_fd()) == 1 }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn task_slug_matches_dispatch_naming_rules() {
        assert_eq!(task_slug("Idea/Read Only 001"), "idea-read-only-001");
        assert_eq!(task_slug("---"), "task");
    }

    #[test]
    fn generated_agent_name_stays_within_herdr_limit() {
        let name = generated_agent_name("a-very-long-task-id-that-needs-to-be-truncated");
        assert!(name.len() <= 32);
        assert!(name.starts_with("oa-"));
    }

    #[test]
    fn safe_id_rejects_shell_like_values() {
        assert!(safe_id(Some(&json!("w1:t1")), "tab_id").is_ok());
        assert!(safe_id(Some(&json!("w1; rm -rf")), "tab_id").is_err());
    }
}
