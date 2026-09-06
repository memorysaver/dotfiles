from pathlib import Path
import tempfile, subprocess, os, shlex
r=Path(__file__).resolve().parents[1]
script=(r/'install/workspace.sh').read_text()
# Exercise the real installer with only its destination root redirected to disposable fixtures.
script=script.replace('source "$(dirname "$0")/../lib/helpers.sh"',f'source {shlex.quote(str(r/"lib/helpers.sh"))}')
with tempfile.TemporaryDirectory(prefix='workspace-lifecycle-') as tmp:
    work=Path(tmp)/'Work'
    script=script.replace('workspace_root="$HOME/Work"',f'workspace_root={shlex.quote(str(work))}')
    def install(ok=True):
        p=subprocess.run(['bash','-c',script],capture_output=True,text=True,
                         env={**os.environ, 'DOTFILES_DIR': str(r), 'DOTFILES_LINK_MODE': 'refuse'})
        assert (p.returncode==0)==ok,p.stdout+p.stderr
    install()
    names=['AGENTS.md','README.md','computer-rule','workspace-rules']
    for name in names: assert (work/name).resolve()==r/'config/workspace'/name
    inode={n:(work/n).lstat().st_ino for n in names}
    install()
    assert inode=={n:(work/n).lstat().st_ino for n in names}
    (work/'README.md').unlink(); (work/'README.md').write_text('user-owned\n')
    install(False); assert (work/'README.md').read_text()=='user-owned\n'
    (work/'README.md').unlink(); (work/'README.md').symlink_to(Path(tmp)/'missing-user-target')
    install(False); assert os.readlink(work/'README.md')==str(Path(tmp)/'missing-user-target')
    # Exercise only the workspace unlink block, never unrelated application unlink actions.
    just=(r/'justfile').read_text(); start=just.index('    # Remove only workspace links')
    end=just.index('    links=()',start)
    unlink=just[start:end].replace('{{ dotfiles }}',str(r)).replace('$HOME/Work',str(work))
    result=subprocess.run(['bash','-c','set -eu\nok() { :; }\n'+unlink],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert (work/'README.md').is_symlink() # foreign link preserved
    assert not any((work/n).is_symlink() for n in names if n!='README.md')
    assert all((work/n).is_dir() for n in ['github','cowork','tries'])
print('Workspace lifecycle fixture passed: creation, idempotence, real-file and dangling-link refusal, owned-only unlink, repository directories preserved.')
