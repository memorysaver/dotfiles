"""Host paths, lifecycle boundary, and local service rendering without live sockets."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

repo=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('orchestrator',repo/'tools/workspace-orchestrator.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class HostTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='orchestrator spaces ')
        self.root=Path(self.temp.name);self.home=self.root/'home';self.home.mkdir()
        self.idea=self.root/'private idea';self.work=self.root/'Work';self.work.mkdir()
        self.rules=self.idea/'private-config/computers/test-host/orchestration-rules'
        self.rules.mkdir(parents=True)
        (self.rules/'README.md').write_text('Computer ID: test-host\n')
        (self.rules/'profile').write_text('omarchy-server\n')
        (self.rules/'orchestrator.toml').write_text('computer_id="test-host"\nenabled=true\n[agent]\nkind="codex"\n[transport]\nbroker_socket='+json.dumps(str(self.home/'.config/herdr-dispatchd/dispatch.sock'))+'\n')
        (self.work/'orchestration-rules').symlink_to(self.rules)
        (self.work/'AGENTS.md').symlink_to(repo/'config/workspace/AGENTS.md')
        (self.work/'README.md').symlink_to(repo/'config/workspace/README.md')
        self.identity=self.root/'id';self.identity.write_text('test-host\n')
        self.dags=self.root/'custom dags';self.dags.mkdir()
        self.state=self.root/'state'
        self.config=self.root/'local locations.toml'
        paths={'dotfiles':str(repo),'idea':str(self.idea),'workspace':str(self.work),
               'dags':str(self.dags),'identity':str(self.identity),'state':str(self.state)}
        self.config.write_text('[paths]\n'+'\n'.join(k+'='+json.dumps(v) for k,v in paths.items()))
        environment={k:v for k,v in os.environ.items() if k not in module.resolver.VARIABLES.values()
                     and k!='WORKSPACE_PATHS_FILE'}
        self.env=patch.dict(os.environ,environment,clear=True);self.env.start()
        self.mockhome=patch.object(Path,'home',return_value=self.home);self.mockhome.start()
        self.os=patch.object(module.platform,'system',return_value='Linux');self.os.start()
    def tearDown(self):
        self.os.stop();self.mockhome.stop();self.env.stop();self.temp.cleanup()
    def test_custom_locations_and_override_priority(self):
        paths=module.resolver.resolve(self.config)
        self.assertEqual(paths['hosts'],self.idea/'private-config/computers')
        special=self.root/'idea $literal; $(touch nope)';special.mkdir()
        with patch.dict(os.environ,{'WORKSPACE_IDEA_ROOT':str(special)}):
            paths=module.resolver.resolve(self.config)
            self.assertEqual(paths['idea'],special)
            self.assertEqual(paths['hosts'],special/'private-config/computers')
    def test_reject_relative_config_and_symlinked_config(self):
        self.config.write_text('[paths]\nidea="relative"\n')
        with self.assertRaises(ValueError): module.resolver.resolve(self.config)
        alias=self.root/'alias';alias.symlink_to(self.config)
        with self.assertRaises(ValueError): module.resolver.resolve(alias)
    def test_identity_conflict_stops_before_delivery(self):
        self.identity.write_text('other-host\n')
        with patch.object(module.subprocess,'run') as run:
            with self.assertRaises(ValueError): module.ensure(self.config)
            run.assert_not_called()
    def test_bootstrap_external_boundary_and_temporary_prompt_cleanup(self):
        def run(command,**kwargs):
            self.assertIn('ensure-orchestrator',command)
            self.assertNotIn('herdr',command)
            prompt=Path(command[command.index('--prompt-file')+1]).read_text()
            self.assertIn(str(self.idea),prompt)
            self.assertIn('Do not perform business work',prompt)
            class Result:
                returncode=0;stdout='{"created":false,"agent":{"agent_status":"blocked"}}';stderr=''
            return Result()
        with patch.object(module.shutil,'which',return_value='/bin/herdr-dispatch'),patch.object(module.subprocess,'run',side_effect=run):
            self.assertFalse(module.ensure(self.config)['created'])
        self.assertEqual(list(self.state.glob('bootstrap-*')),[])
        self.assertTrue((self.state/'lifecycle.json').exists())
    def test_unmanaged_launchers_are_preserved(self):
        workflow=self.rules/'workflows/orchestrator-presence.yaml'
        workflow.parent.mkdir();workflow.write_text('name: test\nsteps: []\n')
        binary=self.home/'.local/bin/workspace-orchestrator';binary.parent.mkdir(parents=True)
        binary.write_text('user executable')
        from types import SimpleNamespace
        with patch.object(module.subprocess,'run',return_value=SimpleNamespace(
                returncode=0,stdout='DAGs directory: '+str(self.dags)+'\n',stderr='')) as run:
            with self.assertRaises(ValueError): module.install(self.config)
            self.assertTrue(all('systemctl' not in c.args[0] for c in run.call_args_list))
        self.assertEqual(binary.read_text(),'user executable')
    def test_service_and_dagu_link_follow_custom_locations(self):
        workflow=self.rules/'workflows/orchestrator-presence.yaml'
        workflow.parent.mkdir();workflow.write_text('name: test\nsteps: []\n')
        from types import SimpleNamespace
        def successful(command,**kwargs):
            return SimpleNamespace(returncode=0,stdout='DAGs directory: '+str(self.dags)+'\n',stderr='')
        with patch.object(module.subprocess,'run',side_effect=successful) as run:
            module.install(self.config)
            self.assertEqual(run.call_count,6)
        unit=self.home/'.config/systemd/user/workspace-orchestrator.service'
        self.assertIn(str(repo),unit.read_text())
        self.assertIn(str(self.config),unit.read_text())
        self.assertEqual((self.dags/'orchestrator/orchestrator-presence.yaml').resolve(),workflow)
        launcher=(self.home/'.local/bin/workspace-orchestrator').read_text()
        self.assertIn(str(self.config),launcher)
        compile(launcher,'launcher','exec')

    def test_execution_claim_prevents_duplicate_effects(self):
        registry=self.rules/'projects.toml'
        registry.write_text('[projects.probe]\ninternal=true\nrepo="."\n[projects.probe.tasks.once]\nentrypoint=["python3","-c","from pathlib import Path; Path(\\\"effect\\\").write_text(\\\"once\\\")"]\n')
        payload=module.events.registered_task(module,self.config,'probe','once')
        event=dict(event_id='probe:run',nonce='nonce',state='accepted',terminal_id='generation',payload=payload)
        def broker(host,config,action,**kwargs):
            if action=='resolve': return {'terminal_id':'generation'}
            if action=='claim': return {'state':'accepted'}
            return {'state':kwargs['status'],'result':kwargs['result']}
        with patch.object(module.events,'call',side_effect=broker):
            result=module.events.execute(module,self.config,event)
            self.assertEqual(result['state'],'completed')
            with self.assertRaisesRegex(ValueError,'already claimed'):
                module.events.execute(module,self.config,event)
        self.assertEqual((self.work/'effect').read_text(),'once')
        self.assertEqual(len(list((self.state/'execution-claims').glob('*.result.json'))),1)
    def test_readonly_bridge_accepts_silent_pane_run_without_broker_access(self):
        from types import SimpleNamespace
        replies=[SimpleNamespace(stdout=json.dumps({'result':{'agent':{'agent':'codex','cwd':str(self.work),'pane_id':'fixed-pane'}}})),
                 SimpleNamespace(stdout=json.dumps({'result':{'pane':{'pane_id':'callback-pane'}}})),
                 SimpleNamespace(stdout='')]
        with patch.dict(os.environ,{'HERDR_ENV':'1','HERDR_PANE_ID':'fixed-pane'}),patch.object(module.events.subprocess,'run',side_effect=replies) as run:
            result=module.events.bridge(module,self.config,'11111111-1111-1111-1111-111111111111','consume')
            self.assertEqual(result['pane_id'],'callback-pane')
            self.assertTrue(all(c.args[0][0]=='herdr' for c in run.call_args_list))
            self.assertIn('--no-focus',run.call_args_list[1].args[0])
            self.assertIn('event consume --nonce',run.call_args_list[2].args[0][-1])
            self.assertFalse(self.state.exists())

    def project_fixture(self):
        import subprocess
        project=self.work/'repo';project.mkdir()
        (project/'AGENTS.md').write_text('Project rules')
        (project/'README.md').write_text('Project readme')
        subprocess.run(['git','init','-q',str(project)],check=True)
        (self.rules/'projects.toml').write_text('[projects.media]\nenabled=true\nrepo="repo"\n[projects.media.orchestrator]\nname="project-media"\nkind="codex"\n[projects.media.tasks.probe]\nentrypoint=["python3","-c","print(123)"]\n[projects.internal]\ninternal=true\nrepo="."\n')
        return project

    def test_managed_project_inventory_excludes_internal_probes(self):
        project=self.project_fixture()
        result=module.events.projects_main(module,self.config,['list'])
        self.assertEqual(result['managed_count'],1)
        self.assertEqual(result['projects'][0]['repo'],str(project))
        self.assertEqual(result['projects'][0]['route']['name'],'project-media')
        with self.assertRaises(ValueError): module.events.registered_project(module,self.config,'unknown')

    def test_computer_consumption_forwards_without_executing_project_entrypoint(self):
        project=self.project_fixture()
        payload=module.events.registered_task(module,self.config,'media','probe')
        event=dict(event_id='event',nonce='nonce',state='submitted',payload=payload)
        def broker(host,config,action,**kwargs):
            return dict(event,state='accepted')
        with patch.dict(os.environ,{'HERDR_ENV':'1'}),patch.object(module.events,'find_event',return_value=event),patch.object(module.events,'call',side_effect=broker) as call,patch.object(module.events,'execute') as execute:
            module.events.main(module,self.config,['consume','--nonce','nonce'])
            self.assertEqual([c.args[2] for c in call.call_args_list],['ack','forward'])
            execute.assert_not_called()

    def test_project_execution_requires_its_own_acknowledgment(self):
        self.project_fixture()
        payload=module.events.registered_task(module,self.config,'media','probe')
        event=dict(event_id='event',nonce='nonce',state='accepted',payload=payload,project_delivery={'state':'submitted'})
        with self.assertRaisesRegex(ValueError,'Project has not acknowledged'):
            module.events.execute(module,self.config,event)
        self.assertFalse((self.state/'execution-claims').exists())

    def test_project_local_claim_blocks_resend_even_before_broker_claim(self):
        import hashlib
        previous={'event_id':'event','nonce':'computer-nonce','project_delivery':{'nonce':'project-nonce'}}
        claims=self.state/'execution-claims';claims.mkdir(parents=True)
        claim=claims/(hashlib.sha256(b'event:project-nonce').hexdigest()+'.json');claim.write_text('{}')
        with patch.object(module.events,'find_event',return_value=previous),patch.object(module.events,'call') as call:
            with self.assertRaisesRegex(ValueError,'Execution claim exists'):
                module.events.main(module,self.config,['reconcile','--event-id','event','--decision','resend','--reason','inspect','--confirmed'])
            call.assert_not_called()

    def test_legacy_project_tool_context_requires_stage_capability_and_live_generation(self):
        from types import SimpleNamespace
        self.project_fixture()
        route=module.events.registered_project(module,self.config,'media')['route']
        nonce='11111111-1111-1111-1111-111111111111'
        socket=module.configuration(self.config)[-1];socket.parent.mkdir(parents=True,exist_ok=True)
        event={'state':'accepted','payload':{'project':'media','project_agent':route},'project_delivery':{'state':'submitted','nonce':nonce,'terminal_id':'generation'}}
        store=socket.parent/'orchestrator-events.json';store.write_text(json.dumps({'events':{'event':event}}))
        replies=[SimpleNamespace(stdout=json.dumps({'result':{'agent':{'agent':'codex','cwd':route['cwd'],'pane_id':'fixed-project','terminal_id':'generation'}}})),
                 SimpleNamespace(stdout=json.dumps({'result':{'pane':{'pane_id':'stale-context'}}})),
                 SimpleNamespace(stdout=json.dumps({'result':{'pane':{'pane_id':'callback'}}})),SimpleNamespace(stdout='')]
        with patch.dict(os.environ,{'HERDR_ENV':'1','HERDR_PANE_ID':'stale-context'}),patch.object(Path,'cwd',return_value=Path(route['cwd'])),patch.object(module.events,'registered_project',return_value={'route':route}),patch.object(module.events.subprocess,'run',side_effect=replies):
            self.assertEqual(module.events.bridge(module,self.config,nonce,'project-consume','media')['pane_id'],'callback')
        event['project_delivery']['terminal_id']='replaced-generation';store.write_text(json.dumps({'events':{'event':event}}))
        with patch.dict(os.environ,{'HERDR_ENV':'1','HERDR_PANE_ID':'stale-context'}),patch.object(Path,'cwd',return_value=Path(route['cwd'])),patch.object(module.events,'registered_project',return_value={'route':route}),patch.object(module.events.subprocess,'run',side_effect=replies[:2]) as transport:
            with self.assertRaisesRegex(ValueError,'does not match'):
                module.events.bridge(module,self.config,nonce,'project-consume','media')
            self.assertEqual(transport.call_count,2)

        with patch.dict(os.environ,{'HERDR_ENV':'1','HERDR_PANE_ID':'stale-context'}),patch.object(Path,'cwd',return_value=self.work),patch.object(module.events,'registered_project',return_value={'route':route}),patch.object(module.events.subprocess,'run',side_effect=replies[:2]) as transport:
            with self.assertRaisesRegex(ValueError,'registered repo cwd'):
                module.events.bridge(module,self.config,nonce,'project-consume','media')
            self.assertEqual(transport.call_count,2)

    def test_missing_work_instruction_link_stops_before_broker(self):
        (self.work/'AGENTS.md').unlink()
        with patch.object(module.subprocess,'run') as run:
            with self.assertRaises(ValueError): module.ensure(self.config)
            run.assert_not_called()

if __name__=='__main__': unittest.main()
