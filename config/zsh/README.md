# Zsh Configuration

## Adding a new plugin

1. Add the plugin name to the `zsh_plugins` array in `install/core.sh`
2. Add the plugin name to the `plugins=()` list in `config/zsh/.zshrc`
3. Run `just core` to install it
