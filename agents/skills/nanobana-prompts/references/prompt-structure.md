# Prompt Structure Guide

## The Universal Pattern: Subject → Outward

Build from the center (subject) outward to the environment and technical framing. This pattern consistently produces better results across 12,400+ tested prompts.

### Layer 1: Subject / Character

The anchor of the image. State what the viewer should focus on first.

- Person: age, gender, ethnicity, build, defining features
- Object: type, size, material, condition
- Scene: primary element that defines the composition

**Examples:**
- "A young woman in her mid-20s with sharp features"
- "A vintage leather-bound journal"
- "A towering Gothic cathedral"

### Layer 2: Appearance Details

Physical details that make the subject specific and vivid.

- Hair: color, length, texture, style
- Face: expression, skin tone, notable features
- For objects: surface finish, wear, patina

**Examples:**
- "dark brown wavy hair cascading past shoulders, confident expression, tanned skin with light freckles"
- "cracked spine, yellowed pages, faded gold embossing"

### Layer 3: Clothing / Attire

Layer clothing descriptions from inner to outer garments.

- Base layer → mid layer → outer layer
- Describe fit, fabric, color, condition

**Examples:**
- "White turtleneck under a cropped tweed jacket, black pleated mini skirt, knee-high leather boots"
- "Worn mechanic's jumpsuit with oil stains, sleeves rolled to the elbows"

### Layer 4: Accessories

Props and details that add character and story.

- Jewelry, bags, glasses, weapons, tools
- Held items, worn items, nearby items

**Examples:**
- "Cat-eye sunglasses pushed up on her head, leather handbag with gold logo clasp"
- "Steampunk goggles around the neck, pocket watch chain visible"

### Layer 5: Environment / Location

Where the scene takes place. Moves attention from subject to surroundings.

- Immediate setting → broader environment
- Time of day, season, weather
- Background elements

**Examples:**
- "Standing in front of a luxury storefront with gold lettering on a rain-slicked Parisian street"
- "Inside a dimly lit Japanese izakaya, wooden counter, sake bottles on shelves behind"

### Layer 6: Lighting & Mood

How the scene is lit and what emotional atmosphere it creates.

- Light source direction (front, back, side, overhead, below)
- Light quality (soft, harsh, diffused, directional, volumetric)
- Color temperature (warm/golden, cool/blue, neutral)
- Atmosphere (foggy, hazy, crisp, dusty, smoky)

**Examples:**
- "Soft golden hour sunlight from the left, warm tones, gentle lens flare"
- "Dramatic chiaroscuro lighting, deep shadows, single overhead spotlight"
- "Neon-lit, cyan and magenta reflections on wet surfaces, moody and electric"

### Layer 7: Technical Specifications

Camera and rendering details that control the final look.

- Camera: focal length, aperture, ISO, shutter speed
- Composition: framing, angle, depth of field
- Resolution and aspect ratio

**Examples:**
- "Shot on 85mm f/1.4, shallow depth of field, subject sharp against blurred background"
- "Wide-angle 24mm lens, low angle looking up, deep depth of field"
- "4:5 aspect ratio, 4K resolution"

### Layer 8: Style / Rendering Engine

The overall visual style or tool used to create the look.

- Artistic style (photorealistic, anime, watercolor, etc.)
- Rendering engine (Cinema 4D, Blender, Unreal Engine 5)
- Quality descriptors (ultra-high definition, professional grade)

**Examples:**
- "Photorealistic, shot on Sony A7III, editorial photography"
- "Studio Ghibli-inspired anime style, hand-drawn feel"
- "Cinema 4D render, PBR materials, ray-traced reflections"

### Layer 9: Negative Constraints

What to explicitly exclude. Prevents common issues. Organize by category for thoroughness:

- **Character count:** "No extra characters", "single subject only"
- **Quality defects:** "No blur, no low quality, no artifacts"
- **Unwanted elements:** "No watermarks, no text overlay, no logos"
- **Style mismatches:** "No fantasy elements", "no cartoon style"
- **Emotional excess:** "No exaggerated emotions, no dramatic action"

**Examples:**
- "No watermarks, no text overlay, no blur"
- "Avoid extra fingers, no distorted faces"
- "No busy background, no clutter"

## Supplementary Patterns

These patterns don't fit the 9-layer structure but appear frequently in high-quality prompts:

### Spatial Layout

Specify where elements sit in the frame. Critical for thumbnails, quote cards, and multi-element compositions.

**Examples:**
- "Portrait on the left third, text area on the right two-thirds"
- "Large empty center area reserved for text overlay (leave 60% of center clear)"
- "Subject positioned in the left third of the frame"
- "Three interconnected hexagonal platforms arranged left, center (elevated), right"

### Text & Typography

For prompts that include text elements (quote cards, infographics, posters). Specify font style, size, color, and placement.

**Examples:**
- "Light-gold serif font for the quote, smaller sans-serif for the attribution"
- "Large bold white text area reserved on the right"
- "Stylized 3D English title suspended above the scene"
- "No text" — when you want the image clean for adding text in post

### Color Palette

Explicitly naming your color palette constrains the output and creates cohesion.

**Examples:**
- "Color palette: Black, white, gold, cream, beige"
- "Teal-cyan and warm amber dual-tone palette"
- "Muted earth tones with deep blacks and warm golds"
- "Pastel greens, warm wood tones, soft pinks, cream and white"

### Reference Image Usage

When working from an existing image, anchor the prompt with a reference directive.

**Examples:**
- "Use [uploaded image] as the single source of truth for the subject's identity"
- "Use [uploaded image] as Woman Reference"
- "Maintain the exact face, hair, and body proportions from the reference"

### Multi-Panel Layouts

For grid compositions, comic panels, or comparison images.

**Examples:**
- "A 4-panel grid layout, each panel showing a different season"
- "3×4 compartmentalized box structure, each compartment displaying different items"
- "Split-screen comparison: left side shows before, right side shows after"

### Dynamic Variables / Template Prompts

Use bracket notation to create reusable prompt templates. Useful for batch generation or iterating on a concept.

**Examples:**
- "A detailed isometric 3D scene showcasing the [movie series name] franchise"
- "A wide quote card featuring [famous person] with the quote: [quote text]"
- "{argument name="subject" default="a cat"} sitting in {argument name="setting" default="a garden"}"

### Quality & Prestige Keywords

Boosting keywords that encourage higher fidelity output. Place at the end of style/rendering layer.

**Use sparingly — 1–2 per prompt:**
- "masterpiece", "award-winning", "professional grade"
- "ultra-high definition", "stunningly realistic"
- "highly detailed", "sharp focus", "4K/8K"

**Avoid stacking** — "masterpiece ultra-high definition 8K award-winning professional" reads as spam and can degrade output.

### Emotion + Visual Manifestation

For characters, pair the emotional state with its physical expression. More effective than emotion alone.

**Examples:**
- "sad expression with visible tears, tired eyes" (not just "looks sad")
- "laughing genuinely, eyes crinkling, head tilted back" (not just "happy")
- "cold, determined expression, jaw clenched, eyes narrowed" (not just "angry")

## Required Layers by Use Case

Not every prompt needs all 9 layers. Use this table:

| Use Case | Required Layers | Optional Layers |
|----------|----------------|-----------------|
| Portrait / Avatar | 1, 2, 6, 8 | 3, 4, 5, 7, 9 |
| Product Shot | 1, 5, 6, 7 | 8, 9 |
| Landscape | 1 (as scene), 5, 6, 8 | 7, 9 |
| Character Design | 1, 2, 3, 4, 8 | 5, 6, 7, 9 |
| Infographic | 1, 5, 8, 9 | 6, 7 |
| YouTube Thumbnail | 1, 2, 5, 6, 8, 9 | 3, 4, 7 |
| 3D Isometric | 1, 5, 8 (renderer), 6 | 7, 9 |
| Fashion Photography | 1, 2, 3, 4, 5, 6, 7 | 8, 9 |
| Quote Card / Social | 1 (as layout), 6, 8, 9 | 5, 7 |
| Game Asset | 1, 2, 3, 4, 8 | 5, 6, 9 |

## Prompt Length Guide

| Complexity | Word Count | When to Use |
|------------|------------|-------------|
| Simple | 50–100 | Icons, avatars, simple objects, minimal compositions |
| Medium | 100–200 | Character scenes, product shots, single-focus compositions |
| Complex | 200–400 | Multi-element scenes, infographics, detailed environments, storyboards |

## Formatting Tips

- Use line breaks between logical sections for readability
- Label sections with keywords (Attire:, Lighting:, Location:) — the model responds well to labeled structure
- Put the most important descriptors early in each section
- Use commas to separate attributes within a section, periods between sections
