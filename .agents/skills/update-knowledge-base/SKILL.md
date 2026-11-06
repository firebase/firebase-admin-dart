---
name: update-knowledge-base
description: Updates the knowledge base in .agents/knowledge (an Open Knowledge Format bundle of this repository's decisions, divergences from the Node.js SDK and constraints). Use when a change makes a concept wrong, when a change adds or reverses a decision, or when ./scripts/knowledge.sh check fails.
---

# Update the knowledge base

`.agents/knowledge/` holds one concept per architectural decision, per divergence from the Node.js Admin SDK, and per repository constraint. Agents read a concept before editing the files it `governs`. A concept that no longer matches the code misleads every agent after you, so fix it in the same PR as the change.

## 1. Find the concepts your change touches

```bash
./scripts/knowledge.sh for <each path you changed>
```

Read each concept listed. If your change makes anything in one untrue, edit it. If your change is a new decision, divergence or constraint that an agent could get wrong, add a concept.

## 2. Edit or add a concept

Copy the shape of an existing concept of the same `type`. Keep the frontmatter's indentation: `scripts/knowledge.sh` parses it. Write `governs` and `sources` as block lists, with one `  - ` item per line and each source's keys indented four spaces. `check` rejects the inline `[...]` and `{...}` forms.

- **Frontmatter:**
  - `type`: `Decision`, `Divergence` (how Dart differs from Node), `Constraint` (a rule the repo enforces or expects) or `Playbook`.
  - `title`: up to 60 characters.
  - `description`: one sentence in the present tense.
  - `tags`.
  - `agents_md`: `always` if AGENTS.md must state the rule; `when-touching` if it matters only when editing the governed files; `reference` otherwise.
  - `governs`: path globs from the repo root. Keep them narrow, so that `for` lists only concepts that matter.
  - `sources`: the durable places that show or enforce the concept.
    - A repo file is given as a path relative to the concept file, with `symbol:` set to a literal string the file must contain.
    - A Node.js file is given as a GitHub URL on the default branch.
    - No line numbers and no commit SHAs.
- **Body sections:**
  - Decision: `# Decision`, `# Why`, `# Rules for agents`, `# Related`.
  - Divergence: `# Node.js`, `# Dart`, `# Why`, `# Rules for agents`, `# Related`.
  - Constraint: `# Constraint`, `# Why`, `# Enforced by`, `# Rules for agents`, `# Related`.
  - Playbook: `# When to use`, `# Steps`, `# Related`.
- **Rules for agents** start with **Must:**, **Must not:**, **Should:** or **Ask first:**. Make each rule only as strong as its evidence.
- **Why:** label the reason honestly.
  - "The maintainers' stated reason: …" when a maintainer said it.
  - "The likely reason (not recorded): …" when it's inferred.
  - "The reason isn't recorded. Ask a maintainer before changing it." when nobody knows.
- **Timeless:** concepts state what is true and why, not how it got there.
  - No pull request or issue numbers, commit SHAs, dates, names, release versions used as history, or "now" and "currently". `check` rejects `#123`-style references, "PR 123", pull and issue URLs, and dates.
  - For a value the code holds, such as a version constraint or a threshold, point to where it lives instead of copying it.
- **Links** between concepts use bundle-relative paths, e.g. `[Title](/firestore/standalone-package.md)`.
- **Footnotes** attribute a claim to one of the concept's sources: `[^source-id]`, where `source-id` is a `sources` entry's `id`. Define each footnote at the end of the body.

- **Provenance (optional):** when a maintainer has checked a concept against the code, they can add `verified: { by: human:<github-login>, at: <UTC time> }`. A concept nobody has verified stays unverified, and that's allowed. Don't record which tool or model wrote a concept.

A reversed decision isn't deleted. Set `status: deprecated`, say what replaced it, and link the new concept, so agents don't re-propose the old way. Remove its `governs` globs, so `for` stops listing it, and keep only the `sources` that still exist, or drop `sources` entirely.

## 3. Regenerate, log and check

```bash
./scripts/knowledge.sh index   # rewrites index.md from the frontmatter
./scripts/knowledge.sh check   # what CI runs
```

Add a line under today's date at the top of `.agents/knowledge/log.md`, for example `* **Update**: [Title](/area/concept.md) now covers …`.

If the concept is `agents_md: always`, check that AGENTS.md's rule still matches it.
