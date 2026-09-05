use super::*;

struct Temp(PathBuf);
impl Temp {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!("herdr-history-test-{}", Uuid::new_v4()));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}
impl Drop for Temp {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}
fn task() -> Task {
    serde_json::from_value(json!({
        "task_id": "test-001", "agent_name": "oa-test", "agent_kind": "grok",
        "cwd": "/tmp", "workspace_id": "w1", "tab_id": "w1:t1", "pane_id": "w1:p1",
        "label": "test", "layout": "tab", "state": "working",
        "created_at": now_iso(), "updated_at": now_iso(), "discord_thread_id": "123"
    }))
    .unwrap()
}

#[test]
fn journal_survives_restart_and_polls_do_not_grow_it() {
    let temp = Temp::new();
    let mut store = TaskStore::new(temp.0.clone()).unwrap();
    let mut item = task();
    item.error_message = Some("SECRET raw error must not enter event log".into());
    store.put(item).unwrap();
    for _ in 0..30 {
        store
            .update("test-001", |t| t.updated_at = now_iso())
            .unwrap();
    }
    store
        .update("test-001", |t| {
            t.state = "done".into();
            t.updated_at = now_iso();
        })
        .unwrap();
    drop(store);
    let store = TaskStore::new(temp.0.clone()).unwrap();
    let result = store.events(&json!({"discord_thread_id": "123"})).unwrap();
    assert_eq!(result["events"].as_array().unwrap().len(), 2);
    assert_eq!(result["events"][0]["state"], "done");
    assert!(!result.to_string().contains("SECRET"));
    let path = temp
        .0
        .join("history")
        .join(format!("{}.jsonl", Utc::now().format("%Y-%m-%d")));
    assert_eq!(
        fs::metadata(path).unwrap().permissions().mode() & 0o777,
        0o600
    );
    assert!(store.events(&json!({"limit": 201})).is_err());
    assert_eq!(
        store.events(&json!({"task_id": "other"})).unwrap()["events"],
        json!([])
    );
}

#[test]
fn retention_preserves_62_days_and_unresolved_summaries() {
    let temp = Temp::new();
    let mut store = TaskStore::new(temp.0.clone()).unwrap();
    let today = Utc::now().date_naive();
    let cutoff = today.checked_sub_days(Days::new(62)).unwrap();
    let old = today.checked_sub_days(Days::new(63)).unwrap();
    let mut completed = task();
    completed.state = "done".into();
    completed.updated_at = format!("{old}T00:00:00Z");
    store.put(completed.clone()).unwrap();
    completed.task_id = "unresolved".into();
    completed.state = "working".into();
    store.put(completed.clone()).unwrap();
    completed.task_id = "boundary".into();
    completed.state = "done".into();
    completed.updated_at = format!("{cutoff}T00:00:00Z");
    store.put(completed).unwrap();
    let dir = temp.0.join("history");
    fs::write(dir.join(format!("{old}.jsonl")), "{}\n").unwrap();
    fs::write(dir.join(format!("{cutoff}.jsonl")), "{}\n").unwrap();
    fs::write(dir.join("unrelated.jsonl"), "keep").unwrap();
    store.prune_at(today).unwrap();
    assert!(!dir.join(format!("{old}.jsonl")).exists());
    assert!(dir.join(format!("{cutoff}.jsonl")).exists());
    assert!(dir.join("unrelated.jsonl").exists());
    assert!(store.get("test-001").is_err());
    assert!(store.get("unresolved").is_ok());
    assert!(store.get("boundary").is_ok());
    assert!(TaskStore::new(temp.0.clone())
        .unwrap()
        .get("test-001")
        .is_err());
}

#[test]
fn bounded_history_can_page_and_tolerates_partial_tail() {
    let temp = Temp::new();
    let mut store = TaskStore::new(temp.0.clone()).unwrap();
    store.put(task()).unwrap();
    store
        .update("test-001", |t| t.state = "done".into())
        .unwrap();
    let first = store.events(&json!({"limit": 1})).unwrap();
    let second = store
        .events(&json!({"limit": 1, "before": first["next_before"]}))
        .unwrap();
    assert_eq!(first["events"][0]["state"], "done");
    assert_eq!(second["events"][0]["state"], "working");
    let path = temp
        .0
        .join("history")
        .join(format!("{}.jsonl", Utc::now().format("%Y-%m-%d")));
    OpenOptions::new()
        .append(true)
        .open(path)
        .unwrap()
        .write_all(b"{partial")
        .unwrap();
    assert_eq!(store.events(&json!({})).unwrap()["malformed_lines"], 1);
    store
        .update("test-001", |t| t.state = "working".into())
        .unwrap();
    let repaired = store.events(&json!({})).unwrap();
    assert_eq!(repaired["malformed_lines"], 1);
    assert_eq!(repaired["events"].as_array().unwrap().len(), 3);
}

async fn result_with_responses(responses: Vec<(&str, Value)>) -> Value {
    let temp = Temp::new();
    let socket = temp.0.join("herdr.sock");
    let listener = UnixListener::bind(&socket).unwrap();
    let broker = Broker::new(socket, temp.0.join("state"), temp.0.clone()).unwrap();
    broker.store.lock().unwrap().put(task()).unwrap();
    let responses: Vec<(String, Value)> = responses
        .into_iter()
        .map(|(m, v)| (m.to_owned(), v))
        .collect();
    let server = tokio::spawn(async move {
        for (method, mut response) in responses {
            let (stream, _) = listener.accept().await.unwrap();
            let mut reader = AsyncBufReader::new(stream);
            let mut line = String::new();
            reader.read_line(&mut line).await.unwrap();
            let request: Value = serde_json::from_str(&line).unwrap();
            assert_eq!(request["method"], method);
            response["id"] = request["id"].clone();
            let mut bytes = serde_json::to_vec(&response).unwrap();
            bytes.push(b'\n');
            reader.into_inner().write_all(&bytes).await.unwrap();
        }
    });
    let result = broker
        .request("result", json!({"task_id": "test-001"}))
        .await
        .unwrap();
    server.await.unwrap();
    assert_eq!(result["record"]["task_id"], "test-001");
    assert_eq!(result["success_verified"], false);
    assert_eq!(result["history"]["events"][0]["task_id"], "test-001");
    result
}

#[tokio::test]
async fn closed_pane_keeps_dispatch_evidence() {
    let result = result_with_responses(vec![
        (
            "agent.get",
            json!({"error": {"code": "agent_not_found", "message": "gone"}}),
        ),
        (
            "pane.get",
            json!({"error": {"code": "pane_not_found", "message": "gone"}}),
        ),
    ])
    .await;
    assert_eq!(result["live"]["availability"], "pane_missing");
}

#[tokio::test]
async fn replacement_occupant_is_never_read() {
    let result = result_with_responses(vec![
        (
            "agent.get",
            json!({"error": {"code": "not_found", "message": "gone"}}),
        ),
        (
            "pane.get",
            json!({"result": {"pane": {"agent_name": "someone-else"}}}),
        ),
    ])
    .await;
    assert_eq!(result["live"]["availability"], "original_agent_missing");
}

#[tokio::test]
async fn live_result_reads_named_agent_and_records_transition() {
    let result = result_with_responses(vec![
        (
            "agent.get",
            json!({"result": {"agent": {"agent_status": "done"}}}),
        ),
        ("agent.read", json!({"result": {"text": "test receipt"}})),
    ])
    .await;
    assert_eq!(result["live"]["availability"], "agent_present");
    assert_eq!(result["history"]["events"][0]["state"], "done");
    assert!(!result["history"].to_string().contains("test receipt"));
}

#[tokio::test]
async fn offline_herdr_is_not_a_closed_pane() {
    let temp = Temp::new();
    let broker = Broker::new(
        temp.0.join("absent.sock"),
        temp.0.join("state"),
        temp.0.clone(),
    )
    .unwrap();
    broker.store.lock().unwrap().put(task()).unwrap();
    let result = broker
        .request("result", json!({"task_id": "test-001"}))
        .await
        .unwrap();
    assert_eq!(result["live"]["availability"], "unavailable");
    assert_eq!(result["record"]["state"], "working");
}
