# Generate Asset

Generate a single image, video, or SVG for a project.

## Steps

### 1. Check environment

```bash
wavespeed --help
echo $WAVESPEED_API_KEY
```

If either fails, load [references/installation.md](../references/installation.md) and stop.

### 2. Clarify requirements

Understand what the user needs. Ask about any of these that aren't clear from context:

- **Type**: Image, video, or SVG/vector?
- **Purpose**: Hero image, thumbnail, placeholder, social graphic, product shot, logo, icon?
- **Style/mood**: Photorealistic, illustrated, minimal, vibrant, dark, professional?
- **Dimensions**: Standard web sizes (1024x768, 1920x1080, 1080x1080 for social)?
- **Reference images**: Does the user have an existing image to build from?
- **Priority**: Speed, quality, or cost?

Don't over-ask — if the user said "make me a hero image for my landing page", you have enough to start. Fill in reasonable defaults and iterate.

### 3. Select model

Load [references/model-guide.md](../references/model-guide.md) and match the user's intent to the right model. Tell the user which model you chose and why, in one sentence. If they want a different tradeoff, the guide has alternatives.

### 4. Craft the prompt

Write a detailed, descriptive prompt. Good prompts include:
- Subject and composition
- Style descriptors (photorealistic, minimalist, flat design, etc.)
- Lighting and mood
- Color palette if relevant
- Negative space and layout considerations for UI assets

Share the prompt with the user before generating so they can adjust it.

### 5. Generate

Load [references/cli.md](../references/cli.md) and run the appropriate command with `--json`:

```bash
wavespeed generate image -p "your prompt here" -m <model> --json
```

### 6. Present result

Show the user the output file path, model used, and prompt. If they want changes, route to [iterate-design](iterate-design.md).

### 7. File placement

If in a project context, suggest an appropriate location:
- Web projects: `public/images/`, `src/assets/`, `static/`
- General: current working directory

Offer to move the file.
