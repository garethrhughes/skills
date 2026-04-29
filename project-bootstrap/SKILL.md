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
>
> For most questions I'll show a **default** in bold brackets — this is the approach
> used in the reference stack (NestJS 11 + TypeScript / Next.js 16 App Router /
> PostgreSQL + TypeORM / Docker Compose / AWS ECS Fargate). To accept a default,
> just say **'yes'**, **'default'**, or press Enter. Override it by giving a different answer.
>
> Let's start."

---

## Phase 1 — Project Identity

Ask the following. All are required (use `[TBD]` if the user doesn't know yet).
There are no defaults for this phase — every answer is project-specific.

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
- What backend framework and language? [**NestJS 11 + TypeScript strict mode**]
- What database and ORM/data layer? [**PostgreSQL 16 + TypeORM** (CLI migrations)]
- How is authentication handled? [**None at application level — CORS as sole access control**]
- Are there API docs? [**Swagger via `@nestjs/swagger`** — served at `/api-docs`, unguarded]
- What is the backend testing framework? [**Jest + Supertest**]
- How are schema migrations managed? [**TypeORM CLI** — `npm run migration:run`; migrations must implement both `up()` and `down()`]

**Round B — Frontend (ask as one message, or skip if backend-only):**
- Is there a frontend? If yes: what framework? [**Next.js 16 (App Router) + React 19**]
- Styling approach? [**Tailwind CSS v4 — CSS-first config via `@theme` in `globals.css`; no `tailwind.config.js`**]
- State management? [**Zustand** — one store file per concern in `store/`]
- Frontend testing framework? [**Vitest + React Testing Library**]
- How does the frontend call the backend? [**Typed `fetch` wrappers in `lib/api.ts`** — no direct fetch calls outside this file]

**Round C — Infrastructure (ask as one message):**
- How is the local dev environment set up? [**Docker Compose** — PostgreSQL 16, database `ai_starter`, port 5432]
- Where does it deploy? [**AWS ECS Fargate** — behind CloudFront + WAF IP allowlist; ECR for images]
- How is config/env managed? [**`.env` files** (never committed); `.env.example` provided; backend reads via NestJS `ConfigService` only]
- Is there a task runner? [**Makefile** — targets: `up`, `down`, `migrate`, `dev-api`, `dev-web`, `test-api`, `test-web`, `deploy`]

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

Defaults (shown in brackets) are based on the reference stack.

Ask:
- Is this a monorepo or a single-app repo? [**Monorepo**]
- What are the top-level directories? [**`backend/`, `frontend/`, `infra/terraform/`, `docs/`, `scripts/`** — plus `apps/` for any auxiliary services (e.g. MCP server)]
- For each main app directory: what is the internal module/folder structure? [**Backend: one NestJS module per feature domain, each containing `*.controller.ts`, `*.service.ts`, `*.module.ts`, and `dto/`. Shared: `database/entities/`, `database/migrations/`, `config/`, `common/`. Frontend: `app/` (App Router pages), `components/ui/`, `components/layout/`, `store/`, `lib/`, `hooks/`**]
- Where do docs, proposals, and ADRs live? [**`docs/proposals/` and `docs/decisions/`** — confirm or override]

Use the answers to build a file tree. If the user doesn't know the exact structure yet,
produce a skeleton with `[fill in]` placeholders for the module names.

---

## Phase 4 — Architecture Rules & Conventions

Defaults (shown in brackets) are based on the reference stack.
Ask as a single message — the user can answer briefly for each:

- Are controllers thin (logic in services)? [**Yes — controllers are thin; all business logic lives in services**]
- Is there a single typed client for all calls to external APIs/services? What is it called and where does it live? [**Yes — a single `[ServiceName]ClientService` in its own module; domain services never call external APIs directly**]
- How is environment config accessed? [**NestJS `ConfigService` only — `process.env` must never be accessed outside of config module setup**]
- Are there any hard rules around queries? [**No N+1 queries — related data fetched in bulk. All `find()` calls on large tables require a `where` clause or explicit pagination**]
- Any frontend-specific rules? [**No logic in page components — delegate to services or custom hooks. All API calls through `lib/api.ts`. No direct state mutation outside Zustand store actions**]
- Any TypeScript strictness rules? [**Strict mode throughout — no `any`, no implicit returns**]
- Any rate-limiting rules? [**`@nestjs/throttler` applied globally — 100 req/min/IP** (adjust limit as needed)]
- Any other architectural rules specific to this project?

Tell the user: "These become the '## Architecture Rules' section of your CLAUDE.md.
I'll include the standard defaults and add your project-specific ones."

---

## Phase 5 — Security & External Integrations

Defaults (shown in brackets) are based on the reference stack.

Ask:
- Are there external APIs or third-party services this project integrates with?
  For each: name, what it's used for, and any rate-limiting or auth constraints.
  [**Example default: a third-party REST API authenticated via Bearer token, rate-limited to X req/min — implement exponential backoff with max 3 retries on HTTP 429**]
- What are the security-sensitive areas? [**Internal tool — no public access; access restricted at infrastructure level (e.g. WAF IP allowlist)**]
- Any specific security rules beyond the standard set? [**No secrets in code, no `process.env` outside config module, no SQL string interpolation, no hardcoded external URLs or resource IDs**]
- Are there API endpoints that must be public (unauthenticated)? [**`GET /health` and `GET /api-docs` are unguarded; all other endpoints require authentication if auth is enabled**]

---

## Phase 6 — Domain & Settled Decisions

Defaults (shown in brackets) are based on the reference stack.

Ask:
- What are the key domain concepts or entities in this system?
  (e.g. "User, Order, Product, Invoice" — a rough list, not a schema)
  [**No default — this is project-specific. Prompt the user to list the main nouns in their system.**]
- Have any significant architectural decisions already been made?
  For each decision: what was decided, and why (brief).
  These will seed the `## Settled Decisions` table in CLAUDE.md.
  [**Suggest seeding with any choices already confirmed from Phase 2–5, e.g. "Use PostgreSQL as the primary data store", "No application-level auth — CORS as sole access control", "Monorepo with backend/ and frontend/ directories"**]
- Are there known edge cases or gotchas the team is aware of?
  [**Example defaults to prompt thinking: timezone handling, external API rate limits, pagination of large result sets, handling of partial/in-progress domain objects**]

---

## Output Generation

Once all phases are complete, produce the following two outputs.

**Important:** When the user accepted a default answer, write the full expanded default
value into the output — never write "default" or "same as reference stack". The output
must always be a complete, specific, human-readable document.

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
