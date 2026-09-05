use clap::{Args, Parser, Subcommand};
use herdr_dispatch::{broker_call, expand_user, read_prompt, BrokerError, MAX_TIMEOUT_MS};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::time::Duration;

#[derive(Debug, Parser)]
#[command(
    name = "herdr-dispatch",
    version,
    about = "CLI client for the local Herdr dispatch broker"
)]
struct Cli {
    #[arg(long, global = true, value_name = "PATH")]
    socket: Option<PathBuf>,
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Health,
    Snapshot,
    Tasks,
    Dispatch(Box<DispatchArgs>),
    Status(TaskArgs),
    Read(ReadArgs),
    Wait(WaitArgs),
}

#[derive(Debug, Args)]
struct DispatchArgs {
    #[arg(long, help = "assert that the user confirmed the proposal")]
    confirmed: bool,
    #[arg(long)]
    task_id: String,
    #[arg(long)]
    kind: String,
    #[arg(long)]
    cwd: String,
    #[arg(
        long,
        value_parser = ["workspace", "tab", "pane"],
        default_value = "workspace"
    )]
    layout: String,
    #[arg(long)]
    label: Option<String>,
    #[arg(long)]
    workspace_id: Option<String>,
    #[arg(long)]
    target_pane_id: Option<String>,
    #[arg(long, value_parser = ["right", "down"], default_value = "right")]
    direction: String,
    #[arg(long)]
    ratio: Option<f64>,
    #[arg(long)]
    agent_name: Option<String>,
    #[arg(long = "agent-arg")]
    agent_args: Vec<String>,
    #[arg(long, default_value_t = 30_000)]
    start_timeout_ms: u64,
    #[arg(long)]
    prompt: Option<String>,
    #[arg(long)]
    prompt_file: Option<PathBuf>,
}

#[derive(Debug, Args)]
struct TaskArgs {
    #[arg(long)]
    task_id: String,
}

#[derive(Debug, Args)]
struct ReadArgs {
    #[arg(long)]
    task_id: String,
    #[arg(long, default_value_t = 120)]
    lines: i64,
}

#[derive(Debug, Args)]
struct WaitArgs {
    #[arg(long)]
    task_id: String,
    #[arg(long, default_value_t = MAX_TIMEOUT_MS)]
    timeout_ms: u64,
    #[arg(long = "until")]
    until: Vec<String>,
}

fn default_socket() -> PathBuf {
    std::env::var_os("HERDR_DISPATCH_SOCKET")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("~/.config/herdr-dispatchd/dispatch.sock"))
}

fn command_request(command: Command) -> Result<(&'static str, Value, Duration), BrokerError> {
    match command {
        Command::Health => Ok(("health", json!({}), Duration::from_secs(30))),
        Command::Snapshot => Ok(("snapshot", json!({}), Duration::from_secs(30))),
        Command::Tasks => Ok(("tasks", json!({}), Duration::from_secs(30))),
        Command::Dispatch(args) => {
            let prompt = read_prompt(args.prompt, args.prompt_file.as_deref())?;
            let timeout = Duration::from_millis(args.start_timeout_ms)
                .saturating_add(Duration::from_secs(60));
            Ok((
                "dispatch",
                json!({
                    "confirmed": args.confirmed,
                    "task_id": args.task_id,
                    "kind": args.kind,
                    "cwd": args.cwd,
                    "layout": args.layout,
                    "label": args.label,
                    "workspace_id": args.workspace_id,
                    "target_pane_id": args.target_pane_id,
                    "direction": args.direction,
                    "ratio": args.ratio,
                    "agent_name": args.agent_name,
                    "agent_args": args.agent_args,
                    "start_timeout_ms": args.start_timeout_ms,
                    "prompt": prompt,
                }),
                timeout,
            ))
        }
        Command::Status(args) => Ok((
            "status",
            json!({"task_id": args.task_id}),
            Duration::from_secs(30),
        )),
        Command::Read(args) => Ok((
            "read",
            json!({"task_id": args.task_id, "lines": args.lines}),
            Duration::from_secs(30),
        )),
        Command::Wait(args) => {
            let until = if args.until.is_empty() {
                vec!["idle", "done", "blocked"]
            } else {
                args.until.iter().map(String::as_str).collect()
            };
            Ok((
                "wait",
                json!({"task_id": args.task_id, "timeout_ms": args.timeout_ms, "until": until}),
                Duration::from_millis(args.timeout_ms).saturating_add(Duration::from_secs(30)),
            ))
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    let socket = expand_user(cli.socket.unwrap_or_else(default_socket));
    let (operation, params, timeout) = command_request(cli.command)?;
    let result = broker_call(&socket, operation, params, timeout)?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}
