#!/usr/bin/env python3
"""Resolve host-owned workspace locations without sourcing shell configuration."""
import argparse
import json
import os
from pathlib import Path
import shlex
import tomllib

VARIABLES = {"dotfiles": "DOTFILES_DIR", "idea": "WORKSPACE_IDEA_ROOT",
             "workspace": "WORKSPACE_ROOT", "dags": "WORKSPACE_DAGU_DAGS_DIR",
             "hosts": "WORKSPACE_HOSTS_DIR", "identity": "WORKSPACE_ID_FILE",
             "state": "WORKSPACE_ORCHESTRATOR_STATE_DIR"}

def resolve(config_file=None):
    home = Path.home()
    config_file = Path(config_file or os.environ.get('WORKSPACE_PATHS_FILE',
        home / '.config/dotfiles/workspace.toml')).expanduser()
    config = {}
    if config_file.exists() or config_file.is_symlink():
        if config_file.is_symlink() or not config_file.is_file():
            raise ValueError('Workspace path config must be a local regular file')
        config = tomllib.loads(config_file.read_text())
    values = config.get('paths', {})
    unknown = set(values) - set(VARIABLES)
    if unknown:
        raise ValueError('Unknown path keys: ' + ', '.join(sorted(unknown)))
    defaults = {'dotfiles': home / '.dotfiles', 'idea': home / 'idea',
                'workspace': home / 'Work', 'dags': home / '.config/dagu/dags',
                'identity': home / '.config/dotfiles/computer-id',
                'state': home / '.local/state/workspace-orchestrator'}
    paths = {}
    for key in VARIABLES:
        default = paths['idea'] / 'private-config/computers' if key == 'hosts' else defaults[key]
        value = os.environ.get(VARIABLES[key], values.get(key, str(default)))
        if not isinstance(value, str) or not value or '\x00' in value or '\n' in value:
            raise ValueError('Invalid workspace path: ' + key)
        path = Path(value).expanduser()
        if not path.is_absolute():
            raise ValueError('Workspace paths must be absolute or ~/ relative: ' + key)
        paths[key] = path.resolve()
    return paths

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config')
    parser.add_argument('--shell', action='store_true')
    parser.add_argument('--get', choices=list(VARIABLES))
    args = parser.parse_args()
    try:
        paths = resolve(args.config)
        if args.get:
            print(paths[args.get])
        elif args.shell:
            for key, variable in VARIABLES.items():
                print('export ' + variable + '=' + shlex.quote(str(paths[key])))
        else:
            print(json.dumps({k: str(v) for k, v in paths.items()}, indent=2))
    except (OSError, ValueError, tomllib.TOMLDecodeError) as error:
        parser.exit(1, str(error) + '\n')
