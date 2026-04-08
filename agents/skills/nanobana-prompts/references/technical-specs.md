# Technical Specifications Reference

Camera, lighting, composition, rendering, and resolution keywords for prompt polish.

## Camera Settings

### Focal Length

| Value | Effect | Best For |
|-------|--------|----------|
| 14–24mm | Ultra wide, dramatic distortion | Architecture, landscapes, interiors |
| 24–35mm | Wide angle, environmental context | Street photography, environmental portraits |
| 50mm | Natural perspective, "normal" view | General purpose, editorial |
| 85mm | Moderate compression, flattering | Portraits, headshots |
| 100–135mm | Strong compression, isolation | Beauty, fashion, detail shots |
| 200mm+ | Extreme compression, background pull | Wildlife, sports, compression effect |

**Prompt format:** "shot on 85mm lens" or "85mm focal length"

### Aperture (Depth of Field)

| Value | Effect |
|-------|--------|
| f/1.2–f/1.8 | Extremely shallow DoF, dreamy bokeh, subject isolation |
| f/2.0–f/2.8 | Shallow DoF, pleasant bokeh, sharp subject |
| f/4.0–f/5.6 | Moderate DoF, partial background detail |
| f/8.0–f/11 | Deep DoF, most of scene in focus |
| f/16–f/22 | Maximum DoF, everything sharp, landscape standard |

**Prompt format:** "f/1.4 aperture, shallow depth of field" or "bokeh background, f/2.0"

### Camera Models (for realism cues)

- Sony A7III, Sony A7RV — natural color science
- Canon EOS R5 — warm skin tones
- Nikon Z9 — sharp detail
- Hasselblad X2D — medium format look, incredible detail
- Fujifilm X-T5 — film simulation look
- Leica M11 — classic rendering, character

**Prompt format:** "shot on Sony A7III" or "Hasselblad medium format"

## Lighting

### Direction

| Direction | Effect |
|-----------|--------|
| Front lighting | Even, flat, minimal shadows — clean product shots |
| Side lighting | Dramatic, sculptural, texture-revealing |
| Back lighting / rim light | Silhouette, halo effect, separation from background |
| Top lighting | Dramatic shadows, overhead sun look |
| Under lighting | Eerie, horror, campfire effect |
| Rembrandt lighting | Triangle of light on cheek, classic portrait |
| Butterfly lighting | Shadow under nose, glamour portrait |
| Loop lighting | Small shadow beside nose, natural portrait |

### Quality

| Quality | Keywords |
|---------|----------|
| Soft / diffused | soft light, diffused, overcast, softbox, cloudy |
| Hard / directional | harsh light, direct sun, spotlight, strong shadows |
| Volumetric | volumetric lighting, god rays, light shafts, atmospheric |
| Ambient | ambient light, available light, natural illumination |

### Color Temperature

| Kelvin | Description | Keywords |
|--------|-------------|----------|
| 2000–3000K | Warm, candlelight, golden | warm light, golden tones, candlelit |
| 3500–4500K | Neutral warm, indoor | tungsten, indoor lighting |
| 5000–5500K | Daylight, neutral | daylight, natural light, neutral |
| 6000–7000K | Cool daylight, overcast | cool light, overcast, cloudy |
| 8000K+ | Blue, twilight | blue hour, cold light, moonlight |

**Prompt format:** "warm golden lighting at 3500K" or "cool blue hour light"

### Named Lighting Setups

- **Golden hour** — warm, long shadows, flattering (best 30 min before sunset)
- **Blue hour** — cool, moody, deep blue sky (just after sunset)
- **Magic hour** — either golden or blue hour, ethereal
- **High key** — bright, minimal shadows, airy
- **Low key** — dark, dramatic shadows, moody
- **Neon** — artificial, colorful, urban night
- **Studio** — controlled, even, professional

## Composition

### Aspect Ratios

| Ratio | Use Case |
|-------|----------|
| 1:1 | Instagram square, profile picture, icon |
| 4:5 | Instagram portrait, social media vertical |
| 3:4 | Standard portrait, print |
| 9:16 | Stories, TikTok, Reels, mobile wallpaper |
| 16:9 | YouTube thumbnail, desktop wallpaper, cinematic |
| 21:9 | Ultra-wide cinematic, banner |
| 2:3 | Classic print, poster |

### Framing

| Framing | Description |
|---------|-------------|
| Extreme close-up | Face only, eyes, detail macro |
| Close-up | Head and shoulders |
| Medium shot | Waist up |
| Full shot | Entire body/subject |
| Wide shot | Subject in environment |
| Extreme wide | Establishing shot, tiny subject in vast space |
| Bird's eye / overhead | Looking straight down |
| Worm's eye / low angle | Looking up, subject appears powerful |
| Dutch angle | Tilted frame, unease or dynamism |
| Over-the-shoulder | From behind one subject looking at another |

### Depth of Field

- **Shallow:** blurred background, subject isolation, bokeh
- **Deep:** everything in focus, landscapes, architecture
- **Tilt-shift:** selective focus mimicking miniature effect

## Rendering & Materials (for 3D / CGI)

### Rendering Engines

- **Cinema 4D** — clean, polished, product visualization
- **Blender Cycles** — realistic, versatile
- **Octane Render** — fast, GPU-based, photorealistic
- **V-Ray** — architectural, accurate lighting
- **Unreal Engine 5** — real-time, game quality, Lumen/Nanite
- **KeyShot** — product design, reflective surfaces

### Material Keywords

- PBR materials (Physically Based Rendering)
- Subsurface scattering (skin, wax, marble)
- Ray-traced reflections
- Caustics (light through glass/water)
- Global illumination
- Ambient occlusion
- Metallic, roughness, specular

## Resolution Keywords

| Keyword | Use |
|---------|-----|
| 2K, 1080p | Standard quality |
| 4K, UHD | High quality, detailed |
| 8K | Maximum detail, large prints |
| ultra-high definition | Generic quality boost |
| highly detailed | Encourages fine detail |
| sharp focus | Prevents blur |
| professional quality | General quality cue |

## Color Palette Specification

Naming your palette creates cohesion. Place after lighting/mood or as a labeled section.

**Approaches:**
- **Named colors:** "Color palette: deep burgundy, matte black, antique gold, cream"
- **Dual-tone:** "Teal-cyan and warm amber dual-tone palette"
- **Temperature:** "Warm earth tones" or "Cool blue-violet palette"
- **Reference:** "Wes Anderson color palette" or "Film noir tonal range"

**Prompt format:** "Color palette: [color 1], [color 2], [color 3], [color 4]"

## Pose & Action

Specifying pose dramatically affects character output. Be directional about weight, gesture, and gaze.

**Standing:**
- "Standing with weight on back foot, relaxed posture"
- "Confident power stance, hands on hips"
- "Leaning against a wall, one foot up, arms crossed"

**Seated:**
- "Seated on ornate chair, leaning forward with elbows on knees"
- "Cross-legged on floor, looking up"

**Action:**
- "Hand touching sunglasses, opposite hand holding handbag"
- "Mid-stride walking pose, coat flowing behind"
- "Reaching toward camera, intense expression"

**Gaze:**
- "Looking directly at camera" (engages viewer)
- "Looking off-frame to the right" (contemplative)
- "Eyes downcast" (introspective, melancholy)
