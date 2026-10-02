//! One executable, with legacy broker names as argv[0] compatibility aliases.
#[path = "../cli/daemon.rs"]
mod daemon;
#[path = "../cli/dispatch.rs"]
mod dispatch;
#[tokio::main]
async fn main() {
    let mut args = std::env::args_os().collect::<Vec<_>>();
    let name = args
        .first()
        .and_then(|s| std::path::Path::new(s).file_name())
        .and_then(|s| s.to_str())
        .unwrap_or("");
    // Offline output must not consult config, state or the server.
    if args.iter().any(|a| a == "--skills") {
        print!("{}", include_str!("../../skills/herdr-dispatch/SKILL.md"));
        return;
    }
    let legacy = if name == "herdr-dispatchd" {
        Some("daemon")
    } else {
        None
    };
    let mut index = 1;
    while index < args.len() && args[index].to_string_lossy().starts_with('-') {
        let option = args[index].to_string_lossy();
        index += if matches!(option.as_ref(), "--config" | "--socket") {
            2
        } else {
            1
        };
    }
    let command = args.get(index).and_then(|a| a.to_str()).unwrap_or("");
    let explicit = args.get(1).and_then(|a| a.to_str());
    let old_worker = matches!(
        command,
        "health" | "snapshot" | "tasks" | "history" | "result" | "status" | "read" | "wait"
    ) || (explicit == Some("dispatch")
        && args
            .get(2)
            .is_some_and(|a| a.to_string_lossy().starts_with("--")));
    let route = legacy
        .map(String::from)
        .or_else(|| {
            Some(command)
                .filter(|s| matches!(*s, "daemon" | "broker" | "dispatch"))
                .map(|s| {
                    if s == "daemon" {
                        "daemon".into()
                    } else {
                        "dispatch".into()
                    }
                })
        })
        .or_else(|| old_worker.then(|| "legacy".into()));
    if matches!(route.as_deref(), Some("daemon" | "dispatch"))
        && legacy.is_none()
        && !(old_worker && explicit == Some("dispatch"))
    {
        args.remove(index);
    }
    let result = match route.as_deref() {
        Some("daemon") => daemon::run(args).await,
        Some("dispatch" | "legacy") => dispatch::run(args),
        _ => herdr_dispatch::workspace::run(args).await,
    };
    if let Err(error) = result {
        eprintln!("{error}");
        let code = if error
            .downcast_ref::<std::io::Error>()
            .is_some_and(|e| e.kind() == std::io::ErrorKind::InvalidInput)
        {
            2
        } else {
            1
        };
        std::process::exit(code);
    }
}
