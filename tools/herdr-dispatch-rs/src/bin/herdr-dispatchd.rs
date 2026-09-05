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
    #[arg(long, value_name = "PATH")]
    socket: Option<PathBuf>,
    #[arg(long = "herdr-socket", value_name = "PATH")]
    herdr_socket: Option<PathBuf>,
    #[arg(long = "state-dir", value_name = "PATH")]
    state_dir: Option<PathBuf>,
    #[arg(long = "allowed-root", value_name = "PATH")]
    allowed_root: Option<PathBuf>,
}

fn env_path(name: &str, fallback: &str) -> PathBuf {
    std::env::var_os(name)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(fallback))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // The systemd unit also sets UMask=0077. Keep direct invocation safe too.
    unsafe { libc::umask(0o077) };
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();
    let args = Args::parse();
    let socket = args.socket.unwrap_or_else(|| {
        env_path(
            "HERDR_DISPATCH_SOCKET",
            "~/.config/herdr-dispatchd/dispatch.sock",
        )
    });
    let herdr_socket = args
        .herdr_socket
        .unwrap_or_else(|| env_path("HERDR_SOCKET_PATH", "~/.config/herdr/herdr.sock"));
    let state_dir = args
        .state_dir
        .unwrap_or_else(|| env_path("HERDR_DISPATCH_STATE_DIR", "~/.config/herdr-dispatchd"));
    let allowed_root = args
        .allowed_root
        .unwrap_or_else(|| env_path("HERDR_DISPATCH_ALLOWED_ROOT", "~/Work"));
    run_daemon(
        expand_user(socket),
        expand_user(herdr_socket),
        expand_user(state_dir),
        expand_user(allowed_root),
    )
    .await?;
    Ok(())
}
