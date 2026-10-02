//! Role operations have exact roots and registered routes; broad worker roots
//! cannot grant role ownership or inject an executable into a Dagu event.
use super::*;
impl Broker {
    pub(super) fn event_schema(&self) -> u64 {
        if self.role_policy.is_some() {
            2
        } else {
            1
        }
    }
    fn role_error(message: &str) -> BrokerError {
        BrokerError::new("role_binding_conflict", message)
    }
    pub(super) fn validate_role_request(
        &self,
        operation: &str,
        params: &Value,
    ) -> Result<(), BrokerError> {
        if operation == "dispatch" {
            let name = params["agent_name"].as_str().unwrap_or("");
            if name == "computer-orchestrator"
                || name.starts_with("project-orchestrator-")
                || name == "orchestrator"
                || self.role_policy.as_ref().is_some_and(|p| {
                    p["retired_names"]
                        .as_array()
                        .is_some_and(|a| a.iter().any(|v| v == name))
                })
            {
                return Err(Self::role_error(
                    "Worker cannot claim a reserved orchestrator name",
                ));
            }
            let cwd = self.cwd(params.get("cwd"))?;
            if !self.allowed_roots.iter().any(|root| cwd.starts_with(root)) {
                return Err(Self::role_error(
                    "Worker cwd is outside authorized worker roots",
                ));
            }
        }
        if !matches!(
            operation,
            "ensure_orchestrator" | "ensure_project_orchestrator" | "orchestrator_event"
        ) {
            return Ok(());
        }
        let Some(policy) = &self.role_policy else {
            #[cfg(test)]
            return Ok(());
            #[cfg(not(test))]
            return Err(Self::role_error(
                "Role operations require a YAML-bound broker",
            ));
        };
        let binding = &policy["binding"];
        if params["role_binding"] != *binding
            || binding["protocol"] != 2
            || params["cwd"] != binding["computer_home"]
            || params["kind"] != binding["kind"]
        {
            return Err(Self::role_error("Protocol v2 Computer binding required"));
        }
        if operation == "ensure_orchestrator" && params["agent_name"] != "computer-orchestrator" {
            return Err(Self::role_error("Computer role has a fixed name"));
        }
        if operation == "ensure_project_orchestrator" || params["action"] == "resolve_project" {
            let route = &params["route"];
            if !binding["projects"].as_object().is_some_and(|m| {
                m.iter().any(|(id, r)| {
                    r == route
                        && (operation != "ensure_project_orchestrator" || params["project"] == *id)
                })
            }) {
                return Err(Self::role_error("Project route is not registered"));
            }
        }
        if operation == "orchestrator_event" && params["action"] == "submit" {
            let payload = &params["payload"];
            let historical = self.event_store(false, |s| {
                Ok(s["events"][params["event_id"].as_str().unwrap_or("")].clone())
            })?;
            if matches!(historical["state"].as_str(), Some("completed" | "failed"))
                && historical["payload"] == *payload
            {
                return Ok(());
            }
            let project = payload["project"].as_str().unwrap_or("");
            let task = payload["task"].as_str().unwrap_or("");
            let expected = &policy["tasks"][project][task];
            if !expected.is_object()
                || payload["definition"] != expected["definition"]
                || payload["project_cwd"] != expected["project_cwd"]
                || payload["project_agent"] != expected["project_agent"]
            {
                return Err(Self::role_error(
                    "Only a registered task and exact project route can be submitted",
                ));
            }
        }
        Ok(())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn exact_roles_do_not_inherit_worker_root_authority() {
        let root = std::env::temp_dir().join(format!("role-policy-{}", Uuid::new_v4()));
        fs::create_dir_all(root.join("repo")).unwrap();
        let mut b = Broker::new(root.join("socket"), root.join("state"), root.clone()).unwrap();
        let route = json!({"name":"project-orchestrator-media","cwd":root.join("repo"),"kind":"codex","args":[]});
        let binding = json!({"protocol":2,"computer_home":root,"kind":"codex","projects":{"media":route},"digest":"frozen"});
        b.role_policy = Some(
            json!({"binding":binding,"tasks":{"media":{"probe":{"definition":{"entrypoint":["git","status"]},"project_cwd":root.join("repo"),"project_agent":route}}},"retired_names":["project-old"]}),
        );
        let mut p = json!({"role_binding":binding,"cwd":root,"kind":"codex","project":"media","route":route});
        assert!(b
            .validate_role_request("ensure_project_orchestrator", &p)
            .is_ok());
        p["route"]["cwd"] = json!(root);
        assert!(b
            .validate_role_request("ensure_project_orchestrator", &p)
            .is_err());
        p["route"] = route.clone();
        p["role_binding"]["digest"] = json!("different-owner");
        assert!(b
            .validate_role_request("ensure_project_orchestrator", &p)
            .is_err());
        assert!(b
            .validate_role_request(
                "ensure_orchestrator",
                &json!({"cwd":root,"kind":"codex","agent_name":"orchestrator"})
            )
            .is_err());
        for name in [
            "computer-orchestrator",
            "project-orchestrator-any",
            "orchestrator",
            "project-old",
        ] {
            assert!(b
                .validate_role_request("dispatch", &json!({"agent_name":name,"cwd":root}))
                .is_err());
        }
        p["role_binding"] = binding;
        p["action"] = json!("submit");
        p["event_id"] = json!("test");
        p["payload"] = json!({"project":"media","task":"probe","definition":{"entrypoint":["touch","unregistered"]},"project_cwd":root.join("repo"),"project_agent":route});
        assert!(b.validate_role_request("orchestrator_event", &p).is_err());
        fs::write(
            root.join("state/orchestrator-events.json"),
            "{\"schema\":1,\"events\":{}}",
        )
        .unwrap();
        assert!(b.event_store(false, |_| Ok(())).is_err());
        fs::remove_dir_all(root).unwrap();
    }
}
