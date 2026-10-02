use super::*;
use std::collections::BTreeMap;
use std::path::Component;

const VARIABLES: &[(&str, &str)] = &[
    ("dotfiles", "DOTFILES_DIR"),
    ("idea", "WORKSPACE_IDEA_ROOT"),
    ("workspace", "WORKSPACE_ROOT"),
    ("dags", "WORKSPACE_DAGU_DAGS_DIR"),
    ("hosts", "WORKSPACE_HOSTS_DIR"),
    ("identity", "WORKSPACE_ID_FILE"),
    ("state", "WORKSPACE_ORCHESTRATOR_STATE_DIR"),
];

#[derive(Clone, Debug)]
pub struct Paths(pub BTreeMap<String, PathBuf>);
impl Paths {
    pub fn get(&self, key: &str) -> &Path {
        &self.0[key]
    }
    pub fn json(&self) -> Value {
        json!(self.0)
    }
    pub fn resolve(config: Option<&Path>) -> Result<Self> {
        let home = home()?;
        let config = config
            .map(Path::to_path_buf)
            .or_else(|| env::var_os("WORKSPACE_PATHS_FILE").map(PathBuf::from))
            .unwrap_or_else(|| home.join(".config/dotfiles/workspace.toml"));
        let overrides = VARIABLES
            .iter()
            .filter_map(|(key, var)| env::var(var).ok().map(|v| (key.to_string(), v)))
            .collect();
        Self::resolve_at(&home, &config, &overrides)
    }
    pub(super) fn resolve_at(
        home: &Path,
        config: &Path,
        overrides: &BTreeMap<String, String>,
    ) -> Result<Self> {
        let config = expand_at(home, config)?;
        let values = match fs::symlink_metadata(&config) {
            Ok(_) => {
                regular_file(&config)?;
                read_toml(&config)?
            }
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => json!({}),
            Err(err) => return Err(err.into()),
        };
        let configured = values.get("paths").and_then(Value::as_object);
        if values.get("paths").is_some() && configured.is_none() {
            return fail("paths must be a TOML table");
        }
        if let Some(values) = configured {
            for key in values.keys() {
                if !VARIABLES.iter().any(|(known, _)| known == key) {
                    return fail(format!("Unknown workspace path key: {key}"));
                }
            }
        }
        let mut paths = BTreeMap::new();
        for (key, _) in VARIABLES {
            let default = match *key {
                "dotfiles" => home.join(".dotfiles"),
                "idea" => home.join("idea"),
                "workspace" => home.join("Work"),
                "dags" => home.join(".config/dagu/dags"),
                "identity" => home.join(".config/dotfiles/computer-id"),
                "state" => home.join(".local/state/workspace-orchestrator"),
                "hosts" => paths
                    .get("idea")
                    .cloned()
                    .unwrap_or_else(|| home.join("idea"))
                    .join("private-config/computers"),
                _ => unreachable!(),
            };
            let value = overrides
                .get(*key)
                .map(String::as_str)
                .or_else(|| configured.and_then(|v| v.get(*key)).and_then(Value::as_str));
            if value.is_none() && configured.and_then(|v| v.get(*key)).is_some() {
                return fail(format!("Invalid path value: {key}"));
            }
            let path = if let Some(value) = value {
                if value.is_empty() || value.contains(['\0', '\n']) {
                    return fail(format!("Invalid path: {key}"));
                }
                expand_at(home, Path::new(value))?
            } else {
                default
            };
            if !path.is_absolute() {
                return fail(format!(
                    "Workspace path must be absolute or ~/ relative: {key}"
                ));
            }
            paths.insert(key.to_string(), weak_canonical(&path)?);
        }
        Ok(Self(paths))
    }
    pub fn shell(&self) -> String {
        VARIABLES
            .iter()
            .map(|(key, var)| format!("export {var}={}", quote(&self.0[*key].to_string_lossy())))
            .collect::<Vec<_>>()
            .join("\n")
    }
}
pub(super) fn home() -> Result<PathBuf> {
    env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| error("HOME is required"))
}
pub(super) fn expand_at(home: &Path, path: &Path) -> Result<PathBuf> {
    let text = path.to_str().ok_or_else(|| error("Path must be UTF-8"))?;
    Ok(if text == "~" {
        home.to_path_buf()
    } else if let Some(rest) = text.strip_prefix("~/") {
        home.join(rest)
    } else {
        path.to_path_buf()
    })
}
pub(super) fn weak_canonical(path: &Path) -> Result<PathBuf> {
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        env::current_dir()?.join(path)
    };
    let mut resolved = PathBuf::new();
    for component in absolute.components() {
        match component {
            Component::ParentDir => {
                resolved.pop();
            }
            Component::CurDir => {}
            other => {
                resolved.push(other.as_os_str());
                if let Ok(canonical) = resolved.canonicalize() {
                    resolved = canonical;
                }
            }
        }
    }
    Ok(resolved)
}
pub(super) fn regular_file(path: &Path) -> Result<()> {
    let metadata = fs::symlink_metadata(path)?;
    if !metadata.file_type().is_file() {
        return fail(format!("Must be a local regular file: {}", path.display()));
    }
    Ok(())
}
pub(super) fn read_toml(path: &Path) -> Result<Value> {
    let value: toml::Value = toml::from_str(&fs::read_to_string(path)?)?;
    Ok(serde_json::to_value(value)?)
}

#[derive(Clone, Debug)]
pub struct Host {
    pub paths: Paths,
    pub rules: PathBuf,
    pub computer: String,
    pub kind: String,
    pub args: Value,
    pub interval: u64,
    pub socket: PathBuf,
    pub config: Option<PathBuf>,
}
impl Host {
    pub fn load(config: Option<&Path>) -> Result<Self> {
        Self::load_yaml(config).map_err(|e| {
            std::io::Error::new(std::io::ErrorKind::InvalidInput, e.to_string()).into()
        })
    }
    pub fn check(&self) -> Value {
        json!({"computer_name":"computer-orchestrator","config":self.config,"computer_id":self.computer,"rules":self.rules,"kind":self.kind,"broker_socket":self.socket,"paths":self.paths.json()})
    }
    pub fn bootstrap(&self) -> String {
        format!("You are the fixed local Herdr Orchestrator for computer {}.\nRead Work AGENTS.md and README.md, then selected orchestration rules.\nResolved local paths: {}\nSelected private rules: {}\nKeep cwd at configured Work root. Manage only this computer. Preserve existing workers and dirty repositories. Dagu events go Computer -> fixed Project, which owns project handlers/producers/workers. Follow project topic and release gates. Do not do business work merely because this bootstrap ran. Do not publish, send messages, bypass approvals or replay uncertain work. Read host task definitions and confirm readiness for authorized work.",self.computer,self.paths.json(),self.rules.display())
    }
    pub fn call(&self, action: &str, mut values: Value) -> Result<Value> {
        let operation = if action == "ensure_project" {
            "ensure_project_orchestrator"
        } else {
            "orchestrator_event"
        };
        if self.config.is_some() {
            values["role_binding"] = self.role_binding()?;
        }
        values["cwd"] = json!(self.paths.get("workspace"));
        values["kind"] = json!(self.kind);
        if action != "ensure_project" {
            values["action"] = json!(action);
        }
        Ok(crate::broker_call(
            &self.socket,
            operation,
            values,
            Duration::from_secs(140),
        )?)
    }
    pub fn ensure(&self) -> Result<Value> {
        let result = crate::broker_call(
            &self.socket,
            "ensure_orchestrator",
            json!({"confirmed":true,"cwd":self.paths.get("workspace"),"kind":self.kind,"agent_name":"computer-orchestrator","role_binding":self.role_binding()?,"agent_args":self.args,"prompt":self.bootstrap(),"start_timeout_ms":30000}),
            Duration::from_secs(210),
        )?;
        atomic_json(
            &self.paths.get("state").join("lifecycle.json"),
            &json!({"computer_id":self.computer,"observed_at":timestamp(),"response":result}),
        )?;
        Ok(result)
    }
    pub fn reply_prefix(&self) -> Result<String> {
        let config = self
            .config
            .as_ref()
            .ok_or_else(|| error("Callback requires an absolute YAML config"))?;
        Ok(format!(
            "env {} {} --config {}",
            quote(&format!(
                "HERDR_COMPUTER_HOME={}",
                self.paths.get("workspace").display()
            )),
            quote(&home()?.join(".local/bin/herdr-dispatch").to_string_lossy()),
            quote(&config.to_string_lossy())
        ))
    }
    pub fn registry(&self) -> Result<Value> {
        if self.config.is_some() {
            return self.yaml_registry();
        }
        #[cfg(not(test))]
        return fail("A YAML project registry is required");
        #[cfg(test)]
        let path = self.rules.join("projects.toml");
        #[cfg(test)]
        Ok(if path.exists() {
            read_toml(&path)?["projects"].clone()
        } else {
            json!({})
        })
    }
    pub fn project_cwd(&self, selected: &Value) -> Result<PathBuf> {
        let repo = text(&selected["repo"], "project repo")?;
        let path = expand_at(&home()?, Path::new(repo))?;
        let cwd = weak_canonical(&if path.is_absolute() {
            path
        } else {
            self.paths.get("workspace").join(path)
        })?;
        if !cwd.is_dir() || !cwd.join("AGENTS.md").is_file() || !cwd.join("README.md").is_file() {
            return fail("Registered project path/instructions missing");
        }
        Ok(cwd)
    }
    pub fn project(&self, id: &str) -> Result<Value> {
        let selected = &self.registry()?[id];
        if selected["enabled"] != true {
            return fail("Project is not enabled on this computer");
        }
        let cwd = self.project_cwd(selected)?;
        let output = std::process::Command::new("git")
            .args(["-C"])
            .arg(&cwd)
            .args(["rev-parse", "--show-toplevel"])
            .output()?;
        if !output.status.success()
            || weak_canonical(Path::new(String::from_utf8(output.stdout)?.trim()))? != cwd
        {
            return fail("Project cwd must be its Git repository root");
        }
        let agent = &selected["orchestrator"];
        let name = text(&agent["name"], "project agent name")?;
        if !Regex::new(r"^project-(?:orchestrator-)?[a-z0-9_-]{1,24}$")?.is_match(name) {
            return fail("Project needs a unique project-* name");
        }
        let kind = agent["kind"].as_str().unwrap_or("codex");
        supported_kind(kind)?;
        let args = agent.get("args").cloned().unwrap_or_else(|| json!([]));
        argv(&args, false)?;
        let mut route = json!({"name":name,"kind":kind,"cwd":cwd,"args":args});
        if let Some(launcher) = agent.get("launcher") {
            argv(launcher, true)?;
            route["launcher"] = launcher.clone();
        }
        Ok(
            json!({"project":id,"repo":cwd,"workspace_label":selected["workspace_label"].as_str().unwrap_or(id),"route":route,"tasks":selected["tasks"].as_object().map(|m|m.iter().map(|(id,t)|json!({"task":id,"scope":t["scope"],"input_env":t.get("input_env").cloned().unwrap_or(json!([])),"has_verifier":t.get("verify_entrypoint").is_some()})).collect::<Vec<_>>()).unwrap_or_default()}),
        )
    }
    pub fn projects(&self) -> Result<Vec<Value>> {
        let registry = self.registry()?;
        let mut projects = Vec::new();
        let mut names = std::collections::HashSet::new();
        if let Some(rows) = registry.as_object() {
            for (id, p) in rows {
                if p["enabled"] == true {
                    let p = self.project(id)?;
                    if !names.insert(p["route"]["name"].clone().to_string()) {
                        return fail("Managed project agent names must be unique");
                    }
                    projects.push(p);
                }
            }
        }
        Ok(projects)
    }
    pub fn ensure_project(&self, id: &str, adopt: Option<&str>) -> Result<Value> {
        let selected = self.project(id)?;
        let bootstrap=format!("You are the fixed Project Orchestrator {} for {id}. Your cwd is {}. Read AGENTS.md/README.md, check Git state and preserve existing work. Computer Orchestrator at Work is your Dagu parent. Own project planning, producers and workers. Acknowledge correlated events before registered entrypoint execution; return results through Computer. Preserve launchers, topic/editor/release gates. This initializes the role only; do not start production.",selected["route"]["name"],selected["repo"]);
        self.call("ensure_project",json!({"confirmed":true,"project":id,"route":selected["route"],"workspace_label":selected["workspace_label"],"bootstrap":bootstrap,"adopt_pane":adopt}))
    }
    pub fn task(&self, project: &str, task: &str) -> Result<Value> {
        if self.config.is_some() && project == "workspace-check" && task == "read-only-probe" {
            return Ok(
                json!({"project":project,"task":task,"project_cwd":self.paths.get("workspace"),"definition":{"entrypoint":["python3","-c","from pathlib import Path; import hashlib,json; p=Path.cwd(); a=p/'AGENTS.md'; assert a.is_file(); print(json.dumps({'cwd':str(p),'agents_sha256':hashlib.sha256(a.read_bytes()).hexdigest(),'read_only':True}))"],"timeout_seconds":30,"scope":"Read-only event transport acceptance; no project work or external messages."}}),
            );
        }
        let registry = self.registry()?;
        let selected = &registry[project];
        let definition = &selected["tasks"][task];
        if !definition.is_object() {
            return fail("Project/task is not registered on this computer");
        }
        let cwd = self.project_cwd(selected)?;
        argv(&definition["entrypoint"], true)?;
        let timeout = definition["timeout_seconds"].as_u64().unwrap_or(7200);
        if !(1..=7200).contains(&timeout)
            || definition
                .get("timeout_seconds")
                .is_some_and(|v| v.as_u64().is_none())
        {
            return fail("Registered timeout must be integer between 1 and 7200");
        }
        let mut payload =
            json!({"project":project,"task":task,"project_cwd":cwd,"definition":definition});
        if selected["internal"] == true {
            if cwd != self.paths.get("workspace") {
                return fail("Internal probes must use Work cwd");
            }
        } else {
            payload["project_agent"] = self.project(project)?["route"].clone();
        }
        Ok(payload)
    }
}
pub(super) fn supported_kind(kind: &str) -> Result<()> {
    if !matches!(kind, "codex" | "claude" | "pi" | "grok") {
        return fail("Unsupported orchestrator kind");
    }
    Ok(())
}
