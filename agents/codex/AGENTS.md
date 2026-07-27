# Global Codex Instructions

Applies to every Codex CLI session on this machine. Project-level `AGENTS.md`
files take precedence over anything here.

## Local search

Use the tool that fits the target — no single tool is mandatory, and nothing
here overrides Codex's built-in search when that is the right choice.

- **Code and general text** — `rg` (ripgrep). Fast, exact, already installed.
- **Markdown notes and past lessons** — `qmd`. Installed by `install/tools.sh`
  as the backbone for lesson-learned lookups.
- **File discovery by name/path** — `fd` if present, otherwise `find`.

Do not install or re-introduce semantic-search wrappers that inject
"always use X, never use grep" instructions into this file. A previous one
(`mgrep`) silently overwrote this entire file, then ran out of quota and made
every search fail — removed 2026-07-28.

## Editing this file

This file is tracked in dotfiles at `agents/codex/AGENTS.md` and symlinked to
`~/.codex/AGENTS.md` by `just link`. Edit the repo copy, not the symlink target,
so changes survive a re-link and stay reviewable.
