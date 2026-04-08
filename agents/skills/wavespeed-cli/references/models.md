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

| Model ID | Input | Speed | Best For |
|----------|-------|-------|----------|
| `wavespeed-ai/wan-2.1/text-to-video` | Text only | Standard | Creating video from a text description |
| `wavespeed-ai/wan-2.1/image-to-video` | Image + text | Standard | Animating a still image with guided motion |
| `bytedance/seedance-2.0-fast/image-to-video` | Image + text | Fast | Quick image animation |
| `wavespeed-ai/framepack` | Text | Standard | Autoregressive video, longer sequences |

**Choosing a video model:**
- Animating a still image? Use `wan-2.1/image-to-video` (quality) or `seedance-2.0-fast` (speed).
- Creating video from scratch? Use `wan-2.1/text-to-video`.
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
