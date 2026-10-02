//! Serialized fixed-agent lifecycle. Never repurpose an existing pane.
use super::*;

// Snapshot structure varies by Herdr version. Only choose a workspace when its
// canonical root is evidenced by cwd (never by its label alone).
fn workspaces_at(value: &Value, cwd: &Path, found: &mut Vec<String>) {
    if let Some(object) = value.as_object() {
        if let Some(workspaces) = object.get("workspaces").and_then(Value::as_array) {
            for workspace in workspaces {
                let direct = workspace
                    .get("cwd")
                    .or_else(|| workspace.get("root_cwd"))
                    .and_then(Value::as_str)
                    .and_then(|p| Path::new(p).canonicalize().ok());
                let explicit_root = direct.as_deref() == Some(cwd);
                // Work is a non-Git workspace. On versions without root cwd,
                // require its Work label AND a pane at the canonical Work root.
                let compatible = direct.is_none()
                    && workspace.get("label").and_then(Value::as_str) == Some("Work")
                    && workspace.get("worktree").map_or(true, Value::is_null)
                    && (contains_cwd(workspace, cwd)
                        || object
                            .get("panes")
                            .and_then(Value::as_array)
                            .is_some_and(|panes| {
                                panes.iter().any(|pane| {
                                    pane.get("workspace_id") == workspace.get("workspace_id")
                                        && contains_cwd(pane, cwd)
                                })
                            }));
                if explicit_root || compatible {
                    if let Some(id) = workspace.get("workspace_id").and_then(Value::as_str) {
                        if !found.iter().any(|old| old == id) {
                            found.push(id.to_owned());
                        }
                    }
                }
            }
        }
        for child in object.values() {
            workspaces_at(child, cwd, found);
        }
    } else if let Some(array) = value.as_array() {
        for child in array {
            workspaces_at(child, cwd, found);
        }
    }
}
fn contains_cwd(value: &Value, cwd: &Path) -> bool {
    match value {
        Value::Object(object) => {
            object
                .get("cwd")
                .and_then(Value::as_str)
                .and_then(|p| Path::new(p).canonicalize().ok())
                .as_deref()
                == Some(cwd)
                || object.values().any(|child| contains_cwd(child, cwd))
        }
        Value::Array(array) => array.iter().any(|child| contains_cwd(child, cwd)),
        _ => false,
    }
}
pub(super) fn verify_agent(
    agent: &Value,
    name: &str,
    kind: &str,
    cwd: &Path,
) -> Result<(), BrokerError> {
    let actual_cwd = agent
        .get("cwd")
        .and_then(Value::as_str)
        .and_then(|p| Path::new(p).canonicalize().ok());
    if agent.get("name").and_then(Value::as_str) != Some(name)
        || agent.get("agent").and_then(Value::as_str) != Some(kind)
        || actual_cwd.as_deref() != Some(cwd)
    {
        return Err(BrokerError::new(
            "orchestrator_conflict",
            "The fixed name exists with a different kind or cwd; leave it untouched",
        ));
    }
    if let Some(foreground) = agent.get("foreground_cwd").and_then(Value::as_str) {
        if Path::new(foreground).canonicalize().ok().as_deref() != Some(cwd) {
            return Err(BrokerError::new(
                "orchestrator_conflict",
                "Agent foreground cwd differs from Work root",
            ));
        }
    }
    Ok(())
}
fn validate_role_args(args: &[String]) -> Result<(), BrokerError> {
    let mut index = 0;
    while index < args.len() {
        match args[index].as_str() {
            "-m" | "--model" | "--effort" | "--provider" | "--thinking" => {
                index += 1;
                if index >= args.len() || args[index].is_empty()
                    || !args[index].chars().all(|c| c.is_ascii_alphanumeric() || "/._:-".contains(c)) {
                    return Err(BrokerError::new("invalid_request", "Invalid Orchestrator model option"));
                }
            }
            "-c" => {
                index += 1;
                if index >= args.len() || !["model_reasoning_effort=low", "model_reasoning_effort=medium", "model_reasoning_effort=high", "model_reasoning_effort=xhigh"].contains(&args[index].as_str()) {
                    return Err(BrokerError::new("invalid_request", "Only model effort configuration is allowed"));
                }
            }
            _ => return Err(BrokerError::new("invalid_request", "Orchestrator args may only configure model/provider/effort; cwd and permissions are host-owned")),
        }
        index += 1;
    }
    Ok(())
}
impl Broker {
    pub(super) async fn ensure_orchestrator(&self, params: Value) -> Result<Value, BrokerError> {
        if params.get("confirmed") != Some(&Value::Bool(true)) {
            return Err(BrokerError::new(
                "confirmation_required",
                "Configured lifecycle authorization is required",
            ));
        }
        let cwd = self.cwd(params.get("cwd"))?;
        let name = self.agent_name(params.get("agent_name"), "orchestrator")?;
        if name != "orchestrator"
            || params.get("agent_name").and_then(Value::as_str) != Some(name.as_str())
        {
            return Err(BrokerError::new(
                "invalid_request",
                "A fixed agent_name is required",
            ));
        }
        let kind = safe_text(params.get("kind"), "kind", 32)?;
        if !ALLOWED_KINDS.contains(&kind.as_str()) {
            return Err(BrokerError::new(
                "invalid_request",
                "Unsupported agent kind",
            ));
        }
        let prompt = safe_text(params.get("prompt"), "prompt", MAX_PROMPT_BYTES)?;
        if prompt.trim().is_empty() {
            return Err(BrokerError::new(
                "invalid_request",
                "Bootstrap prompt is empty",
            ));
        }
        let args = self.agent_args(params.get("agent_args"))?;
        validate_role_args(&args)?;
        let timeout = bounded_timeout(params.get("start_timeout_ms"), "start_timeout_ms", 30_000)?;
        let _guard = self.orchestrator_lock.lock().await;
        let record_path = self
            .store
            .lock()
            .map_err(|_| BrokerError::internal("task store lock was poisoned"))?
            .state_dir
            .join("orchestrator-lifecycle.json");
        let previous: Option<Value> = if record_path.exists() {
            Some(
                serde_json::from_str(
                    &fs::read_to_string(&record_path)
                        .map_err(|error| state_error(&record_path, error))?,
                )
                .map_err(|error| state_error(&record_path, error))?,
            )
        } else {
            None
        };
        match self
            .herdr
            .call(
                "agent.get",
                json!({"target": name}),
                Duration::from_secs(30),
            )
            .await
        {
            Ok(result) => {
                let agent = result.get("agent").ok_or_else(|| {
                    BrokerError::new("herdr_protocol_error", "Missing agent record")
                })?;
                verify_agent(agent, &name, &kind, &cwd)?;
                // An existing working/blocked/unknown agent is alive. Never prompt or restart it.
                return Ok(json!({"type": "orchestrator", "created": false, "agent": agent}));
            }
            Err(error) if matches!(error.code.as_str(), "not_found" | "agent_not_found") => {}
            Err(error) => return Err(error),
        }
        if let Some(record) = previous.as_ref() {
            if record.get("phase").and_then(Value::as_str) != Some("bootstrapped") {
                return Err(BrokerError::new("orchestrator_recovery_required",
                    "Previous startup or bootstrap was uncertain; inspect lifecycle record before retry"));
            }
        }
        let snapshot = self
            .herdr
            .call("session.snapshot", json!({}), Duration::from_secs(30))
            .await?;
        let mut workspaces = Vec::new();
        workspaces_at(&snapshot, &cwd, &mut workspaces);
        let inventory = snapshot.get("snapshot").unwrap_or(&snapshot);
        let can_create_work = workspaces.is_empty()
            && inventory
                .get("workspaces")
                .and_then(Value::as_array)
                .is_some_and(|items| {
                    items.iter().all(|workspace| {
                        workspace.get("label").and_then(Value::as_str) != Some("Work")
                    })
                })
            && inventory
                .get("panes")
                .and_then(Value::as_array)
                .is_some_and(|panes| panes.iter().all(|pane| !contains_cwd(pane, &cwd)));
        // Known empty/other-root inventory permits cold startup. Ambiguity does not.
        if workspaces.len() > 1 || (workspaces.is_empty() && !can_create_work) {
            return Err(BrokerError::new(
                "orchestrator_workspace_unresolved",
                "Exactly one Work workspace at the canonical cwd is required; inspect snapshot",
            ));
        }
        // Persist intent before any mutation; no automatic replay after partial delivery.
        let save = |value: &Value| -> Result<(), BrokerError> {
            let temp = record_path.with_extension("tmp");
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&temp)
                .map_err(|error| state_error(&temp, error))?;
            file.set_permissions(fs::Permissions::from_mode(0o600))
                .map_err(|error| state_error(&temp, error))?;
            file.write_all(serde_json::to_string_pretty(value).unwrap().as_bytes())
                .map_err(|error| state_error(&temp, error))?;
            file.sync_all().map_err(|error| state_error(&temp, error))?;
            fs::rename(&temp, &record_path).map_err(|error| state_error(&record_path, error))?;
            Ok(())
        };
        save(&json!({"phase":"starting", "name":name, "cwd":cwd, "kind":kind}))?;
        let route = if can_create_work {
            json!({"layout":"workspace", "label":"Work"})
        } else {
            json!({"layout":"tab", "workspace_id":workspaces[0], "label":"Orchestrator"})
        };
        let layout = self.layout(&route, &cwd, "orchestrator").await?;
        save(
            &json!({"phase":"starting", "name":name, "cwd":cwd, "kind":kind,
            "workspace_id":layout.workspace_id, "pane_id":layout.pane_id}),
        )?;
        let start = self
            .herdr
            .call(
                "agent.start",
                json!({"name": name, "kind": kind,
            "pane_id": layout.pane_id, "args": args, "timeout_ms": timeout}),
                Duration::from_millis(timeout).saturating_add(Duration::from_secs(15)),
            )
            .await?;
        let agent = self.wait_for_agent_ready(&name, timeout).await?;
        verify_agent(&agent, &name, &kind, &cwd)?;
        let prompted = self
            .herdr
            .call(
                "agent.prompt",
                json!({"target": name, "text": prompt}),
                Duration::from_secs(30),
            )
            .await?;
        save(
            &json!({"phase":"bootstrapped", "name":name, "cwd":cwd, "kind":kind,
            "workspace_id":layout.workspace_id, "pane_id":layout.pane_id}),
        )?;
        Ok(
            json!({"type": "orchestrator", "created": true, "agent": agent,
            "start": start, "prompt": prompted}),
        )
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn canonical_workspace_evidence_and_conflicting_agents() {
        let cwd = std::env::temp_dir().canonicalize().unwrap();
        let mut found = Vec::new();
        workspaces_at(
            &json!({"workspaces": [
                {"workspace_id":"w1", "label":"Work", "cwd": "/missing-work-root"},
                {"workspace_id":"w2", "label":"Work", "panes":[{"cwd":cwd}]},
                {"workspace_id":"w3", "label":"project", "panes":[{"cwd":cwd}]}
            ]}),
            &cwd,
            &mut found,
        );
        assert_eq!(found, vec!["w2"]);
        let mut flat = Vec::new();
        workspaces_at(
            &json!({"workspaces":[
            {"workspace_id":"w4", "label":"Work"},
            {"workspace_id":"w5", "label":"Work"}],
            "panes":[{"workspace_id":"w4","cwd":cwd},
                {"workspace_id":"w5","cwd":"/missing-cwd"}]}),
            &cwd,
            &mut flat,
        );
        assert_eq!(flat, vec!["w4"]);

        let agent = json!({"name":"orchestrator", "agent":"codex", "cwd":cwd, "agent_status":"blocked","workspace_id":"w2"});
        assert!(verify_agent(&agent, "orchestrator", "codex", &cwd).is_ok());
        assert!(verify_agent(&agent, "orchestrator", "claude", &cwd).is_err());
        assert!(verify_agent(&agent, "other", "codex", &cwd).is_err());
    }
    pub(super) fn mock_broker(
        replies: Vec<(&'static str, Value)>,
    ) -> (Broker, PathBuf, std::thread::JoinHandle<()>) {
        use std::os::unix::net::UnixListener;
        let temp = std::env::temp_dir().join(format!("orchestrator-test-{}", Uuid::new_v4()));
        fs::create_dir_all(temp.join("Work")).unwrap();
        let listener = UnixListener::bind(temp.join("herdr.sock")).unwrap();
        let broker = Broker::new(
            temp.join("herdr.sock"),
            temp.join("state"),
            temp.join("Work"),
        )
        .unwrap();
        let thread = std::thread::spawn(move || {
            for (method, mut reply) in replies {
                let (mut stream, _) = listener.accept().unwrap();
                let mut line = String::new();
                BufReader::new(stream.try_clone().unwrap())
                    .read_line(&mut line)
                    .unwrap();
                let request: Value = serde_json::from_str(&line).unwrap();
                assert_eq!(request["method"], method);
                reply["id"] = request["id"].clone();
                stream.write_all(format!("{}\n", reply).as_bytes()).unwrap();
            }
        });
        (broker, temp, thread)
    }
    fn live_snapshot(cwd: &Path) -> Value {
        json!({"result":{"type":"session_snapshot","snapshot":{
            "workspaces":[{"workspace_id":"w1","label":"Work"}],
            "panes":[{"workspace_id":"w1","cwd":cwd}]}}})
    }
    fn live_agent(cwd: &Path, status: &str) -> Value {
        json!({"result":{"agent":{"name":"orchestrator","agent":"codex",
            "cwd":cwd,"workspace_id":"w1","pane_id":"w1:p2","agent_status":status}}})
    }
    fn ensure_params(cwd: &Path) -> Value {
        json!({"confirmed":true,"cwd":cwd,"agent_name":"orchestrator","kind":"codex",
            "prompt":"Confirm local role only", "start_timeout_ms":1000})
    }
    #[tokio::test]
    async fn existing_unknown_agent_is_preserved_without_prompt() {
        // Need the disposable cwd before constructing responses.
        let fixture = std::env::temp_dir().join(format!("orchestrator-fixture-{}", Uuid::new_v4()));
        fs::create_dir_all(&fixture).unwrap();
        let (broker, temp, thread) =
            mock_broker(vec![("agent.get", live_agent(&fixture, "unknown"))]);
        // Use the explicit fixture root, maintaining the normal canonical-root guard.
        let broker = Broker::new(
            broker.herdr.socket_path.clone(),
            temp.join("state-2"),
            fixture.clone(),
        )
        .unwrap();
        let result = broker
            .ensure_orchestrator(ensure_params(&fixture))
            .await
            .unwrap();
        assert_eq!(result["created"], false);
        thread.join().unwrap();
        fs::remove_dir_all(temp).unwrap();
        fs::remove_dir_all(fixture).unwrap();
    }
    #[tokio::test]
    async fn bootstrap_uncertainty_is_durable_and_never_replayed() {
        let fixture = std::env::temp_dir().join(format!("orchestrator-fixture-{}", Uuid::new_v4()));
        fs::create_dir_all(&fixture).unwrap();
        let (initial, temp, thread) = mock_broker(vec![
            (
                "agent.get",
                json!({"error":{"code":"agent_not_found","message":"absent"}}),
            ),
            ("session.snapshot", live_snapshot(&fixture)),
            (
                "tab.create",
                json!({"result":{"workspace":{"workspace_id":"w1"},
                "tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p2"}}}),
            ),
            ("agent.start", json!({"result":{"type":"agent_started"}})),
            ("agent.get", live_agent(&fixture, "idle")),
            (
                "agent.prompt",
                json!({"error":{"code":"timeout","message":"delivery uncertain"}}),
            ),
        ]);
        let broker = Broker::new(
            initial.herdr.socket_path.clone(),
            temp.join("state-2"),
            fixture.clone(),
        )
        .unwrap();
        let params = ensure_params(&fixture);
        assert_eq!(
            broker
                .ensure_orchestrator(params.clone())
                .await
                .unwrap_err()
                .code,
            "timeout"
        );
        thread.join().unwrap();
        let restarted = Broker::new(
            temp.join("no-herdr.sock"),
            temp.join("state-2"),
            fixture.clone(),
        )
        .unwrap();
        assert_eq!(
            restarted
                .ensure_orchestrator(params)
                .await
                .unwrap_err()
                .code,
            "herdr_unavailable"
        );
        fs::remove_dir_all(temp).unwrap();
        fs::remove_dir_all(fixture).unwrap();
    }
    #[tokio::test]
    async fn cold_workspace_creation_and_existing_agent_reuse() {
        let fixture = std::env::temp_dir().join(format!("orchestrator-fixture-{}", Uuid::new_v4()));
        fs::create_dir_all(&fixture).unwrap();
        let (initial, temp, thread) = mock_broker(vec![
            (
                "agent.get",
                json!({"error":{"code":"agent_not_found","message":"absent"}}),
            ),
            (
                "session.snapshot",
                json!({"result":{"snapshot":{"workspaces":[],"panes":[]}}}),
            ),
            (
                "workspace.create",
                json!({"result":{"workspace":{"workspace_id":"w1"},
                "tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p2"}}}),
            ),
            ("agent.start", json!({"result":{"type":"agent_started"}})),
            ("agent.get", live_agent(&fixture, "idle")),
            ("agent.prompt", json!({"result":{"type":"agent_prompted"}})),
            ("agent.get", live_agent(&fixture, "working")),
        ]);
        let broker = Broker::new(
            initial.herdr.socket_path.clone(),
            temp.join("state-2"),
            fixture.clone(),
        )
        .unwrap();
        let params = ensure_params(&fixture);
        assert_eq!(
            broker.ensure_orchestrator(params.clone()).await.unwrap()["created"],
            true
        );
        assert_eq!(
            broker.ensure_orchestrator(params).await.unwrap()["created"],
            false
        );
        thread.join().unwrap();
        fs::remove_dir_all(temp).unwrap();
        fs::remove_dir_all(fixture).unwrap();
    }
}
