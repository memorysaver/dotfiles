//! Metadata-only daily journal. No prompts, terminal output, or raw errors.
use super::*;
use chrono::{Days, NaiveDate};
use std::collections::VecDeque;
use std::io::{Seek, SeekFrom};
use std::os::unix::fs::OpenOptionsExt;

const RETENTION_DAYS: u64 = 62;

#[cfg(test)]
#[path = "history_tests.rs"]
mod tests;

fn journal_date(name: &str) -> Option<NaiveDate> {
    let stem = name.strip_suffix(".jsonl")?;
    let date = NaiveDate::parse_from_str(stem, "%Y-%m-%d").ok()?;
    (date.format("%Y-%m-%d").to_string() == stem).then_some(date)
}

impl TaskStore {
    pub(super) fn append_event(&self, task: &Task) -> Result<(), BrokerError> {
        let dir = self.state_dir.join("history");
        fs::create_dir_all(&dir).map_err(|e| state_error(&dir, e))?;
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o700))
            .map_err(|e| state_error(&dir, e))?;
        let path = dir.join(format!("{}.jsonl", Utc::now().format("%Y-%m-%d")));
        let mut file = OpenOptions::new()
            .create(true)
            .read(true)
            .append(true)
            .mode(0o600)
            .open(&path)
            .map_err(|e| state_error(&path, e))?;
        // Isolate a crash-truncated tail before appending the next complete event.
        if file.metadata().map_err(|e| state_error(&path, e))?.len() > 0 {
            file.seek(SeekFrom::End(-1))
                .map_err(|e| state_error(&path, e))?;
            let mut last = [0];
            file.read_exact(&mut last)
                .map_err(|e| state_error(&path, e))?;
            if last[0] != b'\n' {
                file.write_all(b"\n").map_err(|e| state_error(&path, e))?;
            }
        }
        let event = json!({
            "at": now_iso(), "task_id": task.task_id, "state": task.state,
            "agent_name": task.agent_name, "kind": task.agent_kind,
            "cwd": task.cwd, "workspace_id": task.workspace_id,
            "tab_id": task.tab_id, "pane_id": task.pane_id,
            "parent_task_id": task.parent_task_id,
            "discord_thread_id": task.discord_thread_id,
            "discord_message_id": task.discord_message_id,
            "error_code": task.error_code,
        });
        let mut line = serde_json::to_vec(&event).map_err(|e| state_error(&path, e))?;
        line.push(b'\n');
        file.write_all(&line)
            .and_then(|_| file.sync_all())
            .map_err(|e| state_error(&path, e))
    }

    fn prune_at(&mut self, today: NaiveDate) -> Result<(), BrokerError> {
        if self.last_pruned == Some(today) {
            return Ok(());
        }
        let cutoff = today.checked_sub_days(Days::new(RETENTION_DAYS)).unwrap();
        let dir = self.state_dir.join("history");
        if dir.exists() {
            for entry in fs::read_dir(&dir).map_err(|e| state_error(&dir, e))? {
                let entry = entry.map_err(|e| state_error(&dir, e))?;
                // Exact owned filenames only; never follow symlinks or recurse.
                if entry
                    .file_type()
                    .map_err(|e| state_error(&entry.path(), e))?
                    .is_file()
                    && journal_date(&entry.file_name().to_string_lossy())
                        .is_some_and(|d| d < cutoff)
                {
                    fs::remove_file(entry.path()).map_err(|e| state_error(&entry.path(), e))?;
                }
            }
        }
        // Preserve unresolved summaries indefinitely, even when their events age out.
        let before = self.tasks.len();
        self.tasks.retain(|_, task| {
            !matches!(task.state.as_str(), "done" | "idle")
                || chrono::DateTime::parse_from_rfc3339(&task.updated_at)
                    .map(|at| at.date_naive() >= cutoff)
                    .unwrap_or(true)
        });
        if before != self.tasks.len() {
            self.save()?;
        }
        self.last_pruned = Some(today);
        Ok(())
    }

    fn events(&self, params: &Value) -> Result<Value, BrokerError> {
        let limit = match params.get("limit") {
            None => 20,
            Some(v) => v
                .as_u64()
                .filter(|n| (1..=200).contains(n))
                .ok_or_else(|| BrokerError::new("invalid_request", "limit must be 1..200"))?
                as usize,
        };
        for key in ["task_id", "discord_thread_id"] {
            if params.get(key).is_some_and(|v| !v.is_null()) {
                safe_text(params.get(key), key, 128)?;
            }
        }
        let before = match params.get("before").and_then(Value::as_str) {
            Some(s) => Some(
                chrono::DateTime::parse_from_rfc3339(s)
                    .map_err(|_| BrokerError::new("invalid_request", "before must be RFC3339"))?,
            ),
            None => None,
        };
        let dir = self.state_dir.join("history");
        let mut paths = Vec::new();
        if dir.exists() {
            for entry in fs::read_dir(&dir).map_err(|e| state_error(&dir, e))? {
                let entry = entry.map_err(|e| state_error(&dir, e))?;
                if entry
                    .file_type()
                    .map_err(|e| state_error(&entry.path(), e))?
                    .is_file()
                    && journal_date(&entry.file_name().to_string_lossy()).is_some()
                {
                    paths.push(entry.path());
                }
            }
        }
        paths.sort();
        let mut events = VecDeque::with_capacity(limit);
        let mut malformed_lines = 0;
        for path in paths.iter().rev() {
            let mut day = VecDeque::with_capacity(limit);
            let file = fs::File::open(path).map_err(|e| state_error(path, e))?;
            for line in BufReader::new(file).lines() {
                let line = line.map_err(|e| state_error(path, e))?;
                let event: Value = match serde_json::from_str(&line) {
                    Ok(v) => v,
                    Err(_) => {
                        malformed_lines += 1;
                        continue;
                    }
                };
                if ["task_id", "discord_thread_id"].iter().any(|key| {
                    params
                        .get(*key)
                        .filter(|v| !v.is_null())
                        .is_some_and(|v| event.get(*key) != Some(v))
                }) {
                    continue;
                }
                if let Some(before) = before {
                    if event
                        .get("at")
                        .and_then(Value::as_str)
                        .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
                        .map_or(true, |at| at >= before)
                    {
                        continue;
                    }
                }
                if day.len() == limit {
                    day.pop_front();
                }
                day.push_back(event);
            }
            for event in day.into_iter().rev() {
                if events.len() < limit {
                    events.push_back(event);
                }
            }
            if events.len() == limit {
                break;
            }
        }
        let next_before = events.back().and_then(|e| e.get("at")).cloned();
        Ok(
            json!({"type": "history", "events": events, "retention_days": RETENTION_DAYS,
            "order": "newest_first", "next_before": next_before, "malformed_lines": malformed_lines,
            "note": "Observed metadata only. Legacy tasks may have no events; no output is archived."}),
        )
    }
}

impl Broker {
    pub fn prune_history(&self) -> Result<(), BrokerError> {
        self.store
            .lock()
            .map_err(|_| BrokerError::internal("task store lock was poisoned"))?
            .prune_at(Utc::now().date_naive())
    }

    pub(super) fn history(&self, params: &Value) -> Result<Value, BrokerError> {
        self.store
            .lock()
            .map_err(|_| BrokerError::internal("task store lock was poisoned"))?
            .events(params)
    }

    pub(super) async fn task_result(&self, params: &Value) -> Result<Value, BrokerError> {
        let task_id = safe_text(params.get("task_id"), "task_id", 128)?;
        let lines = params
            .get("lines")
            .map_or(Some(120), Value::as_i64)
            .filter(|n| (1..=MAX_READ_LINES).contains(n))
            .ok_or_else(|| BrokerError::new("invalid_request", "lines must be 1..200"))?;
        let task = self
            .store
            .lock()
            .map_err(|_| BrokerError::internal("task store lock was poisoned"))?
            .get(&task_id)?;
        // Names follow live occupants; never fall back to reading the old pane's new occupant.
        let live = match self.task_status(&json!({"task_id": task_id})).await {
            Ok(status) => match self
                .task_read(&json!({"task_id": task_id, "lines": lines}))
                .await
            {
                Ok(read) => {
                    json!({"availability": "agent_present", "status": status, "read": read})
                }
                Err(e) => {
                    json!({"availability": "output_unavailable", "status": status, "error_code": e.code})
                }
            },
            Err(e) if matches!(e.code.as_str(), "not_found" | "agent_not_found") => {
                match self
                    .herdr
                    .call(
                        "pane.get",
                        json!({"pane_id": task.pane_id}),
                        Duration::from_secs(10),
                    )
                    .await
                {
                    Ok(_) => json!({"availability": "original_agent_missing", "pane_exists": true}),
                    Err(p) if matches!(p.code.as_str(), "not_found" | "pane_not_found") => {
                        json!({"availability": "pane_missing", "pane_exists": false})
                    }
                    Err(p) => json!({"availability": "unavailable", "error_code": p.code}),
                }
            }
            Err(e) => json!({"availability": "unavailable", "error_code": e.code}),
        };
        let history = self.history(&json!({"task_id": task_id, "limit": 200}))?;
        Ok(
            json!({"type": "task_result", "record": task, "history": history, "live": live,
            "success_verified": false,
            "next_step": "Check live output and repository artifacts. Missing pane or idle/done is not proof of success. Never replay mutations; use a new parent-linked verification task if needed."}),
        )
    }
}
