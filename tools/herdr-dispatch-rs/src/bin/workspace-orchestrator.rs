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
    let legacy = if name == "herdr-dispatchd" {
        Some("daemon")
    } else if name == "herdr-dispatch" {
        Some("dispatch")
    } else {
        None
    };
    let route = legacy.map(String::from).or_else(|| {
        args.get(1)
            .and_then(|s| s.to_str())
            .filter(|s| matches!(*s, "daemon" | "dispatch"))
            .map(String::from)
    });
    if route.is_some() && legacy.is_none() {
        args.remove(1);
    }
    let result = match route.as_deref() {
        Some("daemon") => daemon::run(args).await,
        Some("dispatch") => dispatch::run(args),
        _ => herdr_dispatch::workspace::run(args).await,
    };
    if let Err(error) = result {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
