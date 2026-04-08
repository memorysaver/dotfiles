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

Before generating, understand what the user needs. Ask about any of these that aren't clear from context:

- **Type**: Image, video, or SVG/vector?
- **Purpose**: Hero image, thumbnail, placeholder, social graphic, product shot, background, icon, logo?
- **Style/mood**: Photorealistic, illustrated, minimal, vibrant, dark, professional?
- **Dimensions**: Standard web sizes (1024x768, 1920x1080, 1080x1080 for social)?
- **Reference images**: Does the user have an existing image to build from?
- **Priority**: Speed, quality, or cost?

Don't over-ask — if the user said "make me a hero image for my landing page", you have enough to start. Fill in reasonable defaults and iterate.

### 3. Select model

Use the **Model Selection Guide** in SKILL.md to pick the right model based on the user's intent and priority. The guide has decision trees for every use case.

Quick defaults if no special requirements:
- **Image from text**: `google/nano-banana-2/text-to-image`
- **SVG / logo / icon**: `recraft-ai/recraft-v4-pro/text-to-vector`
- **Video from text**: `alibaba/wan-2.7/text-to-video`
- **Video from image**: `alibaba/wan-2.7/image-to-video`

Tell the user which model you chose and why, in one sentence. If they want a different tradeoff (faster, cheaper, higher quality), suggest the alternative from the guide.

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
wavespeed generate image -p "your prompt here" -m <model> --json
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
