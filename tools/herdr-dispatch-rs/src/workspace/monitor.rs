use super::*;
use std::io::{BufRead, BufReader};
use std::os::unix::net::UnixStream;
use std::process::{Child, Command};

#[derive(Debug, clap::Args)]
pub struct MonitorArgs {
    #[arg(long)]
    binary: Option<PathBuf>,
    #[arg(long, default_value = "default")]
    session: String,
    #[arg(long)]
    once: bool,
}
pub(super) fn alive(path: &Path) -> Result<bool> {
    let mut stream = match UnixStream::connect(path) {
        Ok(stream) => stream,
        Err(e)
            if matches!(
                e.kind(),
                std::io::ErrorKind::NotFound | std::io::ErrorKind::ConnectionRefused
            ) =>
        {
            return Ok(false)
        }
        Err(e) => return Err(e.into()),
    };
    stream.set_read_timeout(Some(Duration::from_secs(3)))?;
    stream.set_write_timeout(Some(Duration::from_secs(3)))?;
    let id = Uuid::new_v4().to_string();
    writeln!(stream, "{}", json!({"id":id,"method":"ping","params":{}}))?;
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    loop {
        line.clear();
        if reader.read_line(&mut line)? == 0 {
            return fail("Herdr closed health connection; preserve existing server");
        }
        if line.len() > 1_000_000 {
            return fail("Oversized Herdr health response");
        }
        let response: Value = serde_json::from_str(&line)?;
        if response["id"] == id {
            if response.get("error").is_some() || response["result"]["type"] != "pong" {
                return fail("Unexpected Herdr health response; preserve existing server");
            }
            return Ok(true);
        }
    }
}
pub async fn run(args: MonitorArgs) -> Result<()> {
    if !Regex::new(r"^[a-zA-Z0-9_-]+$")?.is_match(&args.session) {
        return fail("Invalid local Herdr session");
    }
    let binary = match args.binary {
        Some(binary) => binary,
        None => find_executable("herdr")?,
    };
    let mut base = home()?.join(".config/herdr");
    if args.session != "default" {
        base = base.join("sessions").join(&args.session);
    }
    let mut child: Option<Child> = None;
    let mut previous = String::new();
    loop {
        let result = (|| -> Result<bool> {
            let healthy = alive(&base.join("herdr.sock"))?;
            let exited = match child.as_mut() {
                Some(child) => child.try_wait()?.is_some(),
                None => true,
            };
            if !healthy && exited {
                let mut command = Command::new(&binary);
                if args.session != "default" {
                    command.args(["--session", &args.session]);
                }
                child = Some(command.arg("server").spawn()?);
                println!("Launching configured local Herdr server");
            }
            if args.once && !healthy {
                return fail("Server launch submitted; readiness not yet verified");
            }
            Ok(healthy)
        })();
        let message = match result {
            Ok(true) => "Local Herdr server healthy; preserving existing panes".to_string(),
            Ok(false) => "Local Herdr server startup pending".to_string(),
            Err(e) => {
                if args.once {
                    return Err(e);
                }
                e.to_string()
            }
        };
        if previous != message {
            println!("{message}");
            let _ = std::io::stdout().flush();
            previous = message;
        }
        if args.once {
            return Ok(());
        }
        tokio::time::sleep(Duration::from_secs(5)).await;
    }
}
pub(super) fn find_executable(name: &str) -> Result<PathBuf> {
    for directory in env::split_paths(&env::var_os("PATH").unwrap_or_default()) {
        let path = directory.join(name);
        if path.is_file() && fs::metadata(&path)?.permissions().mode() & 0o111 != 0 {
            return Ok(path);
        }
    }
    fail(format!("{name} executable is unavailable"))
}
