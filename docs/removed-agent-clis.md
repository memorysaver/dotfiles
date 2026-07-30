# Removed Agent CLIs

CLI tools this repo used to install globally on every machine, and no longer does.

They fell into two groups: **skill installers** (a whole CLI whose only job was to copy
a skill into a project — redundant now that everything goes through the skills CLI) and
**skill backends** (a CLI that one skill in `agents/skills/` shells out to, which belongs
wherever that skill is actually used, not on every machine).

Nothing here is judged bad. This file exists so that removing them is reversible and so
that a future "what was that CLI called again?" has an answer.

Removed 2026-07-30.

## Skill installers

| CLI | Package | What it did | Why removed |
| --- | --- | --- | --- |
| `uipro` | `uipro-cli` (MIT, `viettranx`) | Installed the UI/UX Pro Max skill into a project — `.claude/skills`, `.codex/skills`, `.cursor/skills` — for 15 different agents. Pulls from `nextlevelbuilder/ui-ux-pro-max-skill`, or `--offline` to use its bundled copy. | Duplicates `npx skills add`, against the same upstream, into the same directory. |

```bash
# If you want it again -- no global install needed
npx uipro-cli@2.2.3 init --ai claude --offline

# Or the way this repo now prefers
npx skills@1.5.20 add nextlevelbuilder/ui-ux-pro-max-skill --full-depth -a claude-code -y
```

`uipro` bundles more than the skill text: `assets/data/*.csv` (colors, typography, charts,
icons, ux-guidelines, react-performance, …) plus three Python search scripts. `npx skills add`
copies `SKILL.md` and its bundled files, so check the result if you depend on those CSVs.

## Skill backends

Each of these backs exactly one skill under `agents/skills/`. The skill stays in this repo
— only the automatic global install is gone. Install the CLI in the project, or globally by
hand, on the machines where you actually use that skill.

| CLI | Install command | Backs |
| --- | --- | --- |
| `opencli` | `npm install -g @jackwener/opencli` | `agents/skills/opencli` — pull structured data off public websites without login |
| `podwise` | `brew install hardhackerlabs/podwise-tap/podwise` | `agents/skills/podwise` — podcast search, transcripts, summaries. macOS only; no Linux package |
| `wavespeed` | `npm install -g ~/.dotfiles/tools/wavespeed-cli` | `agents/skills/wavespeed-cli` — AI image/video generation. Needs `WAVESPEED_API_KEY` |
| `qmd` | `bun install -g @tobilu/qmd` | **nothing** — see below |

### `qmd` was already orphaned

Its install block was commented "memory backbone for the lesson-learned skill". That skill
is not in `agents/skills/` and has not been for some time, so `qmd` was being installed on
every machine to support something that no longer existed.

### `wavespeed-cli` global link was already drifting

`install/tools.sh` installed it from `$DOTFILES_DIR/tools/wavespeed-cli`, but the actual
global link on the primary machine pointed at
`~/Documents/github/monetlab-video-workflow/tools/wavespeed-cli` — a different checkout.
If you reinstall it, decide which copy is canonical first. The vendored copy under
`tools/wavespeed-cli/` is still in this repo.

## Still installed globally

`install/tools.sh` continues to install these, because they are general-purpose developer
tools rather than skill plumbing: `gh`, `glab`, `jq`, `yq`, `just`, `agent-browser`,
`portless`.

`agent-browser` is a borderline case — `vercel-labs/agent-browser` also publishes a skill,
listed in `docs/agent-skills-sources.md`. The CLI is kept because it is useful on its own;
the skill is not installed globally.

## Uninstalling what a machine still has

Removing the install block stops *new* machines from getting these. Machines set up earlier
still have them. To clear one:

```bash
npm uninstall -g uipro-cli
npm uninstall -g @jackwener/opencli
bun  uninstall -g @tobilu/qmd        # or: npm uninstall -g @tobilu/qmd
npm  uninstall -g wavespeed-cli
brew uninstall podwise
```
