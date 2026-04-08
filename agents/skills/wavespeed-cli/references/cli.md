# WaveSpeed CLI Reference

## Global Options

| Flag | Description |
|------|-------------|
| `--json` | Output results as JSON (machine-readable) |
| `-V, --version` | Show version number |
| `-h, --help` | Show help |

The `--json` flag works on all commands. When set, all human-friendly output is suppressed and a single JSON object is printed to stdout. Always use `--json` when you need to parse the output programmatically.

---

## `wavespeed generate image`

Generate an image from a text prompt.

```bash
wavespeed generate image -p <prompt> [options]
```

| Flag | Description | Default |
|------|-------------|---------|
| `-p, --prompt <text>` | Text prompt (required) | — |
| `-m, --model <id>` | Model ID | `google/nano-banana-2/text-to-image` |
| `-s, --size <WxH>` | Dimensions, e.g. `1024x768` | model default |
| `-o, --output <path>` | Output file path | `wavespeed-image-{timestamp}.{ext}` |
| `--seed <number>` | Random seed for reproducibility | random |

**Examples:**

```bash
# Basic image generation
wavespeed generate image -p "A futuristic city skyline at sunset"

# Fast draft with specific size
wavespeed generate image -p "Product mockup on white background" -m wavespeed-ai/z-image/turbo -s 1024x1024

# Save to specific path with JSON output
wavespeed generate image -p "Hero banner for landing page" -o public/images/hero.png --json

# Reproducible generation with seed
wavespeed generate image -p "Abstract geometric pattern" --seed 42
```

---

## `wavespeed generate video`

Generate a video from text, or animate a still image.

```bash
wavespeed generate video -p <prompt> [options]
```

| Flag | Description | Default |
|------|-------------|---------|
| `-p, --prompt <text>` | Text prompt (required) | — |
| `-i, --image <path>` | Source image for image-to-video | — |
| `-m, --model <id>` | Model ID | auto-selected based on `--image` |
| `-o, --output <path>` | Output file path | `wavespeed-video-{timestamp}.{ext}` |

When `--image` is provided, the default model switches to `alibaba/wan-2.7/image-to-video` and the image is automatically uploaded before generation. Without `--image`, the default is `alibaba/wan-2.7/text-to-video`.

Video generation typically takes 1-2 minutes.

**Examples:**

```bash
# Text-to-video
wavespeed generate video -p "A bustling Tokyo street at night with neon lights"

# Animate a still image
wavespeed generate video -p "Camera slowly zooms in, clouds drift across sky" -i hero.png

# Fast image-to-video with specific model
wavespeed generate video -p "Gentle zoom and pan" -i logo.png -m bytedance/seedance-2.0-fast/image-to-video
```

---

## `wavespeed edit`

Edit an existing image using a text instruction.

```bash
wavespeed edit -i <image> -p <prompt> [options]
```

| Flag | Description | Default |
|------|-------------|---------|
| `-i, --image <path>` | Source image to edit (required) | — |
| `-p, --prompt <text>` | Edit instruction (required) | — |
| `-m, --model <id>` | Model ID | `google/nano-banana-2/edit` |
| `-o, --output <path>` | Output file path | `wavespeed-edit-{timestamp}.{ext}` |

The source image is automatically uploaded before the edit operation.

**Examples:**

```bash
# Change background
wavespeed edit -i product.jpg -p "Change the background to pure white"

# Style transfer
wavespeed edit -i photo.png -p "Convert to watercolor painting style"

# Content modification
wavespeed edit -i scene.jpg -p "Add a red sports car in the foreground" -o scene-with-car.jpg
```

---

## `wavespeed upload`

Upload a local file and get a URL for use with other commands or APIs.

```bash
wavespeed upload <file>
```

Prints the URL to stdout (or JSON object with `--json`).

**Examples:**

```bash
# Upload and get URL
wavespeed upload my-image.png

# Upload with JSON output
wavespeed upload reference.jpg --json
```

---

## `wavespeed models`

List available models.

```bash
wavespeed models [options]
```

| Flag | Description | Default |
|------|-------------|---------|
| `-t, --type <type>` | Filter by type: `image`, `video`, `edit` | all |

**Examples:**

```bash
# List all models
wavespeed models

# List only video models
wavespeed models --type video

# List as JSON
wavespeed models --json
```

---

## `wavespeed status`

Check the status of a generation task by its request ID.

```bash
wavespeed status <requestId>
```

**Examples:**

```bash
# Check a task
wavespeed status abc123-def456

# JSON output for scripting
wavespeed status abc123-def456 --json
```

---

## JSON Output Format

When `--json` is used, all commands output a JSON object:

**Success (generate/edit):**
```json
{
  "status": "completed",
  "model": "wavespeed-ai/flux-dev",
  "url": "https://...",
  "localPath": "/absolute/path/to/file.png"
}
```

**Success (upload):**
```json
{
  "status": "uploaded",
  "url": "https://..."
}
```

**Error:**
```json
{
  "status": "error",
  "error": "Error message"
}
```

---

## Error Codes

| Error | Cause | Fix |
|-------|-------|-----|
| `WAVESPEED_API_KEY is not set` | Missing environment variable | `export WAVESPEED_API_KEY=ws-...` |
| `Invalid size` | Bad `--size` format | Use `WxH` format, e.g. `1024x768` |
| `No output URL in response` | API returned no result | Check model ID, try again |
| `Download failed: 4xx/5xx` | CDN issue | Retry, or use URL directly |
