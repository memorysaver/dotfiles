//! Native host CLI, configuration and callbacks. No Python runtime or temporary
//! broker request files; durable broker protocol/state remain compatible.
use clap::{Parser, Subcommand};
use regex::Regex;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs::OpenOptions;
use std::io::Write;
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use std::{env, fs};
use uuid::Uuid;

mod config;
mod events;
mod install;
mod manifest;
mod monitor;
#[cfg(test)]
mod tests;
use config::{home, weak_canonical};
pub use config::{Host, Paths};
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
fn error(message: impl Into<String>) -> Box<dyn std::error::Error> {
    std::io::Error::other(message.into()).into()
}
fn fail<T>(message: impl Into<String>) -> Result<T> {
    Err(error(message))
}
fn text<'a>(value: &'a Value, name: &str) -> Result<&'a str> {
    value
        .as_str()
        .filter(|s| !s.is_empty() && !s.contains('\0'))
        .ok_or_else(|| error(format!("Missing/invalid {name}")))
}
fn argv(value: &Value, nonempty: bool) -> Result<Vec<String>> {
    let args = value
        .as_array()
        .ok_or_else(|| error("Expected argv array"))?;
    if nonempty && args.is_empty() {
        return fail("Empty argv");
    }
    args.iter()
        .map(|v| {
            v.as_str()
                .filter(|s| !s.contains('\0'))
                .map(String::from)
                .ok_or_else(|| error("argv must contain strings without NUL"))
        })
        .collect()
}
fn quote(text: &str) -> String {
    format!("'{}'", text.replace('\'', "'\\''"))
}
fn shell_join(args: &[String]) -> String {
    args.iter().map(|s| quote(s)).collect::<Vec<_>>().join(" ")
}
fn sha256(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}
fn timestamp() -> f64 {
    chrono::Utc::now().timestamp_micros() as f64 / 1_000_000.0
}
fn private_dir(path: &Path) -> Result<()> {
    fs::create_dir_all(path)?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o700))?;
    Ok(())
}
fn read_json(path: &Path) -> Result<Value> {
    Ok(serde_json::from_slice(&fs::read(path)?)?)
}
fn atomic_json(path: &Path, value: &Value) -> Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| error("File requires parent directory"))?;
    private_dir(parent)?;
    let temp = parent.join(format!(".{}.tmp", Uuid::new_v4()));
    let saved = (|| -> Result<()> {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temp)?;
        file.write_all(&serde_json::to_vec_pretty(value)?)?;
        file.sync_all()?;
        fs::rename(&temp, path)?;
        fs::File::open(parent)?.sync_all()?;
        Ok(())
    })();
    if saved.is_err() {
        let _ = fs::remove_file(&temp);
    }
    saved
}
#[derive(Parser)]
#[command(
    name = "herdr-dispatch",
    version,
    about = "Local Computer -> Project orchestration, broker and supervision"
)]
struct Cli {
    #[arg(
        long,
        global = true,
        help = "Print the embedded agent skill without accessing configuration"
    )]
    skills: bool,
    #[arg(long, global = true)]
    config: Option<PathBuf>,
    #[command(subcommand)]
    command: Command,
}
#[derive(Subcommand)]
enum Command {
    Paths {
        #[arg(long, conflicts_with = "get")]
        shell: bool,
        #[arg(long,value_parser=["dotfiles","idea","workspace","dags","hosts","identity","state"])]
        get: Option<String>,
    },
    Check {
        #[arg(long)]
        live: bool,
    },
    Ensure,
    /// Start/reuse managed roles and arrange their workspaces in configured order.
    Start {
        #[arg(long)]
        dry_run: bool,
    },
    Watch,
    Pump,
    Install,
    Event(Box<events::EventArgs>),
    Projects {
        #[arg(value_parser=["list","ensure"])]
        action: String,
        #[arg(long)]
        project: Option<String>,
        #[arg(long)]
        adopt_pane: Option<String>,
    },
    ServerWatch(monitor::MonitorArgs),
    #[command(disable_help_flag = true)]
    Daemon {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<std::ffi::OsString>,
    },
    #[command(disable_help_flag = true)]
    #[command(name = "broker", alias = "dispatch")]
    Dispatch {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<std::ffi::OsString>,
    },
}
/// Main called by the one installed executable. Broker compatibility entrypoints
/// are handled by argv[0] in the binary before this command parser.
pub async fn run(args: impl IntoIterator<Item = std::ffi::OsString>) -> Result<()> {
    let cli = Cli::parse_from(args);
    let result = match cli.command {
        Command::Paths { shell, get } => {
            let paths = Host::load(cli.config.as_deref())?.paths;
            if shell {
                println!("{}", paths.shell());
                return Ok(());
            }
            if let Some(key) = get {
                println!("{}", paths.get(&key).display());
                return Ok(());
            }
            paths.json()
        }
        Command::ServerWatch(args) => {
            monitor::run(args).await?;
            return Ok(());
        }
        Command::Daemon { .. } | Command::Dispatch { .. } => return fail(
            "Place daemon/dispatch immediately after executable; these use their own broker flags",
        ),
        command => {
            let host = Host::load(cli.config.as_deref())?;
            match command {
                Command::Check { live } => {
                    if live {
                        host.call("resolve", json!({}))?;
                        for p in host.projects()? {
                            host.call("resolve_project", json!({"route":p["route"]}))?;
                        }
                    }
                    host.check()
                }
                Command::Ensure => host.ensure()?,
                Command::Start { dry_run } => host.start(dry_run)?,
                Command::Pump => host.pump()?,
                Command::Install => host.install()?,
                Command::Event(args) => host.event(*args).await?,
                Command::Projects {
                    action,
                    project,
                    adopt_pane,
                } => {
                    let projects = host.projects()?;
                    if action == "list" {
                        json!({"managed_count":projects.len(),"projects":projects})
                    } else {
                        if adopt_pane.is_some() && project.is_none() {
                            return fail("Adoption requires a specific project");
                        }
                        if let Some(id) = &project {
                            if !projects.iter().any(|p| p["project"] == *id) {
                                return fail("Project is not managed on this computer");
                            }
                        }
                        let mut result = serde_json::Map::new();
                        for p in projects {
                            let id = text(&p["project"], "project")?;
                            if project.as_deref().is_none_or(|selected| selected == id) {
                                result.insert(
                                    id.into(),
                                    host.ensure_project(id, adopt_pane.as_deref())?,
                                );
                            }
                        }
                        json!(result)
                    }
                }
                Command::Watch => {
                    watch(cli.config.as_deref()).await;
                    return Ok(());
                }
                _ => unreachable!(),
            }
        }
    };
    println!("{}", serde_json::to_string(&result)?);
    Ok(())
}
async fn watch(config: Option<&Path>) {
    let mut previous = String::new();
    loop {
        let result = (|| -> Result<Value> {
            let host = Host::load(config)?;
            let response = host.ensure()?;
            let agent = &response["agent"];
            let projects = host.projects()?;
            let mut errors = serde_json::Map::new();
            for p in &projects {
                let id = text(&p["project"], "project")?;
                if let Err(e) = host.ensure_project(id, None) {
                    errors.insert(id.into(), json!(e.to_string()));
                }
            }
            let delivery = host.pump()?;
            Ok(
                json!({"name":agent["name"],"pane":agent["pane_id"],"status":agent["agent_status"],"created":response["created"],"delivery":delivery["state"],"event_id":delivery["event_id"],"event_state":delivery["event_state"],"since":delivery["since"],"managed_projects":projects.iter().map(|p|p["project"].clone()).collect::<Vec<_>>(),"project_errors":errors}),
            )
        })();
        let message = match result {
            Ok(value) => value.to_string(),
            Err(e) => format!("Orchestrator supervisor: {e}"),
        };
        if message != previous {
            println!("{message}");
            let _ = std::io::stdout().flush();
            previous = message;
        }
        let interval = Host::load(config).map(|h| h.interval).unwrap_or(30);
        tokio::time::sleep(Duration::from_secs(interval)).await;
    }
}
