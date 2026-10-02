//! Strict YAML manifest. Relative checkout paths are based on Computer home,
//! never the directory of the private source behind its symlink.
use super::*;
use config::{expand_at, regular_file, supported_kind};
use std::collections::{BTreeMap, HashSet};

pub const COMPUTER_NAME: &str = "computer-orchestrator";
pub fn computer_home() -> Result<PathBuf> {
    let user_home = home()?;
    let raw = env::var_os("HERDR_COMPUTER_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| user_home.join("Work"));
    let expanded = expand_at(&user_home, &raw)?;
    if expanded.as_os_str().is_empty() || !expanded.is_absolute() {
        return fail("HERDR_COMPUTER_HOME must be an absolute directory or ~/ path");
    }
    let root = expanded.canonicalize()?;
    if !root.is_dir() {
        return fail("Computer home must be a directory");
    }
    Ok(root)
}
fn fields(v: &Value, allowed: &[&str], name: &str) -> Result<()> {
    let map = v
        .as_object()
        .ok_or_else(|| error(format!("{name} must be a mapping")))?;
    for key in map.keys() {
        if !allowed.contains(&key.as_str()) {
            return fail(format!("Unknown {name} field: {key}"));
        }
    }
    Ok(())
}
fn path_at(user_home: &Path, v: Option<&Value>, default: PathBuf) -> Result<PathBuf> {
    let path = if let Some(v) = v {
        expand_at(user_home, Path::new(text(v, "path")?))?
    } else {
        default
    };
    if !path.is_absolute() {
        return fail("Configuration paths must be absolute or ~/ paths");
    }
    weak_canonical(&path)
}
fn role(v: &Value, project: bool) -> Result<()> {
    fields(
        v,
        if project {
            &["key", "kind", "launcher", "args"]
        } else {
            &["kind", "launcher", "args"]
        },
        "orchestrator",
    )?;
    supported_kind(text(&v["kind"], "orchestrator kind")?)?;
    let args = argv(v.get("args").unwrap_or(&json!([])), false)?;
    crate::orchestrator::validate_role_args(&args)?;
    if let Some(launcher) = v.get("launcher") {
        argv(launcher, true)?;
    }
    if v.get("launcher").is_some_and(|l| {
        l.as_array().is_some_and(|a| {
            a.iter()
                .any(|v| matches!(v.as_str(), Some("-c" | "-lc" | "--command")))
        })
    }) {
        return fail("Launcher must be executable argv, without an embedded shell command");
    }
    if project
        && !Regex::new(r"^[a-z]([a-z0-9-]{0,9}[a-z0-9])?$")?
            .is_match(text(&v["key"], "orchestrator key")?)
    {
        return fail("Project orchestrator key must be 1..11 lowercase characters");
    }
    Ok(())
}
pub(super) fn parse(raw: &str) -> Result<Value> {
    let mut options = serde_saphyr::Options::default();
    options.merge_keys = serde_saphyr::MergeKeyPolicy::Error;
    options.reject_unsupported_tags = true;
    options.strict_booleans = true;
    if let Some(budget) = options.budget.as_mut() {
        budget.max_aliases = 0;
        budget.max_anchors = 0;
    }
    let value: Value = serde_saphyr::from_str_with_options(raw, options)?;
    fields(
        &value,
        &[
            "version",
            "computer",
            "transport",
            "runtime",
            "binding",
            "projects",
            "project_order",
        ],
        "manifest",
    )?;
    if value["version"] != 1 {
        return fail("Manifest version must be 1");
    }
    if let Some(order) = value.get("project_order") {
        let order = argv(order, false)?;
        let enabled: HashSet<&str> = value["projects"]
            .as_object()
            .ok_or_else(|| error("projects must be a mapping"))?
            .iter()
            .filter(|(_, p)| p["enabled"] == true)
            .map(|(id, _)| id.as_str())
            .collect();
        let selected: HashSet<&str> = order.iter().map(String::as_str).collect();
        if selected.len() != order.len() || selected != enabled {
            return fail("project_order must list every enabled project exactly once");
        }
    }
    fields(
        &value["computer"],
        &["id", "mode", "timezone", "orchestrator"],
        "computer",
    )?;
    if !Regex::new(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")?
        .is_match(text(&value["computer"]["id"], "computer id")?)
    {
        return fail("Invalid computer id");
    }
    if !matches!(
        value["computer"]["mode"].as_str(),
        Some("bound" | "standalone")
    ) {
        return fail("computer.mode must be bound or standalone");
    }
    if let Some(zone) = value["computer"].get("timezone") {
        text(zone, "timezone")?.parse::<chrono_tz::Tz>()?;
    }
    role(&value["computer"]["orchestrator"], false)?;
    for (key, allowed) in [
        ("transport", &["broker_socket"][..]),
        (
            "runtime",
            &["poll_seconds", "broker_state_dir", "execution_state_dir"][..],
        ),
        (
            "binding",
            &[
                "dotfiles_dir",
                "idea_dir",
                "hosts_dir",
                "identity_file",
                "dags_dir",
            ][..],
        ),
    ] {
        if let Some(v) = value.get(key) {
            fields(v, allowed, key)?;
        }
    }
    if let Some(interval) = value["runtime"].get("poll_seconds") {
        if !interval.as_u64().is_some_and(|n| (10..=300).contains(&n)) {
            return fail("poll_seconds must be integer 10..300");
        }
    }
    let ids = Regex::new(r"^[a-z][a-z0-9_-]{0,63}$")?;
    let inputs = Regex::new(r"^[A-Z][A-Z0-9_]{0,63}$")?;
    let placeholders = Regex::new(r"\$\{env:([^}]+)\}")?;
    let mut keys = HashSet::new();
    for (id, p) in value["projects"]
        .as_object()
        .ok_or_else(|| error("projects must be a mapping"))?
    {
        if id == "workspace-check" {
            return fail("workspace-check is reserved for fixed diagnostics");
        }
        if !ids.is_match(id) {
            return fail("Invalid project ID");
        }
        fields(
            p,
            &[
                "enabled",
                "description",
                "path",
                "workspace",
                "orchestrator",
                "tasks",
            ],
            "project",
        )?;
        if !p["enabled"].is_boolean() {
            return fail("Project enabled must be boolean");
        }
        text(&p["path"], "project path")?;
        if let Some(description) = p.get("description") {
            text(description, "description")?;
        }
        role(&p["orchestrator"], true)?;
        if !keys.insert(text(&p["orchestrator"]["key"], "key")?) {
            return fail("Duplicate orchestrator key");
        }
        if let Some(workspace) = p.get("workspace") {
            fields(workspace, &["label"], "workspace")?;
            text(&workspace["label"], "workspace label")?;
        }
        if let Some(launcher) = p["orchestrator"].get("launcher") {
            argv(launcher, true)?;
        }
        let tasks = p["tasks"]
            .as_object()
            .ok_or_else(|| error("tasks must be a mapping"))?;
        for (task, t) in tasks {
            if !ids.is_match(task) {
                return fail("Invalid task ID");
            }
            fields(
                t,
                &[
                    "entrypoint",
                    "verify_entrypoint",
                    "timeout_seconds",
                    "same_day",
                    "input_env",
                    "scope",
                ],
                "task",
            )?;
            text(&t["scope"], "task scope")?;
            let mut command = argv(&t["entrypoint"], true)?;
            if let Some(v) = t.get("verify_entrypoint") {
                command.extend(argv(v, true)?);
            }
            if let Some(v) = t.get("timeout_seconds") {
                if !v.as_u64().is_some_and(|n| (1..=7200).contains(&n)) {
                    return fail("Task timeout must be integer 1..7200");
                }
            }
            if let Some(v) = t.get("same_day") {
                if !v.is_boolean() {
                    return fail("same_day must be boolean");
                }
            }
            let names = argv(t.get("input_env").unwrap_or(&json!([])), false)?;
            let mut unique = HashSet::new();
            for name in &names {
                if !inputs.is_match(name) || !unique.insert(name) {
                    return fail("Invalid/duplicate input_env");
                }
            }
            for arg in command {
                for m in placeholders.captures_iter(&arg) {
                    if !names.iter().any(|n| n == &m[1]) {
                        return fail("Environment placeholder must appear in input_env");
                    }
                }
            }
        }
    }
    Ok(value)
}
impl Host {
    pub(super) fn load_yaml(config: Option<&Path>) -> Result<Self> {
        Self::load_yaml_at(config, computer_home()?, home()?)
    }
    fn load_yaml_at(config: Option<&Path>, root: PathBuf, user_home: PathBuf) -> Result<Self> {
        let file = weak_canonical(
            &config
                .map(Path::to_path_buf)
                .unwrap_or_else(|| root.join("projects.yaml")),
        )?;
        if file.extension().is_some_and(|s| s == "toml") {
            return fail("TOML routing config retired; migrate to projects.yaml");
        }
        let raw = fs::read_to_string(&file)?;
        if raw.len() > 1024 * 1024 {
            return fail("Manifest exceeds 1 MiB");
        }
        let manifest = parse(&raw)?;
        let binding = &manifest["binding"];
        let idea = path_at(&user_home, binding.get("idea_dir"), user_home.join("idea"))?;
        let mut paths = BTreeMap::new();
        paths.insert("workspace".into(), root);
        paths.insert(
            "dotfiles".into(),
            path_at(
                &user_home,
                binding.get("dotfiles_dir"),
                user_home.join(".dotfiles"),
            )?,
        );
        paths.insert(
            "hosts".into(),
            path_at(
                &user_home,
                binding.get("hosts_dir"),
                idea.join("private-config/computers"),
            )?,
        );
        paths.insert("idea".into(), idea);
        paths.insert(
            "identity".into(),
            path_at(
                &user_home,
                binding.get("identity_file"),
                user_home.join(".config/dotfiles/computer-id"),
            )?,
        );
        paths.insert(
            "dags".into(),
            path_at(
                &user_home,
                binding.get("dags_dir"),
                user_home.join(".config/dagu/dags"),
            )?,
        );
        paths.insert(
            "state".into(),
            path_at(
                &user_home,
                manifest["runtime"].get("execution_state_dir"),
                user_home.join(".local/state/workspace-orchestrator"),
            )?,
        );
        let paths = Paths(paths);
        let computer = text(&manifest["computer"]["id"], "computer id")?.to_string();
        let rules = paths
            .get("hosts")
            .join(&computer)
            .join("orchestration-rules");
        for file in ["AGENTS.md", "README.md"] {
            fs::read(paths.get("workspace").join(file))?;
        }
        if manifest["computer"]["mode"] == "bound" {
            regular_file(paths.get("identity"))?;
            if fs::read_to_string(paths.get("identity"))?.trim() != computer {
                return fail("Computer ID differs from bound local identity");
            }
            if paths
                .get("workspace")
                .join("orchestration-rules")
                .canonicalize()?
                != rules.canonicalize()?
            {
                return fail("Selected computer rules differ from Work link");
            }
            for name in ["AGENTS.md", "README.md"] {
                if paths.get("workspace").join(name).canonicalize()?
                    != paths
                        .get("dotfiles")
                        .join("config/workspace")
                        .join(name)
                        .canonicalize()?
                {
                    return fail("Work instructions must resolve to managed dotfiles sources");
                }
            }
            let profile = fs::read_to_string(rules.join("profile"))?;
            let release = fs::read_to_string("/etc/os-release").unwrap_or_default();
            let omarchy = release
                .lines()
                .any(|l| matches!(l, "ID=omarchy" | "ID=\"omarchy\""));
            let valid = match env::consts::OS {
                "macos" => profile.trim() == "mac",
                "linux" => {
                    (omarchy && matches!(profile.trim(), "omarchy-server" | "omarchy-desktop"))
                        || (!omarchy
                            && profile.trim() == "grok-bot"
                            && env::var("USER").as_deref() == Ok("box")
                            && (env::var("CURSOR_AGENT").as_deref() == Ok("1")
                                || Path::new("/exec-daemon").exists()))
                }
                _ => false,
            };
            if !valid {
                return fail("Bound profile does not match local OS");
            }
            fs::read(rules.join("README.md"))?;
        }
        let host = Self {
            paths,
            rules,
            computer,
            kind: text(&manifest["computer"]["orchestrator"]["kind"], "kind")?.into(),
            args: manifest["computer"]["orchestrator"]
                .get("args")
                .cloned()
                .unwrap_or(json!([])),
            interval: manifest["runtime"]["poll_seconds"].as_u64().unwrap_or(30),
            socket: path_at(
                &user_home,
                manifest["transport"].get("broker_socket"),
                user_home.join(".config/herdr-dispatchd/dispatch.sock"),
            )?,
            config: Some(file),
        };
        let mut roots = HashSet::new();
        for p in host.projects()? {
            let cwd = PathBuf::from(text(&p["repo"], "repo")?);
            if cwd == host.paths.get("workspace") || !roots.insert(cwd.clone()) {
                return fail("Duplicate checkout or project uses Computer home");
            }
            let registered = &manifest["projects"][text(&p["project"], "project")?];
            let declared = expand_at(&user_home, Path::new(text(&registered["path"], "path")?))?;
            if !declared.is_absolute() && !cwd.starts_with(host.paths.get("workspace")) {
                return fail("Relative project path escapes Computer home");
            }
            if let Some(launcher) = p["route"].get("launcher") {
                let args = argv(launcher, true)?;
                for (i, arg) in args.iter().enumerate() {
                    if i == 0 && Path::new(arg).is_absolute() {
                        continue;
                    }
                    if arg.contains('/') || cwd.join(arg).exists() {
                        let expanded = expand_at(&user_home, Path::new(arg))?;
                        let path = weak_canonical(&if expanded.is_absolute() {
                            expanded
                        } else {
                            cwd.join(expanded)
                        })?;
                        if !path.starts_with(&cwd) {
                            return fail("Launcher argument escapes checkout");
                        }
                    }
                }
            }
        }
        Ok(host)
    }
    pub(super) fn yaml(&self) -> Result<Value> {
        parse(&fs::read_to_string(
            self.config
                .as_ref()
                .ok_or_else(|| error("Missing YAML config"))?,
        )?)
    }
    pub fn broker_state_dir(&self) -> Result<PathBuf> {
        path_at(
            &home()?,
            self.yaml()?["runtime"].get("broker_state_dir"),
            home()?.join(".config/herdr-dispatchd"),
        )
    }
    pub fn broker_policy(&self) -> Result<Value> {
        let mut tasks = serde_json::Map::new();
        for p in self.projects()? {
            let id = text(&p["project"], "project")?;
            let registry = self.registry()?;
            let mut registered = serde_json::Map::new();
            for task in registry[id]["tasks"].as_object().unwrap().keys() {
                registered.insert(task.clone(), self.task(id, task)?);
            }
            tasks.insert(id.into(), json!(registered));
        }
        Ok(
            json!({"binding":self.role_binding()?,"tasks":tasks,"retired_names":["orchestrator"],
            "source":self.config,"deployment":{"paths":self.paths.json(),"broker_socket":self.socket,"broker_state_dir":self.broker_state_dir()?}}),
        )
    }
    pub fn role_binding(&self) -> Result<Value> {
        let projects = self
            .projects()?
            .into_iter()
            .map(|p| {
                (
                    p["project"].as_str().unwrap().to_string(),
                    p["route"].clone(),
                )
            })
            .collect::<serde_json::Map<_, _>>();
        Ok(
            json!({"protocol":2,"computer_id":self.computer,"computer_home":self.paths.get("workspace"),"kind":self.kind,"computer_name":COMPUTER_NAME,"computer_launch":{"args":self.args,"launcher":self.computer_launcher()?},"project_order":self.projects()?.iter().map(|p|p["project"].clone()).collect::<Vec<_>>(),"projects":projects,"digest":sha256(serde_json::to_vec(&self.yaml()?)?.as_slice())}),
        )
    }
    pub(super) fn computer_launcher(&self) -> Result<Value> {
        if self.config.is_none() {
            return Ok(Value::Null);
        }
        Ok(self.yaml()?["computer"]["orchestrator"]
            .get("launcher")
            .cloned()
            .unwrap_or(Value::Null))
    }
    pub(super) fn yaml_registry(&self) -> Result<Value> {
        let mut rows = self.yaml()?["projects"].clone();
        for (id, p) in rows.as_object_mut().unwrap() {
            p["repo"] = p["path"].clone();
            p["workspace_label"] = p["workspace"]["label"]
                .as_str()
                .map(|s| json!(s))
                .unwrap_or_else(|| json!(id));
            p["orchestrator"]["name"] = json!(format!(
                "project-orchestrator-{}",
                p["orchestrator"]["key"].as_str().unwrap()
            ));
        }
        Ok(rows)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn basic() -> String {
        "version: 1\ncomputer:\n  id: local-machine\n  mode: standalone\n  orchestrator: {kind: codex}\nprojects: {}\n".into()
    }
    #[test]
    fn strict_yaml() {
        assert!(parse(&basic()).is_ok());
        for suffix in [
            "version: 1\n",
            "unknown: true\n",
            "---\nversion: 1\n",
            "binding: &a {}\ntransport: *a\n",
            "binding: !custom {}\n",
            "binding: {<<: {}}\n",
        ] {
            assert!(parse(&(basic() + suffix)).is_err(), "{suffix}");
        }
    }
    #[test]
    fn role_args_cannot_change_permissions() {
        assert!(role(
            &json!({"kind":"codex","args":["--dangerously-bypass-approvals-and-sandbox"]}),
            false
        )
        .is_err());
    }
    #[test]
    fn explicit_launchers_and_fast_model_options() {
        assert!(role(&json!({"kind":"codex","launcher":["codex","--yolo"],"args":["--model","gpt-6.1-sol","-c","model_reasoning_effort=medium","-c","service_tier=fast"]}), false).is_ok());
        assert!(role(&json!({"kind":"codex","launcher":[]}), false).is_err());
        assert!(role(
            &json!({"kind":"codex","launcher":["bash","-lc","codex --yolo"]}),
            false
        )
        .is_err());
        assert!(role(
            &json!({"kind":"codex","args":["-c","approval_policy=never"]}),
            false
        )
        .is_err());
    }
    #[test]
    fn project_order_requires_exact_enabled_inventory() {
        let raw=basic().replace("projects: {}", "projects:\n  media:\n    enabled: true\n    path: github/media\n    orchestrator: {key: media, kind: codex}\n    tasks: {}\n  other:\n    enabled: false\n    path: github/other\n    orchestrator: {key: other, kind: codex}\n    tasks: {}\n");
        assert!(parse(&(raw.clone() + "project_order: [media]\n")).is_ok());
        for order in ["[]", "[media, media]", "[missing]", "[media, other]"] {
            assert!(parse(&(raw.clone() + &format!("project_order: {order}\n"))).is_err());
        }
    }
    #[test]
    fn yaml_paths_and_registry_bind_to_computer_root() {
        let base = env::temp_dir().join(format!("yaml-host-{}", Uuid::new_v4()));
        let root = base.join("computer");
        let repo = root.join("github/media");
        let outside = base.join("outside");
        fs::create_dir_all(&repo).unwrap();
        fs::create_dir_all(&outside).unwrap();
        for p in [&root, &repo, &outside] {
            for name in ["AGENTS.md", "README.md"] {
                fs::write(p.join(name), "instructions").unwrap();
            }
        }
        for p in [&repo, &outside] {
            assert!(std::process::Command::new("git")
                .args(["init", "-q"])
                .arg(p)
                .status()
                .unwrap()
                .success());
        }
        let config = base.join("private-source.yaml");
        let manifest=basic().replace("projects: {}", "projects:\n  media:\n    enabled: true\n    path: github/media\n    orchestrator: {key: media, kind: codex}\n    tasks: {} ");
        fs::write(&config, &manifest).unwrap();
        let host = Host::load_yaml_at(Some(&config), root.clone(), base.clone()).unwrap();
        assert_eq!(host.project("media").unwrap()["repo"], json!(repo));
        assert_eq!(
            host.project("media").unwrap()["route"]["name"],
            "project-orchestrator-media"
        );
        assert!(host
            .reply_prefix()
            .unwrap()
            .contains("HERDR_COMPUTER_HOME="));
        assert!(host
            .reply_prefix()
            .unwrap()
            .contains(&config.to_string_lossy().to_string()));
        fs::write(&config, manifest.replace("github/media", "../outside")).unwrap();
        assert!(Host::load_yaml_at(Some(&config), root.clone(), base.clone()).is_err());
        fs::write(
            &config,
            manifest.replace("github/media", outside.to_str().unwrap()),
        )
        .unwrap();
        assert!(Host::load_yaml_at(Some(&config), root.clone(), base.clone()).is_ok());
        fs::write(
            &config,
            manifest.replace("github/media", "github/media/subdir"),
        )
        .unwrap();
        fs::create_dir(repo.join("subdir")).unwrap();
        for name in ["AGENTS.md", "README.md"] {
            fs::write(repo.join("subdir").join(name), "nested").unwrap();
        }
        assert!(Host::load_yaml_at(Some(&config), root.clone(), base.clone()).is_err());
        fs::write(
            &config,
            manifest
                .replace("enabled: true", "enabled: false")
                .replace("github/media", "missing-checkout"),
        )
        .unwrap();
        assert!(Host::load_yaml_at(Some(&config), root, base.clone())
            .unwrap()
            .projects()
            .unwrap()
            .is_empty());
        fs::remove_dir_all(base).unwrap();
    }
}
