"""Computer-to-project event routing; external callers use only the broker."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import re
import subprocess
import tempfile
import time
import tomllib
from datetime import datetime
from zoneinfo import ZoneInfo


def call(host, config, action, **values):
    paths, rules, computer, kind, native, interval, socket = host.configuration(config)
    request = dict(cwd=str(paths['workspace']), kind=kind, **values)
    operation='ensure-project-orchestrator' if action=='ensure_project' else 'orchestrator-event'
    if action!='ensure_project': request['action']=action
    client = shutil.which('herdr-dispatch')
    if not client:
        raise ValueError('herdr-dispatch is unavailable')
    paths['state'].mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode='w', dir=paths['state'], prefix='event-', suffix='.json') as f:
        json.dump(request, f); f.flush()
        result = subprocess.run([client, '--socket', str(socket), operation, '--request-file', f.name],
                                capture_output=True, text=True, timeout=100)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'Event broker request failed')
    return json.loads(result.stdout)


def project_registry(host,config):
    rules=host.configuration(config)[1]
    registry=rules/'projects.toml'
    return tomllib.loads(registry.read_text()).get('projects',{}) if registry.exists() else {}


def registered_project(host,config,project):
    paths,rules,computer,*rest=host.configuration(config)
    selected=project_registry(host,config).get(project,{})
    if selected.get('enabled') is not True: raise ValueError('Project is not enabled on this computer')
    location=Path(selected['repo']).expanduser()
    cwd=(location if location.is_absolute() else paths['workspace']/location).resolve()
    if not cwd.is_dir() or not (cwd/'AGENTS.md').is_file() or not (cwd/'README.md').is_file():
        raise ValueError('Registered project path/instructions are missing')
    git_root=Path(subprocess.check_output(['git','-C',str(cwd),'rev-parse','--show-toplevel'],text=True).strip()).resolve()
    if git_root!=cwd: raise ValueError('Project Orchestrator cwd must be its repository root')
    agent=selected.get('orchestrator',{})
    name=agent.get('name'); kind=agent.get('kind','codex')
    if not name or not re.fullmatch(r'project-[a-z0-9_-]{1,24}',name) or kind not in ('codex','claude','pi','grok'):
        raise ValueError('Project needs a unique project-* agent name and supported kind')
    route=dict(name=name,kind=kind,cwd=str(cwd),args=agent.get('args',[]))
    if 'launcher' in agent:
        launcher=agent['launcher']
        if not isinstance(launcher,list) or not launcher or any(not isinstance(v,str) or '\0' in v for v in launcher):
            raise ValueError('Project launcher must be argv')
        route['launcher']=launcher
    return dict(project=project,repo=str(cwd),workspace_label=selected.get('workspace_label',project),route=route)


def project_ensure(host,config,project,adopt_pane=None):
    selected=registered_project(host,config,project)
    bootstrap=(f"You are the fixed Project Orchestrator {selected['route']['name']} for {project}. "
        f"Your cwd is {selected['repo']}. Read AGENTS.md and README.md, check Git status and preserve dirty work. "
        "Computer Orchestrator in Work is your parent for Dagu events. Own project planning, producers and workers. "
        "Await authorized events; read current project instructions and acknowledge each correlated event before execution. "
        "Follow the project's launcher, topic/editor/publication gates. Never infer completion from idle/done or change approvals. "
        "This initializes the role only; do not start production.")
    return call(host,config,'ensure_project',confirmed=True,project=project,route=selected['route'],
                workspace_label=selected['workspace_label'],bootstrap=bootstrap,adopt_pane=adopt_pane)


def projects_main(host,config,arguments):
    parser=argparse.ArgumentParser(prog='workspace-orchestrator projects')
    parser.add_argument('action',choices=['list','ensure']); parser.add_argument('--project'); parser.add_argument('--adopt-pane')
    args=parser.parse_args(arguments)
    selected=[registered_project(host,config,id) for id,p in project_registry(host,config).items() if p.get('enabled') is True]
    if len({p['route']['name'] for p in selected})!=len(selected): raise ValueError('Managed project agent names must be unique')
    if args.action=='list': return dict(managed_count=len(selected),projects=selected)
    if args.project and not any(p['project']==args.project for p in selected): raise ValueError('Project is not managed on this computer')
    if args.adopt_pane and not args.project: raise ValueError('Adoption requires a specific project')
    return {p['project']:project_ensure(host,config,p['project'],args.adopt_pane) for p in selected if not args.project or p['project']==args.project}


def reply_prefix(config):
    prefix=[str(Path.home()/'.local/bin/workspace-orchestrator')]
    if config: prefix+=['--config',str(Path(config).expanduser().resolve())]
    return shlex.join(prefix)


def registered_task(host, config, project, task):
    paths, rules, computer, *rest = host.configuration(config)
    registry = tomllib.loads((rules/'projects.toml').read_text())
    selected = registry.get('projects', {}).get(project, {})
    definition = selected.get('tasks', {}).get(task)
    if not definition:
        raise ValueError('Project/task is not registered on this computer')
    location=Path(selected['repo']).expanduser()
    cwd=(location if location.is_absolute() else paths['workspace']/location).resolve()
    if not cwd.is_dir():
        raise ValueError('Registered project path must exist')
    entrypoint = definition.get('entrypoint')
    if not isinstance(entrypoint, list) or not entrypoint or any(not isinstance(v, str) or '\0' in v for v in entrypoint):
        raise ValueError('Registered entrypoint must be an argv array')
    if not (cwd/'AGENTS.md').is_file() or not (cwd/'README.md').is_file():
        raise ValueError('Project instructions are missing')
    timeout=definition.get('timeout_seconds',7200)
    if not isinstance(timeout,int) or isinstance(timeout,bool) or not 1<=timeout<=7200:
        raise ValueError('Registered timeout must be between 1 and 7200 seconds')
    payload=dict(project=project,task=task,project_cwd=str(cwd),definition=definition)
    if selected.get('internal') is True:
        if cwd!=paths['workspace']: raise ValueError('Internal probes must use Work cwd')
    else:
        payload['project_agent']=registered_project(host,config,project)['route']
    return payload


def pump(host, config):
    paths, rules, computer, *rest = host.configuration(config)
    inputs = [paths['workspace']/'AGENTS.md', paths['workspace']/'README.md',
              rules/'README.md', rules/'agents.md', rules/'profile', rules/'orchestrator.toml',
              paths['dotfiles']/'config/workspace/orchestration-rules/orchestrator.md',
              paths['dotfiles']/'config/workspace/orchestration-rules/external-dispatch.md',
              paths['dotfiles']/'config/workspace/orchestration-rules/profiles'/((rules/'profile').read_text().strip()+'.md')]
    if (rules/'projects.toml').exists(): inputs.append(rules/'projects.toml')
    digest = hashlib.sha256()
    for p in inputs:
        digest.update(str(p.resolve()).encode()); digest.update(p.read_bytes())
    prefix = [str(Path.home()/'.local/bin/workspace-orchestrator')]
    if config: prefix += ['--config', str(Path(config).expanduser().resolve())]
    response=call(host,config,'pump',confirmed=True,rules_version=digest.hexdigest(),
                  bootstrap=host.bootstrap(paths,rules,computer),reply_prefix=shlex.join(prefix))
    forwarding_errors={}
    for event in sorted(call(host,config,'list')['events'].values(),key=lambda e:e.get('created_at','')):
        if event['state']=='accepted' and event.get('project_delivery',{}).get('state')=='queued':
            try: response=call(host,config,'forward',event_id=event['event_id'],nonce=event['nonce'],reply_prefix=reply_prefix(config))
            except (ValueError,OSError,RuntimeError,subprocess.SubprocessError) as error: forwarding_errors[event['event_id']]=str(error)
    if forwarding_errors: response=dict(response,forwarding_errors=forwarding_errors)
    return response


def find_event(host, config, event_id=None, nonce=None):
    if event_id:
        event = call(host, config, 'status', event_id=event_id)
    else:
        candidates = [e for e in call(host, config, 'list')['events'].values() if nonce in (e['nonce'], e.get('project_delivery',{}).get('nonce'), e.get('computer_return',{}).get('nonce'))]
        if len(candidates)!=1: raise ValueError('Nonce must identify exactly one event')
        event = candidates[0]
    if nonce and nonce not in (event['nonce'], event.get('project_delivery',{}).get('nonce'), event.get('computer_return',{}).get('nonce')): raise ValueError('Event nonce differs')
    return event


def execute(host, config, event):
    if event['state']!='accepted': raise ValueError('Event must be acknowledged before execution')
    payload = event['payload']
    current = registered_task(host, config, payload['project'], payload['task'])
    frozen = {k:payload[k] for k in current}
    if current!=frozen: raise ValueError('Registered task changed after enqueue; reconcile before running')
    project_route=payload.get('project_agent')
    if project_route:
        if event.get('project_delivery',{}).get('state')!='accepted': raise ValueError('Project has not acknowledged this event')
        live=call(host,config,'resolve_project',route=project_route)
        expected=event['project_delivery']['terminal_id']
    else:
        live=call(host,config,'resolve'); expected=event['terminal_id']
    if live['terminal_id']!=expected:
        raise ValueError('Agent generation changed before execution')
    execution_nonce=event['project_delivery']['nonce'] if project_route else event['nonce']
    paths, rules, computer, *rest = host.configuration(config)
    if current['definition'].get('same_day') and payload.get('trigger_date')!=datetime.now(ZoneInfo('Asia/Taipei')).date().isoformat():
        return call(host,config,'complete',event_id=event['event_id'],nonce=execution_nonce,status='failed',result={'reason':'Trigger day expired; no project execution'})
    # Create an exclusive execution claim BEFORE running anything. A crash never authorizes replay.
    claims = paths['state']/'execution-claims'; claims.mkdir(parents=True, exist_ok=True, mode=0o700)
    claim = claims/(hashlib.sha256((event['event_id']+':'+execution_nonce).encode()).hexdigest()+'.json')
    try:
        fd = os.open(claim, os.O_WRONLY|os.O_CREAT|os.O_EXCL, 0o600)
    except FileExistsError:
        raise ValueError('Execution was already claimed; inspect its receipt before any replay') from None
    with os.fdopen(fd, 'w') as f:
        json.dump(dict(event_id=event['event_id'], nonce=execution_nonce, started_at=time.time()),f)
        f.flush(); os.fsync(f.fileno())
    call(host,config,'claim',event_id=event['event_id'],nonce=execution_nonce)
    # Keep output in host-owned private logs, outside project dirty trees.
    log = claims/(claim.stem+'.log')
    with log.open('w') as output:
        log.chmod(0o600)
        argv = [part.replace('${date}',payload.get('trigger_date','')).replace('${slot}',payload.get('trigger_slot',''))
                for part in current['definition']['entrypoint']]
        environment=os.environ.copy()
        environment.update(payload.get('trigger_env',{}))
        argv=[re.sub(r'\$\{env:([A-Z_]+)\}',lambda m:payload.get('trigger_env',{}).get(m[1],''),v) for v in argv]
        if payload.get('trigger_artifacts_dir'): environment['DAG_RUN_ARTIFACTS_DIR']=payload['trigger_artifacts_dir']
        process = subprocess.Popen(argv, env=environment, cwd=current['project_cwd'], stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            exit_code=process.wait(timeout=current['definition'].get('timeout_seconds',7200))
            receipt=dict(exit_code=exit_code, log=str(log), finished_at=time.time(),
                         verification='project entrypoint exit status; business artifacts remain project-owned')
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGKILL); process.wait()
            receipt=dict(outcome='timeout', effects='unknown; reconcile project artifacts before replay',log=str(log),finished_at=time.time())
    receipt_file=claim.with_suffix('.result.json')
    with tempfile.NamedTemporaryFile(mode='w',dir=claims,delete=False) as f:
        temporary=Path(f.name); json.dump(receipt,f); f.flush(); os.fsync(f.fileno())
    temporary.replace(receipt_file)
    directory_fd=os.open(claims,os.O_RDONLY)
    try: os.fsync(directory_fd)
    finally: os.close(directory_fd)
    if receipt.get('outcome')=='timeout':
        raise RuntimeError('Project timed out; receipt saved, effects unknown, event remains accepted')
    # A lost completion response can be reconciled using the persisted receipt, without rerunning.
    return call(host, config, 'complete', event_id=event['event_id'], nonce=execution_nonce,
                status='completed' if exit_code==0 else 'failed', result=receipt)


def bridge(host,config,nonce,callback,project=None):
    # The read-only model uses only its explicitly allowed Herdr socket. The new
    # shell receives real Herdr context and runs the registered callback itself.
    if callback not in ('ready','consume','project-consume','computer-complete'): raise ValueError('Bridge requires --callback ready or consume')
    if os.environ.get('HERDR_ENV')!='1': raise ValueError('Bridge requires a genuine Herdr caller')
    if not nonce or not re.fullmatch(r'[0-9a-f-]{36}',nonce): raise ValueError('Invalid callback nonce')
    paths,rules,computer,kind,*rest=host.configuration(config)
    def herdr(*arguments):
        result=subprocess.run(['herdr',*arguments],capture_output=True,text=True,check=True,timeout=40)
        if arguments[:2]==('pane','run') and not result.stdout.strip(): return {}
        return json.loads(result.stdout)['result']
    route=registered_project(host,config,project)['route'] if callback=='project-consume' else dict(name='orchestrator',kind=kind,cwd=str(paths['workspace']))
    live=herdr('agent','get',route['name'])['agent']
    if live['agent']!=route['kind'] or Path(live['cwd']).resolve()!=Path(route['cwd']):
        raise ValueError('Fixed agent identity differs')
    if os.environ.get('HERDR_PANE_ID')!=live['pane_id']:
        raise ValueError('Only the fixed Orchestrator may create its callback shell')
    pane=herdr('pane','split','--pane',live['pane_id'],'--direction','down',
               '--cwd',route['cwd'],'--no-focus')['pane']['pane_id']
    prefix=[str(Path.home()/'.local/bin/workspace-orchestrator')]
    if config: prefix += ['--config',str(Path(config).expanduser().resolve())]
    callback_args=['event',callback,'--nonce',nonce]
    if project: callback_args+=['--project',project]
    command=shlex.join(prefix+callback_args)
    # Only this newly created callback pane is closed, after a successful durable receipt.
    # Failures retain the shell for inspection. Project workers run in their own panes.
    command += ' && '+shlex.join(['herdr','pane','close',pane])
    herdr('pane','run',pane,command)
    return dict(callback=callback,pane_id=pane,submission='shell command submitted; inspect correlated broker receipt')

def main(host, config, arguments):
    parser=argparse.ArgumentParser(prog='workspace-orchestrator event')
    parser.add_argument('action',choices=['submit','status','list','ready','ack','execute','complete','reconcile','verify','bridge','consume','project-consume','computer-complete','reconcile-readiness'])
    parser.add_argument('--project'); parser.add_argument('--task'); parser.add_argument('--event-id')
    parser.add_argument('--nonce'); parser.add_argument('--dagu',action='store_true')
    parser.add_argument('--wait',action='store_true'); parser.add_argument('--timeout',type=int,default=7200)
    parser.add_argument('--result-file'); parser.add_argument('--status',choices=['completed','failed'])
    parser.add_argument('--decision',choices=['resend','drop','completed']); parser.add_argument('--reason')
    parser.add_argument('--confirmed',action='store_true')
    parser.add_argument('--callback',choices=['ready','consume','project-consume','computer-complete'])
    args=parser.parse_args(arguments)
    if args.dagu:
        workflow=os.environ.get('DAG_NAME'); run=os.environ.get('DAG_RUN_ID')
        if not workflow or not run: raise ValueError('Dagu must supply DAG_NAME and DAG_RUN_ID')
        computer=host.configuration(config)[2]
        args.event_id=f'{computer}:{workflow}:{run}:{args.task}'
    if args.action=='bridge': return bridge(host,config,args.nonce,args.callback,args.project)
    if args.action=='reconcile-readiness':
        return call(host,config,'reconcile_readiness',confirmed=args.confirmed,decision=args.decision,reason=args.reason)
    if args.action=='submit':
        payload=registered_task(host,config,args.project,args.task)
        event_id=args.event_id
        if not event_id: raise ValueError('A stable event ID or --dagu is required')
        # Freeze date/slot once; producer retries must retain the original trigger context.
        existing = call(host,config,'list')['events'].get(event_id)
        if existing:
            payload.update({k:v for k,v in existing['payload'].items() if k.startswith('trigger_')})
        else:
            now=datetime.now(ZoneInfo('Asia/Taipei'))
            inputs=payload['definition'].get('input_env',[])
            if not isinstance(inputs,list) or any(not re.fullmatch(r'[A-Z][A-Z0-9_]{0,63}',v) for v in inputs): raise ValueError('Invalid task environment allowlist')
            payload['trigger_env']={key:os.environ.get(key,'') for key in inputs}
            payload.update(trigger_artifacts_dir=os.environ.get('DAG_RUN_ARTIFACTS_DIR'),trigger_date=now.date().isoformat(),
                           trigger_slot='morning' if now.hour<15 else 'afternoon' if now.hour<21 else 'evening')
        event=call(host,config,'submit',confirmed=True,event_id=event_id,payload=payload)
        if args.wait:
            deadline=time.monotonic()+args.timeout
            while event['state'] not in ('completed','failed'):
                if event['state']=='delivery_unknown' or event.get('project_delivery',{}).get('state')=='delivery_unknown' or event.get('computer_return',{}).get('state')=='delivery_unknown': raise RuntimeError('Delivery is uncertain; reconcile without replay')
                if time.monotonic()>=deadline: raise TimeoutError('Event is still pending; retry the SAME event ID to observe it')
                time.sleep(2); event=call(host,config,'status',event_id=event_id)
            if event['state']=='failed': raise RuntimeError('Project event failed: '+json.dumps(event.get('result',event.get('reconciliation'))))
        return event
    if args.action=='list': return call(host,config,'list')
    if args.action=='ready': return call(host,config,'ready',nonce=args.nonce)
    if args.action=='reconcile':
        if args.decision=='resend':
            previous=find_event(host,config,args.event_id)
            state=host.configuration(config)[0]['state']
            execution_nonce=previous.get('project_delivery',{}).get('nonce',previous['nonce'])
            claim=state/'execution-claims'/(hashlib.sha256((previous['event_id']+':'+execution_nonce).encode()).hexdigest()+'.json')
            if claim.exists(): raise ValueError('Execution claim exists; reconcile with its result instead of resend')
        return call(host,config,'reconcile',event_id=args.event_id,confirmed=args.confirmed,decision=args.decision,reason=args.reason,
                    result=json.loads(Path(args.result_file).read_text()) if args.result_file else None)
    event=find_event(host,config,args.event_id,args.nonce)
    if args.action=='status': return event
    if args.action in ('consume','project-consume'):
        if os.environ.get('HERDR_ENV')!='1': raise ValueError('Consumption requires real Herdr context')
        if args.action=='project-consume':
            if args.project!=event['payload']['project']: raise ValueError('Project callback target differs')
            event=call(host,config,'project_ack',event_id=event['event_id'],nonce=args.nonce)
        else:
            event=call(host,config,'ack',event_id=event['event_id'],nonce=args.nonce)
            if event['payload'].get('project_agent'):
                return call(host,config,'forward',event_id=event['event_id'],nonce=args.nonce,reply_prefix=reply_prefix(config))
        result=execute(host,config,event)
        if result['state']=='failed' or result.get('project_delivery',{}).get('state')=='failed': raise RuntimeError('Project failed; durable receipt/log saved, callback pane retained')
        return result
    if args.action=='computer-complete':
        return call(host,config,'computer_complete',event_id=event['event_id'],nonce=args.nonce)
    if args.action=='execute': return execute(host,config,event)
    if args.action=='verify':
        if event['state']!='completed': raise ValueError('Verify only after this event completed')
        payload=event['payload']; task=registered_task(host,config,payload['project'],payload['task'])
        if task['definition']!=payload['definition']: raise ValueError('Task changed; inspect before verification')
        if not task['definition'].get('verify_entrypoint'): raise ValueError('Task has no project verifier')
        argv=[v.replace('${date}',payload['trigger_date']).replace('${slot}',payload['trigger_slot']) for v in task['definition']['verify_entrypoint']]
        subprocess.run(argv,cwd=task['project_cwd'],check=True)
        return dict(event_id=event['event_id'],verification='project verifier passed')
    values=dict(event_id=event['event_id'],nonce=args.nonce)
    if args.action=='complete': values.update(status=args.status,result=json.loads(Path(args.result_file).read_text()))
    return call(host,config,args.action,**values)
