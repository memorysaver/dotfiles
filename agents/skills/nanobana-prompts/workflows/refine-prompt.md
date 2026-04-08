# Refine Prompt

Analyze and improve an existing Nano Banana Pro prompt.

## Steps

### 1. Receive the prompt

Get the user's existing prompt text. If they paste it directly, proceed. If they reference a file, read it.

### 2. Load references

Load [references/prompt-structure.md](../references/prompt-structure.md) to compare against the universal structure.

If the prompt targets a specific style, also load [references/styles.md](../references/styles.md) to check for missing or conflicting style keywords.

### 3. Diagnose issues

Analyze across these dimensions:

**Structure:**
- Does it follow Subject → Outward ordering?
- Are layers logically grouped or jumbled?
- Is there a clear subject anchor?

**Specificity:**
- Are descriptions vague ("nice lighting") or specific ("soft golden hour sunlight from the left at 4500K")?
- Are colors named precisely ("deep burgundy") or generically ("red")?
- Are materials/textures specified where relevant?

**Completeness — missing layers:**
- Missing lighting? (very common — causes flat, default-lit results)
- Missing mood/atmosphere? (causes generic feel)
- Missing technical specs? (causes inconsistent framing/resolution)
- Missing negative constraints? (causes watermarks, blur, unwanted elements)

**Conflicts:**
- Contradictory style cues ("photorealistic watercolor")?
- Incompatible technical specs?
- Too many competing focal points?

**Length:**
- Too short for the scene complexity?
- Unnecessarily verbose (redundant descriptors)?

### 4. Present diagnosis

Show a brief assessment:

**Strengths:** What works well.
**Issues:** Numbered list of specific problems.
**Missing:** Layers or details that would improve results.

### 5. Rewrite

Present the original and improved version side by side (original in a collapsed section or brief summary, rewrite in a code block). Load [references/technical-specs.md](../references/technical-specs.md) as needed for technical polish.

Summarize what changed below the rewritten prompt.

### 6. Offer next steps

Ask: **"Want to refine further, keep the original, or generate with wavespeed-cli?"**

- **Refine further**: Loop back with new feedback.
- **Keep original**: Respect their choice.
- **Generate**: Hand off to wavespeed-cli skill.
