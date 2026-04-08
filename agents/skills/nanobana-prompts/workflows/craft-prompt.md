# Craft Prompt

Build a complete Nano Banana Pro prompt from scratch through structured conversation.

## Steps

### 1. Gather intent

Determine these from context (fill in reasonable defaults — don't over-ask):

- **Use case**: What is this image for? (avatar, social post, thumbnail, product shot, poster, game asset, infographic, character design, etc.)
- **Subject**: What is the main focus? (person, product, landscape, architecture, animal, abstract, typography, etc.)
- **Style**: What visual style? (photography, cinematic, anime, 3D render, illustration, watercolor, pixel art, etc.)
- **Mood/tone**: What feeling? (elegant, dramatic, playful, dark, warm, professional, etc.)
- **Reference image**: Does the user have an existing image to base the prompt on? If so, include a reference directive (see "Reference Image Usage" in the prompt-structure reference).

If the user gave a clear request like "write me a prompt for a cyberpunk cityscape poster", you already have use case (poster), subject (cityscape), style (cyberpunk), and mood (implied: dark, neon, futuristic). Proceed directly.

### 2. Load references

Load [references/prompt-structure.md](../references/prompt-structure.md) to apply the universal structure.

If the user chose a specific style, also load [references/styles.md](../references/styles.md) to get the right keywords.

For prompts needing technical polish (photography, cinematic, 3D renders), also load [references/technical-specs.md](../references/technical-specs.md).

### 3. Determine prompt length

| Complexity | Length | When |
|------------|--------|------|
| Simple | 50–100 words | Icons, avatars, simple objects, minimal compositions |
| Medium | 100–200 words | Character scenes, product shots, single-focus compositions |
| Complex | 200–400 words | Multi-element scenes, infographics, detailed environments |

### 4. Build the prompt

Follow the Subject → Outward structure. For the chosen use case and style, include the relevant layers:

1. **Subject/character** — who or what is the focus
2. **Appearance** — physical details, expression, features (if applicable)
3. **Clothing/attire** — layered description (if applicable)
4. **Accessories** — props, items, details
5. **Environment** — location, setting, background
6. **Lighting & mood** — direction, quality, temperature, atmosphere
7. **Technical specs** — camera settings, resolution, aspect ratio
8. **Style/renderer** — rendering engine, artistic style
9. **Negative constraints** — what to avoid

Not every prompt needs all 9 layers. Check the use-case table in the prompt-structure reference.

Also consider the supplementary patterns from the reference:
- **Spatial layout** — for thumbnails, quote cards, multi-element scenes
- **Text & typography** — for prompts that include text elements
- **Color palette** — explicitly name colors for cohesion
- **Multi-panel layouts** — for grids, comparisons, comic strips

### 5. Format and present

Present the completed prompt in a clean, copy-ready code block:

```
[The complete prompt text, with line breaks between logical sections]
```

Below the prompt, briefly explain your choices (1–2 sentences on style keywords, technical specs, or structural decisions).

### 6. Offer refinement or generation

Ask: **"Want to adjust anything, or shall I generate this with wavespeed-cli?"**

- **Adjust**: Go back to step 4 with their feedback.
- **Generate**: Hand off to wavespeed-cli skill. Suggest Nano Banana Pro for max quality, Nano Banana 2 for speed.
- **Save**: If they want to keep the prompt, suggest saving to a file.
