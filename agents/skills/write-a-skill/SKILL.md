---
name: write-a-skill
description: Create portable agent skills with clear triggers, concise instructions, progressive disclosure, and optional bundled resources. Use when the user wants to create, write, build, improve, or package a new skill.
license: MIT
version: 0.1.0
homepage: https://github.com/mattpocock/skills/tree/main/skills/productivity/write-a-skill
compatibility:
  claude-code: supported
  codex: supported
  pi-agent: supported
metadata:
  upstream: mattpocock/skills/skills/productivity/write-a-skill
---

# Write A Skill

Create portable agent skills with a small `SKILL.md` plus optional relative resources.

## Process

1. Gather requirements:
   - What task or domain does the skill cover?
   - What specific use cases should trigger it?
   - Does it need executable scripts or only instructions?
   - What reference material should be included?

2. Draft the skill:
   - Create `SKILL.md` with concise instructions.
   - Add reference files when the main instructions would become long.
   - Add utility scripts for deterministic operations that would otherwise be regenerated.

3. Review with the user:
   - Confirm the draft covers the target use cases.
   - Ask what is missing or unclear.
   - Tighten sections that are too broad or too detailed.

## Skill Structure

```text
skill-name/
├── SKILL.md
├── references/
│   └── topic.md
├── scripts/
│   └── helper.sh
└── assets/
    └── example.txt
```

Only `SKILL.md` is required.

## SKILL.md Template

```md
---
name: skill-name
description: Brief description of capability. Use when [specific triggers].
license: Apache-2.0
version: 0.1.0
---

# Skill Name

## Workflow

[Minimal instructions the agent should follow.]

## References

Load `references/topic.md` only when deeper detail is needed.
```

## Description Requirements

The description is the main signal an agent sees before deciding whether to load the skill.

Make it:

- 1024 characters or less.
- Third person.
- Clear about what the skill does.
- Explicit about when to use it.

Good:

```text
Extract text and tables from PDF files, fill forms, and merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

Bad:

```text
Helps with documents.
```

## When To Add Scripts

Add scripts when an operation is deterministic, repeated, or needs exact error handling. Prefer scripts for validation, formatting, conversion, and other repeatable workflows.

## When To Split Files

Split content into references when `SKILL.md` exceeds roughly 100 lines, when content has distinct domains, or when advanced detail is rarely needed.

## Review Checklist

- Description includes concrete triggers.
- `SKILL.md` stays concise.
- Time-sensitive information is avoided or clearly sourced.
- Terminology is consistent.
- Examples are concrete.
- Relative links point to bundled files.
