---
name: wavespeed-cli
description: "AI image generation, video generation, and image editing powered by WaveSpeed AI CLI. Use when the user wants to generate images, create videos from text or images, edit/modify images with AI, create visual assets (hero images, thumbnails, placeholders, social media graphics), animate still images into video, batch-generate multiple assets, or iterate on designs. Also triggers for: 'make me an image', 'generate a thumbnail', 'create a placeholder', 'animate this', 'edit this photo', 'change the background', 'generate assets for my project', 'I need visuals', or any request involving AI-powered image/video creation or editing — even if the user doesn't mention WaveSpeed by name."
version: 0.1.0
---

# WaveSpeed CLI

Generate images, videos, and edit images using WaveSpeed AI models — all from the command line.

## References

Load these files when needed — do not load all of them upfront:

- [references/cli.md](references/cli.md) — full CLI command reference. Load before running any `wavespeed` command or looking up flags and syntax.
- [references/installation.md](references/installation.md) — installation and API key setup. Load if `wavespeed` is not installed or `WAVESPEED_API_KEY` is not set.
- [references/models.md](references/models.md) — model catalog with IDs, types, speed tiers, and strengths. Load when selecting which model to use for a task.

## Environment Check

Before running any workflow, verify the CLI is available and authenticated:

```bash
wavespeed --help
echo $WAVESPEED_API_KEY
```

If `wavespeed` is not installed or the API key is missing, load [references/installation.md](references/installation.md) and stop until setup is complete.

## CLI Reference

Before running any `wavespeed` command, load [references/cli.md](references/cli.md) as the source of truth for exact flags, subcommands, and examples. Do not guess command syntax from memory.

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
- Any single image or video generation request

---

**`workflows/iterate-design.md`**
- "Refine this image" / "Try a different style"
- "Change the background / colors / style of this image"
- "Edit this photo to..."
- "I don't like this, try again with..."
- "Can you make it more [adjective]?"
- "Iterate on this design"
- Any request to modify, improve, or vary a previously generated or existing image

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
