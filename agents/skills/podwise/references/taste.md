# Podwise Taste Profile

This reference describes the `taste.md` file that the Podwise skill reads from the current working directory.

The file is user-authored project context, not part of the skill install itself.

## Expected Location

- Preferred: `./taste.md` in the current working directory
- If the user chooses another location, follow their preference and say where it was written

## Expected Sections

The canonical structure is:

```markdown
# Listener Taste

_Last updated: 2026-04-21_

## Subscribed Podcasts
## Core Interest Areas
## Listening Style
## What the User Does with Insights
## Output Preferences
## Shows to Prioritize
## Shows to Deprioritize
```

## How Other Workflows Use It

- `catch-up` uses it for triage priority
- `weekly-recap` uses it for recap structure and emphasis
- `discover` uses it for recommendation quality
- `topic-research` uses it for framing and output format
- `episode-debate` uses it for the user's preferred angle and depth

## Portability Notes

- Treat `taste.md` as ordinary Markdown, not as agent-specific memory
- Keep references relative to the current project so Claude Code, Codex, and Pi can all follow the same workflow
- Do not assume any harness-specific slash commands or storage directories
