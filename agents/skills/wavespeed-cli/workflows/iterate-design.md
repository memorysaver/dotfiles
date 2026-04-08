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
- **Prompt refinement**: The concept is right but the details are off
- **Specialized transform**: Relight, restore, colorize, change season, face swap, blend

### 4. Select model and approach

Load [references/model-guide.md](../references/model-guide.md) — the "Editing an existing image" and "Specialized tools" sections map each edit type to the right model.

The key decision is whether to **edit** the existing image or **re-generate** from scratch:
- Edit (preserves the original, changes specific things) → `wavespeed edit -i source.png -p "instruction" -m <model> --json`
- Re-generate (start fresh with adjusted prompt) → `wavespeed generate image -p "new prompt" --json`
- Variation (same concept, different seed) → `wavespeed generate image -p "same prompt" --seed N --json`

Tell the user which model and approach you're using and why.

### 5. Generate and present

Load [references/cli.md](../references/cli.md) and run the command with `--json`. Show the user the new output file path and what changed.

### 6. Loop

Ask: **"Keep this, try again, or adjust further?"**

- **Keep**: Offer to move the file to the right project location.
- **Try again**: Re-run with same or slightly modified parameters.
- **Adjust**: Go back to step 3 with new feedback.

Keep intermediate files so the user can compare versions.

### 7. Clean up

When done, offer to rename the final file, move it to the project directory, and delete intermediates.
