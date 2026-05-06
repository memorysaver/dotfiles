# Presentation and Media Handoff

Use this reference when the user wants to turn systems-thinking work into a presentable artifact: a Remotion animation, a Guizang-style editorial web deck, generated conceptual images, or a combined explainer package.

This file is a bridge. It does not replace the dedicated media skills:

- Use `remotion-best-practices` when writing or editing Remotion code.
- Use `guizang-ppt-skill` when creating an editorial horizontal web PPT.
- Use `imagegen` when generating or editing raster images such as conceptual photos, editorial infographics, relationship visuals, UI mockups, or deck/video assets.

## Contents

- Media selection
- Required alignment questions
- Reasoning-to-media workflow
- Standard handoff brief
- Remotion animation planning
- Remotion layout lessons
- Guizang deck planning
- Generated image planning
- Visual explanation patterns
- Validation checklist

## Media selection

Choose Remotion when:

- The explanation depends on time, sequence, buildup, or loop dominance changing over time.
- You need to animate causality: arrows appearing, stocks filling, delays revealing, loops strengthening, or leverage points interrupting a pattern.
- The user wants a video, motion explainer, social clip, narration, or reusable animated composition.

Choose a Guizang-style presentation when:

- The user needs to present live, guide a room through a story, or leave behind a browsable deck.
- The output should feel editorial, reflective, and structured as slides.
- The explanation benefits from act dividers, big claims, diagrams, data poster pages, quotes, and system relationship images.

Choose generated images when:

- A concept needs a memorable visual anchor.
- A diagram or slide needs a magazine-style relationship image, process visual, comparison image, or conceptual illustration.
- The user lacks images and the artifact would be too abstract without them.

Use a combination when:

- A deck needs embedded generated visuals.
- A Remotion video needs generated concept frames or diagram backgrounds.
- A presentation and video should share one narrative brief and asset set.

## Required alignment questions

Ask only the questions needed to avoid building the wrong artifact:

- Audience: Who needs to understand this?
- Context: live talk, async explainer, social clip, workshop, executive briefing, or classroom?
- Duration: 30-90 second video, 3-5 minute explainer, 10-20 minute talk, or longer?
- Language and tone: Chinese, English, bilingual; analytical, editorial, executive, educational?
- Output: Remotion video, Guizang web deck, generated images, or all of them?
- Inputs: existing notes, diagrams, data, screenshots, brand constraints, or image references?

If the user is still exploring the system, do not jump to media production. Finish the thinking model first.

## Reasoning-to-media workflow

1. Freeze the reasoning snapshot:
   - Reference behavior.
   - Dominant loops.
   - Important delays.
   - Stocks and flows.
   - Model portfolio insights.
   - Leverage points.
   - Assumptions and open questions.

2. Extract the audience takeaway:
   - What should the viewer understand differently after watching or seeing this?
   - What misconception should the artifact correct?
   - What action or question should remain?

3. Build the narrative arc:
   - Hook: the surprising recurring behavior.
   - Structure: the loop or model that explains it.
   - Delay: why the intuitive fix misleads.
   - Reframe: what the better mental model is.
   - Leverage: where action changes the system.
   - Close: what to test or do next.

4. Select the medium:
   - Remotion for motion-first causal explanation.
   - Guizang deck for live presentation and chaptered argument.
   - Generated images for concept anchors and visual metaphors.

5. Produce a handoff brief before implementation.

## Standard handoff brief

Use this format before creating a deck or video:

```text
Artifact goal:
[What the artifact helps the audience understand.]

Audience:
[Who it is for and what they already know.]

Core thesis:
[One sentence.]

Reference behavior:
[The behavior-over-time pattern.]

Key structure:
[Dominant loops, stocks, delays, or model portfolio insight.]

Narrative arc:
1. Hook:
2. Structure:
3. Surprise/delay:
4. Reframe:
5. Leverage:
6. Close:

Medium plan:
[Remotion / Guizang deck / generated images / combination.]

Assets needed:
[Diagrams, data, screenshots, generated images, narration, fonts, logos.]

Validation:
[What must be true for the artifact to be considered clear.]
```

## Remotion animation planning

When planning Remotion output, create a scene list rather than a slide list.

Use this format:

```text
Composition:
- Format: 16:9, 1:1, 9:16, or custom.
- Duration:
- FPS:
- Visual style:
- Narration/captions:

Scenes:
1. [Scene name]
   Purpose:
   On-screen elements:
   Animation:
   System concept:
   Voiceover/caption:
   Assets:
```

System-thinking animation patterns:

- Behavior curve draw-on: animate the reference behavior line before showing causes.
- Causal reveal: reveal variables first, then arrows, then polarity labels.
- Loop trace: move a highlight around a feedback loop to teach how to read it.
- Delay reveal: show a delayed arrow after the short-term fix appears successful.
- Stock fill/drain: animate backlog, trust, fatigue, cash, or debt as an accumulating container.
- Dominance shift: fade one loop down and another loop up to show why behavior changes over time.
- Leverage interrupt: pause the loop, introduce intervention, then show how the next cycle changes.
- Model portfolio cards: introduce 2-5 model lenses as separate frames, then converge them into robust actions.

Remotion implementation notes:

- Load `remotion-best-practices/SKILL.md` before writing Remotion code.
- If starting from an empty folder, prefer the Remotion skill's scaffold command: `npx create-video@latest --yes --blank --no-tailwind <project-name>`.
- For animation details, load its `rules/animations.md`, `rules/sequencing.md`, `rules/charts.md`, `rules/images.md`, `rules/text-animations.md`, `rules/measuring-text.md`, `rules/fonts.md`, and `rules/transitions.md` as needed.
- Drive all animation from `useCurrentFrame()` and `useVideoConfig()`.
- Use `<Sequence>` or `<Series>` for timing.
- Use SVG or React elements for system diagrams; use Remotion `<Img>` and `staticFile()` for generated images.
- Avoid CSS transitions and CSS animations; they will not render reliably in Remotion.
- For reusable explainers, consider a Zod schema so title, thesis, labels, loop names, and colors can be edited in Remotion Studio.
- For text-heavy or multilingual explainers, use the Remotion text measurement guidance to prevent title and label overflow.
- Load fonts explicitly when using non-system fonts; do not assume the render environment matches the local browser.
- Render one or more still frames with `npx remotion still` before full rendering to catch layout, color, and timing issues.
- Start Remotion Studio with `npx remotion studio` for interactive review when the user wants to inspect or iterate.

## Remotion layout lessons

Use these rules when turning a system map into an explanatory animation.

First choose the reading structure, then animate inside it:

- For educational explainers, prefer a clear two-column layout when the viewer must read text and watch a diagram at the same time.
- Put narrative bullets, the scene thesis, and "how to read this" guidance in the left column.
- Put curves, causal loops, stock-flow sketches, and moving highlights in the right column.
- Make the columns explicit with fixed or constrained widths, a generous column gap, and a visible or implied divider.
- Give the animation column its own bounded drawing area with padding and `overflow: hidden` so wide SVGs cannot drift into the text column.
- Avoid positioning diagram elements against the whole composition when they belong inside a column. Position them relative to the animation area instead.

For system-thinking videos, treat layout as part of the pedagogy:

- Use the left column to name the current mental move: observe the pattern, reveal the short-term fix, expose the delay, trace the loop, then locate leverage.
- Use the right column to animate only the structure being discussed in that moment.
- Keep one dominant visual object per scene. If a behavior curve and a causal loop both matter, sequence them or fade one down before emphasizing the other.
- When labels are multilingual or text-heavy, reserve more room than the first draft seems to need.

Use still-frame QA before every full render:

- Render stills at the moments with the densest text, widest diagram, and most active highlight.
- Check whether bullets, diagram labels, arrows, captions, and scene titles overlap.
- If a still looks crowded, fix the layout before rendering the full video.
- After layout changes, rerender the final video; do not assume the previous MP4 reflects the latest stills.

Known good pattern from the overtime-trap example:

```text
Composition frame
- Header: scene title / section marker
- Main grid:
  - Left column: thesis, 3-4 bullets, optional note card
  - Right column: bounded animation surface for curve, loop, stock-flow, or leverage intervention
- Footer: concise reading cue or current loop label
```

## Guizang deck planning

When planning a Guizang-style web deck, create a slide arc.

Use this format:

```text
Deck:
- Title:
- Audience:
- Duration:
- Theme recommendation:
- Image strategy:

Slides:
1. [Slide title]
   Layout:
   Theme:
   Purpose:
   Main claim:
   Visual:
   Speaker note:
   Source insight:
```

System-thinking deck patterns:

- Hero cover: name the recurring pattern.
- Data poster: show the behavior-over-time fact or key symptom.
- Left text/right image: make the human or organizational consequence concrete.
- Pipeline: show the current decision rule or repeated process.
- Causal loop slide: show the system structure.
- Big quote: state the mental model shift.
- Before/after: compare symptom-fix thinking with structural thinking.
- Leverage slide: list interventions by loop or stock.
- Closing question: name the next experiment.

Guizang implementation notes:

- Load `guizang-ppt-skill/SKILL.md` before creating the deck.
- Follow its required clarification, theme rhythm, layout, image, and checklist workflow.
- Prefer editorial restraint: slides should not become dense markdown pasted into HTML.
- Use generated images as supporting visual assets, not as standalone slides with fake chrome.

## Generated image planning

Generated images should clarify a concept, not replace the model. When implementation is needed, load the `imagegen` skill and follow its workflow.

Use this format:

```text
Image purpose:
[Concept anchor / process / comparison / system relationship / data poster / UI scene.]

Target artifact:
[Remotion scene or deck slide.]

Placement:
[16:9 hero, 16:10 side image, 16:9 fit-contain infographic, etc.]

Prompt:
[Short prompt.]

Must avoid:
[Fake logos, dense text, unreadable labels, decorative frames, wrong language, etc.]
```

Image prompt patterns:

- Concept anchor: a documentary or editorial image that gives the system a real-world setting.
- System relationship image: nodes, arrows, roles, and short labels.
- Process image: steps and transition points.
- Comparison image: old model vs new model.
- Data poster image: one key number or finding.

Notes:

- Load `$imagegen` before generating or editing bitmap assets.
- Use `imagegen` built-in tool mode by default for normal image generation and editing.
- Use `imagegen` CLI fallback only when the user explicitly asks for CLI/API/model control, or when the imagegen skill's transparent-output fallback rules require confirmation.
- Prefer short, controlled prompts with ratio and placement constraints.
- If the image contains text, match the user's language.
- For deck assets, follow Guizang's `references/image-prompts.md` ratios and restrictions.
- For Remotion assets, place generated files in `public/` and reference them with `staticFile()`.
- For project-bound images, save final selected assets into the workspace; do not leave project-referenced assets only under the imagegen default output location.

## Visual explanation patterns

Map system-thinking concepts to media moves:

| Concept | Remotion move | Deck move | Image move |
| --- | --- | --- | --- |
| Reference behavior | Draw a line over time | Data poster / chart slide | Simple curve infographic |
| Reinforcing loop | Highlight loop repeatedly | Causal loop slide | System relationship image |
| Balancing loop | Show correction toward target | Before/after slide | Feedback regulator visual |
| Delay | Reveal consequence later | Split slide: now vs later | Timeline/process visual |
| Stock | Fill/drain container | Stock-flow diagram slide | Accumulation visual |
| Leverage point | Interrupt loop path | Intervention slide | Annotated relationship image |
| Model portfolio | Card sequence | Lens comparison slides | Matrix or lens board |

## Validation checklist

Before building:

- The reasoning snapshot is explicit.
- The artifact has one core thesis.
- Each scene, slide, or image maps to a specific insight.
- The chosen medium matches the explanation need.

Before delivery:

- A beginner can say what problem behavior is being explained.
- The artifact distinguishes short-term fix from delayed side effect.
- Loops, stocks, and model lenses are introduced in a readable order.
- Visuals do not add ungrounded claims.
- Generated images are labeled as conceptual when they are conceptual.
- Remotion output follows Remotion timing and asset rules.
- Guizang deck output follows theme rhythm, layout, and checklist rules.
