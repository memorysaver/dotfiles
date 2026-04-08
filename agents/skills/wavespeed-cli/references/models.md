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

### Other providers

| Model ID | Speed | Best For |
|----------|-------|----------|
| `wavespeed-ai/flux-dev` | Fast | General purpose Flux model |
| `wavespeed-ai/z-image/turbo` | Very fast | Ultra-fast drafts, sub-second latency |
| `bytedance/seedream-v4.5` | Standard | High-fidelity photorealistic (ByteDance) |

**Choosing an image model:**
- Default: `google/nano-banana-2/text-to-image` — best balance of quality, speed, and cost.
- Need cheapest? Use `nano-banana-2/text-to-image-fast` at $0.045/img.
- Need maximum quality? Use `nano-banana-pro/text-to-image-ultra` for 4K.
- Need instant previews? Use `z-image/turbo` for sub-second drafts.

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
- Default: `alibaba/wan-2.7/text-to-video` — cinematic quality with built-in thinking mode for better prompt understanding.
- Animating a still image? Use `alibaba/wan-2.7/image-to-video` (quality) or `seedance-2.0-fast` (speed).
- Need character consistency? Use `alibaba/wan-2.7/reference-to-video`.
- Editing existing video? Use `alibaba/wan-2.7/video-edit`.
- Extending a clip? Use `alibaba/wan-2.7/video-extend`.
- Video generation takes 1-2 minutes regardless of model.

## Image Editing

### Google Nano Banana (recommended)

| Model ID | Speed | Best For |
|----------|-------|----------|
| `google/nano-banana-2/edit` | Fast | 4K editing, text localization, subject consistency **(default)** |
| `google/nano-banana-2/edit-fast` | Very fast | Cheapest editing ($0.045/img), 2K default |
| `google/nano-banana-pro/edit` | Standard | Region-aware 4K edits preserving identity |
| `google/nano-banana-pro/edit-multi` | Standard | Multiple edited images per run ($0.07 each) |
| `google/nano-banana/edit` | Standard | Original Nano Banana inpainting/outpainting |

### Other providers

| Model ID | Speed | Best For |
|----------|-------|----------|
| `wavespeed-ai/flux-kontext-pro` | Fast | Instruction-based edits (Flux) |

**Choosing an edit model:**
- Default: `google/nano-banana-2/edit` — 4K capable with subject consistency.
- Need cheapest? Use `nano-banana-2/edit-fast` at $0.045/img.
- Need best quality? Use `nano-banana-pro/edit` for region-aware preservation.

## Notes

- Model availability may change. Run `wavespeed models` for the current list.
- The `--model` flag on all commands accepts any model ID from this catalog.
- Last updated: 2026-04-08
