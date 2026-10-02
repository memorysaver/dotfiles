//! Durable, single-consumer delivery to the existing fixed agent.
use super::*;

fn conflict(message: &str) -> BrokerError {
    BrokerError::new("event_conflict", message)
}

fn event_id(params: &Value) -> Result<String, BrokerError> {
    let id = safe_text(params.get("event_id"), "event_id", 512)?;
    if id.chars().any(char::is_control) {
        return Err(conflict("Event IDs cannot contain control characters"));
    }
    Ok(id)
}
fn active(event: &Value) -> bool {
    matches!(
        event["state"].as_str(),
        Some("sending" | "submitted" | "accepted" | "delivery_unknown")
    )
}

fn occupies_computer(event: &Value) -> bool {
    matches!(
        event["state"].as_str(),
        Some("sending" | "submitted" | "delivery_unknown")
    ) || (event["state"] == "accepted" && event["project_delivery"].is_null())
        || matches!(
            event["computer_return"]["state"].as_str(),
            Some("sending" | "submitted" | "delivery_unknown")
        )
}

impl Broker {
    pub(super) fn event_store<T>(
        &self,
        write: bool,
        update: impl FnOnce(&mut Value) -> Result<T, BrokerError>,
    ) -> Result<T, BrokerError> {
        let _lock = self
            .orchestrator_events_lock
            .lock()
            .map_err(|_| BrokerError::internal("Event lock poisoned"))?;
        let dir = self
            .store
            .lock()
            .map_err(|_| BrokerError::internal("Task lock poisoned"))?
            .state_dir
            .clone();
        let path = dir.join("orchestrator-events.json");
        let mut value = if path.exists() {
            serde_json::from_slice(&fs::read(&path).map_err(|e| state_error(&path, e))?)
                .map_err(|e| state_error(&path, e))?
        } else {
            json!({"schema":1,"events":{},"ready":null})
        };
        if !value["events"].is_object() || value["schema"] != 1 {
            return Err(conflict("Unsupported event store"));
        }
        let previous_store = value.clone();
        let before = value["events"].clone();
        let result = update(&mut value)?;
        if write {
            for (id, event) in value["events"].as_object_mut().unwrap() {
                for key in ["project_delivery", "computer_return"] {
                    if before[id][key]["state"] != event[key]["state"] && event[key].is_object() {
                        if !event["handoffs"].is_array() {
                            event["handoffs"] = json!([]);
                        }
                        let transition = json!({"stage":key,"from":before[id][key]["state"],"to":event[key]["state"],"at":now_iso()});
                        event["handoffs"].as_array_mut().unwrap().push(transition);
                    }
                }
                if before[id]["state"] != event["state"] {
                    let transition =
                        json!({"from":before[id]["state"],"to":event["state"],"at":now_iso()});
                    if !event["transitions"].is_array() {
                        event["transitions"] = json!([]);
                    }
                    event["transitions"]
                        .as_array_mut()
                        .unwrap()
                        .push(transition);
                }
            }
        }
        if write && value != previous_store {
            let temp = dir.join(format!("events.{}.tmp", Uuid::new_v4()));
            let save = (|| -> Result<(), BrokerError> {
                let mut file = OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .open(&temp)
                    .map_err(|e| state_error(&temp, e))?;
                file.set_permissions(fs::Permissions::from_mode(0o600))
                    .map_err(|e| state_error(&temp, e))?;
                file.write_all(&serde_json::to_vec_pretty(&value).unwrap())
                    .map_err(|e| state_error(&temp, e))?;
                file.sync_all().map_err(|e| state_error(&temp, e))?;
                fs::rename(&temp, &path).map_err(|e| state_error(&path, e))?;
                fs::File::open(&dir)
                    .and_then(|f| f.sync_all())
                    .map_err(|e| state_error(&dir, e))?;
                Ok(())
            })();
            if save.is_err() {
                let _ = fs::remove_file(temp);
            }
            save?;
        }
        Ok(result)
    }

    pub(super) async fn resolve_fixed(&self, params: &Value) -> Result<Value, BrokerError> {
        let cwd = self.cwd(params.get("cwd"))?;
        let kind = safe_text(params.get("kind"), "kind", 32)?;
        let result = self
            .herdr
            .call(
                "agent.get",
                json!({"target":"orchestrator"}),
                Duration::from_secs(15),
            )
            .await?;
        let agent = result
            .get("agent")
            .ok_or_else(|| BrokerError::new("herdr_protocol_error", "Agent missing"))?;
        orchestrator::verify_agent(agent, "orchestrator", &kind, &cwd)?;
        safe_text(agent.get("terminal_id"), "terminal_id", 256)?;
        Ok(agent.clone())
    }

    pub(super) async fn orchestrator_event(&self, params: Value) -> Result<Value, BrokerError> {
        let action = safe_text(params.get("action"), "action", 32)?;
        if action == "forward" {
            return self.forward_project(&params).await;
        }
        if action == "resolve_project" {
            return self.resolve_project(&params["route"]).await;
        }
        if action == "resolve" {
            return self.resolve_fixed(&params).await;
        }
        if action == "list" {
            return self.event_store(false, |s| {
                Ok(json!({"events":s["events"],"ready":s["ready"]}))
            });
        }
        if action == "status" {
            let id = event_id(&params)?;
            return self.event_store(false, |s| {
                s["events"]
                    .get(&id)
                    .cloned()
                    .ok_or_else(|| BrokerError::new("event_not_found", "Unknown event"))
            });
        }
        if action == "submit" {
            if params["confirmed"] != true {
                return Err(conflict("Event requires existing task authorization"));
            }
            let id = event_id(&params)?;
            let cwd = self.cwd(params.get("cwd"))?;
            let kind = safe_text(params.get("kind"), "kind", 32)?;
            let payload = params
                .get("payload")
                .filter(|v| v.is_object())
                .ok_or_else(|| conflict("Payload must be an object"))?;
            if serde_json::to_vec(payload).unwrap().len() > MAX_PROMPT_BYTES {
                return Err(conflict("Payload too large"));
            }
            self.cwd(payload.get("project_cwd"))?;
            return self.event_store(true, |s| {
                if let Some(old) = s["events"].get(&id) {
                    if old["payload"] != *payload || old["cwd"] != json!(cwd) || old["kind"] != kind { return Err(conflict("Same event ID has different payload or route")); }
                    return Ok(old.clone());
                }
                let record = json!({"event_id":id,"payload":payload,"cwd":cwd,"kind":kind,"state":"queued",
                    "nonce":Uuid::new_v4().to_string(),"created_at":now_iso(),"updated_at":now_iso()});
                s["events"][&id] = record.clone(); Ok(record)
            });
        }
        if matches!(
            action.as_str(),
            "ready" | "ack" | "project_ack" | "claim" | "complete" | "computer_complete"
        ) {
            let nonce = safe_text(params.get("nonce"), "nonce", 64)?;
            let record = self.event_store(false, |s| {
                if action == "ready" {
                    Ok(s["ready"].clone())
                } else {
                    let id = event_id(&params)?;
                    s["events"]
                        .get(&id)
                        .cloned()
                        .ok_or_else(|| BrokerError::new("event_not_found", "Unknown event"))
                }
            })?;
            let project_receipt = record["payload"]["project_agent"].is_object()
                && matches!(action.as_str(), "project_ack" | "claim" | "complete");
            let nonce_path = if project_receipt {
                "/project_delivery/nonce"
            } else if action == "computer_complete" {
                "/computer_return/nonce"
            } else {
                "/nonce"
            };
            if record.pointer(nonce_path) != Some(&json!(nonce)) {
                return Err(conflict(
                    "Acknowledgment nonce differs for this delivery stage",
                ));
            }
            let claimed_completion = project_receipt
                && action == "complete"
                && record["execution_claim"]["nonce"] == nonce;
            let agent = if claimed_completion {
                json!({"terminal_id":record["project_delivery"]["terminal_id"]})
            } else if project_receipt {
                self.resolve_project(&record["payload"]["project_agent"])
                    .await?
            } else {
                self.resolve_fixed(&record).await?
            };
            let expected = if action == "computer_complete" {
                &record["computer_return"]["terminal_id"]
            } else if project_receipt {
                &record["project_delivery"]["terminal_id"]
            } else {
                &record["terminal_id"]
            };
            if expected != &agent["terminal_id"] {
                return Err(conflict("Agent generation changed; reconcile first"));
            }
            return self.event_store(true, |s| {
                let current = if action == "ready" {
                    &mut s["ready"]
                } else {
                    &mut s["events"][event_id(&params)?]
                };
                if current.pointer(nonce_path) != Some(&json!(nonce))
                    || current["terminal_id"] != record["terminal_id"]
                {
                    return Err(conflict("Concurrent receipt changed"));
                }
                match action.as_str() {
                    "ready" => {
                        if !matches!(
                            current["state"].as_str(),
                            Some("sending" | "submitted" | "ready" | "delivery_unknown")
                        ) {
                            return Err(conflict("Readiness is not pending"));
                        }
                        current["state"] = json!("ready");
                    }
                    "ack" => {
                        if !matches!(
                            current["state"].as_str(),
                            Some("sending" | "submitted" | "accepted" | "delivery_unknown")
                        ) {
                            return Err(conflict("Event is not submitted"));
                        }
                        current["state"] = json!("accepted");
                    }
                    "computer_complete" => {
                        if current["state"] != "accepted"
                            || !matches!(
                                current["project_delivery"]["state"].as_str(),
                                Some("completed" | "failed")
                            )
                        {
                            return Err(conflict(
                                "Project result is not ready for Computer acceptance",
                            ));
                        }
                        current["state"] = current["project_delivery"]["state"].clone();
                        current["result"] = current["project_result"].clone();
                        current["computer_return"]["state"] = json!("accepted");
                    }
                    "project_ack" => {
                        if current["state"] != "accepted"
                            || !matches!(
                                current["project_delivery"]["state"].as_str(),
                                Some("sending" | "submitted" | "accepted" | "delivery_unknown")
                            )
                        {
                            return Err(conflict("Project event was not delegated"));
                        }
                        current["project_delivery"]["state"] = json!("accepted");
                        current["project_delivery"]["accepted_at"] = json!(now_iso());
                    }
                    "claim" => {
                        if project_receipt && current["project_delivery"]["state"] != "accepted" {
                            return Err(conflict("Project must accept before execution claim"));
                        }
                        if current["state"] != "accepted" || !current["execution_claim"].is_null() {
                            return Err(conflict(
                                "Execution is not accepted or was already claimed",
                            ));
                        }
                        current["execution_claim"] = json!({"nonce":nonce,"terminal_id":agent["terminal_id"],"at":now_iso()});
                    }
                    "complete" => {
                        let result = params
                            .get("result")
                            .filter(|v| v.is_object())
                            .ok_or_else(|| conflict("Completion requires a result object"))?;
                        let status = safe_text(params.get("status"), "status", 16)?;
                        if !matches!(status.as_str(), "completed" | "failed") {
                            return Err(conflict("Invalid completion status"));
                        }
                        if project_receipt
                            && matches!(
                                current["project_delivery"]["state"].as_str(),
                                Some("completed" | "failed")
                            )
                        {
                            if current["project_result"] == *result
                                && current["project_delivery"]["state"] == status
                            {
                                return Ok(current.clone());
                            }
                            return Err(conflict("Different Project result already recorded"));
                        }
                        if matches!(current["state"].as_str(), Some("completed" | "failed")) {
                            if current["result"] == *result && current["state"] == status {
                                return Ok(current.clone());
                            }
                            return Err(conflict("Different terminal result already recorded"));
                        }
                        if current["state"] != "accepted" {
                            return Err(conflict("Acknowledge this event before completing it"));
                        }
                        if project_receipt {
                            current["project_delivery"]["state"] = json!(status);
                            current["project_result"] = result.clone();
                            current["computer_return"] = json!({"state":"queued"});
                        } else {
                            current["state"] = json!(status);
                            current["result"] = result.clone();
                        }
                    }
                    _ => unreachable!(),
                }
                current["updated_at"] = json!(now_iso());
                Ok(current.clone())
            });
        }
        if action == "reconcile_readiness" {
            if params["confirmed"] != true {
                return Err(conflict("Readiness reconciliation requires confirmation"));
            }
            let reason = safe_text(params.get("reason"), "reason", 2048)?;
            if params["decision"] != "resend" {
                return Err(conflict("Readiness supports inspected resend only"));
            }
            return self.event_store(true, |s| {
                let ready = &mut s["ready"];
                if !ready.is_object() {
                    return Err(conflict("No readiness to reconcile"));
                }
                ready["nonce"] = json!(Uuid::new_v4().to_string());
                ready["state"] = json!("queued");
                ready["reconciliation"] = json!({"reason":reason});
                Ok(ready.clone())
            });
        }
        if action == "reconcile" {
            if params["confirmed"] != true {
                return Err(conflict("Reconciliation must be explicitly authorized"));
            }
            let id = event_id(&params)?;
            let decision = safe_text(params.get("decision"), "decision", 16)?;
            let reason = safe_text(params.get("reason"), "reason", 2048)?;
            if !matches!(decision.as_str(), "resend" | "drop" | "completed") {
                return Err(conflict(
                    "Choose resend, drop, or completed with verified result",
                ));
            }
            return self.event_store(true, |s| {
                let e = s["events"]
                    .get_mut(&id)
                    .ok_or_else(|| BrokerError::new("event_not_found", "Unknown event"))?;
                if !active(e) && !(decision == "drop" && e["state"] == "queued") {
                    return Err(conflict("Only unresolved delivery can be reconciled"));
                }
                if decision == "resend" && !e["execution_claim"].is_null() {
                    return Err(conflict(
                        "Execution was claimed; inspect result and reconcile without replay",
                    ));
                }
                if decision == "completed" {
                    let result = params
                        .get("result")
                        .filter(|v| v.is_object())
                        .ok_or_else(|| conflict("Verified reconciliation result required"))?;
                    e["result"] = result.clone();
                    e["state"] = json!("completed");
                } else {
                    e["state"] = json!(if decision == "resend" {
                        "queued"
                    } else {
                        "failed"
                    });
                }
                if decision == "resend" {
                    for key in ["project_delivery", "project_result", "computer_return"] {
                        e.as_object_mut().unwrap().remove(key);
                    }
                }
                e["nonce"] = json!(Uuid::new_v4().to_string());
                e["reconciliation"] = json!({"decision":decision,"reason":reason});
                e["updated_at"] = json!(now_iso());
                Ok(e.clone())
            });
        }
        if action != "pump" {
            return Err(BrokerError::new(
                "unknown_operation",
                "Unsupported event action",
            ));
        }
        if params["confirmed"] != true {
            return Err(conflict("Consumer requires configured authorization"));
        }
        let _consumer = self.orchestrator_lock.lock().await;
        let agent = self.resolve_fixed(&params).await?;
        let version = safe_text(params.get("rules_version"), "rules_version", 128)?;
        let bootstrap = safe_text(params.get("bootstrap"), "bootstrap", MAX_PROMPT_BYTES)?;
        let reply = safe_text(params.get("reply_prefix"), "reply_prefix", 4096)?;
        let routes = self.event_store(false, |s| {
            let mut routes = std::collections::BTreeMap::new();
            for e in s["events"].as_object().unwrap().values() {
                if e["execution_claim"].is_null()
                    && matches!(
                        e["project_delivery"]["state"].as_str(),
                        Some("sending" | "submitted" | "accepted")
                    )
                {
                    routes.insert(
                        e["payload"]["project"].as_str().unwrap_or("").to_string(),
                        e["payload"]["project_agent"].clone(),
                    );
                }
            }
            Ok(routes)
        })?;
        let mut project_generations = std::collections::BTreeMap::new();
        for (project, route) in routes {
            match self.resolve_project(&route).await {
                Ok(live) => {
                    project_generations.insert(project, live["terminal_id"].clone());
                }
                Err(e)
                    if matches!(
                        e.code.as_str(),
                        "agent_not_found" | "not_found" | "orchestrator_conflict"
                    ) =>
                {
                    project_generations.insert(project, Value::Null);
                }
                Err(_) => {} // Unreachable server is not proof of a replaced agent.
            }
        }
        let candidate=self.event_store(true, |s| {
            for e in s["events"].as_object_mut().unwrap().values_mut() {
                if (e["project_delivery"]["state"]=="sending" && e["project_delivery"]["broker_instance"]!=self.broker_instance)
                    || (e["execution_claim"].is_null() && matches!(e["project_delivery"]["state"].as_str(),Some("sending"|"submitted"|"accepted")) && project_generations.get(e["payload"]["project"].as_str().unwrap_or("")).is_some_and(|g| g != &e["project_delivery"]["terminal_id"])) {
                    e["project_delivery"]["state"]=json!("delivery_unknown");
                }
                if (e["computer_return"]["state"]=="sending" && e["computer_return"]["broker_instance"]!=self.broker_instance)
                    || (matches!(e["computer_return"]["state"].as_str(),Some("sending"|"submitted")) && e["computer_return"]["terminal_id"]!=agent["terminal_id"]) {
                    e["computer_return"]["state"]=json!("delivery_unknown");
                }
                if (e["state"]=="sending" && e["broker_instance"]!=self.broker_instance)
                    || (active(e) && e["project_delivery"].is_null() && e["terminal_id"].is_string() && e["terminal_id"]!=agent["terminal_id"]) {
                    e["state"]=json!("delivery_unknown");
                }
            }
            if let Some(event)=s["events"].as_object().unwrap().values().find(|e|occupies_computer(e)) { return Ok(json!({"state":"waiting_for_result","event_id":event["event_id"],"event_state":event["state"],"since":event["updated_at"]})); }
            if !matches!(agent["agent_status"].as_str(),Some("idle"|"done")) || agent["interactive_ready"]==false {
                return Ok(json!({"state":"waiting_for_agent","agent_status":agent["agent_status"]}));
            }
            let ready=&mut s["ready"];
            if ready["terminal_id"]!=agent["terminal_id"] || ready["rules_version"]!=version || ready["cwd"]!=params["cwd"] || ready["kind"]!=params["kind"] {
                *ready=json!({"state":"sending","nonce":Uuid::new_v4().to_string(),"terminal_id":agent["terminal_id"],
                    "cwd":params["cwd"],"kind":params["kind"],"rules_version":version,"broker_instance":self.broker_instance});
                return Ok(json!({"type":"readiness","record":ready}));
            }
            if ready["state"]=="queued" {
                ready["state"]=json!("sending"); ready["broker_instance"]=json!(self.broker_instance);
                return Ok(json!({"type":"readiness","record":ready}));
            }
            if ready["state"]=="sending" && ready["broker_instance"]!=self.broker_instance { ready["state"]=json!("delivery_unknown"); }
            if ready["state"]!="ready" { return Ok(json!({"state":"waiting_for_readiness","readiness":ready["state"]})); }
            let result_id=s["events"].as_object().unwrap().iter().find(|(_,e)| e["state"]=="accepted" && e["computer_return"]["state"]=="queued").map(|(id,_)|id.clone());
            if let Some(id)=result_id {
                let e=&mut s["events"][&id];
                e["computer_return"]=json!({"state":"sending","nonce":Uuid::new_v4().to_string(),"terminal_id":agent["terminal_id"],"broker_instance":self.broker_instance});
                return Ok(json!({"type":"computer_result","record":e}));
            }
            let id=s["events"].as_object().unwrap().iter().filter(|(_,e)| e["state"]=="queued")
                .min_by_key(|(_,e)|e["created_at"].as_str().unwrap_or("")).map(|(id,_)|id.clone());
            if let Some(id)=id {
                let e=&mut s["events"][&id];
                if e["cwd"]!=params["cwd"] || e["kind"]!=params["kind"] { return Err(conflict("Queued event route no longer matches configured role")); }
                e["state"]=json!("sending"); e["terminal_id"]=agent["terminal_id"].clone();
                e["broker_instance"]=json!(self.broker_instance); e["updated_at"]=json!(now_iso());
                return Ok(json!({"type":"event","record":e}));
            }
            Ok(json!({"state":"idle"}))
        })?;
        let Some(typ) = candidate["type"].as_str() else {
            return Ok(candidate);
        };
        let record = &candidate["record"];
        let nonce = if typ == "computer_result" {
            &record["computer_return"]["nonce"]
        } else {
            &record["nonce"]
        }
        .as_str()
        .unwrap();
        let text = if typ == "readiness" {
            format!("{bootstrap}\nAfter reading the current rules, confirm readiness through a real Herdr callback shell by running: {reply} event bridge --callback ready --nonce {nonce}\nThis is role initialization only; do not execute business work.")
        } else if typ == "computer_result" {
            format!("Project Orchestrator returned event {} with status {}. Inspect its durable result/log: {}. Read current Work rules. Accept this correlated result by running {reply} event bridge --callback computer-complete --nonce {nonce}. This records the Project result back through Computer to Dagu; do not rerun the project entrypoint. Project artifact verification remains in Dagu. Entrypoint completion is not finished production.",record["event_id"],record["project_delivery"]["state"],record["project_result"])
        } else {
            // JSON-quoted identifiers are data in the prompt, never executed by the broker.
            format!("Authorized local Dagu event: {}\nRead Work AGENTS.md and selected host rules, then this project's instructions. Preserve active workers and dirty trees.\nPayload: {}\nAfter reading these instructions, run {reply} event bridge --callback consume --nonce {nonce}\nThe bridge acknowledges this nonce and forwards it to the registered fixed Project Orchestrator. It never bypasses that role to run a project task. Only internal Work acceptance probes execute locally. Your model stays read-only. Do not directly call event ack/execute from the model sandbox\nThe execute helper preserves project cwd/launcher and records its exit/result. Do not replay if execution or completion is uncertain. If blocked, explain the blocker and leave the event pending. Do not broaden publishing or financial permissions.",record["event_id"],record["payload"])
        };
        let response = self
            .herdr
            .call(
                "agent.prompt",
                json!({"target":"orchestrator","text":text,"wait":{"until":["working","blocked"],"timeout_ms":10000}}),
                Duration::from_secs(30),
            )
            .await;
        self.event_store(true, |s| {
            let e = if typ == "readiness" {
                &mut s["ready"]
            } else {
                &mut s["events"][record["event_id"].as_str().unwrap()]
            };
            if typ == "computer_result" {
                if e["computer_return"]["nonce"] == nonce
                    && e["computer_return"]["state"] == "sending"
                {
                    e["computer_return"]["state"] = json!(match &response {
                        Ok(_) => "submitted",
                        Err(error) if error.code == "agent_blocked" => "queued",
                        Err(_) => "delivery_unknown",
                    });
                }
                return Ok(e.clone());
            }
            if e["nonce"] == nonce && e["state"] == "sending" {
                e["state"] = json!(match &response {
                    Ok(_) => "submitted",
                    Err(error) if error.code == "agent_blocked" => "queued",
                    Err(_) => "delivery_unknown",
                });
                if let Err(error) = &response {
                    e["error"] = json!({"code":error.code,"message":error.message});
                }
            }
            Ok(e.clone())
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::net::UnixListener;

    fn fixture(
        replies: impl FnOnce(&Path) -> Vec<(&'static str, Value)>,
    ) -> (Broker, PathBuf, std::thread::JoinHandle<()>) {
        let root = std::env::temp_dir().join(format!("event-test-{}", Uuid::new_v4()));
        fs::create_dir_all(root.join("Work")).unwrap();
        let listener = UnixListener::bind(root.join("herdr.sock")).unwrap();
        let responses = replies(&root.join("Work"));
        let thread = std::thread::spawn(move || {
            for (method, mut response) in responses {
                let (mut stream, _) = listener.accept().unwrap();
                let mut line = String::new();
                BufReader::new(stream.try_clone().unwrap())
                    .read_line(&mut line)
                    .unwrap();
                let request: Value = serde_json::from_str(&line).unwrap();
                assert_eq!(request["method"], method);
                response["id"] = request["id"].clone();
                stream
                    .write_all(format!("{response}\n").as_bytes())
                    .unwrap();
            }
        });
        let broker = Broker::new(
            root.join("herdr.sock"),
            root.join("state"),
            root.join("Work"),
        )
        .unwrap();
        (broker, root, thread)
    }
    fn agent(cwd: &Path, status: &str) -> Value {
        json!({"result":{"agent":{"name":"orchestrator","agent":"codex","cwd":cwd,"foreground_cwd":cwd,
            "workspace_id":"renamed-or-moved","terminal_id":"generation-1","agent_status":status,"interactive_ready":true}}})
    }
    fn request(root: &Path, action: &str) -> Value {
        json!({"action":action,"confirmed":true,"cwd":root.join("Work"),"kind":"codex","event_id":"host:workflow:run:step",
            "payload":{"project_cwd":root.join("Work"),"task":"read-only"},
            "rules_version":"v1","bootstrap":"Read current AGENTS.md","reply_prefix":"workspace-orchestrator"})
    }
    #[tokio::test]
    async fn enqueue_dedup_conflict_and_durable_restart() {
        let (broker, root, thread) = fixture(|_| vec![]);
        let req = request(&root, "submit");
        let first = broker.orchestrator_event(req.clone()).await.unwrap();
        assert_eq!(first["state"], "queued");
        assert_eq!(
            broker.orchestrator_event(req.clone()).await.unwrap()["nonce"],
            first["nonce"]
        );
        let mut conflict = req.clone();
        conflict["payload"]["task"] = json!("different");
        assert_eq!(
            broker.orchestrator_event(conflict).await.unwrap_err().code,
            "event_conflict"
        );
        let restarted = Broker::new(
            root.join("herdr.sock"),
            root.join("state"),
            root.join("Work"),
        )
        .unwrap();
        assert_eq!(
            restarted
                .orchestrator_event(request(&root, "status"))
                .await
                .unwrap()["nonce"],
            first["nonce"]
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn busy_agent_keeps_event_queued_without_any_prompt() {
        let (broker, root, thread) = fixture(|cwd| vec![("agent.get", agent(cwd, "working"))]);
        broker
            .orchestrator_event(request(&root, "submit"))
            .await
            .unwrap();
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "pump"))
                .await
                .unwrap()["state"],
            "waiting_for_agent"
        );
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "status"))
                .await
                .unwrap()["state"],
            "queued"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn readiness_and_event_acknowledgment_are_separate_from_submission() {
        let (broker, root, thread) = fixture(|cwd| {
            vec![
                ("agent.get", agent(cwd, "idle")),
                ("agent.prompt", json!({"result":{"type":"agent_prompted"}})),
                ("agent.get", agent(cwd, "idle")),
                ("agent.get", agent(cwd, "idle")),
                ("agent.prompt", json!({"result":{"type":"agent_prompted"}})),
                ("agent.get", agent(cwd, "idle")),
                ("agent.get", agent(cwd, "idle")),
            ]
        });
        broker
            .orchestrator_event(request(&root, "submit"))
            .await
            .unwrap();
        let ready = broker
            .orchestrator_event(request(&root, "pump"))
            .await
            .unwrap();
        assert_eq!(ready["state"], "submitted");
        let mut ack = request(&root, "ready");
        ack["nonce"] = ready["nonce"].clone();
        broker.orchestrator_event(ack).await.unwrap();
        let sent = broker
            .orchestrator_event(request(&root, "pump"))
            .await
            .unwrap();
        assert_eq!(sent["state"], "submitted");
        let mut ack = request(&root, "ack");
        ack["nonce"] = sent["nonce"].clone();
        assert_eq!(
            broker.orchestrator_event(ack.clone()).await.unwrap()["state"],
            "accepted"
        );
        ack["action"] = json!("complete");
        ack["status"] = json!("completed");
        ack["result"] = json!({"exit_code":0});
        assert_eq!(
            broker.orchestrator_event(ack).await.unwrap()["state"],
            "completed"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn uncertain_delivery_is_never_replayed_by_pump() {
        let (broker, root, thread) = fixture(|cwd| {
            vec![
                ("agent.get", agent(cwd, "idle")),
                (
                    "agent.prompt",
                    json!({"error":{"code":"timeout","message":"unknown write"}}),
                ),
                ("agent.get", agent(cwd, "idle")),
            ]
        });
        broker
            .orchestrator_event(request(&root, "submit"))
            .await
            .unwrap();
        broker.event_store(true,|s|{s["ready"]=json!({"state":"ready","terminal_id":"generation-1","rules_version":"v1","cwd":root.join("Work"),"kind":"codex"});Ok(())}).unwrap();
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "pump"))
                .await
                .unwrap()["state"],
            "delivery_unknown"
        );
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "pump"))
                .await
                .unwrap()["state"],
            "waiting_for_result"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn queued_drop_and_readiness_recovery_require_explicit_reconciliation() {
        let (broker, root, thread) = fixture(|_| vec![]);
        broker
            .orchestrator_event(request(&root, "submit"))
            .await
            .unwrap();
        let mut drop = request(&root, "reconcile");
        drop["decision"] = json!("drop");
        drop["reason"] = json!("Operator cancelled queued test");
        assert_eq!(
            broker.orchestrator_event(drop).await.unwrap()["state"],
            "failed"
        );
        broker
            .event_store(true, |s| {
                s["ready"] = json!({"state":"delivery_unknown","nonce":"old"});
                Ok(())
            })
            .unwrap();
        let mut retry = request(&root, "reconcile_readiness");
        retry["decision"] = json!("resend");
        retry["reason"] = json!("Composer inspected; old nonce invalidated");
        let ready = broker.orchestrator_event(retry).await.unwrap();
        assert_eq!(ready["state"], "queued");
        assert_ne!(ready["nonce"], "old");
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn changed_generation_blocks_ack_and_pump_never_replays_accepted_work() {
        let (broker, root, thread) = fixture(|cwd| {
            let mut replaced = agent(cwd, "idle");
            replaced["result"]["agent"]["terminal_id"] = json!("generation-2");
            vec![("agent.get", replaced.clone()), ("agent.get", replaced)]
        });
        let queued = broker
            .orchestrator_event(request(&root, "submit"))
            .await
            .unwrap();
        broker
            .event_store(true, |s| {
                let e = &mut s["events"]["host:workflow:run:step"];
                e["state"] = json!("accepted");
                e["terminal_id"] = json!("generation-1");
                Ok(())
            })
            .unwrap();
        let mut ack = request(&root, "ack");
        ack["nonce"] = queued["nonce"].clone();
        assert_eq!(
            broker.orchestrator_event(ack).await.unwrap_err().code,
            "event_conflict"
        );
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "pump"))
                .await
                .unwrap()["state"],
            "waiting_for_result"
        );
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "status"))
                .await
                .unwrap()["state"],
            "delivery_unknown"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn claimed_execution_cannot_be_reconciled_as_resend() {
        let (broker, root, thread) = fixture(|_| vec![]);
        broker
            .orchestrator_event(request(&root, "submit"))
            .await
            .unwrap();
        broker
            .event_store(true, |s| {
                let e = &mut s["events"]["host:workflow:run:step"];
                e["state"] = json!("accepted");
                e["execution_claim"] = json!({"at":"claimed"});
                Ok(())
            })
            .unwrap();
        let mut retry = request(&root, "reconcile");
        retry["decision"] = json!("resend");
        retry["reason"] = json!("Uncertain completion");
        assert_eq!(
            broker.orchestrator_event(retry).await.unwrap_err().code,
            "event_conflict"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    fn project_agent(cwd: &Path, status: &str) -> Value {
        let mut a = agent(cwd, status);
        a["result"]["agent"]["name"] = json!("project-example");
        a["result"]["agent"]["terminal_id"] = json!("project-generation-1");
        a
    }
    fn project_request(root: &Path, action: &str) -> Value {
        let mut p = request(root, action);
        p["payload"]["project"] = json!("example");
        p["payload"]["project_agent"] =
            json!({"name":"project-example","kind":"codex","cwd":root.join("Work"),"args":[]});
        p
    }
    #[tokio::test]
    async fn computer_project_and_return_require_separate_correlated_receipts() {
        let (broker, root, thread) = fixture(|cwd| {
            vec![
                ("agent.get", agent(cwd, "idle")),
                ("agent.prompt", json!({"result":{}})),
                ("agent.get", agent(cwd, "idle")),
                ("agent.get", agent(cwd, "idle")),
                ("agent.get", project_agent(cwd, "idle")),
                ("agent.prompt", json!({"result":{}})),
                ("agent.get", project_agent(cwd, "idle")),
                ("agent.get", project_agent(cwd, "idle")),
                ("agent.get", agent(cwd, "idle")),
                ("agent.prompt", json!({"result":{}})),
                ("agent.get", agent(cwd, "idle")),
            ]
        });
        let submitted = broker
            .orchestrator_event(project_request(&root, "submit"))
            .await
            .unwrap();
        broker.event_store(true,|s|{s["ready"]=json!({"state":"ready","terminal_id":"generation-1","rules_version":"v1","cwd":root.join("Work"),"kind":"codex"});Ok(())}).unwrap();
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "pump"))
                .await
                .unwrap()["state"],
            "submitted"
        );
        let mut ack = request(&root, "ack");
        ack["nonce"] = submitted["nonce"].clone();
        assert_eq!(
            broker.orchestrator_event(ack.clone()).await.unwrap()["state"],
            "accepted"
        );
        ack["action"] = json!("forward");
        let forwarded = broker.orchestrator_event(ack.clone()).await.unwrap();
        assert_eq!(forwarded["state"], "accepted");
        assert_eq!(forwarded["project_delivery"]["state"], "submitted");
        assert!(
            !occupies_computer(&forwarded),
            "Delegated work must not occupy the Computer input slot"
        );
        ack["action"] = json!("project_ack");
        assert_eq!(
            broker
                .orchestrator_event(ack.clone())
                .await
                .unwrap_err()
                .code,
            "event_conflict"
        );
        ack["nonce"] = forwarded["project_delivery"]["nonce"].clone();
        assert_ne!(ack["nonce"], submitted["nonce"]);
        assert_eq!(
            broker.orchestrator_event(ack.clone()).await.unwrap()["project_delivery"]["state"],
            "accepted"
        );
        ack["action"] = json!("claim");
        broker.orchestrator_event(ack.clone()).await.unwrap();
        ack["action"] = json!("complete");
        ack["status"] = json!("completed");
        ack["result"] = json!({"exit_code":0});
        let result = broker.orchestrator_event(ack.clone()).await.unwrap();
        assert_eq!(
            result["state"], "accepted",
            "Project completion must wait for Computer receipt"
        );
        assert_eq!(result["project_delivery"]["state"], "completed");
        assert_eq!(
            broker
                .orchestrator_event(request(&root, "pump"))
                .await
                .unwrap()["computer_return"]["state"],
            "submitted"
        );
        ack["action"] = json!("computer_complete");
        let returned = broker
            .orchestrator_event(request(&root, "status"))
            .await
            .unwrap();
        assert_eq!(
            broker
                .orchestrator_event(ack.clone())
                .await
                .unwrap_err()
                .code,
            "event_conflict"
        );
        ack["nonce"] = returned["computer_return"]["nonce"].clone();
        assert_ne!(ack["nonce"], submitted["nonce"]);
        assert_eq!(
            broker.orchestrator_event(ack).await.unwrap()["state"],
            "completed"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn busy_project_keeps_second_hop_queued_without_prompting() {
        let (broker, root, thread) = fixture(|cwd| {
            vec![
                ("agent.get", agent(cwd, "idle")),
                ("agent.get", project_agent(cwd, "working")),
            ]
        });
        let queued = broker
            .orchestrator_event(project_request(&root, "submit"))
            .await
            .unwrap();
        broker
            .event_store(true, |s| {
                let e = &mut s["events"]["host:workflow:run:step"];
                e["state"] = json!("accepted");
                e["terminal_id"] = json!("generation-1");
                Ok(())
            })
            .unwrap();
        let mut forward = request(&root, "forward");
        forward["nonce"] = queued["nonce"].clone();
        assert_eq!(
            broker.orchestrator_event(forward).await.unwrap()["project_delivery"]["state"],
            "queued"
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn named_project_presence_does_not_depend_on_workspace_layout() {
        let (broker, root, thread) =
            fixture(|cwd| vec![("agent.get", project_agent(cwd, "working"))]);
        let mut ensure = project_request(&root, "unused");
        ensure["project"] = json!("example");
        ensure["route"] = ensure["payload"]["project_agent"].clone();
        assert_eq!(
            broker.ensure_project(ensure).await.unwrap()["created"],
            false
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn project_cold_start_uses_registered_launcher_in_existing_workspace() {
        let (broker, root, thread) = fixture(|cwd| {
            let mut unnamed = project_agent(cwd, "idle");
            unnamed["result"]["agent"]["name"] = Value::Null;
            vec![
                (
                    "agent.get",
                    json!({"error":{"code":"agent_not_found","message":"missing"}}),
                ),
                (
                    "session.snapshot",
                    json!({"result":{"snapshot":{"workspaces":[{"workspace_id":"project-w","cwd":cwd}],"panes":[]}}}),
                ),
                (
                    "tab.create",
                    json!({"result":{"tab":{"workspace_id":"project-w","tab_id":"project-t"},"root_pane":{"pane_id":"project-p"}}}),
                ),
                ("pane.send_input", json!({"result":{}})),
                ("agent.get", unnamed),
                ("agent.rename", json!({"result":{}})),
                ("agent.get", project_agent(cwd, "idle")),
                ("agent.prompt", json!({"result":{}})),
            ]
        });
        let mut ensure = project_request(&root, "unused");
        ensure["project"] = json!("example");
        ensure["route"] = ensure["payload"]["project_agent"].clone();
        ensure["route"]["launcher"] = json!(["bash", "scripts/codexyolo.sh"]);
        ensure["bootstrap"] = json!("Read project rules");
        assert_eq!(
            broker.ensure_project(ensure).await.unwrap()["created"],
            true
        );
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn replaced_project_generation_marks_handoff_uncertain_without_replay() {
        let (broker, root, thread) = fixture(|cwd| {
            vec![
                ("agent.get", agent(cwd, "idle")),
                ("agent.get", project_agent(cwd, "idle")),
            ]
        });
        broker
            .orchestrator_event(project_request(&root, "submit"))
            .await
            .unwrap();
        broker.event_store(true, |s| {
            s["ready"]=json!({"state":"ready","terminal_id":"generation-1","rules_version":"v1","cwd":root.join("Work"),"kind":"codex"});
            for e in s["events"].as_object_mut().unwrap().values_mut() {
                e["state"]=json!("accepted");
                e["project_delivery"]=json!({"state":"submitted","terminal_id":"old-project-generation"});
            }
            Ok(())
        }).unwrap();
        broker
            .orchestrator_event(request(&root, "pump"))
            .await
            .unwrap();
        let result = broker
            .orchestrator_event(request(&root, "status"))
            .await
            .unwrap();
        assert_eq!(result["project_delivery"]["state"], "delivery_unknown");
        thread.join().unwrap();
        fs::remove_dir_all(root).unwrap();
    }
}
