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

impl Broker {
    fn event_store<T>(
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

    async fn resolve_fixed(&self, params: &Value) -> Result<Value, BrokerError> {
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
        if matches!(action.as_str(), "ready" | "ack" | "claim" | "complete") {
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
            if record["nonce"] != nonce {
                return Err(conflict("Acknowledgment nonce differs"));
            }
            let agent = self.resolve_fixed(&record).await?;
            if record["terminal_id"] != agent["terminal_id"] {
                return Err(conflict("Agent generation changed; reconcile first"));
            }
            return self.event_store(true, |s| {
                let current = if action == "ready" {
                    &mut s["ready"]
                } else {
                    &mut s["events"][event_id(&params)?]
                };
                if current["nonce"] != nonce || current["terminal_id"] != record["terminal_id"] {
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
                    "claim" => {
                        if current["state"] != "accepted" || !current["execution_claim"].is_null() {
                            return Err(conflict(
                                "Execution is not accepted or was already claimed",
                            ));
                        }
                        current["execution_claim"] = json!({"nonce":nonce,"at":now_iso()});
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
                        if matches!(current["state"].as_str(), Some("completed" | "failed")) {
                            if current["result"] == *result && current["state"] == status {
                                return Ok(current.clone());
                            }
                            return Err(conflict("Different terminal result already recorded"));
                        }
                        if current["state"] != "accepted" {
                            return Err(conflict("Acknowledge this event before completing it"));
                        }
                        current["state"] = json!(status);
                        current["result"] = result.clone();
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
        let candidate=self.event_store(true, |s| {
            for e in s["events"].as_object_mut().unwrap().values_mut() {
                if (e["state"]=="sending" && e["broker_instance"]!=self.broker_instance)
                    || (active(e) && e["terminal_id"].is_string() && e["terminal_id"]!=agent["terminal_id"]) {
                    e["state"]=json!("delivery_unknown");
                }
            }
            if let Some(event)=s["events"].as_object().unwrap().values().find(|e|active(e)) { return Ok(json!({"state":"waiting_for_result","event_id":event["event_id"],"event_state":event["state"],"since":event["updated_at"]})); }
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
        let nonce = record["nonce"].as_str().unwrap();
        let text = if typ == "readiness" {
            format!("{bootstrap}\nAfter reading the current rules, confirm readiness through a real Herdr callback shell by running: {reply} event bridge --callback ready --nonce {nonce}\nThis is role initialization only; do not execute business work.")
        } else {
            // JSON-quoted identifiers are data in the prompt, never executed by the broker.
            format!("Authorized local Dagu event: {}\nRead Work AGENTS.md and selected host rules, then this project's instructions. Preserve active workers and dirty trees.\nPayload: {}\nAfter reading these instructions, run {reply} event bridge --callback consume --nonce {nonce}\nThe bridge creates a real Herdr shell that acknowledges this nonce, then executes ONLY the registered task. Your model stays read-only. Do not directly call event ack/execute from the model sandbox\nThe execute helper preserves project cwd/launcher and records its exit/result. Do not replay if execution or completion is uncertain. If blocked, explain the blocker and leave the event pending. Do not broaden publishing or financial permissions.",record["event_id"],record["payload"])
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
}
