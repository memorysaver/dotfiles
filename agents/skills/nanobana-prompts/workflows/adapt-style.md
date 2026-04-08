# Adapt Style

Transform a prompt from one visual style to another while preserving the subject and composition.

## Steps

### 1. Identify source and target

Determine:
- **Source prompt**: The existing prompt text.
- **Source style**: What style is it currently in? (Detect from keywords, or ask.)
- **Target style**: What style should it become?

### 2. Load style reference

Load [references/styles.md](../references/styles.md) to get the complete keyword set for the target style.

If the target style involves technical specs (photography, cinematic, 3D render), also load [references/technical-specs.md](../references/technical-specs.md).

### 3. Transform

**Remove source style markers:**
- Strip style-specific keywords from the source (e.g., remove "oil painting texture", "visible brushstrokes" if converting from oil painting)
- Remove incompatible technical specs (e.g., remove "f/1.4 bokeh" if converting from photography to pixel art)
- Remove source renderer references unless the target also uses them

**Add target style markers:**
- Check the target style's "Avoid combining with" list to catch conflicts with remaining source elements
- Add the target style's core keywords from the styles reference
- Add appropriate technical specs for the target style
- Adjust lighting descriptors to match the target style's conventions
- Update mood/atmosphere language if needed

**Preserve core content:**
- Keep subject description, composition, and scene elements intact
- Maintain the same emotional intent/mood (unless the style change inherently shifts it)
- Preserve color palette preferences unless they conflict with the target style

### 4. Present adapted prompt

Show the adapted prompt. Below it, note key changes: what was removed, what was added, and why.

If the style shift is dramatic (e.g., photorealistic → pixel art), warn that some subject details may not translate well and suggest simplifications.

### 5. Offer options

Ask: **"Want to adjust the adaptation, try a different style, or generate with wavespeed-cli?"**

- **Adjust**: Refine the adapted prompt.
- **Different style**: Go back to step 1 with a new target.
- **Generate**: Hand off to wavespeed-cli skill.
