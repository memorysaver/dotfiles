# Batch Generate

Generate multiple images or videos from a list of prompts.

## Steps

### 1. Check environment

```bash
wavespeed --help
echo $WAVESPEED_API_KEY
```

If either fails, load [references/installation.md](../references/installation.md) and stop.

### 2. Gather inputs

Determine the prompt list. Sources:

- **User provides a list**: Multiple prompts directly in the conversation
- **Template with variables**: A single prompt template with substitutions (e.g., "A {color} car on a {background}" with lists of colors and backgrounds)
- **File-based**: A text file with one prompt per line
- **Project-driven**: Generate assets for each page/section/component in a project

### 3. Confirm plan

Before generating, present a summary:

- Number of assets to generate
- Model to use (load [references/models.md](../references/models.md) to select)
- Output type (image or video)
- Output directory
- Estimated time (images: ~5-10s each, videos: ~1-2min each)

Wait for user confirmation before proceeding.

### 4. Execute

Load [references/cli.md](../references/cli.md). Run commands sequentially to avoid rate limits. Use `--json` on all commands.

For each prompt:
1. Run the generation command
2. Report progress: `[3/10] Generated: wavespeed-image-2026-04-08T12-30-00.png`
3. Add a 2-second delay between requests

If a generation fails, log the error and continue with the next prompt. Report failures at the end.

### 5. Present results

Show a summary table:

```
# | Prompt (truncated)         | Output File                    | Status
1 | A sunset over mountains... | wavespeed-image-...-01.png     | OK
2 | A forest path in autumn... | wavespeed-image-...-02.png     | OK
3 | A city at night...         | wavespeed-image-...-03.png     | FAILED: timeout
```

Offer to:
- Move all files to a project directory
- Rename files with meaningful names
- Retry any failed generations
- Open the output directory
