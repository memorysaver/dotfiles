# ToggleTerm.nvim Configuration

Advanced terminal management plugin for Neovim with multiple terminal modes and custom integrations.

## Key Features

### Terminal Toggle Commands
- `Ctrl+\` - Toggle floating terminal
- `<leader>gg` - Toggle Lazygit
- `<leader>th` - Toggle horizontal terminal
- `<leader>tv` - Toggle vertical terminal
- `<leader>tf` - Toggle floating terminal

### Terminal Navigation
- `Esc` or `jk` - Exit terminal mode
- `Ctrl+h/j/k/l` - Navigate between windows

## Configuration Features

- **Float terminal with curved borders** - Beautiful floating terminal window
- **Multiple terminal directions** - Support for horizontal, vertical, tab, and floating modes
- **Auto-scroll and persistent sizing** - Maintains terminal size and auto-scrolls output
- **Lazygit integration** - Quick access to Git interface
- **Smart keymaps** - Terminal-aware navigation and control

## Usage Examples

### Basic Terminal Operations
```vim
:ToggleTerm                    " Open/close terminal
:ToggleTerm direction=float    " Open floating terminal
:ToggleTerm direction=vertical " Open vertical split terminal
:TermSelect                    " Select specific terminal
```

### Sending Commands
```vim
:ToggleTermSendCurrentLine     " Send current line to terminal
:ToggleTermSendVisualSelection " Send visual selection to terminal
```

### Custom Terminal Functions
- **Lazygit**: Quick Git interface with `<leader>gg`
- **Horizontal Terminal**: Bottom split terminal with `<leader>th`
- **Vertical Terminal**: Side split terminal with `<leader>tv`
- **Float Terminal**: Overlay terminal with `<leader>tf`

## Terminal Window Management

The configuration includes smart window navigation that works seamlessly between terminal and editor windows:

- Switch between terminal and editor with standard Vim navigation
- Persistent terminal sessions survive window toggles
- Multiple terminals can be managed simultaneously
- Each terminal direction creates separate instances

## Customization

The configuration can be modified in `toggleterm.lua`:

- **Size**: Adjust terminal size with `size` option
- **Direction**: Change default direction (`float`, `horizontal`, `vertical`, `tab`)
- **Borders**: Customize float window borders (`curved`, `double`, `single`, etc.)
- **Shell**: Use different shell with `shell` option
- **Keymaps**: Add custom terminal functions and keybindings

## Integration Notes

- Works seamlessly with LazyVim's existing terminal features
- Lazygit integration requires `lazygit` to be installed
- All terminals support full color and interactive applications
- Terminal sessions persist across Neovim sessions when configured