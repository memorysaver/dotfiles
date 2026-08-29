# Dotfiles task runner
# Usage: just <recipe>
# Run `just --list` to see all available recipes

set shell := ["bash", "-euo", "pipefail", "-c"]
dotfiles := env("HOME") / ".dotfiles"

# Detect the platform and run its explicit setup recipe.
setup:
    @platform="$$(bash -c 'source {{ dotfiles }}/lib/helpers.sh; printf %s "$$DOTFILES_PLATFORM"')"; just "setup-$$platform"

setup-macos:
    @bash {{ dotfiles }}/install/platform-check.sh macos
    @just _setup

setup-omarchy:
    @bash {{ dotfiles }}/install/platform-check.sh omarchy
    @echo "Omarchy package installation needs sudo; authenticate once to begin."
    @sudo -v
    @just _setup
    @just omarchy-apps
    @just omarchy-moonlight
    @just link
    @just doctor

setup-arch:
    @bash {{ dotfiles }}/install/platform-check.sh arch
    @just _setup

setup-debian:
    @bash {{ dotfiles }}/install/platform-check.sh debian
    @just _setup

# Shared orchestration. Linking is deliberately separate so setup never replaces
# a working machine's configuration as a side effect of installing tools.
_setup: core runtimes agents tools seed-agents
    @echo ""
    @echo "Tools installed."

# Install the platform shell plus tmux, starship, nvim, lazygit, git, and direnv
core:
    @bash {{ dotfiles }}/install/core.sh

# Install language runtimes: pyenv, uv, nvm, Node.js, Bun, Rust
runtimes:
    @bash {{ dotfiles }}/install/runtimes.sh

# Install Herdr + AI coding agents: Claude Code, Codex, OpenCode, agy, Grok Build, Pi
agents:
    @bash {{ dotfiles }}/install/agents.sh

# Upgrade all AI coding agents to their latest release
update-agents:
    @bash {{ dotfiles }}/install/agents.sh --upgrade

# Validate shared skills for Claude Code, Codex, Pi, and Antigravity CLI portability
validate-skills:
    @bash {{ dotfiles }}/tools/validate-agent-skills.sh

# Audit the Moshi + Herdr remote-access security baseline (read-only; uses sudo)
audit-remote-access:
    @bash {{ dotfiles }}/tools/audit-remote-access.sh

# Install CLI tools: gh, glab, jq, yq, just, agent-browser, portless, mole (macOS)
tools:
    @bash {{ dotfiles }}/install/tools.sh

# Install the desktop apps expected on the personal Omarchy workstation
omarchy-apps:
    @bash {{ dotfiles }}/install/omarchy-apps.sh

# Configure Moonlight capture without replacing its host list or pairing data.
omarchy-moonlight:
    @bash {{ dotfiles }}/install/omarchy-moonlight.sh

# Opt in to a persistent 1080p virtual display for a headless Sunshine host.
omarchy-sunshine-headless:
    @bash {{ dotfiles }}/install/omarchy-sunshine-headless.sh

# Install infrastructure tools: Terraform, Pulumi, SST (opt-in)
infra:
    @bash {{ dotfiles }}/install/infra.sh

# Clone/pull personal workspace repos defined in install/repos.txt
repos:
    @bash {{ dotfiles }}/install/repos.sh

# Create all config symlinks (idempotent)
link:
    #!/usr/bin/env bash
    source {{ dotfiles }}/lib/helpers.sh
    info "Linking configuration files..."

    # Shell: macOS owns Zsh; Omarchy keeps its stock Bash rc and sources one
    # additive personal fragment from the repository.
    if [ "$DOTFILES_PLATFORM" = "omarchy" ]; then
      # Preflight the host-owned Hyprland files before changing the shell
      # overlay, so a partial installation cannot be left behind.
      hypr_bindings="$HOME/.config/hypr/bindings.lua"
      hypr_module="{{ dotfiles }}/config/hypr/remote_desktop.lua"
      hypr_target="$HOME/.config/hypr/remote_desktop.lua"
      hypr_require='require("hypr.remote_desktop")'
      if [ ! -f "$hypr_bindings" ]; then
        fail "Required Omarchy Hyprland config is missing: $hypr_bindings"
        exit 1
      fi
      if [ ! -f "$hypr_module" ]; then
        fail "Dotfiles Hyprland module is missing: $hypr_module"
        exit 1
      fi

      ensure_dir "$HOME/.config/dotfiles/shell"
      ensure_symlink "{{ dotfiles }}/config/shell/omarchy/dotfiles.bash" "$HOME/.config/dotfiles/shell/omarchy.bash"
      omarchy_shell_line='[[ -r "$HOME/.config/dotfiles/shell/omarchy.bash" ]] && source "$HOME/.config/dotfiles/shell/omarchy.bash"'
      if ! grep -Fqx -- "$omarchy_shell_line" "$HOME/.bashrc"; then
        backup_file "$HOME/.bashrc"
      fi
      ensure_source_line "$HOME/.bashrc" "$omarchy_shell_line"

      # Add one repository-owned Lua module to Omarchy's host-owned Hyprland
      # config.
      ensure_symlink "$hypr_module" "$hypr_target"
      if ! grep -Fqx -- "$hypr_require" "$hypr_bindings"; then
        backup_file "$hypr_bindings"
      fi
      ensure_source_line "$hypr_bindings" "$hypr_require"
    else
      ensure_symlink "{{ dotfiles }}/config/zsh/.zshenv" "$HOME/.zshenv"
      ensure_symlink "{{ dotfiles }}/config/zsh/.zshrc" "$HOME/.zshrc"
    fi
    # Omarchy owns application configuration. The dotfiles only install/check
    # tools and add the shell fragment plus the isolated Moonlight module above.
    if [ "$DOTFILES_PLATFORM" != "omarchy" ]; then
      ensure_symlink "{{ dotfiles }}/config/tmux/.tmux.conf" "$HOME/.tmux.conf"
      ensure_symlink "{{ dotfiles }}/config/git/.gitconfig" "$HOME/.gitconfig"
      ensure_symlink "{{ dotfiles }}/config/git/.gitmessage" "$HOME/.gitmessage"
      ensure_symlink "{{ dotfiles }}/config/nvim" "$HOME/.config/nvim"
      ensure_dir "$HOME/.config/herdr"
      ensure_symlink "{{ dotfiles }}/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
      ensure_symlink "{{ dotfiles }}/config/starship/macos.toml" "$HOME/.config/starship.toml"
    else
      warn "Omarchy: preserving Git, tmux, Starship, Lazygit, Neovim, Herdr, and terminal configs; adding Moonlight remote-desktop mode"
    fi

    # Lazygit is managed by Omarchy on that platform.
    if [ "$DOTFILES_PLATFORM" = "macos" ]; then
      ensure_symlink "{{ dotfiles }}/config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
    elif [ "$DOTFILES_PLATFORM" != "omarchy" ]; then
      ensure_symlink "{{ dotfiles }}/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
    fi

    # Ghostty (macOS only, matching where core.sh installs it -- linking a config
    # on Linux for an app this repo never installs there is the pointer-without-a-
    # target shape). Link one location only: Ghostty reads both this path and
    # ~/.config/ghostty/config, and font-family appends rather than replaces, so
    # linking both would silently double the fallback chain.
    if [ "$DOTFILES_PLATFORM" = "macos" ]; then
      ensure_symlink "{{ dotfiles }}/config/terminal/macos/ghostty.conf" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
    fi

    # Coding-agent configs are NOT symlinked. Claude Code, Codex, Pi and OpenCode
    # all rewrite their own config in place, and their formats change faster than a
    # shared repo can track. Each machine owns its own copy under ~/. What lives in
    # agents/*/ is a reference template -- run `just seed-agents` to copy it onto a
    # fresh machine, then let the machine diverge. Skills likewise install per
    # project via the skills CLI; see docs/agent-skills-sources.md.

    ok "All symlinks created"

# Show exactly which managed targets already exist; never writes anything.
link-dry-run:
    #!/usr/bin/env bash
    source {{ dotfiles }}/lib/helpers.sh
    targets=()
    if [ "$DOTFILES_PLATFORM" = "omarchy" ]; then
      targets+=("$HOME/.config/dotfiles/shell/omarchy.bash")
      targets+=("$HOME/.config/hypr/remote_desktop.lua")
      source_line='[[ -r "$HOME/.config/dotfiles/shell/omarchy.bash" ]] && source "$HOME/.config/dotfiles/shell/omarchy.bash"'
      if grep -Fqx -- "$source_line" "$HOME/.bashrc"; then
        printf 'READY    %s sources Omarchy overlay\n' "$HOME/.bashrc"
      else
        printf 'APPEND   one source line to %s\n' "$HOME/.bashrc"
      fi
      hypr_require='require("hypr.remote_desktop")'
      if [ -f "$HOME/.config/hypr/bindings.lua" ]; then
        if grep -Fqx -- "$hypr_require" "$HOME/.config/hypr/bindings.lua"; then
          printf 'READY    %s loads Moonlight remote-desktop mode\n' "$HOME/.config/hypr/bindings.lua"
        else
          printf 'APPEND   one require line to %s\n' "$HOME/.config/hypr/bindings.lua"
        fi
      else
        printf 'BLOCKED  missing %s\n' "$HOME/.config/hypr/bindings.lua"
      fi
    else
      targets+=(
        "$HOME/.zshenv"
        "$HOME/.zshrc"
        "$HOME/.tmux.conf"
        "$HOME/.gitconfig"
        "$HOME/.gitmessage"
        "$HOME/.config/starship.toml"
        "$HOME/.config/lazygit/config.yml"
        "$HOME/.config/herdr/config.toml"
        "$HOME/.config/nvim"
      )
    fi
    printf 'Platform: %s\n' "$DOTFILES_PLATFORM"
    for target in "${targets[@]}"; do
      if [ -L "$target" ]; then
        printf 'LINK     %s -> %s\n' "$target" "$(readlink "$target")"
      elif [ -e "$target" ]; then
        printf 'PRESERVE %s (link will refuse without DOTFILES_LINK_MODE=backup)\n' "$target"
      else
        printf 'CREATE   %s\n' "$target"
      fi
    done

# Copy agent config templates to a fresh machine (never overwrites an existing file)
seed-agents:
    #!/usr/bin/env bash
    source {{ dotfiles }}/lib/helpers.sh
    info "Seeding agent configs (existing files are left untouched)..."

    seed() {
      local src="$1" dest="$2"
      if [ -e "$dest" ]; then
        warn "exists, skipped: $dest"
      else
        ensure_dir "$(dirname "$dest")"
        cp -R "$src" "$dest"
        ok "seeded $dest"
      fi
    }

    # The current Claude/Codex templates contain macOS paths. Do not seed those
    # onto Linux; each CLI will create a clean machine-local config on first run.
    if [ "$DOTFILES_PLATFORM" = "macos" ]; then
      seed "{{ dotfiles }}/agents/claude/settings.json"  "$HOME/.claude/settings.json"
      seed "{{ dotfiles }}/agents/claude/statusline.sh"  "$HOME/.claude/statusline.sh"
      seed "{{ dotfiles }}/agents/claude/output-styles"  "$HOME/.claude/output-styles"
      [ -f "$HOME/.claude/statusline.sh" ] && chmod +x "$HOME/.claude/statusline.sh"
      seed "{{ dotfiles }}/agents/codex/config.toml" "$HOME/.codex/config.toml"
      seed "{{ dotfiles }}/agents/codex/AGENTS.md"   "$HOME/.codex/AGENTS.md"
    else
      warn "Skipping macOS-specific Claude and Codex templates on $DOTFILES_PLATFORM"
    fi

    # Pi
    seed "{{ dotfiles }}/agents/pi/settings.json" "$HOME/.pi/agent/settings.json"

    # OpenCode
    seed "{{ dotfiles }}/agents/opencode/opencode.json"       "$HOME/.config/opencode/opencode.json"
    seed "{{ dotfiles }}/agents/opencode/oh-my-opencode.json" "$HOME/.config/opencode/oh-my-opencode.json"

    ok "Agent configs seeded -- they are yours to edit now, this repo will not touch them again"

# Unlink all symlinks (for clean removal)
unlink:
    #!/usr/bin/env bash
    source {{ dotfiles }}/lib/helpers.sh
    links=()
    if [ "$DOTFILES_PLATFORM" != omarchy ]; then
      links+=(
        "$HOME/.zshenv"
        "$HOME/.zshrc"
        "$HOME/.tmux.conf"
        "$HOME/.gitconfig"
        "$HOME/.gitmessage"
        "$HOME/.config/nvim"
        "$HOME/.config/starship.toml"
        "$HOME/.config/herdr/config.toml"
      )
    fi
    # Lazygit (OS-dependent path) and Ghostty (macOS only, as linked)
    if [ "$(uname)" = "Darwin" ]; then
      links+=("$HOME/Library/Application Support/lazygit/config.yml")
      links+=("$HOME/Library/Application Support/com.mitchellh.ghostty/config")
    elif [ "$DOTFILES_PLATFORM" != omarchy ]; then
      links+=("$HOME/.config/lazygit/config.yml")
    fi
    # Agent configs and skills are not symlinked, so there is nothing to unlink for
    # them. Whatever sits under ~/.claude, ~/.codex, ~/.pi and ~/.config/opencode
    # belongs to this machine and is left alone.
    for link in "${links[@]}"; do
      [ -L "$link" ] && rm "$link" && ok "Removed $link"
    done
    if [ "$DOTFILES_PLATFORM" = omarchy ]; then
      source_line='[[ -r "$HOME/.config/dotfiles/shell/omarchy.bash" ]] && source "$HOME/.config/dotfiles/shell/omarchy.bash"'
      if grep -Fqx -- "$source_line" "$HOME/.bashrc"; then
        backup_file "$HOME/.bashrc"
      fi
      remove_source_line "$HOME/.bashrc" "$source_line"
      [ -L "$HOME/.config/dotfiles/shell/omarchy.bash" ] && rm "$HOME/.config/dotfiles/shell/omarchy.bash"

      hypr_target="$HOME/.config/hypr/remote_desktop.lua"
      hypr_module="{{ dotfiles }}/config/hypr/remote_desktop.lua"
      hypr_require='require("hypr.remote_desktop")'
      if [ -L "$hypr_target" ] && [ "$(readlink "$hypr_target")" = "$hypr_module" ]; then
        rm "$hypr_target"
        ok "Removed $hypr_target"
        if grep -Fqx -- "$hypr_require" "$HOME/.config/hypr/bindings.lua" 2>/dev/null; then
          backup_file "$HOME/.config/hypr/bindings.lua"
          remove_source_line "$HOME/.config/hypr/bindings.lua" "$hypr_require"
        fi
      fi

      sunshine_target="$HOME/.config/hypr/sunshine_headless.lua"
      sunshine_module="{{ dotfiles }}/config/hypr/sunshine_headless.lua"
      sunshine_require='require("hypr.sunshine_headless")'
      sunshine_marker='-- Managed by dotfiles: omarchy-sunshine-headless'
      sunshine_managed=false
      if [ -L "$sunshine_target" ] && [ "$(readlink "$sunshine_target")" = "$sunshine_module" ]; then
        sunshine_managed=true
      elif [ -f "$sunshine_target" ] && [ "$(head -n 1 "$sunshine_target")" = "$sunshine_marker" ]; then
        sunshine_managed=true
      fi
      if [ "$sunshine_managed" = true ]; then
        rm "$sunshine_target"
        ok "Removed $sunshine_target"
        if grep -Fqx -- "$sunshine_require" "$HOME/.config/hypr/autostart.lua" 2>/dev/null; then
          backup_file "$HOME/.config/hypr/autostart.lua"
          remove_source_line "$HOME/.config/hypr/autostart.lua" "$sunshine_require"
        fi
      fi
    fi

# Health-check this machine: symlinks, commands, global skills, brew taps (read-only)
doctor:
    @bash {{ dotfiles }}/tools/doctor.sh

# Install Omarchy 4 from the official ISO into a local VM -- macOS, emulated, opt-in
omarchy-vm:
    @bash {{ dotfiles }}/tools/omarchy-vm.sh up

# Print how to reach the Omarchy VM and what to expect on first boot
omarchy-vm-info:
    @bash {{ dotfiles }}/tools/omarchy-vm.sh info

# Report whether the Omarchy VM is running, and its ISO/disk sizes
omarchy-vm-status:
    @bash {{ dotfiles }}/tools/omarchy-vm.sh status

# Shut the Omarchy VM down, leaving its disk intact
omarchy-vm-stop:
    @bash {{ dotfiles }}/tools/omarchy-vm.sh stop

# Delete the Omarchy VM's disk and UEFI variables (the cached ISO is kept)
omarchy-vm-destroy:
    @bash {{ dotfiles }}/tools/omarchy-vm.sh destroy

# Report any symlink still pointing into this repo from an agent config directory
check-agent-links:
    @bash {{ dotfiles }}/tools/agent-links.sh check

# Turn agent config symlinks into real machine-local files (run once per old machine)
adopt-agents:
    @bash {{ dotfiles }}/tools/agent-links.sh adopt
