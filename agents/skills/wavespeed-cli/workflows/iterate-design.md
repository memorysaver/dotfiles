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

### 4. Choose approach

Load [references/cli.md](../references/cli.md) and [references/models.md](../references/models.md).

| Change Type | Approach | Command |
|-------------|----------|---------|
| Content edit (add/remove/modify elements) | `wavespeed edit` with flux-kontext | `wavespeed edit -i source.png -p "instruction" --json` |
| Style/prompt refinement | Re-generate with adjusted prompt | `wavespeed generate image -p "new prompt" --json` |
| Variations (same concept, different seed) | Re-generate with seed | `wavespeed generate image -p "same prompt" --seed N --json` |

### 5. Generate and present

Run the command with `--json`. Show the user:
- The new output file path
- What changed (the edit instruction or prompt adjustment)

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
