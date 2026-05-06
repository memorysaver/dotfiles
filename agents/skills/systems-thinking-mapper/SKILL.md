---
name: systems-thinking-mapper
description: Helps analyze systemic problems, teach systems-thinking concepts, and create explainable diagrams such as causal loop diagrams, stock-flow sketches, behavior-over-time graphs, leverage maps, model portfolios, and intervention hypotheses. Use when the user wants to understand a complex recurring problem, learn how to read systems diagrams, apply many-model thinking, compare multiple models, mentions systems thinking, causal loops, feedback loops, Sherwood, Seeing the Forest for the Trees, Scott E. Page, The Model Thinker, stock and flow, leverage points, root causes, unintended consequences, or asks to make a diagram of a business, product, organizational, social, or operational system.
---

# Systems Thinking Mapper

Use this skill to help the user see the structure behind a complex problem and turn that structure into clear diagrams. This is a systems-thinking workflow inspired by practical management systems thinking, including Dennis Sherwood's *Seeing the Forest for the Trees*, but it must not claim to reproduce or contain the full book.

## Core posture

- Treat the user's first description as a partial view of a system, not as the system itself.
- Prefer diagrams that expose causality, feedback, delays, accumulations, constraints, and trade-offs.
- Separate observed facts, user assumptions, and agent inferences.
- Ask for missing context only when it changes the structure of the model; otherwise state assumptions and proceed.
- Use the diagram to improve understanding before recommending interventions.
- When the user asks for a root cause, reframe the request as a search for recurring system structure: feedback loops, delays, accumulations, decision rules, incentives, and side effects. Avoid naming one final cause unless the evidence clearly supports it.
- When the user is new to systems thinking, teach just enough notation and reading strategy to make the current diagram understandable. Do not turn the response into a textbook.
- When using Scott E. Page-style many-model thinking, treat systems thinking as one useful model family inside a broader model portfolio. Use additional models to cross-check, reveal blind spots, and generate alternative explanations; do not collapse every problem into feedback loops.

## Workflow

1. Frame the system:
   - Name the problem behavior, not only the bad event.
   - Define system boundary, time horizon, stakeholders, and key outcomes.
   - Identify symptoms, recurring patterns, and what "better" would look like.
   - Establish the reference behavior: which variable changes over time, across what time horizon, and what curve shape the model must explain.

2. Sketch behavior over time:
   - Describe the observed pattern before drawing causal structure: growth, decline, plateau, oscillation, overshoot, drift, or repeated crisis.
   - If data is unavailable, state the hypothesized behavior-over-time pattern and mark it as an assumption.
   - Use this behavior as the test for whether the eventual diagram is useful.

3. Extract variables:
   - Convert nouns into measurable variables where possible.
   - Prefer variable names that can go up or down, such as `customer wait time`, `team capacity`, `defect backlog`, or `trust`.
   - Avoid vague labels like `process`, `quality`, or `culture` unless clarified.

4. Map causal links:
   - Mark same-direction links with `+`: if A rises, B tends to rise above what it would have been.
   - Mark opposite-direction links with `-`: if A rises, B tends to fall below what it would have been.
   - Mark important time lags as delays.
   - Keep each link explainable in one sentence.

5. Identify feedback:
   - Reinforcing loops amplify change. Label them `R1`, `R2`, etc.
   - Balancing loops resist change or seek a target. Label them `B1`, `B2`, etc.
   - Classify loops by tracing the full cycle: an even number of negative links is reinforcing; an odd number of negative links is balancing.
   - Give each loop a plain-language name.
   - Explain the loop's story in 2-4 sentences.

6. Add stocks and flows when useful:
   - Use stocks for things that accumulate: backlog, cash, inventory, trust, fatigue, knowledge, technical debt.
   - Use flows for rates that increase or decrease stocks: hiring rate, resolution rate, defect creation rate.
   - Stocks change only through flows. Do not draw a causal link that directly changes a stock unless the link affects an inflow or outflow.
   - Use stock-flow sketches when accumulation, delays, or capacity constraints matter more than simple correlation.

7. Test the model:
   - Check whether it explains the observed behavior over time.
   - Look for missing delays, hidden constraints, circular reasoning, and exogenous "magic" causes.
   - Identify where local fixes may shift burden, create side effects, or worsen the system later.

8. Find leverage:
   - List low, medium, and high-leverage intervention points.
   - For each intervention, state the expected loop effect, likely delay, leading indicators, and possible unintended consequences.
   - Prefer experiments that can test the model rather than one-shot "solutions."

9. Add a many-model check when useful:
   - Select 2-5 additional model lenses that fit the problem.
   - For each lens, state what it explains, what it hides, and what evidence would support or weaken it.
   - Compare conclusions across models: where they agree, where they conflict, and what action remains robust.
   - Prefer a small high-quality model portfolio over a long catalog of loosely relevant models.

## Teaching mode

Use teaching mode when the user asks how to read a diagram, says they are new to the method, asks for an explanation of a generated diagram, or when the diagram is complex enough that a reader may need orientation.

Teach in this order:

1. Start with the reference behavior:
   - Explain what changing pattern the diagram is trying to explain.
   - Name the time horizon and main outcome variable.

2. Explain the notation in context:
   - `+` means two variables move in the same direction, all else equal.
   - `-` means two variables move in opposite directions, all else equal.
   - A delay means the effect appears later, which can hide consequences.
   - `R` loops amplify change; `B` loops resist change or seek a target.

3. Walk one loop at a time:
   - Pick the most important loop first.
   - Read it aloud as a causal story: "as A rises, B rises, which then..."
   - State whether the loop explains growth, decline, correction, oscillation, plateau, or recurring crisis.

4. Separate diagnosis from intervention:
   - First explain why the system behaves this way.
   - Then identify leverage points and likely side effects.
   - Warn when an intuitive fix may create a delayed downside.

5. Give the user a reading checklist:
   - What variable is changing over time?
   - Which loop is currently dominant?
   - Where are the delays?
   - What stock is accumulating or draining?
   - Which intervention changes the structure rather than only suppressing a symptom?

Keep explanations concrete and tied to the user's actual diagram. Prefer a small worked example over abstract definitions.

## Diagram output

Default to Mermaid diagrams when the user wants a visual artifact. Use `flowchart` for causal loop diagrams and stock-flow sketches unless another format is clearly better.

For each diagram, include:

- A short title.
- A legend for `+`, `-`, and delay markers.
- Named reinforcing and balancing loops.
- A concise explanation of what the diagram says.
- A short "how to read this" walkthrough when the user is learning the method or the diagram has more than one loop.
- A list of assumptions and open questions.

For deeper notation guidance, diagram templates, and review checklists, load `references/system-tools.md`.
When the user wants to learn the method step by step, asks for a beginner tutorial, or needs a structured explanation before using the diagrams, load `references/tutorial.md`.
When the user asks for many-model thinking, model portfolios, The Model Thinker, Scott E. Page, or cross-checking a system diagram with other models, load `references/model-thinking.md`.
When the user asks which model to use or mentions the 32 models from The Model Thinker, load `references/model-thinker-32-models.md`.

## Quality bar

- The diagram should make the system easier to reason about, not merely prettier.
- Do not overfit: 6-12 variables is usually enough for a first causal loop diagram.
- Use multiple smaller diagrams when one large diagram becomes hard to read.
- Avoid claiming causality is proven unless evidence is provided.
- If the user asks for advice, connect each recommendation to a specific loop or stock-flow structure.
