# WaveSpeed Model Catalog

## Image Generation

### Google Nano Banana (recommended)

| Model ID | Speed | Best For |
|----------|-------|----------|
| `google/nano-banana-2/text-to-image` | Fast | Pro quality at flash speed, 512px–4K **(default)** |
| `google/nano-banana-2/text-to-image-fast` | Very fast | Lowest cost ($0.045/img), 2K default |
| `google/nano-banana-pro/text-to-image` | Standard | Sharper, higher-fidelity with improved prompt control |
| `google/nano-banana-pro/text-to-image-ultra` | Standard | Ultra-detailed 4K generation |
| `google/nano-banana-pro/text-to-image-multi` | Standard | Multiple high-quality images per run ($0.07 each) |
| `google/nano-banana/text-to-image` | Standard | Original Nano Banana text-to-image |

### Recraft (professional design)

| Model ID | Speed | Best For |
|----------|-------|----------|
| `recraft-ai/recraft-v4-pro/text-to-image` | Standard | Premium quality for professional design |
| `recraft-ai/recraft-v4/text-to-image` | Standard | High quality with color palette control |

### Other providers

| Model ID | Speed | Best For |
|----------|-------|----------|
| `wavespeed-ai/phota/text-to-image` | Standard | Personalized photographs, 1K/4K |
| `wavespeed-ai/qwen-image/text-to-image` | Standard | 20B MMDiT next-gen model |
| `sourceful/riverflow-2.0-pro/text-to-image` | Standard | Agentic model, high-precision generation |
| `wavespeed-ai/z-image/turbo` | Very fast | Ultra-fast drafts, sub-second latency |
| `wavespeed-ai/flux-dev` | Fast | General purpose Flux model |
| `bytedance/seedream-v4.5` | Standard | High-fidelity photorealistic (ByteDance) |
| `openai/gpt-image-2/text-to-image` | Fast | Strong prompt fidelity, accurate in-image text rendering ($0.10/img) |

**Choosing an image model:**
- Default: `google/nano-banana-2/text-to-image` — best balance of quality, speed, and cost.
- Professional design: `recraft-ai/recraft-v4-pro/text-to-image` — premium quality.
- Need cheapest? Use `nano-banana-2/text-to-image-fast` at $0.045/img.
- Need maximum quality? Use `nano-banana-pro/text-to-image-ultra` for 4K.
- Need instant previews? Use `z-image/turbo` for sub-second drafts.
- Need accurate in-image text (posters, packaging, UI mockups)? Use `openai/gpt-image-2/text-to-image`. Sizes: `1024x1024`, `1024x1536`, `1536x1024`.

## SVG / Vector Generation

| Model ID | Speed | Best For |
|----------|-------|----------|
| `recraft-ai/recraft-v4-pro/text-to-vector` | Standard | Professional SVG for logos, icons, branding |
| `recraft-ai/recraft-v4/text-to-vector` | Standard | Native SVG graphics for design assets |

Use these when the user needs scalable vector output — logos, icons, illustrations, or any asset that must scale without pixelation.

## Video Generation

### WAN 2.7 — Alibaba (recommended, with thinking mode)

| Model ID | Input | Resolution | Best For |
|----------|-------|------------|----------|
| `alibaba/wan-2.7/text-to-video` | Text | 720p/1080p | Cinematic text-to-video with thinking mode **(default)** |
| `alibaba/wan-2.7/image-to-video` | Image + text | 720p/1080p | Animate images with audio and frame control **(default with --image)** |
| `alibaba/wan-2.7/reference-to-video` | Reference + text | 720p/1080p | Character/scene videos preserving identity |
| `alibaba/wan-2.7/video-edit` | Video + text | 720p/1080p | Prompt-driven video editing with multi-image reference |
| `alibaba/wan-2.7/video-extend` | Video | 720p/1080p | Extend clips with last-frame control |

### Other providers

| Model ID | Input | Speed | Best For |
|----------|-------|-------|----------|
| `bytedance/seedance-2.0-fast/image-to-video` | Image + text | Fast | Quick image animation |
| `wavespeed-ai/framepack` | Text | Standard | Autoregressive video, longer sequences |

**Choosing a video model:**
- Default: `alibaba/wan-2.7/text-to-video` — cinematic quality with thinking mode.
- Animating a still image? `alibaba/wan-2.7/image-to-video` (quality) or `seedance-2.0-fast` (speed).
- Character consistency? `alibaba/wan-2.7/reference-to-video`.
- Editing existing video? `alibaba/wan-2.7/video-edit`.
- Extending a clip? `alibaba/wan-2.7/video-extend`.

## Image Editing

### Google Nano Banana (recommended)

| Model ID | Speed | Best For |
|----------|-------|----------|
| `google/nano-banana-2/edit` | Fast | 4K editing, text localization, subject consistency **(default)** |
| `google/nano-banana-2/edit-fast` | Very fast | Cheapest editing ($0.045/img), 2K default |
| `google/nano-banana-pro/edit` | Standard | Region-aware 4K edits preserving identity |

### Other providers

| Model ID | Speed | Best For |
|----------|-------|----------|
| `wavespeed-ai/phota/edit` | Standard | Multi-reference editing (up to 10 reference images) |
| `wavespeed-ai/qwen-image/edit-2511` | Standard | Multi-person identity/pose consistency |
| `sourceful/riverflow-2.0-pro/edit` | Standard | Agentic precise editing |
| `wavespeed-ai/flux-kontext-pro` | Fast | Instruction-based edits (Flux) |
| `openai/gpt-image-2/edit` | Fast | Multi-image reference editing, no manual masking ($0.10/edit). Pass multiple `-i` flags. Sizes: `auto`, `1024x1024`, `1024x1536`, `1536x1024`. |

## Specialized Tools

| Model ID | Speed | Best For |
|----------|-------|----------|
| `bria/fibo/relight` | Fast | Change lighting direction and atmosphere |
| `bria/fibo/restore` | Fast | Remove noise, scratches, blur from old photos |
| `bria/fibo/colorize` | Fast | Add color to B&W photos |
| `bria/fibo/reseason` | Fast | Change season or weather atmosphere |
| `bria/fibo/image-blend` | Fast | Merge objects, apply textures within images |
| `wavespeed-ai/infinite-you` | Standard | Zero-shot face swapping with identity preservation |
| `wavespeed-ai/sam3-image` | Fast | Image segmentation via text, points, or boxes |

These are single-purpose tools for specific transformations. Use them when the user needs a targeted operation like relighting, restoration, colorization, or face swapping.

## Notes

- Model availability may change. Run `wavespeed models` for the current list.
- The `--model` flag on all commands accepts any model ID from this catalog.
- Run `wavespeed models --type <type>` to filter by: `image`, `video`, `edit`, `svg`, `tool`.
- Last updated: 2026-04-22
