use clap::Parser;
use env_logger::Env;
use herdr_dispatch::{expand_user, run_daemon};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(
    name = "herdr-dispatchd",
    version,
    about = "Local broker for approved OpenAB-to-Herdr dispatch"
)]
struct Args {
    #[arg(long)]
    config: Option<PathBuf>,
    #[arg(long, value_name = "PATH")]
    socket: Option<PathBuf>,
    #[arg(long = "herdr-socket", value_name = "PATH")]
    herdr_socket: Option<PathBuf>,
    #[arg(long = "state-dir", value_name = "PATH")]
    state_dir: Option<PathBuf>,
    #[arg(long = "allowed-root", value_name = "PATH")]
    allowed_root: Vec<PathBuf>,
}

fn env_path(name: &str, fallback: &str) -> PathBuf {
    std::env::var_os(name)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(fallback))
}

pub async fn run(
    args: impl IntoIterator<Item = std::ffi::OsString>,
) -> Result<(), Box<dyn std::error::Error>> {
    // The systemd unit also sets UMask=0077. Keep direct invocation safe too.
    unsafe { libc::umask(0o077) };
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();
    let args = Args::parse_from(args);
    let host = herdr_dispatch::workspace::Host::load(args.config.as_deref())?;
    let socket = args.socket.unwrap_or_else(|| host.socket.clone());
    let herdr_socket = args
        .herdr_socket
        .unwrap_or_else(|| env_path("HERDR_SOCKET_PATH", "~/.config/herdr/herdr.sock"));
    let state_dir = args
        .state_dir
        .unwrap_or_else(|| host.broker_state_dir().expect("validated broker state"));
    let allowed_roots = if args.allowed_root.is_empty() {
        vec![host.paths.get("workspace").to_path_buf()]
    } else {
        args.allowed_root
    };
    if expand_user(herdr_socket.clone()) != expand_user("~/.config/herdr/herdr.sock") {
        return Err("YAML v1 supports the local default Herdr socket only".into());
    }
    if expand_user(socket.clone()) != host.socket
        || expand_user(state_dir.clone()) != host.broker_state_dir()?
    {
        return Err("Daemon paths differ from YAML configuration".into());
    }
    run_daemon(
        expand_user(socket),
        expand_user(herdr_socket),
        expand_user(state_dir),
        allowed_roots,
        host.broker_policy()?,
    )
    .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allowed_root_is_repeatable_and_optional() {
        assert!(Args::try_parse_from(["herdr-dispatchd"])
            .unwrap()
            .allowed_root
            .is_empty());
        let args = Args::try_parse_from([
            "herdr-dispatchd",
            "--allowed-root",
            "/work",
            "--allowed-root",
            "/private",
        ])
        .unwrap();
        assert_eq!(
            args.allowed_root,
            vec![PathBuf::from("/work"), PathBuf::from("/private")]
        );
    }
}
