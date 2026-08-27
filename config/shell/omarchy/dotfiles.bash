# Personal additions layered after Omarchy's Bash defaults.
# Omarchy continues to own environment bootstrap, Mise, Starship, Zoxide, FZF,
# completion, EDITOR, BROWSER, and its aliases/functions.

dotfiles_shell_dir="$HOME/.dotfiles/config/shell/common"
[ -r "$dotfiles_shell_dir/env.sh" ] && source "$dotfiles_shell_dir/env.sh"
[ -r "$dotfiles_shell_dir/aliases.sh" ] && source "$dotfiles_shell_dir/aliases.sh"
[ -r "$dotfiles_shell_dir/functions.sh" ] && source "$dotfiles_shell_dir/functions.sh"
unset dotfiles_shell_dir

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi
