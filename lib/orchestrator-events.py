"""Host event producer/consumer and registered project execution; no Herdr CLI access."""
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
    request = dict(action=action, cwd=str(paths['workspace']), kind=kind, **values)
    client = shutil.which('herdr-dispatch')
    if not client:
        raise ValueError('herdr-dispatch is unavailable')
    paths['state'].mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode='w', dir=paths['state'], prefix='event-', suffix='.json') as f:
        json.dump(request, f); f.flush()
        result = subprocess.run([client, '--socket', str(socket), 'orchestrator-event', '--request-file', f.name],
                                capture_output=True, text=True, timeout=100)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'Event broker request failed')
    return json.loads(result.stdout)


def registered_task(host, config, project, task):
    paths, rules, computer, *rest = host.configuration(config)
    registry = tomllib.loads((rules/'projects.toml').read_text())
    selected = registry.get('projects', {}).get(project, {})
    definition = selected.get('tasks', {}).get(task)
    if not definition:
        raise ValueError('Project/task is not registered on this computer')
    location = selected['repo']
    cwd = (paths['workspace']/location).resolve()
    if not cwd.is_relative_to(paths['workspace']) or not cwd.is_dir():
        raise ValueError('Registered project must exist beneath configured Work')
    entrypoint = definition.get('entrypoint')
    if not isinstance(entrypoint, list) or not entrypoint or any(not isinstance(v, str) or '\0' in v for v in entrypoint):
        raise ValueError('Registered entrypoint must be an argv array')
    if not (cwd/'AGENTS.md').is_file() or not (cwd/'README.md').is_file():
        raise ValueError('Project instructions are missing')
    timeout=definition.get('timeout_seconds',7200)
    if not isinstance(timeout,int) or isinstance(timeout,bool) or not 1<=timeout<=7200:
        raise ValueError('Registered timeout must be between 1 and 7200 seconds')
    return dict(project=project, task=task, project_cwd=str(cwd), definition=definition)


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
    return call(host, config, 'pump', confirmed=True, rules_version=digest.hexdigest(),
                bootstrap=host.bootstrap(paths, rules, computer), reply_prefix=shlex.join(prefix))


def find_event(host, config, event_id=None, nonce=None):
    if event_id:
        event = call(host, config, 'status', event_id=event_id)
    else:
        candidates = [e for e in call(host, config, 'list')['events'].values() if e['nonce']==nonce]
        if len(candidates)!=1: raise ValueError('Nonce must identify exactly one event')
        event = candidates[0]
    if nonce and event['nonce']!=nonce: raise ValueError('Event nonce differs')
    return event


def execute(host, config, event):
    if event['state']!='accepted': raise ValueError('Event must be acknowledged before execution')
    payload = event['payload']
    current = registered_task(host, config, payload['project'], payload['task'])
    frozen = {k:payload[k] for k in current}
    if current!=frozen: raise ValueError('Registered task changed after enqueue; reconcile before running')
    live = call(host, config, 'resolve')
    if live['terminal_id']!=event['terminal_id']:
        raise ValueError('Agent generation changed before execution')
    paths, rules, computer, *rest = host.configuration(config)
    if current['definition'].get('same_day') and payload.get('trigger_date')!=datetime.now(ZoneInfo('Asia/Taipei')).date().isoformat():
        return call(host,config,'complete',event_id=event['event_id'],nonce=event['nonce'],status='failed',result={'reason':'Trigger day expired; no project execution'})
    # Create an exclusive execution claim BEFORE running anything. A crash never authorizes replay.
    claims = paths['state']/'execution-claims'; claims.mkdir(parents=True, exist_ok=True, mode=0o700)
    claim = claims/(hashlib.sha256((event['event_id']+':'+event['nonce']).encode()).hexdigest()+'.json')
    try:
        fd = os.open(claim, os.O_WRONLY|os.O_CREAT|os.O_EXCL, 0o600)
    except FileExistsError:
        raise ValueError('Execution was already claimed; inspect its receipt before any replay') from None
    with os.fdopen(fd, 'w') as f:
        json.dump(dict(event_id=event['event_id'], nonce=event['nonce'], started_at=time.time()),f)
        f.flush(); os.fsync(f.fileno())
    call(host,config,'claim',event_id=event['event_id'],nonce=event['nonce'])
    # Keep output in host-owned private logs, outside project dirty trees.
    log = claims/(claim.stem+'.log')
    with log.open('w') as output:
        log.chmod(0o600)
        argv = [part.replace('${date}',payload.get('trigger_date','')).replace('${slot}',payload.get('trigger_slot',''))
                for part in current['definition']['entrypoint']]
        environment=os.environ.copy()
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
    return call(host, config, 'complete', event_id=event['event_id'], nonce=event['nonce'],
                status='completed' if exit_code==0 else 'failed', result=receipt)


def bridge(host,config,nonce,callback):
    # The read-only model uses only its explicitly allowed Herdr socket. The new
    # shell receives real Herdr context and runs the registered callback itself.
    if callback not in ('ready','consume'): raise ValueError('Bridge requires --callback ready or consume')
    if os.environ.get('HERDR_ENV')!='1': raise ValueError('Bridge requires a genuine Herdr caller')
    if not nonce or not re.fullmatch(r'[0-9a-f-]{36}',nonce): raise ValueError('Invalid callback nonce')
    paths,rules,computer,kind,*rest=host.configuration(config)
    def herdr(*arguments):
        result=subprocess.run(['herdr',*arguments],capture_output=True,text=True,check=True,timeout=40)
        if arguments[:2]==('pane','run') and not result.stdout.strip(): return {}
        return json.loads(result.stdout)['result']
    live=herdr('agent','get','orchestrator')['agent']
    if live['agent']!=kind or Path(live['cwd']).resolve()!=paths['workspace']:
        raise ValueError('Fixed agent identity differs')
    if os.environ.get('HERDR_PANE_ID')!=live['pane_id']:
        raise ValueError('Only the fixed Orchestrator may create its callback shell')
    pane=herdr('pane','split','--pane',live['pane_id'],'--direction','down',
               '--cwd',str(paths['workspace']),'--no-focus')['pane']['pane_id']
    prefix=[str(Path.home()/'.local/bin/workspace-orchestrator')]
    if config: prefix += ['--config',str(Path(config).expanduser().resolve())]
    command=shlex.join(prefix+['event',callback,'--nonce',nonce])
    # Only this newly created callback pane is closed, after a successful durable receipt.
    # Failures retain the shell for inspection. Project workers run in their own panes.
    command += ' && '+shlex.join(['herdr','pane','close',pane])
    herdr('pane','run',pane,command)
    return dict(callback=callback,pane_id=pane,submission='shell command submitted; inspect correlated broker receipt')

def main(host, config, arguments):
    parser=argparse.ArgumentParser(prog='workspace-orchestrator event')
    parser.add_argument('action',choices=['submit','status','list','ready','ack','execute','complete','reconcile','verify','bridge','consume','reconcile-readiness'])
    parser.add_argument('--project'); parser.add_argument('--task'); parser.add_argument('--event-id')
    parser.add_argument('--nonce'); parser.add_argument('--dagu',action='store_true')
    parser.add_argument('--wait',action='store_true'); parser.add_argument('--timeout',type=int,default=7200)
    parser.add_argument('--result-file'); parser.add_argument('--status',choices=['completed','failed'])
    parser.add_argument('--decision',choices=['resend','drop','completed']); parser.add_argument('--reason')
    parser.add_argument('--confirmed',action='store_true')
    parser.add_argument('--callback',choices=['ready','consume'])
    args=parser.parse_args(arguments)
    if args.dagu:
        workflow=os.environ.get('DAG_NAME'); run=os.environ.get('DAG_RUN_ID')
        if not workflow or not run: raise ValueError('Dagu must supply DAG_NAME and DAG_RUN_ID')
        computer=host.configuration(config)[2]
        args.event_id=f'{computer}:{workflow}:{run}:{args.task}'
    if args.action=='bridge': return bridge(host,config,args.nonce,args.callback)
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
            payload.update(trigger_artifacts_dir=os.environ.get('DAG_RUN_ARTIFACTS_DIR'),trigger_date=now.date().isoformat(),
                           trigger_slot='morning' if now.hour<15 else 'afternoon' if now.hour<21 else 'evening')
        event=call(host,config,'submit',confirmed=True,event_id=event_id,payload=payload)
        if args.wait:
            deadline=time.monotonic()+args.timeout
            while event['state'] not in ('completed','failed'):
                if event['state']=='delivery_unknown': raise RuntimeError('Delivery is uncertain; reconcile without replay')
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
            claim=state/'execution-claims'/(hashlib.sha256((previous['event_id']+':'+previous['nonce']).encode()).hexdigest()+'.json')
            if claim.exists(): raise ValueError('Execution claim exists; reconcile with its result instead of resend')
        return call(host,config,'reconcile',event_id=args.event_id,confirmed=args.confirmed,decision=args.decision,reason=args.reason,
                    result=json.loads(Path(args.result_file).read_text()) if args.result_file else None)
    event=find_event(host,config,args.event_id,args.nonce)
    if args.action=='status': return event
    if args.action=='consume':
        if os.environ.get('HERDR_ENV')!='1': raise ValueError('Consumption requires real Herdr context')
        event=call(host,config,'ack',event_id=event['event_id'],nonce=args.nonce)
        result=execute(host,config,event)
        if result['state']=='failed': raise RuntimeError('Project failed; durable receipt/log saved, callback pane retained')
        return result
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
