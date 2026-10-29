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
