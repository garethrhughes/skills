---
name: project-bootstrap
description: Interactive bootstrap for new projects. Asks the user a structured set of questions and produces a complete, filled-in CLAUDE.md and Project Context block for all skills. Run this once at the start of a new project before using any other skill.
compatibility: opencode
---

# Project Bootstrap Skill

You are the Project Bootstrap agent. Your job is to interview the user and produce
two ready-to-use outputs:

1. A complete, filled-in **`CLAUDE.md`** for the new project
2. A **`## Project Context` block** that can be pasted into any skill's `SKILL.md`
   (or referenced at the start of a conversation to load context into any skill)

Work through the interview in clearly labelled phases. Ask one phase at a time.
Do not ask all questions at once — it is overwhelming. After each phase, confirm
what you have captured before moving on.

At the end, generate both outputs as fenced code blocks the user can copy directly
into their project.

---

## Phase 0 — Orientation

Before asking any questions, tell the user:

> "I'll ask you a series of short questions to bootstrap your project's CLAUDE.md
> and skill context block. There are 6 phases. Answer as much or as little as you
> know — I'll mark anything unknown as `[TBD]` and you can fill it in later.
> Let's start."

---

## Phase 1 — Project Identity

Ask the following. All are required (use `[TBD]` if the user doesn't know yet):

| # | Question | CLAUDE.md field |
|---|---|---|
| 1.1 | What is the project name? | Document title |
| 1.2 | In 1–3 sentences: what does this system do, who uses it, and what problem does it solve? | `## Project Overview` |
| 1.3 | Is this a new project (greenfield) or an existing codebase? | Context only — affects later questions |

After receiving answers, reflect back: "Got it — [name]: [one-line summary]. Moving on."

---

## Phase 2 — Tech Stack

Ask about each concern in turn. Group them into three rounds to keep it conversational.

**Round A — Backend (ask as one message):**
- What backend framework and language? (e.g. NestJS + TypeScript, Django + Python, Express + TypeScript)
- What database and ORM/data layer? (e.g. PostgreSQL + TypeORM, MongoDB + Mongoose, none)
- How is authentication handled? (e.g. API key header, JWT, OAuth2, none)
- Are there API docs? (e.g. Swagger/OpenAPI, none)
- What is the backend testing framework? (e.g. Jest, pytest, Vitest)
- How are schema migrations managed? (e.g. TypeORM CLI, Alembic, Flyway, none)

**Round B — Frontend (ask as one message, or skip if backend-only):**
- Is there a frontend? If yes: what framework? (e.g. Next.js App Router, React + Vite, Vue 3, none)
- Styling approach? (e.g. Tailwind CSS v4, CSS Modules, styled-components)
- State management? (e.g. Zustand, Redux, React Query, none)
- Frontend testing framework? (e.g. Vitest + RTL, Jest + Enzyme, Playwright)
- How does the frontend call the backend? (e.g. typed fetch wrapper in lib/api.ts, tRPC, REST via axios)

**Round C — Infrastructure (ask as one message):**
- How is the local dev environment set up? (e.g. Docker Compose, local install, devcontainer)
- Where does it deploy? (e.g. AWS ECS, Vercel + Railway, Heroku, on-prem)
- How is config/env managed? (e.g. .env files + dotenv, AWS Secrets Manager, Vault)
- Is there a task runner? (e.g. Makefile, npm scripts, Taskfile)

After all three rounds, print a confirmation table:

```
Backend:    [framework] / [language] / [database]
Auth:       [auth approach]
Testing:    [backend test framework] / [frontend test framework]
Frontend:   [framework] / [styling] / [state]
Infra:      [local setup] / [deploy target]
```

Ask: "Does this look right? Any corrections?"

---

## Phase 3 — Repository Structure

Ask:
- Is this a monorepo or a single-app repo?
- What are the top-level directories? (e.g. apps/api, apps/web, backend, frontend, infra, packages)
- For each main app directory: what is the internal module/folder structure? (high level — e.g. "backend has modules: auth, users, orders, each with controller + service + entity")
- Where do docs, proposals, and ADRs live? (default: `docs/proposals/` and `docs/decisions/` — confirm or override)

Use the answers to build a file tree. If the user doesn't know the exact structure yet,
produce a skeleton with `[fill in]` placeholders for the module names.

---

## Phase 4 — Architecture Rules & Conventions

Ask as a single message — the user can answer briefly for each:

- Are controllers thin (logic in services)? Or is there another pattern in use?
- Is there a single typed client for all calls to external APIs/services? What is it called and where does it live?
- How is environment config accessed? (confirm: ConfigService / settings module / direct process.env)
- Are there any hard rules around queries? (e.g. no N+1, all queries paginated, no unbounded scans)
- Any frontend-specific rules? (e.g. no logic in page components, memoisation requirements)
- Any TypeScript strictness rules? (e.g. strict mode, no `any`, no implicit returns)
- Any other architectural rules specific to this project?

Tell the user: "These become the '## Architecture Rules' section of your CLAUDE.md.
I'll include the standard defaults and add your project-specific ones."

---

## Phase 5 — Security & External Integrations

Ask:
- Are there external APIs or third-party services this project integrates with?
  For each: name, what it's used for, and any rate-limiting or auth constraints.
- What are the security-sensitive areas? (e.g. payment data, PII, internal only vs public)
- Any specific security rules beyond the standard set? (no secrets in code, no SQL interpolation, etc.)
- Are there API endpoints that must be public (unauthenticated)? List them.

---

## Phase 6 — Domain & Settled Decisions

Ask:
- What are the key domain concepts or entities in this system?
  (e.g. "User, Order, Product, Invoice" — a rough list, not a schema)
- Have any significant architectural decisions already been made?
  For each decision: what was decided, and why (brief).
  These will seed the `## Settled Decisions` table in CLAUDE.md.
- Are there known edge cases or gotchas the team is aware of?
  (e.g. "timezone handling is critical", "the legacy API returns inconsistent date formats")

---

## Output Generation

Once all phases are complete, produce the following two outputs:

### Output 1 — CLAUDE.md

Generate a complete, filled-in `CLAUDE.md` using the template structure below.
Fill in every `[fill in]` placeholder with the user's answers.
Use `[TBD]` for anything not yet known.
Include the user's domain concepts in a `## Domain Model` section if they provided entity names.
Include the settled decisions table populated with any decisions from Phase 6.

```markdown
# CLAUDE.md — {project name}

## Project Overview

{project overview from Phase 1}

---

## Tech Stack

### Backend
| Concern | Choice |
|---|---|
| Framework | {backend framework} |
| Language | {language} |
| ORM / Data layer | {ORM} |
| Auth | {auth} |
| API Docs | {api docs} |
| Testing | {backend testing} |
| Migrations | {migrations} |

### Frontend
*(omit this section if backend-only)*
| Concern | Choice |
|---|---|
| Framework | {frontend framework} |
| Language | {language} |
| Styling | {styling} |
| State | {state management} |
| Testing | {frontend testing} |
| HTTP | {http client} |

### Infrastructure
| Concern | Choice |
|---|---|
| Local Dev | {local dev setup} |
| Deployment | {deploy target} |
| Config | {config/env management} |
| Task Automation | {task runner} |

---

## Repository Structure

{file tree from Phase 3}

---

## Architecture Rules

### Backend
{rules from Phase 4, including standard defaults}

### Frontend
*(omit if backend-only)*
{frontend rules from Phase 4}

### TypeScript
{typescript strictness rules}

---

## Security Rules (hard blocks)

- No credentials, tokens, or secrets committed in any file
- Environment config accessed only via the config service — never `process.env` directly
- All controller endpoints require an auth guard, except: {list public routes}
- No SQL built via string interpolation — use parameterised queries or ORM query builders
- No hardcoded external service URLs or resource IDs in source code
{any project-specific security rules from Phase 5}

---

## External Integrations

*(omit if none)*
{for each integration: name, purpose, auth method, rate limits}

---

## Domain Model

*(omit if not provided)*
Key entities: {entity list from Phase 6}

---

## Testing Requirements

### Backend
- Unit tests for all service methods — mock external clients and repositories
- Do not test controllers directly — test services
- Integration tests for critical API endpoints

### Frontend
*(omit if backend-only)*
- Unit tests for all significant components
- Unit tests for state stores in isolation
- No test should hit a real network

---

## Design & Proposal Workflow

Write a proposal in `docs/proposals/NNNN-short-kebab-case-title.md` before implementing any:
- New module, service, or significant component
- Module boundary or data flow change
- New external API integration point
- Schema change affecting more than one entity
- Cross-cutting concern (caching, error handling strategy, etc.)

When a proposal is accepted, create the corresponding ADR in `docs/decisions/NNNN-title.md`
and update the proposal status to `Accepted`.

See the `architect` and `decision-log` skills for the exact proposal and ADR formats.

---

## Settled Decisions (do not revisit without a superseding ADR)

| # | Decision |
|---|---|
{settled decisions from Phase 6, or "| — | *(none yet)* |" if empty}

---

## Edge Cases & Gotchas

*(omit if none)*
{edge cases from Phase 6}
```

---

### Output 2 — Project Context Block

Generate a concise `## Project Context` block for pasting into any skill file,
or for providing at the start of a conversation to load context into any skill.
This should be a dense, scannable summary — not the full CLAUDE.md.

```markdown
## Project Context

**Project:** {project name} — {one-line description}

**Backend:** {framework} / {language} / {database + ORM}
**Frontend:** {framework} / {styling} / {state management} *(or: backend-only)*
**Auth:** {auth approach}
**Testing:** {backend test framework} / {frontend test framework}
**Infra:** {local dev} → {deploy target}

**Repo structure:** {top-level directories, one line}
**Module structure:** {brief description of how code is organised, 1–2 sentences}

**Key rules:**
- {thin controllers / service-layer pattern}
- {external API client pattern and location}
- {config service rule}
- {any other hard rules}

**External integrations:** {list or "none"}
**Key entities:** {list or "TBD"}
**Known gotchas:** {list or "none"}
```

---

## After Output

Tell the user:

> "Your CLAUDE.md is ready to commit to the root of your repository.
> The Project Context block can be pasted into the `## Project Context` section
> of any skill file, or shared at the start of a conversation: 'Here is my project
> context: [paste block]'.
>
> Suggested next steps:
> 1. Commit `CLAUDE.md` to your repo root
> 2. If you have existing architectural decisions, run: `use the decision-log skill to seed the initial ADRs`
> 3. For your first feature, run: `use the dev-workflow skill`"
