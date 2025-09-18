#!/usr/bin/env python3
"""
Sync OpenAI Codex configuration from dotfiles to ~/.codex/config.toml
Merges dotfiles config while preserving existing project trust settings.
"""

import os
import sys
import tomllib
import shutil
from pathlib import Path

def load_toml(file_path):
    """Load TOML file and return parsed content."""
    try:
        with open(file_path, 'rb') as f:
            return tomllib.load(f)
    except FileNotFoundError:
        print(f"Error: {file_path} not found")
        return None
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None

def write_toml(data, file_path):
    """Write TOML data to file."""
    try:
        import tomlkit
        with open(file_path, 'w') as f:
            tomlkit.dump(data, f)
    except ImportError:
        # Fallback: manual TOML writing for basic structures
        write_toml_manual(data, file_path)

def write_toml_manual(data, file_path):
    """Manual TOML writing for basic structures."""
    with open(file_path, 'w') as f:
        f.write("## Codex CLI configuration\n")
        f.write("# Customize Codex CLI behavior via this config file.\n")
        f.write("# See https://github.com/openai/codex/blob/main/codex-rs/config.md for options.\n\n")

        # Write all top-level config (non-table keys)
        top_level_keys = [k for k, v in data.items() if not isinstance(v, dict)]
        for key in sorted(top_level_keys):
            value = data[key]
            if isinstance(value, str):
                f.write(f'{key} = "{value}"\n')
            elif isinstance(value, bool):
                f.write(f'{key} = {str(value).lower()}\n')
            elif isinstance(value, (int, float)):
                f.write(f'{key} = {value}\n')
        if top_level_keys:
            f.write('\n')

        # Write projects section
        if 'projects' in data:
            for project_path, settings in data['projects'].items():
                f.write(f'[projects."{project_path}"]\n')
                for key, value in settings.items():
                    f.write(f'{key} = "{value}"\n')
                f.write('\n')

        # Write model_providers section
        if 'model_providers' in data:
            for provider_name, settings in data['model_providers'].items():
                f.write(f'[model_providers.{provider_name}]\n')
                for key, value in settings.items():
                    f.write(f'{key} = "{value}"\n')
                f.write('\n')

        # Write profiles section
        if 'profiles' in data:
            for profile_name, settings in data['profiles'].items():
                f.write(f'[profiles.{profile_name}]\n')
                for key, value in settings.items():
                    f.write(f'{key} = "{value}"\n')
                f.write('\n')

        # Write MCP servers section
        if 'mcp_servers' in data:
            f.write('# MCP (Model Context Protocol) servers\n')
            for server_name, settings in data['mcp_servers'].items():
                f.write(f'[mcp_servers.{server_name}]\n')
                f.write(f'command = "{settings["command"]}"\n')
                if 'args' in settings:
                    args_str = ', '.join(f'"{arg}"' for arg in settings['args'])
                    f.write(f'args = [{args_str}]\n')
                f.write('\n')

def sync_configs():
    """Sync dotfiles config to active Codex config while preserving projects."""
    dotfiles_config = Path.home() / ".dotfiles" / "openai-codex" / "config.toml"
    active_config = Path.home() / ".codex" / "config.toml"
    backup_config = Path.home() / ".codex" / "config.toml.backup"

    print(f"Syncing Codex config from {dotfiles_config} to {active_config}")

    # Load configs
    dotfiles_data = load_toml(dotfiles_config)
    if not dotfiles_data:
        sys.exit(1)

    active_data = load_toml(active_config) if active_config.exists() else {}

    # Create backup
    if active_config.exists():
        shutil.copy2(active_config, backup_config)
        print(f"Backup created: {backup_config}")

    # Merge configs: dotfiles base + preserve existing projects
    merged_data = dotfiles_data.copy()

    # Preserve existing projects section
    if 'projects' in active_data:
        merged_data['projects'] = active_data['projects']
        print(f"Preserved {len(active_data['projects'])} project trust settings")

    # Write merged config
    write_toml_manual(merged_data, active_config)
    print(f"Config synced successfully to {active_config}")

    # Show what was updated
    print("\nSynced from dotfiles:")
    for section in ['model', 'model_provider', 'model_providers', 'profiles', 'mcp_servers']:
        if section in dotfiles_data:
            if isinstance(dotfiles_data[section], dict):
                print(f"  - {section}: {list(dotfiles_data[section].keys())}")
            else:
                print(f"  - {section}: {dotfiles_data[section]}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print(__doc__)
        print("\nUsage: python3 sync-codex-config.py")
        print("       ./sync-codex-config.py")
        sys.exit(0)

    sync_configs()