# Model Selection Guide

Use this guide to pick the right WaveSpeed model based on what the user is trying to accomplish. If you need the full catalog with all model IDs and details, load [models.md](models.md).

## Decision Tree

### Creating an image from text

| Priority | Model | Why |
|----------|-------|-----|
| Best default | `google/nano-banana-2/text-to-image` | Pro quality at flash speed, up to 4K |
| Cheapest ($0.045/img) | `google/nano-banana-2/text-to-image-fast` | Budget batch work, 2K |
| Maximum quality / 4K | `google/nano-banana-pro/text-to-image-ultra` | When every pixel matters |
| Professional design / branding | `recraft-ai/recraft-v4-pro/text-to-image` | Premium, design-oriented |
| Instant draft (sub-second) | `wavespeed-ai/z-image/turbo` | Rapid iteration, preview-quality |
| Photorealistic people | `bytedance/seedream-v4.5` | Strong at human faces/bodies |
| Personalized photos | `wavespeed-ai/phota/text-to-image` | "Photos of me" style |
| Accurate in-image text (posters, packaging, UI) | `openai/gpt-image-2/text-to-image` | Strong typography and prompt fidelity |

### Creating SVG / vector (logos, icons, illustrations)

| Priority | Model |
|----------|-------|
| Professional branding | `recraft-ai/recraft-v4-pro/text-to-vector` |
| General SVG assets | `recraft-ai/recraft-v4/text-to-vector` |

### Creating video

| Scenario | Model |
|----------|-------|
| Video from text (default) | `alibaba/wan-2.7/text-to-video` |
| Animate a still image (default) | `alibaba/wan-2.7/image-to-video` |
| Fast image animation | `bytedance/seedance-2.0-fast/image-to-video` |
| Character/scene consistency | `alibaba/wan-2.7/reference-to-video` |
| Edit existing video | `alibaba/wan-2.7/video-edit` |
| Extend a clip | `alibaba/wan-2.7/video-extend` |

### Editing an existing image

| Edit type | Model | Why |
|-----------|-------|-----|
| General edit (default) | `google/nano-banana-2/edit` | 4K, fast, subject-consistent |
| Cheapest edit | `google/nano-banana-2/edit-fast` | $0.045/img |
| Best quality edit | `google/nano-banana-pro/edit` | Region-aware, identity-preserving |
| Multi-person scene | `wavespeed-ai/qwen-image/edit-2511` | Identity/pose consistency |
| Edit with reference images | `wavespeed-ai/phota/edit` | Up to 10 reference images |
| Multi-image natural-language edit | `openai/gpt-image-2/edit` | OpenAI model, no manual masking, strong prompt alignment |

### Specialized single-purpose tools

These match specific verbs — when the user says one of these things, use the corresponding model directly:

| User says... | Model |
|-------------|-------|
| "relight" / "change lighting" / "darker" / "brighter" | `bria/fibo/relight` |
| "restore" / "fix old photo" / "remove scratches" | `bria/fibo/restore` |
| "colorize" / "add color to B&W" | `bria/fibo/colorize` |
| "change season" / "make it winter/summer" | `bria/fibo/reseason` |
| "blend" / "merge" / "apply texture" | `bria/fibo/image-blend` |
| "face swap" / "put my face on" | `wavespeed-ai/infinite-you` |
| "segment" / "cut out" / "mask" | `wavespeed-ai/sam3-image` |

## Disambiguating

When the user's request doesn't clearly map to one model, ask one question about their goal — not about model names:

- "Are you going for speed or maximum quality?"
- "Is this a quick draft or a final production asset?"
- "Do you need vector/SVG output or raster?"
- "Are you editing an existing image or creating from scratch?"
