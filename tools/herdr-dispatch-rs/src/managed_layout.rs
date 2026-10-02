//! Arrange configured roles with native move operations, preserving terminal IDs.
use super::*;

fn plan(snapshot: &Value, binding: &Value, allow_missing: bool) -> Result<Vec<Value>, BrokerError> {
    if snapshot["protocol"].as_u64().is_none_or(|v| v < 22) {
        return Err(BrokerError::new(
            "unsupported_herdr",
            "Managed layout requires Herdr protocol 22 or newer",
        ));
    }
    let mut routes = vec![
        json!({"name":binding["computer_name"], "kind":binding["kind"], "cwd":binding["computer_home"]}),
    ];
    for id in binding["project_order"]
        .as_array()
        .ok_or_else(|| BrokerError::internal("Missing project order"))?
    {
        routes.push(
            binding["projects"][id
                .as_str()
                .ok_or_else(|| BrokerError::internal("Invalid project order"))?]
            .clone(),
        );
    }
    let agents = snapshot["agents"]
        .as_array()
        .ok_or_else(|| BrokerError::internal("Missing snapshot agents"))?;
    let mut workspaces = HashSet::new();
    let mut result = Vec::new();
    for route in routes {
        let matches: Vec<_> = agents
            .iter()
            .filter(|a| a["name"] == route["name"])
            .collect();
        if matches.len() > 1 {
            return Err(BrokerError::new(
                "orchestrator_conflict",
                "Duplicate role name",
            ));
        }
        if let Some(agent) = matches.first() {
            orchestrator::verify_agent(
                agent,
                route["name"].as_str().unwrap(),
                route["kind"].as_str().unwrap(),
                Path::new(route["cwd"].as_str().unwrap()),
            )?;
            let workspace = safe_text(agent.get("workspace_id"), "workspace_id", 256)?;
            let tab = safe_text(agent.get("tab_id"), "tab_id", 256)?;
            if !workspaces.insert(workspace.clone()) {
                return Err(BrokerError::new(
                    "orchestrator_conflict",
                    "Each managed role must have its own workspace",
                ));
            }
            if !snapshot["workspaces"]
                .as_array()
                .is_some_and(|w| w.iter().any(|w| w["workspace_id"] == workspace))
                || !snapshot["tabs"].as_array().is_some_and(|t| {
                    t.iter()
                        .any(|t| t["tab_id"] == tab && t["workspace_id"] == workspace)
                })
            {
                return Err(BrokerError::new(
                    "orchestrator_conflict",
                    "Role layout is absent from snapshot",
                ));
            }
            result.push(json!({"name":route["name"],"cwd":route["cwd"],"workspace_id":workspace,"tab_id":tab,"pane_id":agent["pane_id"],"terminal_id":agent["terminal_id"],"missing":false}));
        } else if allow_missing {
            result.push(json!({"name":route["name"],"cwd":route["cwd"],"missing":true}));
        } else {
            return Err(BrokerError::new(
                "agent_not_found",
                "Managed role is missing after startup",
            ));
        }
    }
    Ok(result)
}

impl Broker {
    pub(super) async fn managed_layout(&self, params: Value) -> Result<Value, BrokerError> {
        let dry_run = params["dry_run"]
            .as_bool()
            .ok_or_else(|| BrokerError::new("invalid_request", "dry_run must be boolean"))?;
        let _guard = self.orchestrator_lock.lock().await;
        let snapshot = self
            .herdr
            .call("session.snapshot", json!({}), Duration::from_secs(15))
            .await?["snapshot"]
            .clone();
        let roles = plan(&snapshot, &params["role_binding"], dry_run)?;
        if dry_run {
            return Ok(json!({"dry_run":true,"roles":roles}));
        }
        let ids: Vec<_> = roles.iter().map(|r| r["workspace_id"].clone()).collect();
        let current: Vec<_> = snapshot["workspaces"]
            .as_array()
            .unwrap()
            .iter()
            .map(|w| w["workspace_id"].clone())
            .collect();
        if !current.starts_with(&ids) {
            let before = current.iter().find(|id| !ids.contains(id));
            self.herdr
                .call(
                    "workspace.move_block",
                    json!({"workspace_ids":ids,"before_workspace_id":before}),
                    Duration::from_secs(15),
                )
                .await?;
        }
        for role in &roles {
            let tabs: Vec<_> = snapshot["tabs"]
                .as_array()
                .unwrap()
                .iter()
                .filter(|t| t["workspace_id"] == role["workspace_id"])
                .collect();
            if tabs.first().is_none_or(|t| t["tab_id"] != role["tab_id"]) {
                self.herdr
                    .call(
                        "tab.move",
                        json!({"tab_id":role["tab_id"],"insert_index":0}),
                        Duration::from_secs(15),
                    )
                    .await?;
            }
        }
        let after = self
            .herdr
            .call("session.snapshot", json!({}), Duration::from_secs(15))
            .await?["snapshot"]
            .clone();
        let verified = plan(&after, &params["role_binding"], false)?;
        let order: Vec<_> = after["workspaces"]
            .as_array()
            .unwrap()
            .iter()
            .map(|w| w["workspace_id"].clone())
            .collect();
        if roles != verified
            || !order.starts_with(&ids)
            || roles.iter().any(|r| {
                after["tabs"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .find(|t| t["workspace_id"] == r["workspace_id"])
                    .is_none_or(|t| t["tab_id"] != r["tab_id"])
            })
        {
            return Err(BrokerError::new("layout_changed", "Managed layout verification failed; preserve current panes and inspect before retry"));
        }
        Ok(json!({"dry_run":false,"verified":true,"roles":verified}))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn native_moves_preserve_sessions_and_second_start_is_a_noop() {
        use std::os::unix::net::UnixListener;
        let dir = std::env::temp_dir().join(format!("layout-{}", Uuid::new_v4()));
        fs::create_dir_all(&dir).unwrap();
        let socket = dir.join("herdr.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        let (mut before, binding) = fixture();
        before["workspaces"]
            .as_array_mut()
            .unwrap()
            .insert(0, json!({"workspace_id":"unmanaged"}));
        before["tabs"]
            .as_array_mut()
            .unwrap()
            .insert(0, json!({"workspace_id":"wc","tab_id":"wc:other"}));
        let mut after = before.clone();
        after["workspaces"] = json!([{"workspace_id":"wc"},{"workspace_id":"wz"},{"workspace_id":"wa"},{"workspace_id":"unmanaged"}]);
        after["tabs"] = json!([{"workspace_id":"wc","tab_id":"wc:t1"},{"workspace_id":"wc","tab_id":"wc:other"},{"workspace_id":"wa","tab_id":"wa:t1"},{"workspace_id":"wz","tab_id":"wz:t1"}]);
        let script = vec![
            ("session.snapshot", json!({}), json!({"snapshot":before})),
            (
                "workspace.move_block",
                json!({"workspace_ids":["wc","wz","wa"],"before_workspace_id":"unmanaged"}),
                json!({}),
            ),
            (
                "tab.move",
                json!({"tab_id":"wc:t1","insert_index":0}),
                json!({}),
            ),
            ("session.snapshot", json!({}), json!({"snapshot":after})),
            ("session.snapshot", json!({}), json!({"snapshot":after})),
            ("session.snapshot", json!({}), json!({"snapshot":after})),
        ];
        let server = std::thread::spawn(move || {
            for (method, params, result) in script {
                let (mut stream, _) = listener.accept().unwrap();
                let mut line = String::new();
                BufReader::new(stream.try_clone().unwrap())
                    .read_line(&mut line)
                    .unwrap();
                let request: Value = serde_json::from_str(&line).unwrap();
                assert_eq!(request["method"], method);
                assert_eq!(request["params"], params);
                use std::io::Write;
                writeln!(stream, "{}", json!({"id":request["id"],"result":result})).unwrap();
            }
        });
        let broker = Broker::new(socket, dir.join("state"), std::env::temp_dir()).unwrap();
        let params = json!({"dry_run":false,"role_binding":binding});
        let first = broker.managed_layout(params.clone()).await.unwrap();
        assert_eq!(first["verified"], true);
        assert_eq!(first, broker.managed_layout(params).await.unwrap());
        server.join().unwrap();
        fs::remove_dir_all(dir).unwrap();
    }
    fn fixture() -> (Value, Value) {
        let cwd = std::env::temp_dir().canonicalize().unwrap();
        let binding = json!({"computer_name":"computer-orchestrator","computer_home":cwd,"kind":"codex",
            "project_order":["z","a"],"projects":{"a":{"name":"project-orchestrator-a","kind":"codex","cwd":cwd},"z":{"name":"project-orchestrator-z","kind":"codex","cwd":cwd}}});
        let agents:Vec<_>=[("project-orchestrator-a","wa"),("computer-orchestrator","wc"),("project-orchestrator-z","wz")].iter().map(|(name,w)|json!({"name":name,"agent":"codex","cwd":cwd,"workspace_id":w,"tab_id":format!("{w}:t1"),"pane_id":format!("{w}:p1"),"terminal_id":format!("term-{w}")})).collect();
        let snapshot = json!({"protocol":22,"agents":agents,"workspaces":[{"workspace_id":"wa"},{"workspace_id":"wc"},{"workspace_id":"wz"}],"tabs":agents.iter().map(|a|json!({"tab_id":a["tab_id"],"workspace_id":a["workspace_id"]})).collect::<Vec<_>>()});
        (snapshot, binding)
    }
    #[test]
    fn configured_order_overrides_snapshot_and_alphabetical_order() {
        let (snapshot, binding) = fixture();
        let roles = plan(&snapshot, &binding, false).unwrap();
        assert_eq!(
            roles
                .iter()
                .map(|r| r["workspace_id"].clone())
                .collect::<Vec<_>>(),
            vec![json!("wc"), json!("wz"), json!("wa")]
        );
        assert_eq!(roles, plan(&snapshot, &binding, false).unwrap());
    }
    #[test]
    fn missing_roles_are_only_allowed_during_preview() {
        let (mut snapshot, binding) = fixture();
        snapshot["agents"] = json!([]);
        assert_eq!(plan(&snapshot, &binding, true).unwrap().len(), 3);
        assert!(plan(&snapshot, &binding, false).is_err());
        snapshot["protocol"] = json!(21);
        assert!(plan(&snapshot, &binding, true).is_err());
    }
    #[test]
    fn conflicting_names_roots_and_shared_workspaces_fail() {
        let (snapshot, binding) = fixture();
        let mut duplicate = snapshot.clone();
        duplicate["agents"]
            .as_array_mut()
            .unwrap()
            .push(snapshot["agents"][0].clone());
        assert!(plan(&duplicate, &binding, true).is_err());
        let mut wrong = snapshot.clone();
        wrong["agents"][0]["cwd"] = json!("/");
        assert!(plan(&wrong, &binding, true).is_err());
        let mut shared = snapshot.clone();
        shared["agents"][0]["workspace_id"] = json!("wc");
        shared["agents"][0]["tab_id"] = json!("wc:t1");
        assert!(plan(&shared, &binding, true).is_err());
    }
}
