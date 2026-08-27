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
    @just _setup

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
    @echo "Tools installed. Review with 'just link-dry-run', then run 'just link'."

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

# Install CLI tools: gh, glab, jq, yq, just, agent-browser, portless, mole (macOS)
tools:
    @bash {{ dotfiles }}/install/tools.sh

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
      ensure_dir "$HOME/.config/dotfiles/shell"
      ensure_symlink "{{ dotfiles }}/config/shell/omarchy/dotfiles.bash" "$HOME/.config/dotfiles/shell/omarchy.bash"
      ensure_source_line "$HOME/.bashrc" '[[ -r "$HOME/.config/dotfiles/shell/omarchy.bash" ]] && source "$HOME/.config/dotfiles/shell/omarchy.bash"'
    else
      ensure_symlink "{{ dotfiles }}/config/zsh/.zshenv" "$HOME/.zshenv"
      ensure_symlink "{{ dotfiles }}/config/zsh/.zshrc" "$HOME/.zshrc"
    fi
    ensure_symlink "{{ dotfiles }}/config/tmux/.tmux.conf" "$HOME/.tmux.conf"

    # Git
    ensure_symlink "{{ dotfiles }}/config/git/.gitconfig" "$HOME/.gitconfig"
    ensure_symlink "{{ dotfiles }}/config/git/.gitmessage" "$HOME/.gitmessage"

    # Editors. Omarchy keeps its Neovim defaults.
    if [ "$DOTFILES_PLATFORM" != "omarchy" ]; then
      ensure_symlink "{{ dotfiles }}/config/nvim" "$HOME/.config/nvim"
    else
      warn "Omarchy: preserving ~/.config/nvim"
    fi

    # Starship has complete platform profiles rather than a lossy merged file.
    if [ "$DOTFILES_PLATFORM" = "omarchy" ]; then
      starship_profile=omarchy
    else
      starship_profile=macos
    fi
    ensure_symlink "{{ dotfiles }}/config/starship/${starship_profile}.toml" "$HOME/.config/starship.toml"

    # Herdr's tracked config currently contains macOS IME behavior. Preserve the
    # machine-local Omarchy config until platform overlays are split further.
    if [ "$DOTFILES_PLATFORM" != "omarchy" ]; then
      ensure_dir "$HOME/.config/herdr"
      ensure_symlink "{{ dotfiles }}/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
    else
      warn "Omarchy: preserving ~/.config/herdr/config.toml"
    fi

    # Lazygit (OS-dependent path)
    if [ "$DOTFILES_PLATFORM" = "macos" ]; then
      ensure_symlink "{{ dotfiles }}/config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
    else
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
    targets=(
      "$HOME/.tmux.conf"
      "$HOME/.gitconfig"
      "$HOME/.gitmessage"
      "$HOME/.config/starship.toml"
      "$HOME/.config/lazygit/config.yml"
    )
    if [ "$DOTFILES_PLATFORM" = "omarchy" ]; then
      targets+=("$HOME/.config/dotfiles/shell/omarchy.bash")
      source_line='[[ -r "$HOME/.config/dotfiles/shell/omarchy.bash" ]] && source "$HOME/.config/dotfiles/shell/omarchy.bash"'
      if grep -Fqx -- "$source_line" "$HOME/.bashrc"; then
        printf 'READY    %s sources Omarchy overlay\n' "$HOME/.bashrc"
      else
        printf 'APPEND   one source line to %s\n' "$HOME/.bashrc"
      fi
    else
      targets+=("$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.config/herdr/config.toml" "$HOME/.config/nvim")
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
    links=(
      "$HOME/.zshenv"
      "$HOME/.zshrc"
      "$HOME/.tmux.conf"
      "$HOME/.gitconfig"
      "$HOME/.gitmessage"
      "$HOME/.config/nvim"
      "$HOME/.config/starship.toml"
      "$HOME/.config/herdr/config.toml"
    )
    # Lazygit (OS-dependent path) and Ghostty (macOS only, as linked)
    if [ "$(uname)" = "Darwin" ]; then
      links+=("$HOME/Library/Application Support/lazygit/config.yml")
      links+=("$HOME/Library/Application Support/com.mitchellh.ghostty/config")
    else
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
      remove_source_line "$HOME/.bashrc" "$source_line"
      [ -L "$HOME/.config/dotfiles/shell/omarchy.bash" ] && rm "$HOME/.config/dotfiles/shell/omarchy.bash"
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
