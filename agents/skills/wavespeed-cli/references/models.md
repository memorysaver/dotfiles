# WaveSpeed Model Catalog

## Image Generation

| Model ID | Speed | Best For |
|----------|-------|----------|
| `wavespeed-ai/flux-dev` | Fast | General purpose — good default for most image tasks |
| `wavespeed-ai/z-image/turbo` | Very fast | Quick drafts and previews, sub-second latency |
| `black-forest-labs/flux-dev` | Standard | High quality photorealistic images |
| `bytedance/seedream-v4.5` | Standard | High-fidelity photorealistic (ByteDance Seedream) |

**Choosing an image model:**
- Need speed? Use `z-image/turbo` for instant previews, then switch to `flux-dev` for the final version.
- Need photorealism? Use `seedream-v4.5` or `black-forest-labs/flux-dev`.
- General use? `wavespeed-ai/flux-dev` is the best default.

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

| Model ID | Speed | Best For |
|----------|-------|----------|
| `wavespeed-ai/flux-kontext-pro` | Fast | Instruction-based edits: background changes, style transfers, content additions/removals |

This is currently the only editing model. It handles a wide range of edit types — background swaps, object addition/removal, style changes, color adjustments — all via natural language instructions.

## Notes

- Model availability may change. Run `wavespeed models` for the current list.
- The `--model` flag on all commands accepts any model ID from this catalog.
- Last updated: 2026-04-08
