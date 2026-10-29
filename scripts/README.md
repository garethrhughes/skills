# scripts/

Operational scripts for installing the skills repo into different AI assistants.
All scripts are run from your **project root** (not from this directory) and read
the project-local skills in `.opencode/skills` unless another path in the project is
passed as the first argument.

## Scripts

### `install-claude-agents.sh`

Generates `.claude/agents/<skill>.md` files for Claude Code subagents.

- Strips OpenCode-specific frontmatter (`compatibility`, `permission`).
- Applies per-skill tool restrictions (e.g. `infosec` is read-only).
- Copies `RULES.md`, `rules/`, `profiles/` and `templates/` into `.claude/` so the
  skills' relative links resolve; replaces an existing `templates/` only if it carries
  the `.from-skills` marker.
- Writes the `.rules-version` sidecar (from `**Version:**` in `RULES.md`), and
  `.rules-upstream.cksum` for an unmodified git checkout of the skills.
- Safe to re-run after `update-skills` pulls upstream changes.

```bash
.opencode/skills/scripts/install-claude-agents.sh
```

### `install-copilot-agents.sh`

Symlinks each `SKILL.md` into `.github/agents/<skill>.md` for GitHub Copilot.

- Skips files that already exist (manual replacement required).
- Copies `RULES.md`, `rules/`, `profiles/` and `templates/` into `.github/` (not
  symlinked), with the same `templates/` marker rule.
- Writes the `.rules-version` sidecar.

```bash
.opencode/skills/scripts/install-copilot-agents.sh
```

### `migrate-agents-md.sh`

Moves the project to `AGENTS.md` as its instruction file: a `CLAUDE.md` alone becomes
`AGENTS.md` (byte for byte, backed up first under `.agents-md-backup/` in the skills
dir) and `CLAUDE.md` becomes the import of it (`CLAUDE.md.template`); an `AGENTS.md`
alone gets that `CLAUDE.md`. Anything else (both files with content, symlinks, a root
it cannot determine) is reported and left alone. `update-skills` runs it on every
update and `project-onboard` on a project with only a `CLAUDE.md`; it is safe to run
again. The header comment says how it finds the project root and lists the cases.

```bash
bash .opencode/skills/scripts/migrate-agents-md.sh
```

The two installers never create or change `AGENTS.md` or `CLAUDE.md`.

## Tests for update.sh and the migration

[`tests/update-skills/`](../tests/update-skills/) holds a scenario harness: real scratch
projects, the skills installed from an older commit, `update.sh` run through its
self-update path against the commit under test, with byte-for-byte checks. It covers
every migration case, the Project Context backups, the `templates/` marker and the
`RULES.md` record. It needs only `python3`, `git` and `bash`, the full history (it
installs from older commits), and writes only to a fresh temporary directory. From the
skills repository:

```bash
python3 tests/update-skills/harness.py      # the committed HEAD; exit 0 = all pass
python3 tests/update-skills/mutants.py      # breaks each control in turn; exit 0 = all caught
```

Run both after changing `update.sh` or `migrate-agents-md.sh`, and add a case (and a
mutant) for every new behaviour. `--src-ref <rev>` tests another commit.

## When to re-run

Re-run the installer for your assistant after every `update-skills` run so that
skill changes (especially RULES.md updates and per-skill tool restriction
changes) propagate into the agent directories.

OpenCode users do **not** need to run any installer — OpenCode reads
`.opencode/skills/` directly.

## Custom skills directory

All scripts accept the skills directory as the first argument:

```bash
.opencode/skills/scripts/install-claude-agents.sh path/in/project/to/skills
```
