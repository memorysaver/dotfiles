use super::*;
use monitor::find_executable;
use std::process::Command;

const MARKER: &str = "Managed by workspace-orchestrator";
pub(super) fn unit_quote(value: &str) -> String {
    format!(
        "\"{}\"",
        value
            .replace('\\', "\\\\")
            .replace('"', "\\\"")
            .replace('%', "%%")
    )
}
fn command_unit(args: &[String]) -> String {
    args.iter()
        .map(|v| unit_quote(v))
        .collect::<Vec<_>>()
        .join(" ")
}
fn managed(path: &Path) -> Result<()> {
    if let Ok(meta) = fs::symlink_metadata(path) {
        if !meta.file_type().is_file() || !fs::read_to_string(path)?.contains(MARKER) {
            return fail(format!(
                "Refusing to overwrite unmanaged path: {}",
                path.display()
            ));
        }
    }
    Ok(())
}
fn managed_write(path: &Path, content: &str) -> Result<()> {
    managed(path)?;
    fs::create_dir_all(
        path.parent()
            .ok_or_else(|| error("Missing parent directory"))?,
    )?;
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(path)?;
    file.set_permissions(fs::Permissions::from_mode(0o600))?;
    file.write_all(content.as_bytes())?;
    file.sync_all()?;
    Ok(())
}
fn checked(command: &str, args: &[&str]) -> Result<()> {
    if !Command::new(command).args(args).status()?.success() {
        return fail(format!("{command} failed"));
    }
    Ok(())
}
pub(super) fn linux_units(
    binary: &Path,
    herdr: &Path,
    config: Option<&Path>,
    path: &str,
) -> (String, String) {
    let mut command = vec![binary.to_string_lossy().to_string(), "watch".into()];
    if let Some(config) = config {
        command.extend(["--config".into(), config.to_string_lossy().to_string()]);
    }
    let server = vec![
        binary.to_string_lossy().to_string(),
        "server-watch".into(),
        "--binary".into(),
        herdr.to_string_lossy().to_string(),
    ];
    let unit=format!("[Unit]\n# {MARKER}\nDescription=Fixed local Herdr Orchestrator supervisor\nAfter=workspace-herdr-server.service herdr-dispatchd.service\nWants=workspace-herdr-server.service herdr-dispatchd.service\n\n[Service]\nType=simple\nUMask=0077\nEnvironment={}\nExecStart={}\nRestart=always\nRestartSec=10\n\n[Install]\nWantedBy=default.target\n",unit_quote(&format!("PATH={path}")),command_unit(&command));
    let server=format!("[Unit]\n# {MARKER}\nDescription=Local persistent Herdr server\n\n[Service]\nType=simple\nUMask=0077\nEnvironment={}\nExecStart={}\nKillMode=process\nRestart=always\nRestartSec=10\n\n[Install]\nWantedBy=default.target\n",unit_quote(&format!("PATH={path}")),command_unit(&server));
    (unit, server)
}
fn xml(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}
fn launch_agent(label: &str, args: &[String], path: &str, state: Option<&Path>) -> String {
    let args = args
        .iter()
        .map(|v| format!("<string>{}</string>", xml(v)))
        .collect::<String>();
    let logs=state.map(|s|format!("<key>StandardOutPath</key><string>{}</string><key>StandardErrorPath</key><string>{}</string>",xml(&s.join("supervisor.log").to_string_lossy()),xml(&s.join("supervisor-error.log").to_string_lossy()))).unwrap_or_default();
    format!("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict><key>Label</key><string>{}</string><key>Comment</key><string>{MARKER}</string><key>ProgramArguments</key><array>{args}</array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>10</integer><key>EnvironmentVariables</key><dict><key>PATH</key><string>{}</string></dict>{logs}</dict></plist>\n",xml(label),xml(path))
}
impl Host {
    pub fn install(&self) -> Result<Value> {
        let home = home()?;
        let binary = home.join(".local/bin/workspace-orchestrator");
        let source = self
            .paths
            .get("dotfiles")
            .join("tools/herdr-dispatch-rs/target/release/workspace-orchestrator");
        if source.canonicalize()? != env::current_exe()?.canonicalize()?
            || binary.canonicalize()? != source.canonicalize()?
        {
            return fail("Install the Rust binary from the configured dotfiles checkout first");
        }
        let herdr = find_executable("herdr")?;
        if self.socket != home.join(".config/herdr-dispatchd/dispatch.sock") {
            return fail(
                "Custom broker transport requires explicitly configured Herdr startup service",
            );
        }
        let workflow = self.rules.join("workflows/orchestrator-presence.yaml");
        let output = Command::new("dagu").arg("config").output()?;
        if !output.status.success() {
            return fail("Dagu configuration unavailable");
        }
        let output = String::from_utf8(output.stdout)?;
        let configured = output
            .lines()
            .find_map(|line| line.strip_prefix("DAGs directory:").map(str::trim))
            .ok_or_else(|| error("Dagu DAGs directory unavailable"))?;
        if weak_canonical(&config::expand_at(&home, Path::new(configured))?)?
            != self.paths.get("dags")
        {
            return fail("Configured DAGs path does not match local Dagu configuration");
        }
        let validated = Command::new("dagu")
            .arg("validate")
            .arg(&workflow)
            .output()?;
        if !validated.status.success() {
            return fail(format!(
                "Presence DAG validation failed: {}",
                String::from_utf8_lossy(&validated.stderr)
            ));
        }
        let deployed = self
            .paths
            .get("dags")
            .join("orchestrator/orchestrator-presence.yaml");
        if let Ok(meta) = fs::symlink_metadata(&deployed) {
            if !meta.file_type().is_symlink()
                || deployed.canonicalize()? != workflow.canonicalize()?
            {
                return fail("Refusing to replace unmanaged Dagu definition");
            }
        }
        let path = env::var("PATH").unwrap_or_else(|_| "/usr/local/bin:/usr/bin:/bin".into());
        let unit = match env::consts::OS {
            "linux" => {
                let unit = home.join(".config/systemd/user/workspace-orchestrator.service");
                let server = unit.with_file_name("workspace-herdr-server.service");
                managed(&unit)?;
                managed(&server)?;
                let (content, server_content) =
                    linux_units(&binary, &herdr, self.config.as_deref(), &path);
                managed_write(&unit, &content)?;
                managed_write(&server, &server_content)?;
                unit
            }
            "macos" => {
                let unit =
                    home.join("Library/LaunchAgents/dev.memorysaver.workspace-orchestrator.plist");
                let server = unit.with_file_name("dev.memorysaver.workspace-herdr-server.plist");
                managed(&unit)?;
                managed(&server)?;
                private_dir(self.paths.get("state"))?;
                let mut args = vec![binary.to_string_lossy().to_string(), "watch".into()];
                if let Some(config) = &self.config {
                    args.extend(["--config".into(), config.to_string_lossy().to_string()]);
                }
                managed_write(
                    &unit,
                    &launch_agent(
                        "dev.memorysaver.workspace-orchestrator",
                        &args,
                        &path,
                        Some(self.paths.get("state")),
                    ),
                )?;
                managed_write(
                    &server,
                    &launch_agent(
                        "dev.memorysaver.workspace-herdr-server",
                        &[
                            binary.to_string_lossy().to_string(),
                            "server-watch".into(),
                            "--binary".into(),
                            herdr.to_string_lossy().to_string(),
                        ],
                        &path,
                        None,
                    ),
                )?;
                unit
            }
            _ => return fail("Platform requires its own supervisor deployment"),
        };
        fs::create_dir_all(deployed.parent().unwrap())?;
        if fs::symlink_metadata(&deployed).is_err() {
            std::os::unix::fs::symlink(workflow.canonicalize()?, &deployed)?;
        }
        if env::consts::OS == "linux" {
            checked("systemctl", &["--user", "daemon-reload"])?;
            checked(
                "systemctl",
                &["--user", "enable", "workspace-herdr-server.service"],
            )?;
            checked(
                "systemctl",
                &["--user", "restart", "workspace-herdr-server.service"],
            )?;
            checked(
                "systemctl",
                &["--user", "enable", "workspace-orchestrator.service"],
            )?;
            checked(
                "systemctl",
                &["--user", "restart", "workspace-orchestrator.service"],
            )?;
        } else {
            checked(
                "launchctl",
                &[
                    "bootstrap",
                    &format!("gui/{}", unsafe { libc::getuid() }),
                    unit.to_str()
                        .ok_or_else(|| error("Invalid LaunchAgent path"))?,
                ],
            )?;
        }
        Ok(json!({"computer_id":self.computer,"service":unit,"workflow":deployed}))
    }
}
