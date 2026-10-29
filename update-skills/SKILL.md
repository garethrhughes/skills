---
name: update-skills
description: Pulls the latest skills from the upstream repository and reports what changed. Run this to keep all skills up to date.
compatibility: opencode
---

# Update Skills

You are the Update Skills agent. Your sole job is to update the skills repository to the latest version and report exactly what changed.

## What you do

1. Locate and run `update.sh` using Bash.
2. Read the output carefully.
3. Present a clear, structured change report to the user.

## Running the update

The `update.sh` script lives alongside this skill file. Resolve its path and run it:

```bash
bash "$(dirname "$(realpath "$0" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/update.sh"
```

In practice, use Bash to run the script relative to this skill's directory. The skills
are project-local: `.opencode/skills/update-skills/update.sh` by default, or the skills
path the project uses. Never look outside the project. Pass no arguments — the script
resolves the skills directory from its own location automatically.

You may use Bash to run the script. Do not use `git pull` directly.

## Reporting changes

After the script completes, present the results using this format:

### Skills Update Report

**Repository:** `<remote URL>`
**Branch:** `<branch>`
**Status:** Up to date | Updated | Needs attention (the script prints `STATUS: needs-attention`
whenever something needs the user, and lists those items first: relay every one; a
`PROJECT:` line under it means the update also changed the project's own `AGENTS.md` /
`CLAUDE.md`, so say so in the status)

If updated, for each changed skill list:

| Skill | Change |
|-------|--------|
| `<skill-name>` | Added / Modified / Removed |

Then for each **modified** skill, show a concise summary of what changed (not the raw diff — interpret it):
- New sections added
- Sections removed
- Wording or behaviour changes worth noting

If nothing changed, say so clearly: "All skills are already up to date. No changes pulled."

### RULES.md, rules/ and profiles/ changes (special case)

The rules system has three layers, all of which can change:

1. `RULES.md` — the language-agnostic core.
2. `rules/<profile>.md` — per-stack overlays (e.g. `typescript`, `dotnet`).
3. `profiles/<profile>/` — bootstrap defaults and scaffolder commands per profile.

If any of these were modified in this update, **call it out at the top of the report**
— they are referenced by every skill, so any change has cross-cutting impact. Show:

- The `RULES.md` version line if present (e.g. "RULES.md updated from v1.0 → v2.0")
- For each modified `rules/<profile>.md`: which sections changed (added rules,
  tightened rules, relaxed rules)
- For each modified `profiles/<profile>/bootstrap.md` or `scaffolders.md`: which
  defaults or commands changed
- Any project-specific overrides in the project's `AGENTS.md` that may now conflict
  with the new rules — flag these so the user can review them
- New profiles/overlays added — list them so the user knows new skillsets are
  selectable

### The project's AGENTS.md (migration)

Project facts live in `AGENTS.md` at the project root
([`RULES.md#project-facts`](../RULES.md#project-facts)), and `CLAUDE.md` is only the
import `@AGENTS.md` (`CLAUDE.md.template`), because Claude Code reads only `CLAUDE.md`
when both exist. Every run migrates the project with `scripts/migrate-agents-md.sh`,
automatically and with a backup. Relay its items: **PROJECT MIGRATED** (a change to the
project's own files, no action needed beyond committing them), the AGENTS.md items under
**NEEDS ATTENTION**, and **PROJECT NOTES**.

The project root is the directory holding the skills, from the skills path as given:
`<root>` for the default `<root>/.opencode/skills`, or the top of the git repository that
holds them. If the two disagree, neither exists, a component of the skills path is a
symlink, or the result is `/`, the home directory or a dot-directory in it (`~/.claude`),
nothing is changed and NEEDS ATTENTION says so; the user can name the root with
`SKILLS_PROJECT_ROOT=<root>` (it must contain the skills path).

| At the root | What the update does |
|---|---|
| Only `CLAUDE.md` | Copies it to `.agents-md-backup/CLAUDE.md.backup` in the skills dir (`.backup.2`, … if a different one is there; never overwritten or deleted; the directory has a `.gitignore`, so git ignores it), writes its exact bytes to a writable `AGENTS.md`, replaces `CLAUDE.md` with the import. Reported as migrated, with the backup path, a note if the working-tree version had uncommitted changes, files that still mention `CLAUDE.md`, a reminder to re-run the installers, and its `@`-imports (they resolve the same from `AGENTS.md`, same directory; up to 20 listed, any that reach Claude Code's four-hop limit flagged) |
| `CLAUDE.md` is the import (first content line, after a byte order mark, blank lines and HTML comments, is `@AGENTS.md`) and `AGENTS.md` exists | Nothing, not reported |
| Both, `CLAUDE.md` not the import | Nothing changed; NEEDS ATTENTION: merge `CLAUDE.md` into `AGENTS.md`, then make `CLAUDE.md` the import (until then Claude Code ignores `AGENTS.md`) |
| Only `AGENTS.md` | Creates `CLAUDE.md` as the import (reported), for Claude Code sessions that do not read `AGENTS.md` themselves. Opt out with a `.no-claude-md` file in the skills dir (or `SKILLS_NO_CLAUDE_MD=1`): then it is only noted |
| Neither | Nothing; one note (`project-bootstrap` / `project-onboard` write them) |
| `CLAUDE.md` or `AGENTS.md` a symlink or not a regular file; `CLAUDE.md` unreadable, git-ignored (private), or already importing `AGENTS.md`; `AGENTS.md` git-ignored; the import with no `AGENTS.md` | Nothing changed; NEEDS ATTENTION says why |
| `.claude/CLAUDE.md` | Left alone and listed under NEEDS ATTENTION (other agents do not read it); the root's files are still handled as above |
| `CLAUDE.local.md`, `CLAUDE.md` files in subdirectories | Never touched; a note lists them |

It never overwrites `AGENTS.md` and never deletes a project file. A second run changes
nothing. Tell the user to commit `AGENTS.md` and `CLAUDE.md`, and that the backup can be
deleted once they have checked them. Claude-only instructions may go below the import.

### templates/ and other notices

- `templates/` (the process-document starters) is replaced only when it carries the
  shipped `.from-skills` marker; the project's own `docs/` copies are never touched.
  Summarise template changes and say which project copies the user may update by hand.
  When every template is "(new file)", the project predates them: tell the user to
  install them once (the `project-onboard` skill's *Install the process documents*
  step, or `templates/README.md`) and add the `## Process` section of
  `AGENTS.md.template`, recording the privacy adoption point there.
- A skill whose old `## Project Context` block held project facts is listed under
  NEEDS ATTENTION, with a copy in `.project-context-backup/` (never overwritten: changed
  content goes to `<skill>.2.md`, …): tell the user to move the facts into `AGENTS.md`
  ([`RULES.md#project-facts`](../RULES.md#project-facts)) and delete the file; every
  update lists the backups still there.
- `.rules-upstream.cksum` records the `RULES.md` last installed, so only a real local
  edit triggers the "edited locally" warning. The installers write it for an
  unmodified git checkout of the skills; otherwise the first update writes it, and
  edits made before then are not detected.

## Rules

- Do not edit any skill files yourself — the script handles everything.
- Do not run `git pull` directly; always use the bundled script.
- If the script exits with a non-zero code, report the error output verbatim and stop.

## After updating — re-run installers if applicable

The update script syncs the skills, root files, and the `scripts/`, `rules/`,
`profiles/` and `templates/` directories, but does **not** re-propagate changes into
Claude Code or Copilot agent directories. After
a successful update, remind the user:

- **Claude Code users** — re-run `scripts/install-claude-agents.sh` from each
  project root to refresh `.claude/agents/<skill>.md` and pick up any new tool
  restrictions, `RULES.md` changes, new stack overlays under `rules/`, new
  profiles under `profiles/`, or updated `templates/`.
- **GitHub Copilot users** — re-run `scripts/install-copilot-agents.sh` to refresh
  symlinks in `.github/agents/` and re-copy `RULES.md`, `rules/`, `profiles/` and
  `templates/` alongside.
- **OpenCode users** — no action needed; OpenCode reads `.opencode/skills/`
  directly.

If the rule files were updated, remind the user to compare any overrides in their
project `AGENTS.md` against the new rules — paying particular attention to the active
overlay declared by the `## Active Skillset` line.

### Self-updating script

The `update.sh` script self-updates: after the initial clone it compares the upstream
copy of `update.sh` against the installed copy, and if they differ it installs the
new version and re-execs from it. That means a single `/update-skills` run picks up
both new logic in the script *and* whatever data the new logic syncs (e.g. new
top-level directories). The existing clone is reused so there's no second `git clone`.

### One-time migration: `rules/` and `profiles/` directories

The skills repo grew two new top-level directories — `rules/` (stack overlays) and
`profiles/` (bootstrap defaults per skillset) — referenced by the worker skills via
`../rules/<profile>.md` and `profiles/<profile>/bootstrap.md`.

Self-update was introduced *in the same release* as these directories, so projects
upgrading **from a pre-self-update version** still need two `/update-skills` runs
(the first installs the self-updating `update.sh`; the second uses it to sync the
new dirs). Re-cloning per the README install path is a 1-step alternative.

After detecting that the upstream contains `rules/` or `profiles/` but the installed
copy does not, prompt the user:

> "This update added new top-level `rules/` and `profiles/` directories that the
> updated skills reference. The currently installed update script can't sync them on
> this run — please run `/update-skills` once more to pull them in. Future updates
> will be single-step."
