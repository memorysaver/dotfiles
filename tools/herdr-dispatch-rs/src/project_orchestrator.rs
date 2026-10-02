//! Registered project roles: lifecycle and durable second-hop delivery.
use super::*;

impl Broker {
    pub(super) async fn resolve_project(&self, route: &Value) -> Result<Value, BrokerError> {
        let cwd = self.cwd(route.get("cwd"))?;
        let name = self.agent_name(route.get("name"), "project-orchestrator")?;
        if !name.starts_with("project-") {
            return Err(BrokerError::new(
                "invalid_request",
                "Project role names must start with project-",
            ));
        }
        let kind = safe_text(route.get("kind"), "kind", 32)?;
        let result = self
            .herdr
            .call("agent.get", json!({"target":name}), Duration::from_secs(15))
            .await?;
        let agent = result
            .get("agent")
            .ok_or_else(|| BrokerError::internal("Missing project agent"))?;
        orchestrator::verify_agent(agent, &name, &kind, &cwd)?;
        safe_text(agent.get("terminal_id"), "terminal_id", 256)?;
        Ok(agent.clone())
    }

    pub(super) async fn ensure_project(&self, params: Value) -> Result<Value, BrokerError> {
        if params["confirmed"] != true {
            return Err(BrokerError::new(
                "confirmation_required",
                "Registered project lifecycle authorization required",
            ));
        }
        let project = safe_text(params.get("project"), "project", 64)?;
        let route = &params["route"];
        let cwd = self.cwd(route.get("cwd"))?;
        let name = self.agent_name(route.get("name"), "project-orchestrator")?;
        let kind = safe_text(route.get("kind"), "kind", 32)?;
        if !name.starts_with("project-") || !ALLOWED_KINDS.contains(&kind.as_str()) {
            return Err(BrokerError::new("invalid_request", "Invalid project role"));
        }
        let _guard = self.orchestrator_lock.lock().await;
        match self.resolve_project(route).await {
            Ok(agent) => return Ok(json!({"created":false,"agent":agent})),
            Err(e) if matches!(e.code.as_str(), "agent_not_found" | "not_found") => {}
            Err(e) => return Err(e),
        }
        if let Some(pane) = params["adopt_pane"].as_str() {
            let result = self
                .herdr
                .call("agent.get", json!({"target":pane}), Duration::from_secs(15))
                .await?;
            let agent = &result["agent"];
            if agent["name"].as_str().is_some_and(|v| !v.is_empty())
                || !matches!(agent["agent_status"].as_str(), Some("idle" | "done"))
            {
                return Err(BrokerError::new(
                    "orchestrator_conflict",
                    "Only an explicitly selected unnamed idle project editor may be adopted",
                ));
            }
            let mut expected = agent.clone();
            expected["name"] = json!(name);
            orchestrator::verify_agent(&expected, &name, &kind, &cwd)?;
            self.herdr
                .call(
                    "agent.rename",
                    json!({"target":pane,"name":name}),
                    Duration::from_secs(15),
                )
                .await?;
            let live = self.resolve_project(route).await?;
            self.event_store(true, |s| {
                if !s["projects"].is_object() {
                    s["projects"] = json!({});
                }
                s["projects"][&project] = json!({"phase":"ready","route":route,"agent":live});
                Ok(())
            })?;
            return Ok(json!({"created":false,"adopted":true,"agent":live}));
        }
        let previous = self.event_store(false, |s| Ok(s["projects"][&project].clone()))?;
        let snapshot = self
            .herdr
            .call("session.snapshot", json!({}), Duration::from_secs(20))
            .await?;
        let inventory = snapshot.get("snapshot").unwrap_or(&snapshot);
        let workspaces = inventory["workspaces"]
            .as_array()
            .ok_or_else(|| BrokerError::internal("Unknown workspace inventory"))?;
        let panes = inventory["panes"]
            .as_array()
            .ok_or_else(|| BrokerError::internal("Unknown pane inventory"))?;
        let recorded_pane = previous["agent"]["pane_id"]
            .as_str()
            .or_else(|| previous["pane_id"].as_str());
        let restored = self
            .restored_role_layout(&previous, panes, &cwd, &name)
            .await?;
        let recovery_attempts = if previous.is_object() && previous["phase"] != "ready" {
            let attempts = previous["recovery_attempts"].as_u64().unwrap_or(0) + 1;
            if recorded_pane.is_none() || attempts > 3 {
                return Err(BrokerError::new(
                    "orchestrator_recovery_required",
                    "Project startup uncertain or bounded recovery exhausted; inspect before retry",
                ));
            }
            attempts
        } else {
            0
        };
        let matches: Vec<_> = workspaces
            .iter()
            .filter(|w| {
                let declared = w["worktree"]["checkout_path"]
                    .as_str()
                    .or_else(|| w["cwd"].as_str());
                if let Some(path) = declared {
                    Path::new(path).canonicalize().ok().as_ref() == Some(&cwd)
                } else {
                    panes.iter().any(|p| {
                        p["workspace_id"] == w["workspace_id"]
                            && p["cwd"]
                                .as_str()
                                .and_then(|v| Path::new(v).canonicalize().ok())
                                .as_ref()
                                == Some(&cwd)
                    })
                }
            })
            .collect();
        if matches.len() > 1 {
            return Err(BrokerError::new(
                "orchestrator_workspace_unresolved",
                "Multiple project workspaces match repo cwd",
            ));
        }
        self.event_store(true, |s| {
            if !s["projects"].is_object() {
                s["projects"] = json!({});
            }
            if previous.is_object() && previous["phase"] != "ready" {
                if !s["project_recovery_history"].is_array() {
                    s["project_recovery_history"] = json!([]);
                }
                s["project_recovery_history"]
                    .as_array_mut()
                    .unwrap()
                    .push(json!({"project":project,"previous":previous,"at":now_iso()}));
            }
            s["projects"][&project] =
                json!({"phase":"starting","recovery_attempts":recovery_attempts,"route":route});
            Ok(())
        })?;
        let layout_route = if let Some(workspace) = matches.first() {
            json!({"layout":"tab","workspace_id":workspace["workspace_id"],"label":"Project Orchestrator"})
        } else {
            json!({"layout":"workspace","label":params["workspace_label"]})
        };
        let layout = if let Some(layout) = restored {
            layout
        } else {
            self.layout(&layout_route, &cwd, &project).await?
        };
        self.event_store(true, |s| {
            s["projects"][&project]["pane_id"] = json!(layout.pane_id);
            Ok(())
        })?;
        let args = self.agent_args(route.get("args"))?;
        if let Some(launcher) = route["launcher"].as_array() {
            let argv: Vec<&str> = launcher
                .iter()
                .map(|v| {
                    v.as_str()
                        .ok_or_else(|| BrokerError::new("invalid_request", "Launcher must be argv"))
                })
                .collect::<Result<_, _>>()?;
            if argv.is_empty() {
                return Err(BrokerError::new(
                    "invalid_request",
                    "Empty project launcher",
                ));
            }
            let quote = |v: &str| format!("'{}'", v.replace('\'', "'\\''"));
            let command = argv
                .into_iter()
                .map(quote)
                .chain(args.iter().map(|v| quote(v)))
                .collect::<Vec<_>>()
                .join(" ");
            self.herdr
                .call(
                    "pane.send_input",
                    json!({"pane_id":layout.pane_id,"text":command,"keys":["enter"]}),
                    Duration::from_secs(15),
                )
                .await?;
            let deadline = Instant::now() + Duration::from_secs(30);
            let detected = loop {
                let result = self
                    .herdr
                    .call(
                        "agent.get",
                        json!({"target":layout.pane_id}),
                        Duration::from_secs(5),
                    )
                    .await;
                if let Ok(result) = result {
                    let agent = &result["agent"];
                    if agent["agent_status"] == "blocked" {
                        return Err(BrokerError::new(
                            "agent_blocked",
                            "Project startup approval needs human attention",
                        ));
                    }
                    if agent["agent"] == kind
                        && agent["interactive_ready"] != false
                        && matches!(agent["agent_status"].as_str(), Some("idle" | "done"))
                    {
                        break agent.clone();
                    }
                }
                if Instant::now() >= deadline {
                    return Err(BrokerError::new(
                        "agent_not_ready",
                        "Project launcher startup uncertain; preserve pane",
                    ));
                }
                tokio::time::sleep(Duration::from_millis(250)).await;
            };
            let mut expected = detected.clone();
            expected["name"] = json!(name);
            orchestrator::verify_agent(&expected, &name, &kind, &cwd)?;
            if detected["agent"] != kind {
                return Err(BrokerError::new(
                    "orchestrator_conflict",
                    "Unexpected project launcher kind",
                ));
            }
            self.herdr
                .call(
                    "agent.rename",
                    json!({"target":layout.pane_id,"name":name}),
                    Duration::from_secs(15),
                )
                .await?;
        } else {
            self.herdr.call("agent.start",json!({"name":name,"kind":kind,"pane_id":layout.pane_id,"args":args,"timeout_ms":30000}),Duration::from_secs(45)).await?;
        }
        let agent = self.resolve_project(route).await?;
        let prompt = safe_text(params.get("bootstrap"), "bootstrap", MAX_PROMPT_BYTES)?;
        self.herdr
            .call(
                "agent.prompt",
                json!({"target":name,"text":prompt}),
                Duration::from_secs(30),
            )
            .await?;
        self.event_store(true, |s| {
            s["projects"][&project] = json!({"phase":"ready","route":route,"agent":agent});
            Ok(())
        })?;
        Ok(json!({"created":true,"agent":agent}))
    }

    pub(super) async fn forward_project(&self, params: &Value) -> Result<Value, BrokerError> {
        let _guard = self.orchestrator_lock.lock().await;
        let id = safe_text(params.get("event_id"), "event_id", 512)?;
        let nonce = safe_text(params.get("nonce"), "nonce", 64)?;
        let record = self.event_store(false, |s| Ok(s["events"][&id].clone()))?;
        if record["nonce"] != nonce || record["state"] != "accepted" {
            return Err(BrokerError::new(
                "event_conflict",
                "Computer must accept this nonce before forwarding",
            ));
        }
        if matches!(
            record["project_delivery"]["state"].as_str(),
            Some("sending" | "submitted" | "accepted" | "delivery_unknown")
        ) {
            return Ok(record);
        }
        let computer = self.resolve_fixed(&record).await?;
        if record["project_delivery"].is_null() && computer["terminal_id"] != record["terminal_id"]
        {
            return Err(BrokerError::new(
                "event_conflict",
                "Computer generation changed before handoff",
            ));
        }
        let route = &record["payload"]["project_agent"];
        if record["project_delivery"].is_null() {
            self.event_store(true, |s| {
                s["events"][&id]["project_delivery"] = json!({"state":"queued","route":route});
                Ok(())
            })?;
        }
        let agent = match self.resolve_project(route).await {
            Ok(agent) => agent,
            Err(error) => {
                return self.event_store(true, |s| {
                    s["events"][&id]["project_delivery"]["error"] =
                        json!({"code":error.code,"message":error.message});
                    Ok(s["events"][&id].clone())
                })
            }
        };
        let busy_project = self.event_store(false, |s| {
            Ok(s["events"].as_object().unwrap().iter().any(|(other, e)| {
                other != &id
                    && e["payload"]["project"] == record["payload"]["project"]
                    && matches!(
                        e["project_delivery"]["state"].as_str(),
                        Some("sending" | "submitted" | "accepted" | "delivery_unknown")
                    )
            }))
        })?;
        if busy_project
            || !matches!(agent["agent_status"].as_str(), Some("idle" | "done"))
            || agent["interactive_ready"] == false
        {
            return self.event_store(true, |s| {
                s["events"][&id]["project_delivery"] = json!({"state":"queued","route":route});
                Ok(s["events"][&id].clone())
            });
        }
        let project_nonce = Uuid::new_v4().to_string();
        self.event_store(true,|s|{
            let e=&mut s["events"][&id];
            if e["nonce"]!=nonce || e["state"]!="accepted" {return Err(BrokerError::new("event_conflict","Event changed before project handoff"));}
            e["project_delivery"]=json!({"state":"sending","nonce":project_nonce,"route":route,"terminal_id":agent["terminal_id"],"broker_instance":self.broker_instance,"at":now_iso()});Ok(())
        })?;
        let reply = safe_text(params.get("reply_prefix"), "reply_prefix", 4096)?;
        let text=format!("You are the fixed Project Orchestrator for {}. Computer Orchestrator accepted and delegated event {}. Read your repo AGENTS.md and README.md, check Git status, preserve active work and follow project gates. Frozen payload: {}\nAfter reading the rules, acknowledge and execute through a real Herdr shell: {reply} event bridge --project {} --callback project-consume --nonce {project_nonce}\nUse ONLY the registered entrypoint, preserving its launcher. Return the correlated result through the broker to Computer and Dagu. Entrypoint success may mean producer dispatch only, not finished production. Do not approve topics, publish, or replay uncertain work. This is an authorized event, not new publication authority.",record["payload"]["project"],record["event_id"],record["payload"],record["payload"]["project"].as_str().ok_or_else(||BrokerError::internal("Missing project"))?);
        let response=self.herdr.call("agent.prompt",json!({"target":route["name"],"text":text,"wait":{"until":["working","blocked"],"timeout_ms":10000}}),Duration::from_secs(30)).await;
        self.event_store(true, |s| {
            let e = &mut s["events"][&id];
            if e["nonce"] == nonce && e["project_delivery"]["state"] == "sending" {
                e["project_delivery"]["state"] = json!(match response {
                    Ok(_) => "submitted",
                    Err(ref error) if error.code == "agent_blocked" => "queued",
                    Err(_) => "delivery_unknown",
                });
                if let Err(error) = response {
                    e["project_delivery"]["error"] =
                        json!({"code":error.code,"message":error.message});
                }
            }
            Ok(e.clone())
        })
    }
}
