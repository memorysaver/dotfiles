---
name: wavespeed-cli
description: "AI image generation, video generation, and image editing powered by WaveSpeed AI CLI. Use when the user wants to generate images, create videos from text or images, edit/modify images with AI, create visual assets (hero images, thumbnails, placeholders, social media graphics), animate still images into video, batch-generate multiple assets, iterate on designs, generate SVG/vector logos or icons, restore old photos, relight images, colorize B&W photos, swap faces, or segment images. Also triggers for: 'make me an image', 'generate a thumbnail', 'create a placeholder', 'animate this', 'edit this photo', 'change the background', 'generate assets for my project', 'I need visuals', 'make me a logo', 'restore this old photo', 'relight this', 'which model should I use', or any request involving AI-powered image/video creation or editing — even if the user doesn't mention WaveSpeed by name."
version: 0.2.0
---

# WaveSpeed CLI

Generate images, videos, SVGs, and edit images using WaveSpeed AI models — all from the command line.

## References

Load these files when needed — do not load all of them upfront:

- [references/cli.md](references/cli.md) — full CLI command reference. Load before running any `wavespeed` command or looking up flags and syntax.
- [references/installation.md](references/installation.md) — installation and API key setup. Load if `wavespeed` is not installed or `WAVESPEED_API_KEY` is not set.
- [references/models.md](references/models.md) — full model catalog with IDs, types, speed tiers, and strengths. Load when the user asks about models or when the quick guide below doesn't cover the use case.

## Environment Check

Before running any workflow, verify the CLI is available and authenticated:

```bash
wavespeed --help
echo $WAVESPEED_API_KEY
```

If `wavespeed` is not installed or the API key is missing, load [references/installation.md](references/installation.md) and stop until setup is complete.

## CLI Reference

Before running any `wavespeed` command, load [references/cli.md](references/cli.md) as the source of truth for exact flags, subcommands, and examples. Do not guess command syntax from memory.

## Model Selection Guide

This is the most important section of the skill. With 36+ models available, picking the right one matters. Use this decision tree based on what the user is trying to do:

### What does the user want to create?

**Image from text** → Ask: what's the priority?
| Priority | Model | Why |
|----------|-------|-----|
| Best default (quality + speed + cost) | `google/nano-banana-2/text-to-image` | Pro quality at flash speed, up to 4K |
| Cheapest ($0.045/img) | `google/nano-banana-2/text-to-image-fast` | Budget batch work, 2K |
| Maximum quality / 4K | `google/nano-banana-pro/text-to-image-ultra` | When every pixel matters |
| Professional design / branding | `recraft-ai/recraft-v4-pro/text-to-image` | Premium, design-oriented |
| Instant draft (sub-second) | `wavespeed-ai/z-image/turbo` | Rapid iteration, preview-quality |
| Photorealistic people | `bytedance/seedream-v4.5` | Strong at human faces/bodies |
| Personalized photos | `wavespeed-ai/phota/text-to-image` | When user wants "photos of me" style |

**SVG / Vector** (logos, icons, illustrations) →
| Priority | Model |
|----------|-------|
| Professional branding | `recraft-ai/recraft-v4-pro/text-to-vector` |
| General SVG assets | `recraft-ai/recraft-v4/text-to-vector` |

**Video from text** →
| Priority | Model |
|----------|-------|
| Best quality (default) | `alibaba/wan-2.7/text-to-video` |

**Video from image** (animate a still) →
| Priority | Model |
|----------|-------|
| Best quality (default) | `alibaba/wan-2.7/image-to-video` |
| Fastest | `bytedance/seedance-2.0-fast/image-to-video` |
| Character consistency | `alibaba/wan-2.7/reference-to-video` |

**Video editing / extending** →
| Task | Model |
|------|-------|
| Edit existing video | `alibaba/wan-2.7/video-edit` |
| Make a clip longer | `alibaba/wan-2.7/video-extend` |

**Edit an existing image** → Ask: what kind of edit?
| Edit Type | Model | Why |
|-----------|-------|-----|
| General edit (default) | `google/nano-banana-2/edit` | 4K, fast, subject-consistent |
| Cheapest edit | `google/nano-banana-2/edit-fast` | $0.045/img |
| Multi-person scenes | `wavespeed-ai/qwen-image/edit-2511` | Identity/pose consistency |
| Edit with reference images | `wavespeed-ai/phota/edit` | Up to 10 reference images |
| Best quality edit | `google/nano-banana-pro/edit` | Region-aware, identity-preserving |

**Specialized single-purpose tools** → Match the verb:
| User says... | Model |
|-------------|-------|
| "relight" / "change lighting" / "make it darker/brighter" | `bria/fibo/relight` |
| "restore" / "fix this old photo" / "remove scratches" | `bria/fibo/restore` |
| "colorize" / "add color to this B&W" | `bria/fibo/colorize` |
| "change season" / "make it winter/summer" | `bria/fibo/reseason` |
| "blend" / "merge" / "apply texture" | `bria/fibo/image-blend` |
| "face swap" / "put my face on" | `wavespeed-ai/infinite-you` |
| "segment" / "cut out" / "mask" | `wavespeed-ai/sam3-image` |

### When in doubt

If the user's request doesn't clearly map to one model, ask one question to disambiguate. Frame it around their goal, not the model names:

- "Are you going for speed or maximum quality?"
- "Is this a quick draft or a final production asset?"
- "Do you need vector/SVG output or raster?"
- "Are you editing an existing image or creating from scratch?"

For the full model catalog with detailed descriptions, load [references/models.md](references/models.md).

## Workflow Routing

---

**`workflows/generate-asset.md`**
- "Generate an image for my project"
- "Create a hero image / thumbnail / placeholder"
- "Make me a social media graphic"
- "Generate a video from this description"
- "I need a visual asset for..."
- "Create a video of..."
- "Text to image / text to video"
- "Make me a logo / icon" (SVG workflow)
- Any single image, video, or SVG generation request

---

**`workflows/iterate-design.md`**
- "Refine this image" / "Try a different style"
- "Change the background / colors / style of this image"
- "Edit this photo to..."
- "I don't like this, try again with..."
- "Can you make it more [adjective]?"
- "Iterate on this design"
- "Relight this" / "Restore this old photo" / "Colorize this"
- Any request to modify, improve, or transform an existing image

---

**`workflows/batch-generate.md`**
- "Generate images for all these pages"
- "Create assets for each section"
- "I need 5 variations of..."
- "Batch generate thumbnails for..."
- "Make multiple versions with different styles"
- Any request involving multiple image/video generations from a list of prompts

---

Once you identify the right workflow, load that file and follow its instructions exactly.

If the user's intent matches more than one workflow, ask one clarifying question before routing. If it matches none, ask what they are trying to accomplish. Do not guess.

Some requests can be handled directly with the CLI without loading a workflow. Load [references/cli.md](references/cli.md) and execute directly when the user's intent is a single, self-contained CLI operation:

- Upload a file — `wavespeed upload <file>`
- List available models — `wavespeed models`
- Check generation status — `wavespeed status <request-id>`
- A quick one-off generation where the user already specified all parameters
