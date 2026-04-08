# Iterate Design

Refine an image through an edit-review-repeat loop until the user is satisfied.

## Steps

### 1. Check environment

```bash
wavespeed --help
echo $WAVESPEED_API_KEY
```

If either fails, load [references/installation.md](../references/installation.md) and stop.

### 2. Identify the source

Determine which image to refine:
- A previously generated WaveSpeed output (check recent `wavespeed-*.png` files)
- An existing project file the user points to
- A file path the user provides

Confirm the source file exists before proceeding.

### 3. Understand the change

Ask what should change. Common categories:
- **Content edit**: Add, remove, or change objects/elements
- **Style change**: Different artistic style, color palette, mood
- **Composition**: Crop, zoom, reframe
- **Prompt refinement**: The concept is right but the details are off
- **Specialized transform**: Relight, restore, colorize, change season, face swap

### 4. Choose approach and model

Use the **Model Selection Guide** in SKILL.md to pick the right model. The key decision:

| Change Type | Approach | Model |
|-------------|----------|-------|
| General content edit (default) | `wavespeed edit` | `google/nano-banana-2/edit` |
| Cheapest edit | `wavespeed edit` | `google/nano-banana-2/edit-fast` |
| Multi-person scene edit | `wavespeed edit` | `wavespeed-ai/qwen-image/edit-2511` |
| Edit with reference images | `wavespeed edit` | `wavespeed-ai/phota/edit` |
| Best quality edit | `wavespeed edit` | `google/nano-banana-pro/edit` |
| Style/prompt refinement | Re-generate with adjusted prompt | `google/nano-banana-2/text-to-image` |
| Variations (same concept) | Re-generate with different seed | same model + `--seed N` |
| Relight / change lighting | `wavespeed edit` | `bria/fibo/relight` |
| Restore old/damaged photo | `wavespeed edit` | `bria/fibo/restore` |
| Colorize B&W photo | `wavespeed edit` | `bria/fibo/colorize` |
| Change season/weather | `wavespeed edit` | `bria/fibo/reseason` |
| Blend/merge textures | `wavespeed edit` | `bria/fibo/image-blend` |
| Face swap | `wavespeed edit` | `wavespeed-ai/infinite-you` |

Tell the user which model you're using and why.

### 5. Generate and present

Load [references/cli.md](../references/cli.md) and run the command with `--json`. Show the user:
- The new output file path
- What changed (the edit instruction or prompt adjustment)
- The model used

### 6. Loop

Ask the user: **"Keep this, try again, or adjust further?"**

- **Keep**: Done — offer to move the file to the right project location.
- **Try again**: Re-run with the same or slightly modified parameters.
- **Adjust**: Go back to step 3 with new feedback.

Repeat until the user is satisfied. Keep intermediate files so the user can compare versions.

### 7. Clean up

When the user confirms the final version, offer to:
- Rename the final file to something meaningful
- Move it to the appropriate project directory
- Delete intermediate files if the user doesn't need them
