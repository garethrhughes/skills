# OpenCode Skills

Reusable OpenCode skills for structured software development with AI agents.

## Skills

| Name | Description |
|---|---|
| [architect](architect/SKILL.md) | Drives technical design decisions, writes proposals before significant changes, and maintains the proposal index |
| [developer](developer/SKILL.md) | Writes production-quality TypeScript following TDD (red-green-refactor) and project conventions |
| [reviewer](reviewer/SKILL.md) | Reviews staged changes for security, correctness, performance, IaC safety, observability, and convention adherence; returns a PASS / PASS WITH COMMENTS / BLOCK verdict with Acceptance Criteria traceability |
| [infosec](infosec/SKILL.md) | Read-only security and compliance audit (ISO27001-aligned by default). Audits encryption, access control, audit logging, secrets, IAM, network exposure, and supply chain. Returns APPROVED / REQUIRES CHANGES / APPROVED WITH EXCEPTION |
| [decision-log](decision-log/SKILL.md) | Captures and maintains architectural decisions (ADRs) in `docs/decisions/` with a running index |
| [dev-workflow](dev-workflow/SKILL.md) | Full feature development cycle: proposal → implementation → review → infosec sign-off → decision logging → PR |
| [project-bootstrap](project-bootstrap/SKILL.md) | Interactive bootstrap that asks a structured set of questions (app stack, IaC, observability, security/compliance, domain) and produces a complete CLAUDE.md and Project Context block |

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/garethrhughes/skills ~/Documents/skills
```

### 2. Symlink for global OpenCode access

```bash
ln -s ~/Documents/skills ~/.config/opencode/skills
```

### 3. Verify

Open OpenCode and check that the skills appear in the skill tool. You should see `architect`,
`developer`, `reviewer`, `infosec`, `decision-log`, `dev-workflow`, and `project-bootstrap` listed.

## Usage

Reference a skill in any OpenCode prompt by name:

```
Use the architect skill to design a caching strategy for the sync module.
```

```
Use the developer skill to implement the feature described in proposal 0042.
```

```
Use the reviewer skill to review the staged changes in this branch.
```

```
Use the infosec skill to audit this PR for ISO27001 compliance and security issues.
```

```
Use the decision-log skill to log the decision made in the last conversation.
```

```
Use the dev-workflow skill to walk through the full feature cycle for this task.
```

## Customisation

Each skill contains a `## Project Context` section near the top. This section is intentionally
left as a placeholder — fill it in before use.

**Recommended approach:** copy the content of your project's `CLAUDE.md` into the `## Project Context`
section of each skill, or paste it at the start of a conversation with instructions like:

> "Here is my project context — treat this as the project context for the skill you are using."

A `CLAUDE.md.template` file is provided in this repository as a starting point for new projects.

> **Note:** in OpenCode, your project's `CLAUDE.md` is already loaded into every conversation automatically — you may not need to repeat the full context in each skill's `## Project Context` section. Instead, focus on any skill-specific overrides or additions.

## CLAUDE.md Template

See [`CLAUDE.md.template`](CLAUDE.md.template) for a generic `CLAUDE.md` structure you can
copy into any new project and fill in.
