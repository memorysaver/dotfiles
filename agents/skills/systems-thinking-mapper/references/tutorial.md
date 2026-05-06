# Systems Thinking Mapper Tutorial

Use this tutorial when the user wants a simple, structured way to learn how to read and use systems-thinking diagrams. Keep the teaching grounded in the user's actual problem whenever possible.

## Contents

- What this tool is for
- Start with behavior over time
- Read variables as things that can rise or fall
- Understand `+` and `-` links
- Notice delays
- Read loops as stories
- Reinforcing loops amplify change
- Balancing loops resist change
- Stocks and flows explain accumulation
- Look for the dominant loop
- Use the diagram to find leverage
- A simple reading script
- Mini example

## 1. What this tool is for

Systems thinking helps explain recurring patterns, not just isolated events.

Instead of asking only:

- What happened?
- Who caused it?
- What should we fix?

Ask:

- What pattern keeps repeating?
- What structure keeps producing that pattern?
- Which feedback loops, delays, and accumulations make the problem persist?
- Where could a small change alter the structure?

The goal is not to draw a perfect map. The goal is to make the system easier to think about.

## 2. Start with behavior over time

Before reading arrows, identify the pattern the diagram is trying to explain.

Ask:

- What variable are we watching?
- Is it rising, falling, oscillating, plateauing, or repeatedly spiking?
- Over what time horizon?
- What would a healthier pattern look like?

Example:

```text
Customer wait time is not just high today. It rises every time demand grows, briefly improves after hiring, then rises again a few months later.
```

This behavior-over-time pattern is the "thing to explain." A good diagram should help explain why the pattern happens.

## 3. Read variables as things that can rise or fall

Most boxes in a causal loop diagram are variables. Read each one as something that can increase or decrease.

Good variable names:

- customer wait time
- team capacity
- defect backlog
- trust
- pressure to ship
- technical debt

Weaker labels:

- quality
- process
- culture
- management

Those can be useful, but they usually need clarification. For example, "quality" might mean defect rate, customer-perceived quality, test coverage, or reliability.

## 4. Understand `+` and `-` links

A `+` link means two variables move in the same direction, compared with what otherwise would have happened.

```text
More demand -> more workload
Less demand -> less workload
```

A `-` link means two variables move in opposite directions.

```text
More team capacity -> less wait time
Less team capacity -> more wait time
```

Important: `+` does not mean "good" and `-` does not mean "bad." They only describe direction.

## 5. Notice delays

A delay means the effect arrives later.

Delays matter because they make systems confusing. People may take an action, see no immediate result, then overcorrect. Or they may enjoy a short-term improvement before the delayed side effect arrives.

Common delays:

- hiring takes time to become real capacity
- training takes time to improve skill
- trust takes time to rebuild
- technical debt takes time to damage delivery speed
- brand damage takes time to show up in revenue

When reading a diagram, delays are often where the surprise lives.

## 6. Read loops as stories

A feedback loop is a circular chain of causes.

Read it out loud from one variable until you return to the same variable:

```text
As workload rises, stress rises.
As stress rises, mistakes rise.
As mistakes rise, rework rises.
As rework rises, workload rises further.
```

That is a loop. It explains why a problem can feed itself.

## 7. Reinforcing loops amplify change

A reinforcing loop is labeled `R`.

It can create growth or collapse. It is not automatically good or bad.

Example:

```text
More users -> more word of mouth -> more users
```

Another example:

```text
More workload -> more mistakes -> more rework -> more workload
```

To classify it mechanically, trace the loop:

- zero or an even number of `-` links means reinforcing
- an odd number of `-` links means balancing

## 8. Balancing loops resist change

A balancing loop is labeled `B`.

It pushes the system toward a target, limit, or correction.

Example:

```text
More wait time -> more hiring pressure -> more capacity -> less wait time
```

Balancing loops often explain why growth slows, why problems temporarily improve, or why a system resists change.

## 9. Stocks and flows explain accumulation

Some variables accumulate over time. These are stocks.

Examples:

- backlog
- cash
- inventory
- trust
- fatigue
- technical debt
- organizational knowledge

Stocks change through flows:

- backlog increases through new incoming work
- backlog decreases through completed work
- trust increases through kept promises
- trust decreases through broken promises

Do not treat a stock as something that changes instantly. If a diagram includes a stock, ask what inflow and outflow change it.

## 10. Look for the dominant loop

Many systems have several loops. Not all loops matter equally at the same time.

Ask:

- Which loop is strongest right now?
- Which loop explains the current behavior-over-time pattern?
- Which loop might become dominant later?
- Is a short-term balancing fix feeding a delayed reinforcing problem?

This helps avoid treating the diagram as a static picture. A system can shift over time.

## 11. Use the diagram to find leverage

After understanding the structure, look for interventions.

Weak interventions usually change numbers inside the current structure:

- add more effort
- push harder
- set a higher target
- ask people to be more careful

Stronger interventions often change:

- information flows
- decision rules
- incentives
- capacity constraints
- delays
- goals
- mental models

For each intervention, ask:

- Which loop does this affect?
- Will the effect be immediate or delayed?
- What leading indicator should change first?
- What side effect might appear later?
- Does this change the structure or only suppress the symptom?

## 12. A simple reading script

When looking at any systems diagram, use this sequence:

1. Name the behavior-over-time pattern.
2. Identify the main outcome variable.
3. Read the legend: `+`, `-`, delays, `R`, and `B`.
4. Follow the dominant loop out loud.
5. Check whether any stock is accumulating or draining.
6. Look for delays that could hide consequences.
7. Ask what intervention changes the loop structure.
8. List assumptions and missing evidence.

## 13. Mini example

Problem:

```text
The team keeps missing deadlines even after working overtime.
```

Reference behavior:

```text
Deadline pressure rises near each release. Overtime temporarily increases output, but after several cycles missed deadlines become more frequent.
```

Possible loop:

```text
More deadline pressure -> more overtime -> more fatigue -> more mistakes -> more rework -> more deadline pressure
```

How to read it:

- `deadline pressure` is the problem pressure we are trying to explain.
- `overtime` looks like a fix because it can increase short-term output.
- `fatigue` and `mistakes` are delayed side effects.
- `rework` brings the pressure back again.
- The loop suggests that overtime may be part of the structure producing future deadline pressure.

Possible leverage:

- reduce work in progress
- improve scope control
- reserve capacity for quality work
- make fatigue visible as a planning constraint
- change release commitments before the pressure spike

The point is not "never use overtime." The point is to see when overtime becomes a reinforcing structure that recreates the problem.
