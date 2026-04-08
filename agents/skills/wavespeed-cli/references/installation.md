# WaveSpeed CLI Installation

## Prerequisites

- Node.js 20+
- npm

## Install

The CLI is bundled in the dotfiles repo. Install via:

```bash
just tools
```

Or manually:

```bash
npm install -g ~/.dotfiles/tools/wavespeed-cli
```

## API Key Setup

1. Sign in at https://wavespeed.ai (Google or GitHub)
2. Go to https://wavespeed.ai/accesskey
3. Create a new API key
4. Add to your shell profile (`~/.zshrc`):

```bash
export WAVESPEED_API_KEY="ws-your-key-here"
```

5. Reload: `source ~/.zshrc`

## Verify

```bash
wavespeed --help
wavespeed models
```

If `wavespeed models` prints the model table, you're set. The API key is only needed for generation commands (`generate`, `edit`, `upload`, `status`).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `command not found: wavespeed` | Run `just tools` or `npm install -g ~/.dotfiles/tools/wavespeed-cli` |
| `WAVESPEED_API_KEY is not set` | Add `export WAVESPEED_API_KEY=...` to `~/.zshrc` and reload |
| `npm install` fails | Check Node.js version: `node -v` (need 20+) |
