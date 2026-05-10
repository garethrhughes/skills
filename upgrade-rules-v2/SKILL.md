---
name: upgrade-rules-v2
description: Upgrades a project from rules v1 (monolithic RULES.md) to v2 (language-agnostic core + per-stack overlay). Detects the active stack, injects the `## Active Skillset` line into CLAUDE.md, updates rule links, flags duplicated v1 rule text, and re-runs the relevant installer scripts. Run once per project after pulling the v2 skills via /update-skills.
compatibility: opencode
---

# Upgrade Rules v2

You upgrade an existing project from **rules v1** to **rules v2** in place. This is
a one-shot, idempotent migration that edits the project's `CLAUDE.md` surgically and
re-runs the relevant installer scripts.

## What v1 vs v2 means

- **v1** — `RULES.md` v1.0 was a single opinionated file pinned to TypeScript +
  NestJS + Next.js + TypeORM + pino + Jest/Vitest. Sections included
  `## TypeScript Conventions`, `## Frontend Rules (Next.js)`, `## Backend Rules
  (NestJS)`. Projects' `CLAUDE.md` linked to that one file and had no skillset
  selector.
- **v2** — `RULES.md` v2.0 is **language-agnostic core** plus per-stack overlays in
  `rules/<profile>.md` and bootstrap defaults in `profiles/<profile>/`. Each
  project's `CLAUDE.md` declares an `## Active Skillset:` line right under the
  title, and rule references point to both files.

A v1 project's `CLAUDE.md` will:
- Have **no** `## Active Skillset:` line.
- Reference `RULES.md` only — never `rules/<profile>.md`.
- Sometimes contain pasted-in v1 rule sections that the overlay now owns.

The canonical v2 shape lives in `CLAUDE.md.template` in the skills repo.

## Workflow

### Step 1 — Preflight: are v2 sources installed?

Resolve the installed skills directory (same lookup pattern as `update-skills`):

- `.opencode/skills/` (project-local OpenCode install)
- `~/.config/opencode/skills/` (global OpenCode install)
- `.claude/skills/` or wherever the user's installer copied them

Use whichever exists. Then verify all three of:

1. `RULES.md` exists and its `**Version:**` line begins with `2.` (read the file
   directly with `Read`).
2. `rules/` directory contains at least `typescript.md` and `dotnet.md`.
3. `profiles/` directory exists.

If any check fails, stop and tell the user verbatim:

> "I can't find v2 rule sources in your installed skills directory. Please run
> `/update-skills` first to pull `RULES.md` v2, the `rules/` overlays, and the
> `profiles/` directory, then re-run me."

Do **not** try to fetch them yourself.

### Step 2 — Classify the project's current state

Read `CLAUDE.md` at the repo root.

| State | Signal | Action |
|---|---|---|
| **Already v2** | `## Active Skillset:` line present | Tell the user "Already on v2, nothing to do" and exit. |
| **v1** | No `Active Skillset` line, or links only to `RULES.md` with no `rules/<profile>.md` reference | Continue to Step 3. |
| **No CLAUDE.md** | File missing | Tell the user to run `project-onboard` instead — there's nothing to upgrade. Exit. |

### Step 3 — Detect the active stack

Use the same auto-detection signals as `project-onboard` Phase 1.5:

- **`dotnet`** — any of: `*.sln` at root, `**/*.csproj`, `global.json`,
  `Directory.Build.props`, `Directory.Packages.props`, `appsettings.json`
  adjacent to a `*.csproj`.
- **`typescript`** — any of: root `package.json` containing `next`, `@nestjs/*`,
  `typeorm`, `vite`, `react`, `vue`, `svelte`; root `tsconfig.json`.

Decision rules:

- One stack matches → pick it.
- Both match (e.g. ASP.NET Core API + Next.js SPA) → pick by **backend host
  language** and note the secondary stack as a finding for the report.
- Neither matches, or detection is genuinely ambiguous → ask the user via
  `AskUserQuestion` with options `typescript` and `dotnet`.

Record the chosen `<profile>` and the file paths that justified the choice.

### Step 4 — Build the patch plan

Compute the minimal set of edits to make `CLAUDE.md` v2-compliant. Do **not**
rewrite the file wholesale — only touch these regions:

1. **Insert the Active Skillset line.** Immediately after the `# CLAUDE.md` (or
   `# CLAUDE.md — <project>`) header, insert:

   ```markdown

   ## Active Skillset: <profile>

   This project follows the language-agnostic core rules in
   [`RULES.md`](...) plus the **`<profile>`** stack overlay in
   [`rules/<profile>.md`](...). Skills (`developer`, `reviewer`, `architect`,
   `infosec`) read both when applying conventions to this project.
   ```

   Match the link form already used elsewhere in the file (e.g. relative
   `.opencode/skills/...` vs the GitHub URL form from `CLAUDE.md.template` /
   `project-onboard`). Pick whichever style the existing file uses; default to
   the relative `.opencode/skills/...` form if there's no precedent.

2. **Upgrade existing `RULES.md` references.** Anywhere `CLAUDE.md` links or
   refers to `RULES.md` for engineering rules without also pointing at the
   overlay, replace the surrounding intro with the two-layer block from
   `CLAUDE.md.template` (Engineering Rules section):

   > 1. **Core (language-agnostic):** `RULES.md` …
   > 2. **Stack overlay:** `rules/<profile>.md` …

   Preserve any "Project-specific overrides" and "Project-specific additions"
   subtables verbatim — never touch user content.

3. **Flag (do not delete) duplicated v1 rule sections.** If the project's
   `CLAUDE.md` body contains any of these v1 section titles pasted inline, list
   them in the report so the user can decide whether to delete them or move
   them into `Project-specific additions`:

   - `## TypeScript Conventions`
   - `## Frontend Rules (Next.js)` or `## Frontend Rules`
   - `## Backend Rules (NestJS)` or `## Backend Rules`
   - Any `## Logging & Observability` block that names `pino` specifically
   - Any `## Testing` block that names `Jest` / `Vitest` / `xUnit` specifically

   Do **not** edit these sections automatically — they may contain
   project-specific tweaks the user wants to keep.

### Step 5 — Show the diff and confirm

Render the proposed edits as a unified diff in your response. Ask the user:

> "Apply this patch to `CLAUDE.md`? (yes/no, or tell me what to change)"

Wait for confirmation before writing.

### Step 6 — Apply the patch

Use `Edit` (not `Write`) against `CLAUDE.md`, one targeted edit per region from
Step 4. If any edit's `old_string` doesn't match (the file has drifted from what
you read), stop and re-read — never force-overwrite.

### Step 7 — Re-run installers

The new `RULES.md`, `rules/`, and `profiles/` need to be propagated into the
agent directories the project actually uses. Detect which installers apply:

- If `.claude/agents/` exists → run `scripts/install-claude-agents.sh` from the
  skills dir.
- If `.github/agents/` exists → run `scripts/install-copilot-agents.sh`.
- If only `.opencode/skills/` exists → no installer needed; OpenCode reads the
  skills dir directly.

Run them via `Bash`. Show the user the script output verbatim if it errors.

### Step 8 — Report

Print a structured summary:

```
### Rules v1 → v2 upgrade complete

**Active skillset:** `<profile>`  (evidence: <file paths>)
**Secondary stack noted:** <profile or "none">

**CLAUDE.md edits applied:**
- Inserted `## Active Skillset: <profile>` line
- Upgraded engineering-rules intro to reference `rules/<profile>.md`
- (other edits applied)

**Manual review needed — duplicated v1 rule sections found in CLAUDE.md:**
- `## TypeScript Conventions` at line N — overlay now owns this; delete or move
  to *Project-specific additions* if you have local tweaks.
- (… or "none")

**Installers re-run:**
- `scripts/install-claude-agents.sh` (or "none — OpenCode-native install")

**Next steps:**
1. Review the flagged sections above.
2. Commit `CLAUDE.md` and any refreshed files in `.claude/agents/` or
   `.github/agents/`.
3. Skim the new `rules/<profile>.md` to see what the overlay enforces.
```

## Rules

- **Idempotent.** Running this skill twice on a v2 project is a no-op — Step 2
  exits early.
- **Never delete user content.** Duplicated v1 rule text gets flagged, never
  removed.
- **Never rewrite `CLAUDE.md` wholesale.** Use targeted `Edit` calls only.
- **Never fetch v2 sources yourself.** If preflight fails, defer to
  `/update-skills`.
- **Don't modify `RULES.md`, `rules/`, or `profiles/`** — those are owned by the
  skills repo and synced by `update-skills`.
- If `CLAUDE.md` is missing entirely, do not create one — tell the user to run
  `project-onboard`.
