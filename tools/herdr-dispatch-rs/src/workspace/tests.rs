use super::*;
use std::collections::BTreeMap;
use std::io::{BufRead, BufReader};
use std::os::unix::fs::symlink;
use std::os::unix::net::UnixListener;

struct Fixture {
    root: PathBuf,
    host: Host,
}
impl Fixture {
    fn new() -> Self {
        let root = env::temp_dir().join(format!("rust-orch-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).unwrap();
        let mut paths = BTreeMap::new();
        for key in ["workspace", "dotfiles", "idea", "dags", "hosts", "state"] {
            let path = root.join(key);
            fs::create_dir(&path).unwrap();
            paths.insert(key.into(), path);
        }
        paths.insert("identity".into(), root.join("computer-id"));
        let paths = Paths(paths);
        let rules = paths.get("hosts").join("fixture/orchestration-rules");
        fs::create_dir_all(&rules).unwrap();
        for file in ["AGENTS.md", "README.md"] {
            fs::write(paths.get("workspace").join(file), "fixture rules").unwrap();
        }
        let host = Host {
            paths,
            rules,
            computer: "fixture".into(),
            kind: "codex".into(),
            args: json!([]),
            interval: 30,
            socket: root.join("dispatch.sock"),
            config: None,
        };
        Self { root, host }
    }
    fn task(&self, timeout: u64, same_day: bool) -> Value {
        let effect = self.root.join("effect");
        let task = json!({"entrypoint":["/bin/sh","-c","printf once >> \"$1\"","fixture",effect],"timeout_seconds":timeout,"same_day":same_day});
        let registry = toml::Value::try_from(
            json!({"projects":{"internal":{"internal":true,"repo":".","tasks":{"probe":task}}}}),
        )
        .unwrap();
        fs::write(
            self.host.rules.join("projects.toml"),
            toml::to_string(&registry).unwrap(),
        )
        .unwrap();
        self.host.task("internal", "probe").unwrap()
    }
    fn event(&self, payload: Value) -> Value {
        json!({"event_id":"fixture:event:probe","nonce":"fixture-nonce","state":"accepted","terminal_id":"generation","payload":payload})
    }
    fn broker(&self, replies: Vec<(&'static str, Value)>) -> std::thread::JoinHandle<Vec<Value>> {
        let listener = UnixListener::bind(&self.host.socket).unwrap();
        listener.set_nonblocking(true).unwrap();
        std::thread::spawn(move || {
            let mut requests = Vec::new();
            for (expected, result) in replies {
                let deadline = Instant::now() + Duration::from_secs(5);
                let (mut stream, _) = loop {
                    match listener.accept() {
                        Ok(value) => break value,
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            assert!(
                                Instant::now() < deadline,
                                "Missing broker request {expected}"
                            );
                            std::thread::sleep(Duration::from_millis(5));
                        }
                        Err(e) => panic!("{e}"),
                    }
                };
                stream
                    .set_read_timeout(Some(Duration::from_secs(2)))
                    .unwrap();
                let mut line = String::new();
                BufReader::new(stream.try_clone().unwrap())
                    .read_line(&mut line)
                    .unwrap();
                let request: Value = serde_json::from_str(&line).unwrap();
                assert_eq!(request["op"], "orchestrator_event");
                assert_eq!(request["params"]["action"], expected);
                writeln!(stream, "{}", json!({"id":request["id"],"result":result})).unwrap();
                requests.push(request);
            }
            requests
        })
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}
#[test]
fn custom_paths_env_precedence_dependent_hosts_and_shell_metacharacters() {
    let f = Fixture::new();
    let home = f.root.join("home with spaces $()");
    fs::create_dir(&home).unwrap();
    let config = f.root.join("paths.toml");
    fs::write(
        &config,
        "[paths]\nidea='~/private ideas'\nworkspace='/tmp/quoted work $()'\n",
    )
    .unwrap();
    let overrides = BTreeMap::from([(
        "workspace".into(),
        home.join("override Work").to_string_lossy().to_string(),
    )]);
    let paths = Paths::resolve_at(&home, &config, &overrides).unwrap();
    assert_eq!(paths.get("idea"), home.join("private ideas"));
    assert_eq!(
        paths.get("hosts"),
        home.join("private ideas/private-config/computers")
    );
    assert_eq!(paths.get("workspace"), home.join("override Work"));
    assert!(paths.shell().contains("export WORKSPACE_ROOT='"));
}
#[test]
fn config_symlink_unknown_keys_and_relative_locations_fail_closed() {
    let f = Fixture::new();
    let config = f.root.join("paths.toml");
    for content in [
        "[paths]\nunknown='/tmp'\n",
        "[paths]\nworkspace='relative'\n",
        "[paths]\nworkspace=12\n",
    ] {
        fs::write(&config, content).unwrap();
        assert!(Paths::resolve_at(&f.root, &config, &BTreeMap::new()).is_err());
    }
    let link = f.root.join("linked-config");
    symlink(&config, &link).unwrap();
    assert!(Paths::resolve_at(&f.root, &link, &BTreeMap::new()).is_err());
    assert!(config::regular_file(&link).is_err());
}
#[test]
fn canonical_paths_follow_existing_links_without_requiring_state_directory() {
    let f = Fixture::new();
    symlink(f.host.paths.get("workspace"), f.root.join("work-link")).unwrap();
    let path = f.root.join("work-link/not-created/../state");
    assert_eq!(
        weak_canonical(&path).unwrap(),
        f.host.paths.get("workspace").join("state")
    );
}
#[test]
fn project_requires_repo_root_and_unique_enabled_identity() {
    let f = Fixture::new();
    let repo = f.host.paths.get("workspace").join("repo");
    fs::create_dir(&repo).unwrap();
    assert!(std::process::Command::new("git")
        .arg("init")
        .arg("-q")
        .arg(&repo)
        .status()
        .unwrap()
        .success());
    for file in ["AGENTS.md", "README.md"] {
        fs::write(repo.join(file), "fixture").unwrap();
    }
    fs::write(f.host.rules.join("projects.toml"),"[projects.media]\nenabled=true\nrepo='repo'\n[projects.media.orchestrator]\nname='project-media'\n[projects.probe]\ninternal=true\nrepo='.'\n").unwrap();
    assert_eq!(f.host.projects().unwrap().len(), 1);
    assert_eq!(
        f.host.project("media").unwrap()["route"]["cwd"],
        json!(repo)
    );
    let nested = repo.join("nested");
    fs::create_dir(&nested).unwrap();
    for file in ["AGENTS.md", "README.md"] {
        fs::write(nested.join(file), "nested").unwrap();
    }
    let path = f.host.rules.join("projects.toml");
    fs::write(
        &path,
        fs::read_to_string(&path)
            .unwrap()
            .replace("repo='repo'", "repo='repo/nested'"),
    )
    .unwrap();
    assert!(f
        .host
        .project("media")
        .unwrap_err()
        .to_string()
        .contains("Git repository root"));
}
#[test]
fn internal_probe_cannot_escape_work_and_task_timeout_is_bounded() {
    let f = Fixture::new();
    f.task(30, false);
    let path = f.host.rules.join("projects.toml");
    let original = fs::read_to_string(&path).unwrap();
    for timeout in ["0", "7201", "true"] {
        fs::write(
            &path,
            original.replace(
                "timeout_seconds = 30",
                &format!("timeout_seconds = {timeout}"),
            ),
        )
        .unwrap();
        assert!(f.host.task("internal", "probe").is_err());
    }
    fs::write(&path, original.replace("repo = \".\"", "repo = \"..\"")).unwrap();
    assert!(f.host.task("internal", "probe").is_err());
}
#[test]
fn frozen_arguments_are_data_and_env_placeholders_support_digits() {
    let payload = json!({"trigger_date":"2026-10-02","trigger_slot":"evening","trigger_env":{"INPUT_2":"a' $(touch never)\n"}});
    let args = events::expand_argv(
        &json!(["command", "${date}", "${slot}", "${env:INPUT_2}"]),
        &payload,
    )
    .unwrap();
    assert_eq!(
        args,
        vec!["command", "2026-10-02", "evening", "a' $(touch never)\n"]
    );
    assert!(quote(&args[3]).starts_with("'a'\\''"));
}
#[test]
fn stale_callback_rejects_computer_cwd_nonce_and_changed_generation() {
    let f = Fixture::new();
    let repo = f.host.paths.get("workspace").join("repo");
    fs::create_dir(&repo).unwrap();
    let route = json!({"name":"project-media","cwd":repo,"kind":"codex","args":[]});
    let live = json!({"terminal_id":"generation"});
    let store = json!({"events":{"event":{"state":"accepted","payload":{"project":"media","project_agent":route},"project_delivery":{"state":"submitted","nonce":"project-nonce","terminal_id":"generation"}}}});
    assert!(events::validate_stale_context(
        "project-consume",
        &repo,
        &route,
        &live,
        Some("media"),
        "project-nonce",
        &store
    )
    .is_ok());
    assert!(events::validate_stale_context(
        "project-consume",
        f.host.paths.get("workspace"),
        &route,
        &live,
        Some("media"),
        "project-nonce",
        &store
    )
    .is_err());
    assert!(events::validate_stale_context(
        "project-consume",
        &repo,
        &route,
        &live,
        Some("media"),
        "computer-nonce",
        &store
    )
    .is_err());
    assert!(events::validate_stale_context(
        "project-consume",
        &repo,
        &route,
        &json!({"terminal_id":"replacement"}),
        Some("media"),
        "project-nonce",
        &store
    )
    .is_err());
}
#[tokio::test]
async fn executor_claim_is_exclusive_and_receipt_survives_lost_model_context() {
    let f = Fixture::new();
    let event = f.event(f.task(30, false));
    let thread = f.broker(vec![
        ("resolve", json!({"terminal_id":"generation"})),
        ("claim", json!({})),
        ("complete", json!({"state":"completed"})),
        ("resolve", json!({"terminal_id":"generation"})),
    ]);
    assert_eq!(
        f.host.execute(event.clone()).await.unwrap()["state"],
        "completed"
    );
    assert!(f
        .host
        .execute(event)
        .await
        .unwrap_err()
        .to_string()
        .contains("claim unavailable"));
    let requests = thread.join().unwrap();
    assert_eq!(requests.len(), 4);
    assert_eq!(requests[2]["params"]["result"]["exit_code"], 0);
    assert_eq!(fs::read_to_string(f.root.join("effect")).unwrap(), "once");
    let claims = fs::read_dir(f.host.paths.get("state").join("execution-claims"))
        .unwrap()
        .map(|p| p.unwrap().path())
        .collect::<Vec<_>>();
    assert_eq!(
        claims
            .iter()
            .filter(|p| p.to_string_lossy().ends_with("result.json"))
            .count(),
        1
    );
    assert!(claims
        .iter()
        .all(|p| fs::metadata(p).unwrap().permissions().mode() & 0o777 == 0o600));
}
#[tokio::test]
async fn handler_timeout_preserves_unknown_receipt_and_never_completes_or_replays() {
    let f = Fixture::new();
    let mut payload = f.task(1, false);
    payload["definition"]["entrypoint"] = json!(["/bin/sh", "-c", "sleep 10"]);
    let registry=toml::Value::try_from(json!({"projects":{"internal":{"internal":true,"repo":".","tasks":{"probe":payload["definition"]}}}})).unwrap();
    fs::write(
        f.host.rules.join("projects.toml"),
        toml::to_string(&registry).unwrap(),
    )
    .unwrap();
    let event = f.event(payload);
    let thread = f.broker(vec![
        ("resolve", json!({"terminal_id":"generation"})),
        ("claim", json!({})),
    ]);
    assert!(f
        .host
        .execute(event)
        .await
        .unwrap_err()
        .to_string()
        .contains("effects unknown"));
    thread.join().unwrap();
    let receipt = fs::read_dir(f.host.paths.get("state").join("execution-claims"))
        .unwrap()
        .map(|p| p.unwrap().path())
        .find(|p| p.to_string_lossy().ends_with("result.json"))
        .unwrap();
    assert_eq!(read_json(&receipt).unwrap()["outcome"], "timeout");
    assert!(!f.root.join("effect").exists());
}
#[tokio::test]
async fn expired_trigger_day_returns_failure_without_execution_claim() {
    let f = Fixture::new();
    let mut payload = f.task(30, true);
    payload["trigger_date"] = json!("2000-01-01");
    let thread = f.broker(vec![
        ("resolve", json!({"terminal_id":"generation"})),
        ("complete", json!({"state":"failed"})),
    ]);
    assert_eq!(
        f.host.execute(f.event(payload)).await.unwrap()["state"],
        "failed"
    );
    let requests = thread.join().unwrap();
    assert_eq!(requests[1]["params"]["status"], "failed");
    assert!(!f.host.paths.get("state").join("execution-claims").exists());
    assert!(!f.root.join("effect").exists());
}
#[tokio::test]
async fn unacknowledged_and_changed_definition_events_never_execute() {
    let f = Fixture::new();
    let payload = f.task(30, false);
    let mut event = f.event(payload);
    event["state"] = json!("submitted");
    assert!(f
        .host
        .execute(event.clone())
        .await
        .unwrap_err()
        .to_string()
        .contains("acknowledged"));
    event["state"] = json!("accepted");
    event["payload"]["definition"]["entrypoint"] = json!(["touch", "never"]);
    assert!(f
        .host
        .execute(event)
        .await
        .unwrap_err()
        .to_string()
        .contains("changed after enqueue"));
    assert!(!f.root.join("effect").exists());
}
#[test]
fn health_missing_socket_is_absence_but_unexpected_protocol_preserves_server() {
    let f = Fixture::new();
    let socket = f.root.join("herdr.sock");
    assert!(!monitor::alive(&socket).unwrap());
    let listener = UnixListener::bind(&socket).unwrap();
    let thread = std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut line = String::new();
        BufReader::new(stream.try_clone().unwrap())
            .read_line(&mut line)
            .unwrap();
        let request: Value = serde_json::from_str(&line).unwrap();
        writeln!(
            stream,
            "{}",
            json!({"id":request["id"],"result":{"type":"unexpected"}})
        )
        .unwrap();
    });
    assert!(monitor::alive(&socket)
        .unwrap_err()
        .to_string()
        .contains("preserve existing server"));
    thread.join().unwrap();
}
#[test]
fn service_units_call_only_native_binary_and_preserve_adopted_server() {
    let (unit, server) = install::linux_units(
        Path::new("/path with spaces/workspace-orchestrator"),
        Path::new("/usr/bin/herdr"),
        Some(Path::new("/config $data 100%/paths.toml")),
        "/a$path%:/bin",
    );
    assert!(unit.contains("\"/path with spaces/workspace-orchestrator\" \"watch\" \"--config\" \"/config $$data 100%%/paths.toml\""));
    assert!(unit.contains("Environment=\"PATH=/a$path%%:/bin\""));
    assert!(server.contains("\"server-watch\""));
    assert!(server.contains("KillMode=process"));
    assert!(!unit.contains("python"));
    assert!(!server.contains("python"));
}
#[test]
fn cli_keeps_existing_dagu_callback_and_global_config_positions() {
    assert!(Cli::try_parse_from([
        "workspace-orchestrator",
        "event",
        "submit",
        "--project",
        "media",
        "--task",
        "probe",
        "--dagu",
        "--wait",
        "--timeout",
        "21600",
        "--config",
        "/custom paths.toml"
    ])
    .is_ok());
    assert!(Cli::try_parse_from([
        "workspace-orchestrator",
        "--config",
        "/custom paths.toml",
        "event",
        "bridge",
        "--project",
        "media",
        "--callback",
        "project-consume",
        "--nonce",
        "11111111-1111-1111-1111-111111111111"
    ])
    .is_ok());
    assert!(Cli::try_parse_from([
        "workspace-orchestrator",
        "event",
        "submit",
        "--timeout",
        "-1"
    ])
    .is_err());
}

#[tokio::test]
async fn herdr_cli_timeout_returns_uncertainty_without_waiting_for_child() {
    let mut command = tokio::process::Command::new("/bin/sleep");
    command.arg("10");
    let started = Instant::now();
    assert!(events::bounded_output(command, Duration::from_millis(20))
        .await
        .unwrap_err()
        .to_string()
        .contains("inspect delivery before retrying"));
    assert!(started.elapsed() < Duration::from_secs(1));
}
