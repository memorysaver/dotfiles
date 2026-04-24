#!/usr/bin/env node

import { program } from "commander";
import wavespeed from "wavespeed";
import { writeFile, readFile } from "node:fs/promises";
import { basename, extname, resolve } from "node:path";
import { createReadStream } from "node:fs";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function requireApiKey() {
  if (!process.env.WAVESPEED_API_KEY) {
    console.error(
      "Error: WAVESPEED_API_KEY is not set.\n" +
        "Get your key at https://wavespeed.ai/accesskey\n" +
        "Then: export WAVESPEED_API_KEY=ws-..."
    );
    process.exit(1);
  }
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
}

function shapeSize(model, size) {
  if (!size) return {};
  const isGptImage2 = model?.startsWith("openai/gpt-image-2/");
  if (isGptImage2 && size.toLowerCase() === "auto") {
    return { size: "auto" };
  }
  const [w, h] = size.toLowerCase().split(/[x*]/).map(Number);
  if (!w || !h) {
    console.error(`Invalid size "${size}". Use WxH format, e.g. 1024x768`);
    process.exit(1);
  }
  // openai/gpt-image-2/* expects `size: "W*H"` (string), not width/height numbers
  if (isGptImage2) return { size: `${w}*${h}` };
  return { width: w, height: h };
}

function collectPath(val, arr) {
  arr.push(val);
  return arr;
}

// Edit models that require `images: [url, ...]` even for a single reference.
const MULTI_IMAGE_EDIT_MODELS = new Set(["openai/gpt-image-2/edit"]);

async function downloadFile(url, outputPath) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Download failed: ${res.status} ${res.statusText}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await writeFile(outputPath, buf);
  return outputPath;
}

function guessExtension(url, fallback = "png") {
  try {
    const pathname = new URL(url).pathname;
    const ext = extname(pathname).slice(1);
    return ext || fallback;
  } catch {
    return fallback;
  }
}

function outputResult(data, jsonMode) {
  if (jsonMode) {
    console.log(JSON.stringify(data, null, 2));
  } else {
    if (data.localPath) console.log(`Saved: ${data.localPath}`);
    if (data.url) console.log(`URL:   ${data.url}`);
    if (data.model) console.log(`Model: ${data.model}`);
    if (data.status) console.log(`Status: ${data.status}`);
  }
}

// ---------------------------------------------------------------------------
// Model catalog
// ---------------------------------------------------------------------------

const MODELS = [
  // Image generation — Google
  { id: "google/nano-banana-2/text-to-image", type: "image", speed: "fast", description: "Pro quality at flash speed, 512px–4K (default)" },
  { id: "google/nano-banana-2/text-to-image-fast", type: "image", speed: "very fast", description: "Lowest cost ($0.045/img), 2K default" },
  { id: "google/nano-banana-pro/text-to-image", type: "image", speed: "standard", description: "Sharper, higher-fidelity with improved prompt control" },
  { id: "google/nano-banana-pro/text-to-image-ultra", type: "image", speed: "standard", description: "Ultra-detailed 4K generation" },
  { id: "google/nano-banana/text-to-image", type: "image", speed: "standard", description: "Original Nano Banana text-to-image" },
  // Image generation — Recraft
  { id: "recraft-ai/recraft-v4-pro/text-to-image", type: "image", speed: "standard", description: "Premium quality for professional design" },
  { id: "recraft-ai/recraft-v4/text-to-image", type: "image", speed: "standard", description: "High quality with color palette control" },
  // Image generation — other
  { id: "wavespeed-ai/phota/text-to-image", type: "image", speed: "standard", description: "Personalized photographs, 1K/4K" },
  { id: "wavespeed-ai/qwen-image/text-to-image", type: "image", speed: "standard", description: "20B MMDiT next-gen model" },
  { id: "sourceful/riverflow-2.0-pro/text-to-image", type: "image", speed: "standard", description: "Agentic model, high-precision generation" },
  { id: "wavespeed-ai/z-image/turbo", type: "image", speed: "very fast", description: "Ultra-fast 6B model, sub-second" },
  { id: "wavespeed-ai/flux-dev", type: "image", speed: "fast", description: "General purpose Flux model" },
  { id: "bytedance/seedream-v4.5", type: "image", speed: "standard", description: "High-fidelity photorealistic (ByteDance)" },
  { id: "openai/gpt-image-2/text-to-image", type: "image", speed: "fast", description: "Strong prompt fidelity, accurate in-image text ($0.10/img)" },
  // SVG / Vector generation
  { id: "recraft-ai/recraft-v4-pro/text-to-vector", type: "svg", speed: "standard", description: "Professional SVG for logos, icons, branding" },
  { id: "recraft-ai/recraft-v4/text-to-vector", type: "svg", speed: "standard", description: "Native SVG graphics for design assets" },
  // Video generation — WAN 2.7 (Alibaba, with thinking mode)
  { id: "alibaba/wan-2.7/text-to-video", type: "video", speed: "standard", description: "Cinematic 720p/1080p text-to-video with thinking mode (default)" },
  { id: "alibaba/wan-2.7/image-to-video", type: "video", speed: "standard", description: "Image-to-video 720p/1080p with audio and frame control" },
  { id: "alibaba/wan-2.7/reference-to-video", type: "video", speed: "standard", description: "Character/scene reference video with identity preservation" },
  { id: "alibaba/wan-2.7/video-extend", type: "video", speed: "standard", description: "Extend existing videos with last-frame control" },
  { id: "alibaba/wan-2.7/video-edit", type: "video", speed: "standard", description: "Prompt-driven video editing with multi-image reference" },
  // Video generation — other
  { id: "bytedance/seedance-2.0-fast/image-to-video", type: "video", speed: "fast", description: "Fast image-to-video (ByteDance)" },
  { id: "wavespeed-ai/framepack", type: "video", speed: "standard", description: "Autoregressive video generation" },
  // Image editing — Google
  { id: "google/nano-banana-2/edit", type: "edit", speed: "fast", description: "4K-capable editing, text localization, subject consistency" },
  { id: "google/nano-banana-2/edit-fast", type: "edit", speed: "very fast", description: "Cheapest editing ($0.045/img), 2K default" },
  { id: "google/nano-banana-pro/edit", type: "edit", speed: "standard", description: "Region-aware 4K edits preserving identity" },
  // Image editing — other
  { id: "wavespeed-ai/phota/edit", type: "edit", speed: "standard", description: "Multi-reference editing (up to 10 refs)" },
  { id: "wavespeed-ai/qwen-image/edit-2511", type: "edit", speed: "standard", description: "Multi-person identity/pose consistency" },
  { id: "sourceful/riverflow-2.0-pro/edit", type: "edit", speed: "standard", description: "Agentic precise editing" },
  { id: "wavespeed-ai/flux-kontext-pro", type: "edit", speed: "fast", description: "Instruction-based image editing (Flux)" },
  { id: "openai/gpt-image-2/edit", type: "edit", speed: "fast", description: "Multi-image reference editing with strong prompt alignment ($0.10/edit)" },
  // Specialized tools
  { id: "bria/fibo/relight", type: "tool", speed: "fast", description: "Modify lighting direction and atmosphere" },
  { id: "bria/fibo/restore", type: "tool", speed: "fast", description: "Remove noise, scratches, blur from old photos" },
  { id: "bria/fibo/colorize", type: "tool", speed: "fast", description: "Add color to B&W photos" },
  { id: "bria/fibo/reseason", type: "tool", speed: "fast", description: "Change season or weather atmosphere" },
  { id: "bria/fibo/image-blend", type: "tool", speed: "fast", description: "Merge objects, apply textures" },
  { id: "wavespeed-ai/infinite-you", type: "tool", speed: "standard", description: "Zero-shot face swapping with identity preservation" },
  { id: "wavespeed-ai/sam3-image", type: "tool", speed: "fast", description: "Image segmentation via text, points, or boxes" },
];

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

program
  .name("wavespeed")
  .version("0.1.0")
  .option("--json", "Output results as JSON");

// --- generate image ---
const generate = program.command("generate").description("Generate images or videos");

generate
  .command("image")
  .description("Generate an image from a text prompt")
  .requiredOption("-p, --prompt <text>", "Text prompt describing the image")
  .option("-m, --model <id>", "Model ID", "google/nano-banana-2/text-to-image")
  .option("-s, --size <WxH>", "Image dimensions, e.g. 1024x768")
  .option("-o, --output <path>", "Output file path")
  .option("--seed <number>", "Random seed for reproducibility", parseInt)
  .action(async (opts) => {
    requireApiKey();
    const jsonMode = program.opts().json;
    const params = { prompt: opts.prompt, ...shapeSize(opts.model, opts.size) };
    if (opts.seed !== undefined) params.seed = opts.seed;

    if (!jsonMode) console.log(`Generating image with ${opts.model}...`);

    try {
      const result = await wavespeed.run(opts.model, params);
      const url = result.outputs?.[0] || result.output;
      if (!url) throw new Error("No output URL in response");

      const ext = guessExtension(url, "png");
      const outPath = opts.output || `wavespeed-image-${timestamp()}.${ext}`;
      await downloadFile(url, resolve(outPath));

      outputResult({ status: "completed", model: opts.model, url, localPath: resolve(outPath) }, jsonMode);
    } catch (err) {
      if (jsonMode) {
        console.log(JSON.stringify({ status: "error", error: err.message }));
      } else {
        console.error(`Error: ${err.message}`);
      }
      process.exit(1);
    }
  });

// --- generate video ---
generate
  .command("video")
  .description("Generate a video from text or image")
  .requiredOption("-p, --prompt <text>", "Text prompt describing the video")
  .option("-i, --image <path>", "Source image for image-to-video")
  .option("-m, --model <id>", "Model ID (auto-selected based on --image)")
  .option("-o, --output <path>", "Output file path")
  .action(async (opts) => {
    requireApiKey();
    const jsonMode = program.opts().json;
    const params = { prompt: opts.prompt };

    // Auto-select model based on whether an image is provided
    let model = opts.model;
    if (opts.image) {
      model = model || "alibaba/wan-2.7/image-to-video";
      if (!jsonMode) console.log("Uploading source image...");
      const imageUrl = await wavespeed.upload(resolve(opts.image));
      params.image = imageUrl;
    } else {
      model = model || "alibaba/wan-2.7/text-to-video";
    }

    if (!jsonMode) console.log(`Generating video with ${model}... (this may take 1-2 minutes)`);

    try {
      const result = await wavespeed.run(model, params);
      const url = result.outputs?.[0] || result.output;
      if (!url) throw new Error("No output URL in response");

      const ext = guessExtension(url, "mp4");
      const outPath = opts.output || `wavespeed-video-${timestamp()}.${ext}`;
      await downloadFile(url, resolve(outPath));

      outputResult({ status: "completed", model, url, localPath: resolve(outPath) }, jsonMode);
    } catch (err) {
      if (jsonMode) {
        console.log(JSON.stringify({ status: "error", error: err.message }));
      } else {
        console.error(`Error: ${err.message}`);
      }
      process.exit(1);
    }
  });

// --- edit ---
program
  .command("edit")
  .description("Edit an image using a text instruction")
  .option("-i, --image <path>", "Source image(s) — repeat for multi-image models", collectPath, [])
  .requiredOption("-p, --prompt <text>", "Edit instruction")
  .option("-m, --model <id>", "Model ID", "google/nano-banana-2/edit")
  .option("-s, --size <WxH>", "Output size (WxH, or 'auto' for gpt-image-2)")
  .option("-o, --output <path>", "Output file path")
  .action(async (opts) => {
    requireApiKey();
    const jsonMode = program.opts().json;

    if (!opts.image.length) {
      console.error("Error: at least one -i/--image is required");
      process.exit(1);
    }

    if (!jsonMode) {
      console.log(
        opts.image.length === 1
          ? "Uploading source image..."
          : `Uploading ${opts.image.length} source images...`
      );
    }
    const imageUrls = [];
    for (const path of opts.image) {
      imageUrls.push(await wavespeed.upload(resolve(path)));
    }

    const params = { prompt: opts.prompt, ...shapeSize(opts.model, opts.size) };
    if (imageUrls.length > 1 || MULTI_IMAGE_EDIT_MODELS.has(opts.model)) {
      params.images = imageUrls;
    } else {
      params.image = imageUrls[0];
    }

    if (!jsonMode) console.log(`Editing with ${opts.model}...`);

    try {
      const result = await wavespeed.run(opts.model, params);
      const url = result.outputs?.[0] || result.output;
      if (!url) throw new Error("No output URL in response");

      const ext = guessExtension(url, "png");
      const outPath = opts.output || `wavespeed-edit-${timestamp()}.${ext}`;
      await downloadFile(url, resolve(outPath));

      outputResult({ status: "completed", model: opts.model, url, localPath: resolve(outPath) }, jsonMode);
    } catch (err) {
      if (jsonMode) {
        console.log(JSON.stringify({ status: "error", error: err.message }));
      } else {
        console.error(`Error: ${err.message}`);
      }
      process.exit(1);
    }
  });

// --- upload ---
program
  .command("upload <file>")
  .description("Upload a file and return its URL")
  .action(async (file) => {
    requireApiKey();
    const jsonMode = program.opts().json;

    try {
      const url = await wavespeed.upload(resolve(file));
      if (jsonMode) {
        console.log(JSON.stringify({ status: "uploaded", url }));
      } else {
        console.log(url);
      }
    } catch (err) {
      if (jsonMode) {
        console.log(JSON.stringify({ status: "error", error: err.message }));
      } else {
        console.error(`Error: ${err.message}`);
      }
      process.exit(1);
    }
  });

// --- models ---
program
  .command("models")
  .description("List available models")
  .option("-t, --type <type>", "Filter by type: image, video, edit")
  .action((opts) => {
    const jsonMode = program.opts().json;
    let models = MODELS;
    if (opts.type) {
      models = models.filter((m) => m.type === opts.type);
    }

    if (jsonMode) {
      console.log(JSON.stringify(models, null, 2));
    } else {
      const maxId = Math.max(...models.map((m) => m.id.length));
      const maxType = Math.max(...models.map((m) => m.type.length));
      console.log(
        `${"MODEL".padEnd(maxId)}  ${"TYPE".padEnd(maxType)}  ${"SPEED".padEnd(9)}  DESCRIPTION`
      );
      console.log("-".repeat(maxId + maxType + 40));
      for (const m of models) {
        console.log(
          `${m.id.padEnd(maxId)}  ${m.type.padEnd(maxType)}  ${m.speed.padEnd(9)}  ${m.description}`
        );
      }
    }
  });

// --- status ---
program
  .command("status <requestId>")
  .description("Check the status of a generation task")
  .action(async (requestId) => {
    requireApiKey();
    const jsonMode = program.opts().json;

    try {
      const res = await fetch(
        `https://api.wavespeed.ai/api/v3/predictions/${requestId}/result`,
        { headers: { Authorization: `Bearer ${process.env.WAVESPEED_API_KEY}` } }
      );
      const data = await res.json();
      if (jsonMode) {
        console.log(JSON.stringify(data, null, 2));
      } else {
        console.log(`Status: ${data.status || "unknown"}`);
        if (data.outputs?.[0]) console.log(`Output: ${data.outputs[0]}`);
      }
    } catch (err) {
      if (jsonMode) {
        console.log(JSON.stringify({ status: "error", error: err.message }));
      } else {
        console.error(`Error: ${err.message}`);
      }
      process.exit(1);
    }
  });

program.parse();
