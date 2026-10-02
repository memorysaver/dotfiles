//! Transactional manifest adoption on the broker's pinned configuration source.
use super::*;
fn validate_change(previous: &Value, binding: &Value) -> Result<(), BrokerError> {
    let old = &previous["role_binding"];
    if old.is_object() && old != binding {
        for key in ["computer_id", "computer_home", "kind", "computer_name"] {
            if old[key] != binding[key] {
                return Err(BrokerError::new(
                    "role_owner_conflict",
                    "Persisted Computer owner differs",
                ));
            }
        }
        for (id, route) in old["projects"].as_object().into_iter().flatten() {
            if let Some(next) = binding["projects"].get(id) {
                for key in ["name", "cwd", "kind"] {
                    if route[key] != next[key] {
                        return Err(BrokerError::new(
                            "role_owner_conflict",
                            "Existing Project owner differs; explicit migration required",
                        ));
                    }
                }
            }
        }
        if previous["events"]
            .as_object()
            .unwrap()
            .values()
            .any(|e| !matches!(e["state"].as_str(), Some("completed" | "failed")))
        {
            return Err(BrokerError::new(
                "configuration_busy",
                "Configuration is busy; retain the original YAML until all events finish, then apply changes",
            ));
        }
    }
    Ok(())
}

impl Broker {
    pub(super) fn apply_role_policy(&self, mut policy: Value) -> Result<(), BrokerError> {
        let previous = self.event_store(false, |s| Ok(s.clone()))?;
        validate_change(&previous, &policy["binding"])?;
        let legacy = previous["legacy_names"]
            .as_object()
            .map(|m| m.keys().cloned().map(Value::String).collect::<Vec<_>>())
            .unwrap_or_default();
        policy["retired_names"]
            .as_array_mut()
            .unwrap()
            .extend(legacy);
        {
            let mut store = self
                .store
                .lock()
                .map_err(|_| BrokerError::internal("task store lock poisoned"))?;
            store.schema_two = true;
            store.save()?;
        }
        self.event_store(true, |state| {
            if state["role_binding"] != policy["binding"] {
                state["ready"] = Value::Null;
            }
            state["role_binding"] = policy["binding"].clone();
            Ok(())
        })?;
        *self
            .role_policy
            .lock()
            .map_err(|_| BrokerError::internal("policy lock poisoned"))? = Some(policy);
        Ok(())
    }
    pub(super) async fn reload_config(&self, params: &Value) -> Result<Value, BrokerError> {
        let dry_run = params["dry_run"]
            .as_bool()
            .ok_or_else(|| BrokerError::new("invalid_request", "dry_run must be boolean"))?;
        let active = self.role_policy().ok_or_else(|| {
            BrokerError::new("configuration_unavailable", "YAML-bound broker required")
        })?;
        let source = active["source"].as_str().ok_or_else(|| {
            BrokerError::new(
                "configuration_unavailable",
                "Broker lacks a pinned YAML source; deploy the updated broker once",
            )
        })?;
        let host = workspace::Host::load(Some(Path::new(source)))
            .map_err(|e| BrokerError::new("invalid_configuration", e.to_string()))?;
        let candidate = host
            .broker_policy()
            .map_err(|e| BrokerError::new("invalid_configuration", e.to_string()))?;
        if candidate["source"] != active["source"]
            || candidate["deployment"] != active["deployment"]
        {
            return Err(BrokerError::new("deployment_changed","Root/socket/state location changes require explicit deployment; current broker is preserved"));
        }
        if params["role_binding"] != candidate["binding"] {
            return Err(BrokerError::new(
                "role_binding_conflict",
                "Requested YAML differs from the broker's pinned configuration source",
            ));
        }
        let previous = self.event_store(false, |s| Ok(s.clone()))?;
        validate_change(&previous, &candidate["binding"])?;
        let changed = active["binding"] != candidate["binding"];
        let snapshot = self
            .herdr
            .call("session.snapshot", json!({}), Duration::from_secs(15))
            .await?["snapshot"]
            .clone();
        let roles = managed_layout::plan(&snapshot, &candidate["binding"], true)?;
        if changed && !dry_run {
            self.apply_role_policy(candidate)?;
        }
        Ok(json!({"dry_run":dry_run,"changed":changed,"applied":changed && !dry_run,"roles":roles}))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn binding() -> Value {
        json!({"computer_id":"test","computer_home":"/test","computer_name":"computer-orchestrator","kind":"codex","projects":{},"digest":"old"})
    }
    #[test]
    fn pending_events_block_changes_but_not_unchanged_starts() {
        let original = binding();
        let state = json!({"role_binding":original,"events":{"event":{"state":"running"}}});
        assert!(validate_change(&state, &original).is_ok());
        let mut next = original.clone();
        next["digest"] = json!("new");
        assert_eq!(
            validate_change(&state, &next).unwrap_err().code,
            "configuration_busy"
        );
        for status in ["queued", "offered", "executing", "uncertain"] {
            let mut pending = state.clone();
            pending["events"]["event"]["state"] = json!(status);
            assert!(validate_change(&pending, &next).is_err());
        }
        for status in ["completed", "failed"] {
            let mut terminal = state.clone();
            terminal["events"]["event"]["state"] = json!(status);
            assert!(validate_change(&terminal, &next).is_ok());
        }
    }
    #[test]
    fn owner_changes_require_explicit_migration() {
        let mut original = binding();
        original["projects"] = json!({"media":{"name":"project-orchestrator-media","cwd":"/test/media","kind":"codex"}});
        let state = json!({"role_binding":original,"events":{}});
        for field in ["computer_id", "computer_home", "computer_name", "kind"] {
            let mut next = original.clone();
            next[field] = json!("different");
            assert_eq!(
                validate_change(&state, &next).unwrap_err().code,
                "role_owner_conflict"
            );
        }
        for field in ["name", "cwd", "kind"] {
            let mut next = original.clone();
            next["projects"]["media"][field] = json!("different");
            assert_eq!(
                validate_change(&state, &next).unwrap_err().code,
                "role_owner_conflict"
            );
        }
    }
    #[test]
    fn adoption_is_shared_and_keeps_event_history_on_failure() {
        let root = std::env::temp_dir().join(format!("reload-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).unwrap();
        let broker = Broker::new(root.join("socket"), root.join("state"), root.clone()).unwrap();
        let original = json!({"binding":binding(),"retired_names":[]});
        *broker.role_policy.lock().unwrap() = Some(original.clone());
        broker.apply_role_policy(original.clone()).unwrap();
        broker
            .event_store(true, |s| {
                s["events"] = json!({"history":{"state":"completed","receipt":"keep"}});
                s["ready"] = json!({"state":"ready"});
                Ok(())
            })
            .unwrap();
        let clone = broker.clone();
        let mut next = original;
        next["binding"]["digest"] = json!("new");
        broker.apply_role_policy(next.clone()).unwrap();
        assert_eq!(clone.role_policy().unwrap()["binding"], next["binding"]);
        let saved = broker.event_store(false, |s| Ok(s.clone())).unwrap();
        assert!(saved["ready"].is_null());
        assert_eq!(saved["events"]["history"]["receipt"], "keep");
        broker
            .event_store(true, |s| {
                s["events"]["pending"] = json!({"state":"queued"});
                Ok(())
            })
            .unwrap();
        let before = broker.event_store(false, |s| Ok(s.clone())).unwrap();
        let active = broker.role_policy();
        next["binding"]["digest"] = json!("blocked");
        assert_eq!(
            broker.apply_role_policy(next).unwrap_err().code,
            "configuration_busy"
        );
        assert_eq!(broker.role_policy(), active);
        assert_eq!(
            broker.event_store(false, |s| Ok(s.clone())).unwrap(),
            before
        );
        fs::remove_dir_all(root).unwrap();
    }
}
