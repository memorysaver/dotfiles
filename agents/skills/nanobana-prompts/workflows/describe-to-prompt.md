# Describe to Prompt

Convert a visual description, concept, or reference image analysis into a structured Nano Banana Pro prompt.

## Steps

### 1. Receive the description

Accept the user's input. This could be:
- A natural language description ("I'm imagining a cozy coffee shop with rain on the windows...")
- A description of an existing image they want to recreate
- A mood board concept ("something that feels like Blade Runner meets Studio Ghibli")
- A list of elements they want combined

### 2. Extract elements

Parse the description into prompt-structure layers:
- **Subject**: What is the main focus?
- **Details**: Appearance, features, textures mentioned
- **Setting**: Environment, location, time of day
- **Mood**: Emotional tone, atmosphere
- **Style hints**: Any style references (film names, artist names, genre cues)
- **Technical hints**: Any specs mentioned (aspect ratio, resolution, camera angle)

List what you extracted and what was missing or ambiguous. Ask one clarifying question if a critical element (subject or style) is unclear.

### 3. Load references

Load [references/prompt-structure.md](../references/prompt-structure.md) to structure the output.

Determine the best style from the user's hints and load [references/styles.md](../references/styles.md) for the right keywords.

If technical specs are relevant, load [references/technical-specs.md](../references/technical-specs.md).

If the user wants to see examples in their category, load [references/example-prompts.md](../references/example-prompts.md).

### 4. Build the prompt

Transform extracted elements into a properly structured prompt following Subject → Outward. Fill gaps with sensible defaults:
- If no lighting specified, choose lighting that matches the mood
- If no style specified, infer from the description's tone (moody → cinematic, whimsical → illustration)
- If no technical specs, add appropriate defaults for the use case

### 5. Present and compare

Show the structured prompt. Below it, note:
- What you inferred (elements not explicitly stated by the user)
- Alternative interpretations if the description was ambiguous
- Suggested variations (different style or mood that could also work)

### 6. Offer next steps

Ask: **"Want to adjust anything, see a variation, or generate with wavespeed-cli?"**
