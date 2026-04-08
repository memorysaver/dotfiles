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

function parseSize(size) {
  if (!size) return {};
  const [w, h] = size.toLowerCase().split("x").map(Number);
  if (!w || !h) {
    console.error(`Invalid size "${size}". Use WxH format, e.g. 1024x768`);
    process.exit(1);
  }
  return { width: w, height: h };
}

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
  // Image generation — other
  { id: "wavespeed-ai/flux-dev", type: "image", speed: "fast", description: "General purpose Flux model" },
  { id: "wavespeed-ai/z-image/turbo", type: "image", speed: "very fast", description: "Ultra-fast 6B model, sub-second" },
  { id: "bytedance/seedream-v4.5", type: "image", speed: "standard", description: "High-fidelity photorealistic (ByteDance)" },
  // Video generation
  { id: "wavespeed-ai/wan-2.1/text-to-video", type: "video", speed: "standard", description: "Text-to-video generation" },
  { id: "wavespeed-ai/wan-2.1/image-to-video", type: "video", speed: "standard", description: "Animate a still image" },
  { id: "bytedance/seedance-2.0-fast/image-to-video", type: "video", speed: "fast", description: "Fast image-to-video (ByteDance)" },
  { id: "wavespeed-ai/framepack", type: "video", speed: "standard", description: "Autoregressive video generation" },
  // Image editing — Google
  { id: "google/nano-banana-2/edit", type: "edit", speed: "fast", description: "4K-capable editing, text localization, subject consistency" },
  { id: "google/nano-banana-2/edit-fast", type: "edit", speed: "very fast", description: "Cheapest editing ($0.045/img), 2K default" },
  { id: "google/nano-banana-pro/edit", type: "edit", speed: "standard", description: "Region-aware 4K edits preserving identity" },
  // Image editing — other
  { id: "wavespeed-ai/flux-kontext-pro", type: "edit", speed: "fast", description: "Instruction-based image editing (Flux)" },
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
    const params = { prompt: opts.prompt, ...parseSize(opts.size) };
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
      model = model || "wavespeed-ai/wan-2.1/image-to-video";
      if (!jsonMode) console.log("Uploading source image...");
      const imageUrl = await wavespeed.upload(resolve(opts.image));
      params.image = imageUrl;
    } else {
      model = model || "wavespeed-ai/wan-2.1/text-to-video";
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
  .requiredOption("-i, --image <path>", "Source image to edit")
  .requiredOption("-p, --prompt <text>", "Edit instruction")
  .option("-m, --model <id>", "Model ID", "google/nano-banana-2/edit")
  .option("-o, --output <path>", "Output file path")
  .action(async (opts) => {
    requireApiKey();
    const jsonMode = program.opts().json;

    if (!jsonMode) console.log("Uploading source image...");
    const imageUrl = await wavespeed.upload(resolve(opts.image));

    if (!jsonMode) console.log(`Editing with ${opts.model}...`);

    try {
      const result = await wavespeed.run(opts.model, {
        image: imageUrl,
        prompt: opts.prompt,
      });
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
