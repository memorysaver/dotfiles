#!/usr/bin/env python3
"""Maintain one named local Herdr agent through the allowlisted dispatch broker."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
import plistlib

EVENT_SPEC = importlib.util.spec_from_file_location('orchestrator_events', Path(__file__).resolve().parents[1]/'lib/orchestrator-events.py')
events = importlib.util.module_from_spec(EVENT_SPEC); EVENT_SPEC.loader.exec_module(events)

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('workspace_paths', REPO / 'lib/workspace-paths.py')
resolver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolver)

def configuration(config_file=None):
    paths = resolver.resolve(config_file)
    identity = paths['identity']
    if identity.is_symlink() or not identity.is_file():
        raise ValueError('Computer identity must be a local regular file')
    computer = identity.read_text().strip()
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', computer):
        raise ValueError('Invalid computer identity')
    rules = paths['hosts'] / computer / 'orchestration-rules'
    if (paths['workspace'] / 'orchestration-rules').resolve() != rules.resolve():
        raise ValueError('Workspace rules do not match the selected computer')
    for filename in ('AGENTS.md', 'README.md'):
        source = paths['dotfiles']/'config/workspace'/filename
        deployed = paths['workspace']/filename
        if not deployed.is_file() or deployed.resolve()!=source.resolve():
            raise ValueError('Work '+filename+' must resolve to its managed dotfiles source')
    for filename in ('README.md', 'profile', 'orchestrator.toml'):
        if not (rules / filename).is_file():
            raise ValueError('Selected computer is missing ' + filename)
    profile = (rules / 'profile').read_text().strip()
    system = platform.system()
    if system == 'Darwin':
        valid = profile == 'mac'
    elif system == 'Linux':
        release = Path('/etc/os-release').read_text() if Path('/etc/os-release').exists() else ''
        omarchy = any(line in ('ID=omarchy', 'ID="omarchy"') for line in release.splitlines())
        valid = (profile in ('omarchy-server','omarchy-desktop') and omarchy
                 or profile == 'grok-bot' and not omarchy and os.environ.get('USER') == 'box'
                 and (os.environ.get('CURSOR_AGENT') == '1' or Path('/exec-daemon').exists()))
    else:
        valid = False
    if not valid:
        raise ValueError('Selected computer profile does not match the actual OS')
    host = tomllib.loads((rules / 'orchestrator.toml').read_text())
    if host.get('computer_id') != computer or host.get('enabled') is not True:
        raise ValueError('Orchestrator manifest must enable this exact computer')
    agent = host.get('agent', {})
    if agent.get('name', 'orchestrator') != 'orchestrator':
        raise ValueError('The shared fixed agent name is orchestrator')
    kind = agent.get('kind', 'codex')
    if kind not in ('codex','claude','pi','grok'):
        raise ValueError('Unsupported configured orchestrator kind')
    args = agent.get('args', [])
    if not isinstance(args, list) or any(not isinstance(a, str) for a in args):
        raise ValueError('Agent args must be a string array')
    interval = host.get('poll_seconds', 30)
    if not isinstance(interval, int) or isinstance(interval,bool) or not 10 <= interval <= 300:
        raise ValueError('poll_seconds must be between 10 and 300')
    transport = host.get('transport', {})
    socket = Path(transport.get('broker_socket', '~/.config/herdr-dispatchd/dispatch.sock')).expanduser()
    if not socket.is_absolute():
        raise ValueError('Broker socket must be absolute or ~/ relative')
    for name in ('workspace','dotfiles','idea','dags'):
        if not paths[name].is_dir():
            raise ValueError('Required configured directory is missing: ' + name)
    return paths, rules, computer, kind, args, interval, socket

def bootstrap(paths, rules, computer):
    return ('You are the fixed local Herdr Orchestrator for computer ' + computer + '.\n'
            'Read the Work AGENTS.md and README.md, then selected orchestration rules.\n'
            + 'Resolved local paths: ' + json.dumps({k:str(v) for k,v in paths.items()}) + '\n'
            + 'Selected private rules: ' + str(rules) + '\n'
            + 'Keep your cwd at the configured Work root; tab/pane placement does not identify you. Manage only this computer. '
            'Preserve existing workers and dirty repositories. Project implementation belongs '
            'in the receiving project workspace. Reuse authorized workers and verify artifacts. '
            'Do not perform business work merely because this bootstrap ran. '
            'Do not publish, send messages, or bypass approval dialogs. '
            'Read the host task definitions before accepting scheduled tasks. '
            'Confirm the role and remain available for authorized work.\n')

def ensure(config_file=None):
    paths, rules, computer, kind, args, interval, socket = configuration(config_file)
    client = shutil.which('herdr-dispatch')
    if not client:
        raise ValueError('herdr-dispatch is unavailable; install the updated broker first')
    paths['state'].mkdir(parents=True,exist_ok=True,mode=0o700)
    with tempfile.NamedTemporaryFile(mode='w', dir=paths['state'], prefix='bootstrap-', suffix='.txt') as f:
        f.write(bootstrap(paths,rules,computer));f.flush()
        command=[client,'--socket',str(socket),'ensure-orchestrator','--confirmed',
            '--cwd',str(paths['workspace']),'--agent-name','orchestrator','--kind',kind,
            '--prompt-file',f.name]
        for arg in args: command += ['--agent-arg='+arg]
        result=subprocess.run(command,capture_output=True,text=True,timeout=210)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'Orchestrator ensure failed')
    response=json.loads(result.stdout)
    # Atomic lifecycle receipt, not a transcript or a task-success receipt.
    with tempfile.NamedTemporaryFile(mode='w', dir=paths['state'], prefix='lifecycle-', delete=False) as record:
        tmp=Path(record.name)
        record.write(json.dumps({'computer_id':computer,'observed_at':time.time(),
                             'response':response},indent=2)+'\n')
        record.flush();os.fsync(record.fileno())
    try: tmp.replace(paths['state']/'lifecycle.json')
    finally: tmp.unlink(missing_ok=True)
    return response

def unit_quote(value):
    return '"'+str(value).replace('\\','\\\\').replace('"','\\"').replace('%','%%')+'"'

def managed_file(path,content):
    path.parent.mkdir(parents=True,exist_ok=True)
    if path.exists() or path.is_symlink():
        if path.is_symlink() or 'Managed by workspace-orchestrator' not in path.read_text():
            raise ValueError('Refusing to overwrite unmanaged path: '+str(path))
    path.write_text(content)
    path.chmod(0o600)

def install(config_file=None):
    paths,rules,computer,kind,args,interval,socket=configuration(config_file)
    if REPO.resolve() != paths['dotfiles']:
        raise ValueError('Install from the configured dotfiles checkout')
    herdr=shutil.which('herdr')
    if not herdr:
        raise ValueError('Herdr is unavailable')
    if socket != Path.home()/'.config/herdr-dispatchd/dispatch.sock':
        raise ValueError('Custom broker transport requires an explicitly configured Herdr startup service')
    # This validates manifests and paths before changing any local deployment.
    workflow=rules/'workflows/orchestrator-presence.yaml'
    if not workflow.is_file():
        raise ValueError('Selected computer is missing its orchestrator-presence workflow')
    dagu=shutil.which('dagu')
    if not dagu:
        raise ValueError('Dagu is unavailable; install the local scheduler first')
    resolved=subprocess.run([dagu,'config'],capture_output=True,text=True,check=True)
    actual_dags=next((line.split(':',1)[1].strip() for line in resolved.stdout.splitlines()
                     if line.startswith('DAGs directory:')),None)
    if actual_dags is None or Path(actual_dags).expanduser().resolve()!=paths['dags']:
        raise ValueError('Configured DAGs path does not match the local Dagu configuration')
    subprocess.run([dagu,'validate',str(workflow)],check=True,capture_output=True,text=True)
    binary=Path.home()/'.local/bin/workspace-orchestrator'
    source=REPO/'tools/workspace-orchestrator.py'
    binary.parent.mkdir(parents=True,exist_ok=True)
    launcher = ('#!/usr/bin/env python3\n# Managed by workspace-orchestrator\n'
        'import os,sys\n'
        + 'command = ' + repr([str(Path(sys.executable).resolve()),str(source)]) + '\n'
        + 'arguments = sys.argv[1:]\n'
        + ('arguments += ["--config", ' + repr(str(Path(config_file).expanduser().resolve())) + ']\n' if config_file else '')
        + 'os.execv(command[0],command+arguments)\n')
    managed_file(binary,launcher)
    binary.chmod(0o755)
    command=[str(Path(sys.executable).resolve()),str(source),'watch']
    if config_file: command += ['--config',str(Path(config_file).expanduser().resolve())]
    deployed=paths['dags']/'orchestrator/orchestrator-presence.yaml'
    deployed.parent.mkdir(parents=True,exist_ok=True)
    if deployed.exists() or deployed.is_symlink():
        if not deployed.is_symlink() or deployed.resolve()!=workflow.resolve():
            raise ValueError('Refusing to replace an unmanaged Dagu definition')
    else:
        deployed.symlink_to(workflow.resolve())
    server_command=[str(Path(sys.executable).resolve()),str(REPO/'tools/herdr-server-supervisor.py'),'--binary',herdr]
    if platform.system()=='Linux':
        unit=Path.home()/'.config/systemd/user/workspace-orchestrator.service'
        content=('[Unit]\n# Managed by workspace-orchestrator\n'
            'Description=Fixed local Herdr Orchestrator supervisor\n'
            'After=workspace-herdr-server.service herdr-dispatchd.service\nWants=workspace-herdr-server.service herdr-dispatchd.service\n\n'
            '[Service]\nType=simple\nUMask=0077\n'
            'Environment='+unit_quote('PATH='+os.environ.get('PATH',os.defpath))+'\n'
            'ExecStart='+' '.join(unit_quote(v) for v in command)+'\n'
            'Restart=always\nRestartSec=10\n\n[Install]\nWantedBy=default.target\n')
        server_unit=unit.with_name('workspace-herdr-server.service')
        server_content=('[Unit]\n# Managed by workspace-orchestrator\n'
            'Description=Local persistent Herdr server\n\n[Service]\nType=simple\nUMask=0077\n'
            'Environment='+unit_quote('PATH='+os.environ.get('PATH',os.defpath))+'\n'
            'ExecStart='+' '.join(unit_quote(v) for v in server_command)+'\n'
            'KillMode=process\nRestart=always\nRestartSec=10\n'
            '\n[Install]\nWantedBy=default.target\n')
        managed_file(server_unit,server_content)
        managed_file(unit,content)
        subprocess.run(['systemctl','--user','daemon-reload'],check=True)
        # The server supervisor adopts the healthy server without replacing panes.
        subprocess.run(['systemctl','--user','enable','--now','workspace-herdr-server.service'],check=True)
        subprocess.run(['systemctl','--user','enable','workspace-orchestrator.service'],check=True)
        subprocess.run(['systemctl','--user','restart','workspace-orchestrator.service'],check=True)
    elif platform.system()=='Darwin':
        label='dev.memorysaver.workspace-orchestrator'
        unit=Path.home()/'Library/LaunchAgents'/ (label+'.plist')
        paths['state'].mkdir(parents=True,exist_ok=True,mode=0o700)
        if unit.exists():
            old=plistlib.loads(unit.read_bytes())
            if old.get('Comment')!='Managed by workspace-orchestrator':
                raise ValueError('Refusing to overwrite an unmanaged LaunchAgent')
        unit.parent.mkdir(parents=True,exist_ok=True)
        unit.write_bytes(plistlib.dumps({'Label':label,'Comment':'Managed by workspace-orchestrator',
            'ProgramArguments':command,'RunAtLoad':True,'KeepAlive':True,'ThrottleInterval':10,
            'EnvironmentVariables':{'PATH':os.environ.get('PATH',os.defpath)},
            'StandardOutPath':str(paths['state']/'supervisor.log'),
            'StandardErrorPath':str(paths['state']/'supervisor-error.log')}))
        unit.chmod(0o600)
        server_unit=unit.with_name('dev.memorysaver.workspace-herdr-server.plist')
        if server_unit.exists():
            old=plistlib.loads(server_unit.read_bytes())
            if old.get('Comment')!='Managed by workspace-orchestrator':
                raise ValueError('Refusing to overwrite an unmanaged Herdr startup job')
        server_unit.write_bytes(plistlib.dumps({'Label':'dev.memorysaver.workspace-herdr-server',
            'Comment':'Managed by workspace-orchestrator','ProgramArguments':server_command,
            'RunAtLoad':True,'KeepAlive':True,'ThrottleInterval':10,
            'EnvironmentVariables':{'PATH':os.environ.get('PATH',os.defpath)}}))
        server_unit.chmod(0o600)
        # Server startup is registered for login; current panes stay open.
        # Loading a changed running job is a separate deliberate deployment operation.
        subprocess.run(['launchctl','bootstrap','gui/'+str(os.getuid()),str(unit)],check=True)
    else:
        raise ValueError('This platform requires its own supervisor deployment')
    print(json.dumps({'computer_id':computer,'service':str(unit),'workflow':str(deployed)}))

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('command',choices=['paths','check','ensure','watch','install','pump','event'])
    parser.add_argument('--config')
    args, remaining=parser.parse_known_args()
    if args.command=='event':
        print(json.dumps(events.main(sys.modules[__name__],args.config,remaining)));return
    if remaining: parser.error('Unexpected arguments')
    if args.command=='pump':
        print(json.dumps(events.pump(sys.modules[__name__],args.config)));return
    if args.command=='paths':
        print(json.dumps({k:str(v) for k,v in resolver.resolve(args.config).items()},indent=2));return
    if args.command=='check':
        paths,rules,computer,kind,native,interval,socket=configuration(args.config)
        print(json.dumps({'computer_id':computer,'rules':str(rules),'kind':kind,
            'broker_socket':str(socket),'paths':{k:str(v) for k,v in paths.items()}},indent=2));return
    if args.command=='install': install(args.config);return
    if args.command=='ensure': print(json.dumps(ensure(args.config)));return
    previous=None
    while True:
        try:
            response=ensure(args.config);agent=response.get('agent',{})
            delivery=events.pump(sys.modules[__name__],args.config)
            summary={'name':agent.get('name'),'pane':agent.get('pane_id'),
                     'status':agent.get('agent_status'),'created':response.get('created'),
                     'delivery':delivery.get('state'),'event_id':delivery.get('event_id'),
                     'event_state':delivery.get('event_state'),'since':delivery.get('since')}
            if summary != previous: print(json.dumps(summary),flush=True)
            previous=summary
        except Exception as error:
            message=str(error)
            if message != previous: print(message,file=sys.stderr,flush=True)
            previous=message
        # Reload host settings each iteration; an invalid manifest does not spin.
        try: interval=configuration(args.config)[5]
        except Exception: interval=30
        time.sleep(interval)

if __name__=='__main__':
    try: main()
    except (ValueError,OSError,RuntimeError,TimeoutError,subprocess.SubprocessError) as error:
        print(str(error),file=sys.stderr);sys.exit(1)
