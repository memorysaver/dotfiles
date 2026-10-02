use super::*;
use chrono::Timelike;
use std::os::unix::process::{CommandExt, ExitStatusExt};
use std::process::{Command, Stdio};

#[derive(Debug, Clone, clap::Args)]
pub struct EventArgs {
    #[arg(value_parser=["submit","status","list","ready","ack","execute","complete","reconcile","verify","bridge","consume","project-consume","computer-complete","reconcile-readiness"])]
    pub action: String,
    #[arg(long)]
    pub project: Option<String>,
    #[arg(long)]
    pub task: Option<String>,
    #[arg(long)]
    pub event_id: Option<String>,
    #[arg(long)]
    pub nonce: Option<String>,
    #[arg(long)]
    pub dagu: bool,
    #[arg(long)]
    pub wait: bool,
    #[arg(long, default_value_t = 7200)]
    pub timeout: u64,
    #[arg(long)]
    pub result_file: Option<PathBuf>,
    #[arg(long,value_parser=["completed","failed"])]
    pub status: Option<String>,
    #[arg(long,value_parser=["resend","drop","completed"])]
    pub decision: Option<String>,
    #[arg(long)]
    pub reason: Option<String>,
    #[arg(long)]
    pub confirmed: bool,
    #[arg(long,value_parser=["ready","consume","project-consume","computer-complete"])]
    pub callback: Option<String>,
}
fn taipei() -> chrono::DateTime<chrono::FixedOffset> {
    chrono::Utc::now().with_timezone(&chrono::FixedOffset::east_opt(28800).unwrap())
}
fn execution_nonce(event: &Value) -> Result<&str> {
    text(
        if event["payload"]["project_agent"].is_object() {
            &event["project_delivery"]["nonce"]
        } else {
            &event["nonce"]
        },
        "execution nonce",
    )
}
fn claim_path(host: &Host, event: &Value) -> Result<PathBuf> {
    let key = format!(
        "{}:{}",
        text(&event["event_id"], "event ID")?,
        execution_nonce(event)?
    );
    Ok(host
        .paths
        .get("state")
        .join("execution-claims")
        .join(format!("{}.json", sha256(key.as_bytes()))))
}
fn uncertain(event: &Value) -> bool {
    event["state"] == "delivery_unknown"
        || event["project_delivery"]["state"] == "delivery_unknown"
        || event["computer_return"]["state"] == "delivery_unknown"
}
impl Host {
    pub fn find_event(&self, id: Option<&str>, nonce: Option<&str>) -> Result<Value> {
        let event = if let Some(id) = id {
            self.call("status", json!({"event_id":id}))?
        } else {
            let nonce = nonce.ok_or_else(|| error("Event ID or nonce is required"))?;
            let store = self.call("list", json!({}))?;
            let matches = store["events"]
                .as_object()
                .ok_or_else(|| error("Unknown event inventory"))?
                .values()
                .filter(|e| {
                    [
                        &e["nonce"],
                        &e["project_delivery"]["nonce"],
                        &e["computer_return"]["nonce"],
                    ]
                    .iter()
                    .any(|v| v.as_str() == Some(nonce))
                })
                .cloned()
                .collect::<Vec<_>>();
            if matches.len() != 1 {
                return fail("Nonce must identify exactly one event");
            }
            matches[0].clone()
        };
        if let Some(nonce) = nonce {
            if ![
                &event["nonce"],
                &event["project_delivery"]["nonce"],
                &event["computer_return"]["nonce"],
            ]
            .iter()
            .any(|v| v.as_str() == Some(nonce))
            {
                return fail("Event nonce differs");
            }
        }
        Ok(event)
    }
    pub fn pump(&self) -> Result<Value> {
        let profile = fs::read_to_string(self.rules.join("profile"))?;
        let mut inputs = vec![
            self.paths.get("workspace").join("AGENTS.md"),
            self.paths.get("workspace").join("README.md"),
            self.rules.join("README.md"),
            self.rules.join("agents.md"),
            self.rules.join("profile"),
            self.rules.join("orchestrator.toml"),
            self.paths
                .get("dotfiles")
                .join("config/workspace/orchestration-rules/orchestrator.md"),
            self.paths
                .get("dotfiles")
                .join("config/workspace/orchestration-rules/external-dispatch.md"),
            self.paths
                .get("dotfiles")
                .join("config/workspace/orchestration-rules/profiles")
                .join(format!("{}.md", profile.trim())),
        ];
        if self.rules.join("projects.toml").exists() {
            inputs.push(self.rules.join("projects.toml"));
        }
        let mut digest = Sha256::new();
        for input in inputs {
            digest.update(input.canonicalize()?.to_string_lossy().as_bytes());
            digest.update(fs::read(input)?);
        }
        let mut response=self.call("pump",json!({"confirmed":true,"rules_version":format!("{:x}",digest.finalize()),"bootstrap":self.bootstrap(),"reply_prefix":self.reply_prefix()?}))?;
        let store = self.call("list", json!({}))?;
        let mut events = store["events"]
            .as_object()
            .ok_or_else(|| error("Unknown event inventory"))?
            .values()
            .collect::<Vec<_>>();
        events.sort_by_key(|e| e["created_at"].as_str().unwrap_or(""));
        let mut errors = serde_json::Map::new();
        for event in events {
            if event["state"] == "accepted" && event["project_delivery"]["state"] == "queued" {
                match self.call("forward",json!({"event_id":event["event_id"],"nonce":event["nonce"],"reply_prefix":self.reply_prefix()?})) {
                Ok(result)=>response=result,Err(e)=>{errors.insert(event["event_id"].as_str().unwrap_or("").into(),json!(e.to_string()));},
            }
            }
        }
        if !errors.is_empty() {
            response["forwarding_errors"] = json!(errors);
        }
        Ok(response)
    }
    pub async fn execute(&self, event: Value) -> Result<Value> {
        if event["state"] != "accepted" {
            return fail("Event must be acknowledged before execution");
        }
        let payload = &event["payload"];
        let current = self.task(
            text(&payload["project"], "project")?,
            text(&payload["task"], "task")?,
        )?;
        for (key, value) in current.as_object().unwrap() {
            if &payload[key] != value {
                return fail("Registered task changed after enqueue; reconcile before running");
            }
        }
        let project = payload["project_agent"].is_object();
        let (live, expected) = if project {
            if event["project_delivery"]["state"] != "accepted" {
                return fail("Project has not acknowledged this event");
            }
            (
                self.call("resolve_project", json!({"route":payload["project_agent"]}))?,
                &event["project_delivery"]["terminal_id"],
            )
        } else {
            (self.call("resolve", json!({}))?, &event["terminal_id"])
        };
        if &live["terminal_id"] != expected {
            return fail("Agent generation changed before execution");
        }
        let nonce = execution_nonce(&event)?;
        if current["definition"]["same_day"] == true
            && payload["trigger_date"] != taipei().date_naive().to_string()
        {
            return self.call("complete",json!({"event_id":event["event_id"],"nonce":nonce,"status":"failed","result":{"reason":"Trigger day expired; no project execution"}}));
        }
        let claim = claim_path(self, &event)?;
        private_dir(claim.parent().unwrap())?;
        let mut file = OpenOptions::new()
            .create_new(true)
            .write(true)
            .mode(0o600)
            .open(&claim)
            .map_err(|e| {
                error(format!(
                    "Execution claim unavailable; never replay without inspection: {e}"
                ))
            })?;
        file.write_all(
            serde_json::to_string(
                &json!({"event_id":event["event_id"],"nonce":nonce,"started_at":timestamp()}),
            )?
            .as_bytes(),
        )?;
        file.sync_all()?;
        fs::File::open(claim.parent().unwrap())?.sync_all()?;
        self.call("claim", json!({"event_id":event["event_id"],"nonce":nonce}))?;
        let log = claim.with_extension("log");
        let output = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&log)?;
        let args = expand_argv(&current["definition"]["entrypoint"], payload)?;
        let mut command = Command::new(&args[0]);
        command
            .args(&args[1..])
            .current_dir(text(&current["project_cwd"], "project cwd")?)
            .stdout(Stdio::from(output.try_clone()?))
            .stderr(Stdio::from(output));
        if let Some(inputs) = payload["trigger_env"].as_object() {
            for (key, value) in inputs {
                command.env(key, text(value, "trigger environment")?);
            }
        }
        if let Some(dir) = payload["trigger_artifacts_dir"].as_str() {
            command.env("DAG_RUN_ARTIFACTS_DIR", dir);
        }
        // A separate process group preserves the existing timeout/effect boundary.
        unsafe {
            command.pre_exec(|| {
                if libc::setsid() < 0 {
                    return Err(std::io::Error::last_os_error());
                }
                Ok(())
            });
        }
        let mut child = command.spawn()?;
        let deadline = Instant::now()
            + Duration::from_secs(
                current["definition"]["timeout_seconds"]
                    .as_u64()
                    .unwrap_or(7200),
            );
        let receipt = loop {
            if let Some(status) = child.try_wait()? {
                let exit = status
                    .code()
                    .unwrap_or_else(|| -status.signal().unwrap_or(1));
                break json!({"exit_code":exit,"log":log,"finished_at":timestamp(),"verification":"project entrypoint exit status; business artifacts remain project-owned"});
            }
            if Instant::now() >= deadline {
                unsafe {
                    libc::kill(-(child.id() as i32), libc::SIGKILL);
                }
                child.wait()?;
                break json!({"outcome":"timeout","effects":"unknown; reconcile project artifacts before replay","log":log,"finished_at":timestamp()});
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        };
        atomic_json(&claim.with_extension("result.json"), &receipt)?;
        if receipt["outcome"] == "timeout" {
            return fail(
                "Project timed out; receipt saved, effects unknown, event remains accepted",
            );
        }
        self.call("complete",json!({"event_id":event["event_id"],"nonce":nonce,"status":if receipt["exit_code"]==0{"completed"}else{"failed"},"result":receipt}))
    }
    pub async fn bridge(
        &self,
        nonce: &str,
        callback: &str,
        project: Option<&str>,
    ) -> Result<Value> {
        if !matches!(
            callback,
            "ready" | "consume" | "project-consume" | "computer-complete"
        ) {
            return fail("Bridge requires a valid callback");
        }
        if env::var("HERDR_ENV").as_deref() != Ok("1") {
            return fail("Bridge requires a genuine Herdr caller");
        }
        if !Regex::new(r"^[0-9a-f-]{36}$")?.is_match(nonce) {
            return fail("Invalid callback nonce");
        }
        let route = if callback == "project-consume" {
            self.project(project.ok_or_else(|| error("Project callback requires --project"))?)?
                ["route"]
                .clone()
        } else {
            json!({"name":"orchestrator","kind":self.kind,"cwd":self.paths.get("workspace")})
        };
        let live =
            herdr(&["agent", "get", text(&route["name"], "role name")?]).await?["agent"].clone();
        if live["agent"] != route["kind"]
            || weak_canonical(Path::new(text(&live["cwd"], "live cwd")?))?
                != Path::new(text(&route["cwd"], "role cwd")?)
            || live["foreground_cwd"].as_str().is_some_and(|v| {
                weak_canonical(Path::new(v)).ok().as_deref()
                    != Some(Path::new(route["cwd"].as_str().unwrap()))
            })
        {
            return fail("Fixed agent identity differs");
        }
        if env::var("HERDR_PANE_ID").ok().as_deref() != live["pane_id"].as_str() {
            let caller = herdr(&["pane", "current", "--current"]).await.ok();
            if caller.as_ref().map(|v| &v["pane"]["pane_id"]) != Some(&live["pane_id"]) {
                validate_stale_context(
                    callback,
                    &env::current_dir()?,
                    &route,
                    &live,
                    project,
                    nonce,
                    &read_json(
                        &self
                            .socket
                            .parent()
                            .ok_or_else(|| error("Invalid broker socket"))?
                            .join("orchestrator-events.json"),
                    )?,
                )?;
            }
        }
        let pane = herdr(&[
            "pane",
            "split",
            "--pane",
            text(&live["pane_id"], "role pane")?,
            "--direction",
            "down",
            "--cwd",
            text(&route["cwd"], "role cwd")?,
            "--no-focus",
        ])
        .await?["pane"]["pane_id"]
            .as_str()
            .ok_or_else(|| error("Missing callback pane"))?
            .to_string();
        let mut parts = vec![
            "event".into(),
            callback.into(),
            "--nonce".into(),
            nonce.into(),
        ];
        if let Some(project) = project {
            parts.extend(["--project".into(), project.into()]);
        }
        let command = format!(
            "{} {} && herdr pane close {}",
            self.reply_prefix()?,
            shell_join(&parts),
            quote(&pane)
        );
        herdr(&["pane", "run", &pane, &command]).await?;
        Ok(
            json!({"callback":callback,"pane_id":pane,"submission":"shell command submitted; inspect correlated broker receipt"}),
        )
    }
    pub async fn event(&self, mut args: EventArgs) -> Result<Value> {
        if args.dagu {
            let workflow = env::var("DAG_NAME").map_err(|_| error("Dagu must supply DAG_NAME"))?;
            let run = env::var("DAG_RUN_ID").map_err(|_| error("Dagu must supply DAG_RUN_ID"))?;
            if workflow.is_empty() || run.is_empty() {
                return fail("Dagu identity cannot be empty");
            }
            args.event_id = Some(format!(
                "{}:{workflow}:{run}:{}",
                self.computer,
                args.task
                    .as_deref()
                    .ok_or_else(|| error("Dagu identity requires task"))?
            ));
        }
        let id = args.event_id.as_deref();
        let nonce = args.nonce.as_deref();
        match args.action.as_str() {
            "bridge" => {
                return self
                    .bridge(
                        nonce.ok_or_else(|| error("Bridge requires nonce"))?,
                        args.callback
                            .as_deref()
                            .ok_or_else(|| error("Bridge requires --callback"))?,
                        args.project.as_deref(),
                    )
                    .await
            }
            "list" => return self.call("list", json!({})),
            "ready" => return self.call("ready", json!({"nonce":nonce})),
            "reconcile-readiness" => return self.call(
                "reconcile_readiness",
                json!({"confirmed":args.confirmed,"decision":args.decision,"reason":args.reason}),
            ),
            "submit" => {
                let mut payload = self.task(
                    args.project
                        .as_deref()
                        .ok_or_else(|| error("Submission requires project"))?,
                    args.task
                        .as_deref()
                        .ok_or_else(|| error("Submission requires task"))?,
                )?;
                let id = id.ok_or_else(|| error("A stable event ID or --dagu is required"))?;
                let events = self.call("list", json!({}))?;
                if let Some(existing) = events["events"].get(id) {
                    for (key, value) in existing["payload"]
                        .as_object()
                        .ok_or_else(|| error("Invalid saved payload"))?
                    {
                        if key.starts_with("trigger_") {
                            payload[key] = value.clone();
                        }
                    }
                } else {
                    let now = taipei();
                    let mut inputs = serde_json::Map::new();
                    if let Some(input) = payload["definition"].get("input_env") {
                        let input_pattern = Regex::new(r"^[A-Z][A-Z0-9_]{0,63}$")?;
                        for key in argv(input, false)? {
                            if !input_pattern.is_match(&key) {
                                return fail("Invalid environment allowlist");
                            }
                            inputs.insert(key.clone(), json!(env::var(&key).unwrap_or_default()));
                        }
                    }
                    payload["trigger_env"] = json!(inputs);
                    payload["trigger_date"] = json!(now.date_naive().to_string());
                    payload["trigger_slot"] = json!(if now.hour() < 15 {
                        "morning"
                    } else if now.hour() < 21 {
                        "afternoon"
                    } else {
                        "evening"
                    });
                    payload["trigger_artifacts_dir"] =
                        json!(env::var("DAG_RUN_ARTIFACTS_DIR").ok());
                }
                let mut event = self.call(
                    "submit",
                    json!({"confirmed":true,"event_id":id,"payload":payload}),
                )?;
                if args.wait {
                    let deadline = Instant::now() + Duration::from_secs(args.timeout);
                    while !matches!(event["state"].as_str(), Some("completed" | "failed")) {
                        if uncertain(&event) {
                            return fail("Delivery is uncertain; reconcile without replay");
                        }
                        if Instant::now() >= deadline {
                            return fail(
                                "Event is still pending; retry the SAME event ID to observe it",
                            );
                        }
                        tokio::time::sleep(Duration::from_secs(2)).await;
                        event = self.call("status", json!({"event_id":id}))?;
                    }
                    if event["state"] == "failed" {
                        return fail(format!(
                            "Project event failed: {}",
                            event.get("result").unwrap_or(&event["reconciliation"])
                        ));
                    }
                }
                return Ok(event);
            }
            "reconcile" => {
                if args.decision.as_deref() == Some("resend")
                    && claim_path(self, &self.find_event(id, None)?)?.exists()
                {
                    return fail("Execution claim exists; reconcile with result instead of resend");
                }
                let result = args.result_file.as_deref().map(read_json).transpose()?;
                return self.call("reconcile",json!({"event_id":id,"confirmed":args.confirmed,"decision":args.decision,"reason":args.reason,"result":result}));
            }
            _ => {}
        }
        let mut event = self.find_event(id, nonce)?;
        match args.action.as_str() {
            "status"=>Ok(event),
            "consume"|"project-consume"=> {
                if env::var("HERDR_ENV").as_deref()!=Ok("1"){return fail("Consumption requires real Herdr context");}
                if args.action=="project-consume" {
                    if args.project.as_deref()!=event["payload"]["project"].as_str(){return fail("Project callback target differs");}
                    event=self.call("project_ack",json!({"event_id":event["event_id"],"nonce":nonce}))?;
                }else {
                    event=self.call("ack",json!({"event_id":event["event_id"],"nonce":nonce}))?;
                    if event["payload"]["project_agent"].is_object() {return self.call("forward",json!({"event_id":event["event_id"],"nonce":nonce,"reply_prefix":self.reply_prefix()?}));}
                }
                let result=self.execute(event).await?;
                if result["state"]=="failed"||result["project_delivery"]["state"]=="failed"{return fail("Project failed; durable receipt/log saved, callback pane retained");}
                Ok(result)
            },
            "computer-complete"=>self.call("computer_complete",json!({"event_id":event["event_id"],"nonce":nonce})),
            "execute"=>self.execute(event).await,
            "verify"=> {
                if event["state"]!="completed" {return fail("Verify only after event completed");}
                let payload=&event["payload"];let task=self.task(text(&payload["project"],"project")?,text(&payload["task"],"task")?)?;
                if task["definition"]!=payload["definition"]{return fail("Task changed; inspect before verification");}
                let args=expand_argv(&task["definition"]["verify_entrypoint"],payload)?;
                let status=Command::new(&args[0]).args(&args[1..]).current_dir(text(&task["project_cwd"],"project cwd")?).status()?;
                if !status.success(){return fail("Project verifier failed");}
                Ok(json!({"event_id":event["event_id"],"verification":"project verifier passed"}))
            },
            "complete"=>self.call("complete",json!({"event_id":event["event_id"],"nonce":nonce,"status":args.status,"result":read_json(args.result_file.as_deref().ok_or_else(||error("Completion requires result file"))?)?})),
            "ack"=>self.call("ack",json!({"event_id":event["event_id"],"nonce":nonce})),
            _=>fail("Unknown event action"),
        }
    }
}
pub(super) fn expand_argv(value: &Value, payload: &Value) -> Result<Vec<String>> {
    let pattern = Regex::new(r"\$\{env:([A-Z][A-Z0-9_]*)\}")?;
    Ok(argv(value, true)?
        .into_iter()
        .map(|arg| {
            let arg = arg
                .replace("${date}", payload["trigger_date"].as_str().unwrap_or(""))
                .replace("${slot}", payload["trigger_slot"].as_str().unwrap_or(""));
            pattern
                .replace_all(&arg, |c: &regex::Captures| {
                    payload["trigger_env"][&c[1]]
                        .as_str()
                        .unwrap_or("")
                        .to_string()
                })
                .into_owned()
        })
        .collect())
}
pub(super) fn validate_stale_context(
    callback: &str,
    cwd: &Path,
    route: &Value,
    live: &Value,
    project: Option<&str>,
    nonce: &str,
    store: &Value,
) -> Result<()> {
    if callback != "project-consume"
        || weak_canonical(cwd)? != Path::new(text(&route["cwd"], "project cwd")?)
    {
        return fail(
            "Only fixed Project caller at registered repo cwd may use stale-context recovery",
        );
    }
    let matches = store["events"]
        .as_object()
        .ok_or_else(|| error("Invalid private event store"))?
        .values()
        .filter(|e| e["project_delivery"]["nonce"] == nonce)
        .collect::<Vec<_>>();
    if matches.len() != 1 {
        return fail("No correlated Project callback capability");
    }
    let event = matches[0];
    if event["payload"]["project"].as_str() != project
        || &event["payload"]["project_agent"] != route
        || event["project_delivery"]["terminal_id"] != live["terminal_id"]
        || event["state"] != "accepted"
        || !matches!(
            event["project_delivery"]["state"].as_str(),
            Some("sending" | "submitted" | "accepted")
        )
    {
        return fail("Project callback capability does not match live role");
    }
    Ok(())
}
pub(super) async fn bounded_output(
    mut command: tokio::process::Command,
    timeout: Duration,
) -> Result<std::process::Output> {
    command.kill_on_drop(true);
    tokio::time::timeout(timeout, command.output())
        .await
        .map_err(|_| error("Herdr command timed out; inspect delivery before retrying"))?
        .map_err(Into::into)
}
pub(super) async fn herdr(args: &[&str]) -> Result<Value> {
    let mut command = tokio::process::Command::new("herdr");
    command.args(args);
    let output = bounded_output(command, Duration::from_secs(40)).await?;
    if !output.status.success() {
        return fail(String::from_utf8_lossy(&output.stderr).to_string());
    }
    if args.starts_with(&["pane", "run"]) && output.stdout.is_empty() {
        return Ok(json!({}));
    }
    Ok(serde_json::from_slice::<Value>(&output.stdout)?["result"].clone())
}
