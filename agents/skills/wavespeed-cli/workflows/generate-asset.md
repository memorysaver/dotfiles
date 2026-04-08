# Generate Asset

Generate a single image or video for a project.

## Steps

### 1. Check environment

```bash
wavespeed --help
echo $WAVESPEED_API_KEY
```

If either fails, load [references/installation.md](../references/installation.md) and stop.

### 2. Clarify requirements

Before generating, understand what the user needs. Ask about any of these that aren't clear from context:

- **Type**: Image or video?
- **Purpose**: Hero image, thumbnail, placeholder, social graphic, product shot, background, icon?
- **Style/mood**: Photorealistic, illustrated, minimal, vibrant, dark, professional?
- **Dimensions**: Standard web sizes (1024x768, 1920x1080, 1080x1080 for social)?
- **Reference images**: Does the user have an existing image to build from?

Don't over-ask — if the user said "make me a hero image for my landing page", you have enough to start. Fill in reasonable defaults and iterate.

### 3. Select model

Load [references/models.md](../references/models.md) and pick the right model:

- **Image**: `wavespeed-ai/flux-dev` for most cases. Use `z-image/turbo` for quick drafts.
- **Video from text**: `wavespeed-ai/wan-2.1/text-to-video`
- **Video from image**: `wavespeed-ai/wan-2.1/image-to-video`

### 4. Craft the prompt

Write a detailed, descriptive prompt based on the user's requirements. Good prompts include:
- Subject and composition
- Style descriptors (photorealistic, minimalist, flat design, etc.)
- Lighting and mood
- Color palette if relevant
- Negative space and layout considerations for UI assets

Share the prompt with the user before generating so they can adjust it.

### 5. Generate

Load [references/cli.md](../references/cli.md) and run the appropriate command. Always use `--json` to capture the output programmatically.

```bash
wavespeed generate image -p "your prompt here" --json
```

### 6. Present result

Show the user:
- The output file path
- The model used
- The prompt used

If the file is an image, suggest they view it. If they want changes, route to the [iterate-design workflow](iterate-design.md).

### 7. File placement

If you're in a project context, suggest an appropriate location:
- Web projects: `public/images/`, `src/assets/`, `static/`
- General: current working directory

Offer to move the file to the suggested location.
