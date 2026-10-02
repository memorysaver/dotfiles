//! Verify managed launch settings without interrupting existing conversations.
use super::*;

fn settings(route: &Value) -> Value {
    json!({"kind":route["kind"],"launcher":route["launcher"],"args":route["args"]})
}

fn process(info: &Value) -> Option<&Value> {
    let processes = info["foreground_processes"].as_array()?;
    (processes.len() == 1
        && processes[0]["pid"].as_u64().is_some()
        && processes[0]["argv"]
            .as_array()
            .is_some_and(|a| !a.is_empty()))
    .then(|| &processes[0])
}

fn matches_launch(route: &Value, info: &Value, receipt: &Value, terminal: &Value) -> bool {
    let Some(live) = process(info) else {
        return false;
    };
    let launcher = route["launcher"].as_array();
    let mut expected = launcher
        .cloned()
        .unwrap_or_else(|| vec![route["kind"].clone()]);
    let Some(executable) = expected.first().and_then(Value::as_str).map(str::to_owned) else {
        return false;
    };
    // Arbitrary wrappers cannot be reconstructed from their child process.
    if Path::new(&executable).file_name().and_then(|p| p.to_str()) != route["kind"].as_str() {
        // A wrapper needs a broker-issued receipt for this exact process.
        return !terminal.is_null()
            && receipt["settings"] == settings(route)
            && receipt["terminal_id"] == *terminal
            && receipt["pid"] == live["pid"]
            && receipt["argv"] == live["argv"];
    }
    expected.extend(route["args"].as_array().into_iter().flatten().cloned());
    let actual = live["argv"].as_array().unwrap();
    actual.len() == expected.len()
        && actual[1..] == expected[1..]
        && actual[0].as_str().is_some_and(|a| {
            if Path::new(&executable).is_absolute() {
                a == executable
            } else {
                Path::new(a).file_name() == Path::new(&executable).file_name()
            }
        })
}

impl Broker {
    pub(super) async fn record_role_launch(
        &self,
        agent: &Value,
        route: &Value,
    ) -> Result<(), BrokerError> {
        let result = self
            .herdr
            .call(
                "pane.process_info",
                json!({"pane_id":agent["pane_id"]}),
                Duration::from_secs(15),
            )
            .await?;
        let live = process(&result["process_info"]).ok_or_else(|| {
            BrokerError::new(
                "launch_unverified",
                "Cannot identify launched foreground process; preserve pane",
            )
        })?;
        safe_text(agent.get("terminal_id"), "terminal_id", 256)?;
        let executable = route["launcher"][0].as_str().unwrap_or("");
        if Path::new(executable).file_name().and_then(|p| p.to_str()) == route["kind"].as_str()
            && !matches_launch(
                route,
                &result["process_info"],
                &Value::Null,
                &agent["terminal_id"],
            )
        {
            return Err(BrokerError::new(
                "launch_settings_mismatch",
                "New agent argv differs from configured launcher/args; preserve pane",
            ));
        }
        self.event_store(true, |s| {
            if !s["role_launches"].is_object() { s["role_launches"] = json!({}); }
            s["role_launches"][agent["name"].as_str().unwrap()] = json!({"settings":settings(route),"terminal_id":agent["terminal_id"],"pid":live["pid"],"argv":live["argv"]});
            Ok(())
        })
    }

    pub(super) async fn audit_role_launches(
        &self,
        roles: &mut [Value],
        binding: &Value,
        enforce: bool,
    ) -> Result<(), BrokerError> {
        let receipts = self.event_store(false, |s| Ok(s["role_launches"].clone()))?;
        for role in roles {
            let name = role["name"].as_str().unwrap().to_owned();
            let route = if name == binding["computer_name"] {
                json!({"kind":binding["kind"],"launcher":binding["computer_launch"]["launcher"],"args":binding["computer_launch"]["args"]})
            } else {
                binding["projects"]
                    .as_object()
                    .unwrap()
                    .values()
                    .find(|r| r["name"] == name)
                    .unwrap()
                    .clone()
            };
            role["configured_launch"] = settings(&route);
            if role["missing"] == true {
                role["launch_status"] = json!("pending_start");
                continue;
            }
            let result = self
                .herdr
                .call(
                    "pane.process_info",
                    json!({"pane_id":role["pane_id"]}),
                    Duration::from_secs(15),
                )
                .await?;
            let info = &result["process_info"];
            let matched = matches_launch(&route, info, &receipts[&name], &role["terminal_id"]);
            role["launch_status"] = json!(if matched {
                "matched"
            } else {
                "mismatch_or_unverified"
            });
            role["observed_argv"] = process(info)
                .map(|p| p["argv"].clone())
                .unwrap_or(Value::Null);
            if enforce && !matched {
                return Err(BrokerError::new("launch_settings_mismatch", format!("{name}: existing launch does not match or cannot be verified against YAML. Configured: {}; observed argv: {}. Session preserved; arrange an explicit handoff/relaunch before retrying start.", settings(&route), role["observed_argv"])));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn info(argv: Value, pid: u64) -> Value {
        json!({"foreground_processes":[{"pid":pid,"argv":argv}]})
    }
    #[test]
    fn direct_launch_requires_yolo_and_all_model_options() {
        let route =
            json!({"kind":"codex","launcher":["codex","--yolo"],"args":["--model","gpt-6.1-sol"]});
        assert!(matches_launch(
            &route,
            &info(
                json!(["/mise/bin/codex", "--yolo", "--model", "gpt-6.1-sol"]),
                1
            ),
            &Value::Null,
            &json!("t")
        ));
        for argv in [
            json!(["codex", "--model", "gpt-6.1-sol"]),
            json!(["codex", "--yolo"]),
            json!(["codex", "--yolo", "--model", "other"]),
            json!([
                "codex",
                "--yolo",
                "--model",
                "gpt-6.1-sol",
                "-s",
                "read-only"
            ]),
        ] {
            assert!(!matches_launch(
                &route,
                &info(argv, 1),
                &Value::Null,
                &json!("t")
            ));
        }
        let wrong = info(json!(["codex"]), 1);
        let receipt =
            json!({"settings":settings(&route),"terminal_id":"t","pid":1,"argv":["codex"]});
        assert!(!matches_launch(&route, &wrong, &receipt, &json!("t")));
    }
    #[test]
    fn wrapper_receipt_is_bound_to_settings_process_and_terminal() {
        let route = json!({"kind":"codex","launcher":["bash","scripts/codexyolo.sh"],"args":[]});
        let live = info(json!(["codex", "--yolo"]), 123);
        let receipt = json!({"settings":settings(&route),"terminal_id":"t","pid":123,"argv":["codex","--yolo"]});
        assert!(matches_launch(&route, &live, &receipt, &json!("t")));
        assert!(!matches_launch(&route, &live, &Value::Null, &json!("t")));
        assert!(!matches_launch(&route, &live, &receipt, &json!("other")));
        assert!(!matches_launch(
            &route,
            &info(json!(["codex", "--yolo"]), 124),
            &receipt,
            &json!("t")
        ));
        let mut changed = route.clone();
        changed["args"] = json!(["--model", "other"]);
        assert!(!matches_launch(&changed, &live, &receipt, &json!("t")));
    }

    #[tokio::test]
    async fn preview_reports_old_session_and_start_refuses_without_mutation() {
        let reply = json!({"result":{"process_info":{"foreground_processes":[{"pid":1,"argv":["codex"]}]}}});
        let (broker, root, thread) = crate::orchestrator::tests::mock_broker(vec![
            ("pane.process_info", reply.clone()),
            ("pane.process_info", reply),
        ]);
        let binding = json!({"computer_name":"computer-orchestrator","kind":"codex","computer_launch":{"launcher":["codex","--yolo"],"args":[]},"projects":{}});
        let mut roles = vec![
            json!({"name":"computer-orchestrator","pane_id":"p","terminal_id":"t","missing":false}),
        ];
        let before = broker.event_store(false, |s| Ok(s.clone())).unwrap();
        broker
            .audit_role_launches(&mut roles, &binding, false)
            .await
            .unwrap();
        assert_eq!(roles[0]["launch_status"], "mismatch_or_unverified");
        assert_eq!(
            broker
                .audit_role_launches(&mut roles, &binding, true)
                .await
                .unwrap_err()
                .code,
            "launch_settings_mismatch"
        );
        assert_eq!(
            broker.event_store(false, |s| Ok(s.clone())).unwrap(),
            before
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
}
