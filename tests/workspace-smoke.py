"""Exercise real setup/binding scripts with disposable paths, without replacing HOME."""
from pathlib import Path
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='workspace lifecycle ') as tmp:
    root = Path(tmp)
    work = root / 'Work'
    hosts = root / 'private machines'
    identity = root / 'local/computer-id'
    env = {**os.environ, 'DOTFILES_DIR': str(repo), 'DOTFILES_LINK_MODE': 'refuse',
           'DOTFILES_PLATFORM': 'omarchy', 'WORKSPACE_ROOT': str(work),
           'WORKSPACE_ID_FILE': str(identity), 'WORKSPACE_HOSTS_DIR': str(hosts)}

    def run(script, *args, ok=True, extra=None):
        result = subprocess.run(['bash', str(repo / 'install' / script), *args],
                                env={**env, **(extra or {})}, capture_output=True, text=True)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr

    def fixture(name, profile):
        source = hosts / name / 'orchestration-rules'
        source.mkdir(parents=True)
        (source / 'README.md').write_text('Private machine rule\n')
        (source / 'profile').write_text(profile + '\n')
        return source

    # Upgrade the former public split directories, including dangling source symlinks.
    work.mkdir()
    (work / 'computer-rule').symlink_to(repo / 'config/workspace/computer-rule')
    (work / 'workspace-rules').symlink_to(repo / 'config/workspace/workspace-rules')
    run('workspace.sh')
    assert not (work / 'computer-rule').is_symlink()
    assert not (work / 'workspace-rules').is_symlink()
    names = ['AGENTS.md', 'README.md', 'orchestration-rules']
    for name in names:
        assert (work / name).resolve() == repo / 'config/workspace' / name
    inodes = {n: (work / n).lstat().st_ino for n in names}
    run('workspace.sh')
    assert inodes == {n: (work / n).lstat().st_ino for n in names}
    (work / 'README.md').unlink()
    (work / 'README.md').write_text('user-owned\n')
    run('workspace.sh', ok=False)
    assert (work / 'README.md').read_text() == 'user-owned\n'
    (work / 'README.md').unlink()
    (work / 'README.md').symlink_to(root / 'missing-user-target')
    run('workspace.sh', ok=False)
    assert os.readlink(work / 'README.md') == str(root / 'missing-user-target')

    source = fixture('test-server', 'omarchy-server')
    fixture('test-desktop', 'omarchy-desktop')
    fixture('test-mac', 'mac')
    fixture('test-grok', 'grok-bot')
    for invalid in ['../escape', 'unknown', '', 'test-mac']:
        run('workspace-computer.sh', invalid, ok=False)
        assert not identity.exists()
        assert (work / 'orchestration-rules').resolve() == repo / 'config/workspace/orchestration-rules'
    run('workspace-computer.sh', 'test-server')
    assert identity.read_text() == 'test-server\n'
    assert (work / 'orchestration-rules').resolve() == source
    inode = (work / 'orchestration-rules').lstat().st_ino
    run('workspace-computer.sh', 'test-server')
    assert (work / 'orchestration-rules').lstat().st_ino == inode
    run('workspace-computer.sh', 'test-desktop', ok=False)
    assert identity.read_text() == 'test-server\n'
    # No fallback when a previously selected source is unavailable or the OS is wrong.
    (source / 'README.md').rename(source / 'README.saved')
    run('workspace.sh', ok=False)
    assert (work / 'orchestration-rules').resolve() == source
    (source / 'README.saved').rename(source / 'README.md')
    run('workspace.sh', ok=False, extra={'DOTFILES_PLATFORM': 'macos'})
    (work / 'README.md').unlink()
    run('workspace.sh')
    assert (work / 'orchestration-rules').resolve() == source

    # Upgrade a bound machine after both source repositories renamed their directories.
    (work / 'orchestration-rules').unlink()
    (work / 'computer-rule').symlink_to(source.with_name('computer-rule'))
    (work / 'workspace-rules').symlink_to(repo / 'config/workspace/workspace-rules')
    (work / 'orchestration-rules').mkdir()
    run('workspace.sh', ok=False)
    assert (work / 'computer-rule').is_symlink()  # no cleanup before new rules are installed
    (work / 'orchestration-rules').rmdir()
    run('workspace.sh')
    assert (work / 'orchestration-rules').resolve() == source
    assert not (work / 'computer-rule').is_symlink()
    assert not (work / 'workspace-rules').is_symlink()
    # Custom legacy paths are never removed by migration or unlink.
    (work / 'computer-rule').mkdir()
    (work / 'computer-rule/keep').write_text('custom rules')
    (work / 'workspace-rules').symlink_to(root / 'foreign-old-rules')
    run('workspace.sh')
    assert (work / 'computer-rule/keep').read_text() == 'custom rules'
    assert (work / 'workspace-rules').is_symlink()

    # Run only the actual workspace unlink block; application configs are out of scope.
    just = (repo / 'justfile').read_text()
    start = just.index('    # Remove only workspace links')
    end = just.index('    links=()', start)
    unlink = just[start:end].replace('{{ dotfiles }}', str(repo)).replace('$HOME/Work', '$WORKSPACE_ROOT')
    prelude = 'source "$DOTFILES_DIR/lib/helpers.sh"\nsource "$DOTFILES_DIR/lib/workspace.sh"\nrule_source="$(workspace_rule_source)"\n'
    (work / 'README.md').unlink()
    (work / 'README.md').symlink_to(root / 'foreign-link')
    result = subprocess.run(['bash', '-c', prelude + unlink], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert (work / 'README.md').is_symlink()
    assert not any((work / n).is_symlink() for n in names if n != 'README.md')
    assert all((work / n).is_dir() for n in ['github', 'cowork', 'tries'])
    assert identity.read_text() == 'test-server\n'
    (work / 'README.md').unlink()
    run('workspace.sh')
    assert (work / 'orchestration-rules').resolve() == source
    # Refuse foreign rule paths even when the caller configured backup mode.
    (work / 'orchestration-rules').unlink()
    (work / 'orchestration-rules').mkdir()
    (work / 'orchestration-rules/keep').write_text('preserve')
    run('workspace-computer.sh', 'test-server', ok=False, extra={'DOTFILES_LINK_MODE': 'backup'})
    assert (work / 'orchestration-rules/keep').read_text() == 'preserve'
    # A different isolated computer may select the mac profile; identities do not leak between roots.
    run('workspace-computer.sh', 'test-mac', extra={'DOTFILES_PLATFORM': 'macos',
        'WORKSPACE_ROOT': str(root / 'MacWork'), 'WORKSPACE_ID_FILE': str(root / 'mac-id')})
    assert (root / 'MacWork/orchestration-rules').resolve() == hosts / 'test-mac/orchestration-rules'
    # Grok Bot sandbox may bind only when private profile is grok-bot.
    run('workspace-computer.sh', 'test-server', ok=False, extra={'DOTFILES_PLATFORM': 'grok-bot',
        'WORKSPACE_ROOT': str(root / 'GrokWorkBad'), 'WORKSPACE_ID_FILE': str(root / 'grok-id-bad')})
    assert not (root / 'grok-id-bad').exists()
    run('workspace-computer.sh', 'test-grok', extra={'DOTFILES_PLATFORM': 'grok-bot',
        'WORKSPACE_ROOT': str(root / 'GrokWork'), 'WORKSPACE_ID_FILE': str(root / 'grok-id')})
    assert (root / 'GrokWork/orchestration-rules').resolve() == hosts / 'test-grok/orchestration-rules'
print('Workspace lifecycle and per-computer identity checks passed.')
