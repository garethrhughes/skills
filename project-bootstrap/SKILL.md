---
name: project-bootstrap
description: Interactive bootstrap for new projects. Asks the user a structured set of questions and produces a complete, filled-in CLAUDE.md and Project Context block for all skills. Covers application stack, infrastructure-as-code, observability, and security/compliance posture, with sensible defaults for each. Run this once at the start of a new project before using any other skill.
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

## Authoritative Rules

The defaults proposed throughout this interview reflect the project-wide engineering
conventions in [`RULES.md`](../RULES.md) (language-agnostic core) plus the active
**stack overlay** in [`rules/`](../rules/) and the matching **profile** in
[`profiles/`](../profiles/). When a user accepts the defaults, they are accepting
`RULES.md` + the chosen overlay verbatim. Where a user overrides a default in a way
that conflicts, capture the override in their generated `CLAUDE.md` and call it out
explicitly so future skill runs know the project deviates.

Available profiles (extensible — drop another directory under `profiles/` to add one):

| Identifier | Overlay | Summary |
|---|---|---|
| `typescript` | [`rules/typescript.md`](../rules/typescript.md) | NestJS + Next.js + TypeORM + pino + Jest/Vitest |
| `dotnet` | [`rules/dotnet.md`](../rules/dotnet.md) | ASP.NET Core + EF Core + Serilog + xUnit |

---

## Phase 0 — Orientation

Before asking any questions, tell the user:

> "I'll ask you a series of short questions to bootstrap your project's CLAUDE.md
> and skill context block. There are **10 phases** covering project identity, **skillset
> profile**, application stack, infrastructure-as-code, repository structure,
> conventions, observability, security/compliance, domain, and Jira integration
> (optional). Answer as much or as little as you know — I'll mark anything unknown as
> `[TBD]` and you can fill it in later.
>
> For most questions I'll show a **default** in bold brackets — these come from the
> profile you pick in Phase 1.5. To accept a default, just say **'yes'**, **'default'**,
> or press Enter. Override it by giving a different answer.
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

## Phase 1.5 — Skillset Profile

Ask:

> "Which skillset profile should drive the defaults?
>
> - **`typescript`** [default] — NestJS + Next.js + TypeORM + pino + Jest/Vitest
> - **`dotnet`** — ASP.NET Core + EF Core + Serilog + xUnit
> - **other** — pick the closest profile then plan to override defaults manually
>
> Reply with the identifier, or 'default' for `typescript`."

Record the chosen identifier as `{profile}`. For every subsequent question that
proposes a default, **read the default value from
`profiles/{profile}/bootstrap.md`** rather than from this skill file. Do not
hard-code stack-specific defaults below — the question text is profile-agnostic, the
answer in brackets comes from the profile.

The chosen profile also determines:

- The **stack overlay** (`rules/{profile}.md`) referenced by the generated `CLAUDE.md`
- The **scaffolder commands** (`profiles/{profile}/scaffolders.md`) used in Step 3.1
- The **smoke-test commands** (`profiles/{profile}/scaffolders.md`) used in Step 5

---

## Phase 2 — Application Tech Stack

Ask about each concern in turn. Group them into two rounds. Defaults below are
*placeholders* — replace each `[**…**]` at runtime with the corresponding row from
`profiles/{profile}/bootstrap.md` Phase 2.

**Round A — Backend (ask as one message):**
- What backend framework and language? [**from profile 2A.1**]
- What database and ORM/data layer? [**from profile 2A.2**]
- How is authentication handled? [**from profile 2A.3**; for internal-only tools, override with "None at application level — CORS / WAF as sole access control"]
- Are there API docs? [**from profile 2A.4**]
- Backend testing framework? [**from profile 2A.5**]
- How are schema migrations managed? [**from profile 2A.6**]
- DTO validation library? [**from profile 2A.7**]
- Logging library? [**from profile 2A.8**]

**Round B — Frontend (ask as one message, or skip if backend-only):**
- Is there a frontend? If yes: what framework? [**from profile 2B.1**]
- Styling approach? [**from profile 2B.2**]
- State management? [**from profile 2B.3**]
- Frontend testing framework? [**from profile 2B.4**]
- How does the frontend call the backend? [**from profile 2B.5**]
- Data fetching pattern? [**from profile 2B.6** if present; otherwise from `RULES.md`]

After both rounds, print a confirmation table:

```
Backend:    [framework] / [language] / [database]
Auth:       [auth approach]
Validation: [validation library]
Logging:    [logger]
Testing:    [backend test framework] / [frontend test framework]
Frontend:   [framework] / [styling] / [state]
```

Ask: "Does this look right? Any corrections?"

---

## Phase 3 — Infrastructure-as-Code & Deployment

Ask as a single message. Defaults come from `profiles/{profile}/bootstrap.md` Phase 3
(rows 3.1–3.10). Substitute each `[**from profile 3.x**]` placeholder with the
corresponding row at runtime.

- How is the local dev environment set up? [**from profile 3.1**]
- Where does it deploy? [**from profile 3.2**]
- Which IaC tool? [**from profile 3.3**]
- IaC state backend? [**from profile 3.4**]
- Where do IaC modules live? [**from profile 3.5**]
- Secrets manager? [**from profile 3.6**]
- CI/CD pipeline? [**from profile 3.7**]
- Standard resource tags? [**from profile 3.8** — defaults from `RULES.md#infrastructure-as-code`]
- How is config/env managed? [**from profile 3.9**]
- Is there a task runner? [**from profile 3.10**]
- Does CI run on pull requests, and how is it run locally before a PR? [**Default:** CI
  runs on every PR; locally, a runner that reproduces the CI workflow, or the exact
  commands CI runs, listed in the README. With no CI at all, the commands run instead
  (lint, test, build). See `RULES.md#git--prs`]

After this round, confirm:

```
Local:     [local setup]
Cloud:     [cloud provider + key services]
IaC:       [tool] / state in [backend]
Secrets:   [secrets manager]
CI/CD:     [pipeline]
Local CI:  [command] (CI on PRs: yes/no)
```

Ask: "Does this look right?"

---

## Phase 4 — Repository Structure

Defaults come from `profiles/{profile}/bootstrap.md` Phase 4 (rows 4.1–4.6). Ask:

- Is this a monorepo or a single-app repo? [**from profile 4.1**]
- What are the top-level directories? [**from profile 4.2**]
- For each main app directory: what is the internal module/folder structure? [**combined from profile 4.3 + 4.4 (if frontend) + 4.5**]
- Where do docs, proposals, and ADRs live? [**from profile 4.6**]

Use the answers to build a file tree. If the user doesn't know the exact structure yet,
produce a skeleton with `[fill in]` placeholders for the module names.

---

## Phase 5 — Architecture Rules & Conventions

The default architecture rules are defined in [`RULES.md`](../RULES.md)
(language-agnostic core) plus the active stack overlay
[`rules/{profile}.md`](../rules/). By accepting the defaults the user is accepting
both verbatim. Ask:

> "I'll apply the standard architecture rules from `RULES.md` (configuration via a
> typed config service, single typed client per external service with 5s timeout and
> exponential backoff, structured logging with no secrets, IaC standard tags, no `*`
> action on `*` resource, TDD, etc.) plus the **{profile}** stack overlay (language
> conventions, framework rules, ORM rules, logger, test runner).
>
> Are there any project-specific rules to add on top? Are there any defaults you need
> to **override** (and why)?"

Capture project-specific additions and overrides. These become the
"## Architecture Rules" section of `CLAUDE.md`, written as: `See RULES.md +
rules/{profile}.md, plus the following project-specific rules: ...`.

---

## Phase 6 — Observability

Core principles (no secrets in logs, correlation IDs, JSON) are defined in
[`RULES.md#logging--observability`](../RULES.md#logging--observability). Stack-specific
logging library (`pino`, `Serilog`, etc.) is defined in the active overlay. Defaults
below come from `profiles/{profile}/bootstrap.md` Phase 6.

- Logging backend? [**from profile 6.1**]
- Metrics backend? [**from profile 6.2**]
- Tracing backend? [**from profile 6.3**]
- Required structured log fields? [defaults from `RULES.md#logging--observability`]
- Forbidden log content? [defaults from `RULES.md#logging--observability`]
- Key SLIs to track from day one? [**from profile 6.4**]
- Alerting? [**from profile 6.5**]

---

## Phase 7 — Security & Compliance

Core secrets handling, IAM principles, IaC defaults, and external client patterns are
in [`RULES.md`](../RULES.md). Defaults below come from `profiles/{profile}/bootstrap.md`
Phase 7.

- Compliance framework(s)? [**from profile 7.1**]
- Data classification scheme? [**from profile 7.2**]
- Encryption at rest? [**from profile 7.3**]
- Encryption in transit? [**from profile 7.4**]
- External APIs / third-party services? For each: name, purpose, rate-limit / auth constraints. [**No default — list per project. Client implementation follows `RULES.md#external-http-clients` + the active overlay**]
- Auth model details? [**from profile 7.5**]
- Public (unauthenticated) endpoints? [**from profile 7.6**]
- Secrets handling? [defaults from `RULES.md#configuration--secrets`]
- IAM principle? [defaults from `RULES.md#infrastructure-as-code`]
- Network exposure rules? [**from profile 7.7**]
- Vulnerability scanning? [**from profile 7.8**]
- Audit logging requirements? [**from profile 7.9**]
- Who makes privacy and risk decisions: fills a PIA's *Applicable regimes and lawful
  basis*, and accepts or defers residual risks? [**No default — ask for a name** (usually
  the product owner)]
- Install the optional privacy-screening guard script
  (`templates/scripts/privacy-screening.guard.mjs.template`, installed as
  `scripts/__tests__/privacy-screening.test.mjs`, needs Node 18+)? [**Default:** no]
- Does the project keep a user-facing changelog? If so, where, and what entry limit?
  [**Default:** `CHANGELOG.md`, 300 characters an entry (`RULES.md#changelog`)]

After this round, confirm:

```
Compliance:   [framework or "none"]
Data classes: [scheme]
Encryption:   at rest [approach] / in transit [TLS version]
Secrets:      [secrets manager]
Scanning:     [tools]
Privacy:      decisions by [name]; screening guard [installed / not installed]
Changelog:    [path, limit / none]
```

---

## Phase 8 — Domain & Settled Decisions

Defaults (shown in brackets) are based on the reference stack.

Ask:
- What are the key domain concepts or entities in this system? (e.g. "User, Order, Product, Invoice" — a rough list, not a schema) [**No default — this is project-specific**]
- For each entity, what is its data classification? [**Use the scheme from Phase 7**]
- Have any significant architectural decisions already been made? For each: what was decided, and why (brief). These will seed the `## Settled Decisions` table in CLAUDE.md. [**Suggest seeding with the choices already confirmed from Phases 2–7, e.g. "Use PostgreSQL as the primary data store", "OpenTofu over Terraform for licence reasons", "Zero formal compliance framework", "No application-level auth — CORS/WAF as sole access control" (if applicable)**]
- Known edge cases or gotchas? [**Examples to prompt thinking: timezone handling, external API rate limits, pagination of large result sets, partial/in-progress domain objects, idempotency on retried mutations**]

---

## Phase 9 — Jira Integration (optional)

Ask as a single message, making it clear this phase is optional:

> "Does your team use Jira to track work? If so, I can configure the `jira-feature`
> skill so it knows your instance and project keys out of the box.
>
> - **Jira instance URL** — e.g. `https://your-org.atlassian.net`
> - **Default project key(s)** — e.g. `PLAT, API, FE` (the keys you use most often)
> - **Where are acceptance criteria written?** — e.g. a custom field named
>   'Acceptance Criteria', or a `## Acceptance Criteria` heading in the Description
>
> Reply **skip** if your team doesn't use Jira or you'd rather configure this later."

If the user skips, record `jira: none` and move on.

If the user provides details, confirm back:

```
Jira instance:         {url}
Default project keys:  {keys}
AC location:           {custom field name / heading / pattern}
```

Ask: "Does this look right?"

---

## Output Generation

Once all phases are complete, produce the following two outputs.

**Important:** When the user accepted a default answer, write the **full expanded default
value** into the output — never write "default" or "same as reference stack". The output
must always be a complete, specific, human-readable document.

### Output 1 — CLAUDE.md

Generate a complete, filled-in `CLAUDE.md` using the template structure below.
Fill in every `[fill in]` placeholder with the user's answers.
Use `[TBD]` for anything not yet known.
Include the user's domain concepts in a `## Domain Model` section if they provided entity names.
Include the settled decisions table populated with any decisions from Phase 8.

```markdown
# CLAUDE.md — {project name}

## Active Skillset: {profile}

This project follows the language-agnostic core rules in
[`RULES.md`](https://github.com/garethrhughes/skills/blob/main/RULES.md) plus the
**`{profile}`** stack overlay in
[`rules/{profile}.md`](https://github.com/garethrhughes/skills/blob/main/rules/{profile}.md).
Skills (`architect`, `design`, `developer`, `reviewer`, `infosec`) read both when applying
conventions to this project.

---

## Running Commands — never `cd`

Name the directory in the command instead of changing into it: the shell tool's
working-directory parameter where it has one, otherwise absolute paths, `git -C <dir>`,
`npm --prefix <dir>` (or the stack's equivalent). A `cd`, even in a chain, raises a
permission prompt that halts an unattended run. Two directories means two calls.

---

## Corrections Log — read before deciding

[`docs/corrections-log.md`](docs/corrections-log.md) records every time an agent was wrong
on this project and every time a decision had to be pushed back. Read its **Patterns**
before acting. The checks for every agent, at every step
([`RULES.md#evidence-corrections--decisions`](https://github.com/garethrhughes/skills/blob/main/RULES.md#evidence-corrections--decisions)):
verify a "done / out of scope / pre-existing" claim with a command before writing it;
break what a test guards and watch it fail; `git diff` a passage before claiming it
changed; quote failures, not only the passing count; brief reviewers with the original
request, the diff, and existing evidence (the local CI report or "pending: hosted CI on
the PR head", scanner output, and the privacy screening), never a list of what was done
or where to look; fix a shared function at the source and find every other writer of the
same state; reconcile every copy of a changed rule or name; after removing a name,
search for it. Append an entry when you get something wrong.

---

## Keeping This File Small

This file is loaded into every session, so it holds rules and pointers, not history.
Detail lives in the ADR, feature doc, README or risk-register row it came from. A new
Settled Decision gets **one line**: the rule as it stands, plus which ADRs it amends or
supersedes.

---

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
| Validation | {validation library} |
| Logging | {logger} |

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
| Data fetching | {data fetching pattern} |

### Infrastructure
| Concern | Choice |
|---|---|
| Cloud provider(s) | {cloud} |
| IaC tool | {iac tool} |
| IaC state backend | {state backend} |
| Secrets manager | {secrets manager} |
| CI/CD | {pipeline} |
| Database | {database} |
| Local Dev | {local dev setup} |
| Task Automation | {task runner} |
| Config | {config/env management} |
| Observability | {logs/metrics/traces backends} |

### Security & Compliance
| Concern | Choice |
|---|---|
| Compliance frameworks | {framework or "none"} |
| Encryption at rest | {approach} |
| Encryption in transit | {TLS version} |
| Data classification scheme | {scheme} |
| Vulnerability scanning | {tools} |

---

## Repository Structure

{file tree from Phase 4}

---

## Architecture Rules

This project follows:

- The language-agnostic rules in
  [`RULES.md`](https://github.com/garethrhughes/skills/blob/main/RULES.md) (config &
  secrets, external HTTP clients, observability principles, IaC, testing, git & PRs).
- The **`{profile}`** stack overlay in
  [`rules/{profile}.md`](https://github.com/garethrhughes/skills/blob/main/rules/{profile}.md)
  (language conventions, framework rules, ORM, logger, test runner).

**Project-specific additions / overrides:**
{additions and overrides captured in Phase 5; write "_(none)_" if empty}

---

## Security Rules (hard blocks)

Standard security rules are in `RULES.md` (no secrets in code, `ConfigService`-only
env access, parameterised queries, no `*` action on `*` resource, lockfile committed,
etc.).

**Project-specific additions:**
- Public (unauthenticated) endpoints: {list public routes from Phase 7}
- {any project-specific security rules from Phase 7, or "_(none)_"}

---

## External Integrations

*(omit if none)*
{for each integration: name, purpose, auth method, rate limits}

---

## Jira Integration

*(omit if jira: none)*
| Field | Value |
|---|---|
| Instance URL | {jira instance url} |
| Default project keys | {keys} |
| Acceptance criteria location | {custom field / heading / pattern} |

---

## Domain Model

*(omit if not provided)*
| Entity | Data Class |
|---|---|
{for each entity from Phase 8: name and classification}

---

## Testing Requirements

See [`RULES.md#testing`](https://github.com/garethrhughes/skills/blob/main/RULES.md#testing)
for the canonical testing rules (behaviour-focused names, no real network, services tested
not controllers, IaC modules tested, plan summary in PR description).

{write ONE of these two bullets, from the Phase 3 answer "CI on PRs":}
{CI runs on PRs:} - **CI runs on pull requests.** Where hosted CI runs on pull requests,
  a review held before the PR exists records the CI evidence as **"pending: hosted CI on
  the PR head"**; the gate is re-checked on the PR head before merge: green is required
  to merge, and the agent that opens the PR waits for the run and reports it, failures
  quoted. Before pushing, run `{local CI command from Phase 3}` for the jobs the change
  touches if you want an earlier answer; a local report is not required.
{CI does not run on PRs:} - **CI does not run on pull requests, so run CI locally before
  every PR** with `{local CI command from Phase 3}`, against the committed branch, for
  every CI job the change touches (all of them for a dependency, workflow or config
  change). The report names the jobs that ran and those SKIPPED; a SKIPPED job is **NOT
  VERIFIED**, never "passing", and the reviewer blocks a missing or non-compliant
  report. The local run is the only check before merge.
{No CI at all:} - **No CI.** A project with no CI at all records in `CLAUDE.md` the
  commands it runs instead (lint, test, build), and the local report covers those:
  `{commands from Phase 3}`. The bullet for "CI does not run on PRs" applies to them.

**Project-specific additions:**
{additions captured in Phase 5/8, or "_(none)_"}

---

## Design & Proposal Workflow

Write a proposal in `docs/proposals/NNNN-short-kebab-case-title.md` before implementing any:
- New module, service, or significant component
- Module boundary or data flow change
- New external API integration point
- Schema change affecting more than one entity
- Cross-cutting concern (caching, error handling strategy, etc.)
- New cloud resource type, network topology change, or new IAM role/policy with write/admin scope
- New secret, change to backup/retention, or change to the deployment pipeline

When a proposal is accepted, create the corresponding ADR in `docs/decisions/NNNN-title.md`
and update the proposal status to `Accepted`.

Write a design plan in `docs/design/NNNN-short-kebab-case-title.md` before implementing any
new or reshaped user-facing surface, or when porting a design handover from Claude. Routine
UI work that only consumes existing tokens and components does not need one.

See the `architect`, `design`, and `decision-log` skills for the exact proposal, design
plan, and ADR formats.

**Privacy screening**
([`RULES.md#privacy`](https://github.com/garethrhughes/skills/blob/main/RULES.md#privacy)).
Every feature doc and proposal answers the five-question `## Privacy screening` in
[`docs/privacy/README.md`](docs/privacy/README.md). For a PR with no feature doc (a fix,
dependency, configuration, infrastructure or CI change), the developer writes the
screening **before coding**, as the first action of implementation (create-feature Step
2), in a "Privacy screening" section of a **PR-description draft**, which is handed to
the reviewer and infosec as evidence and later becomes the PR description verbatim. Any
Yes: the developer writes the PIA then, before any code, with the header line `**PR:**
<branch or PR>, screening in the PR-description draft`, and infosec (create-feature Step
4) is required. A docs-only or tests-only PR needs none. **Adoption point:** feature
docs from `{first screened feature number}` and proposals from `{first screened proposal
number}` ({bootstrap: 0001 and 0001; onboard: the numbers after the newest existing
ones}); older documents are not checked unless reopened. **If `CLAUDE.md` records no
adoption point**, the newest feature-doc and proposal numbers that existed when the rule
was adopted, and every number below them, count as before it: neither the reviewer nor
infosec blocks them, and the reviewer asks the product owner to record the "first
screened" numbers (newest + 1) in `CLAUDE.md`. Any Yes means a PIA in `docs/privacy/`
from `TEMPLATE-pia.md`, written before implementation and built only as it lists.
Infosec is then required, and the reviewer BLOCKs a diff that logs or stores what the
PIA does not list. It is an engineering assessment, not legal advice: *Applicable
regimes and lawful basis* is {privacy decision owner from Phase 7}'s field.
{if the guard script was installed: "Run `node --test scripts/__tests__/privacy-screening.test.mjs` before a PR; its `FIRST_SCREENED_*` match the adoption point above."}

---

## Changelog

*(omit if the project keeps no user-facing changelog)*
`{changelog path}`, per [`RULES.md#changelog`](https://github.com/garethrhughes/skills/blob/main/RULES.md#changelog):
it says what changed since the last release, a fix to unreleased work amends the entry
that introduced it, and an entry is a bold headline plus at most two short sentences,
≤{limit, default 300} characters, on one line.

---

## Risk Register

[`docs/risk-register.md`](docs/risk-register.md) lists every risk {privacy decision owner
from Phase 7} has accepted, deferred or not yet treated. When you leave something open on
purpose (a residual an infosec review accepts, a fix deferred to a later release), add a
row there rather than only mentioning it in a PR or a report.

---

## Settled Decisions (do not revisit without a superseding ADR)

One line each: the rule as it stands. The ADR holds the detail.

| # | Decision |
|---|---|
{settled decisions from Phase 8, or "| — | *(none yet)* |" if empty}

---

## Edge Cases & Gotchas

*(omit if none)*
{edge cases from Phase 8}
```

---

### Output 2 — Project Context Block

Generate a concise `## Project Context` block for pasting into any skill file,
or for providing at the start of a conversation to load context into any skill.
This should be a dense, scannable summary — not the full CLAUDE.md.

```markdown
## Project Context

**Project:** {project name} — {one-line description}
**Skillset profile:** `{profile}` (rules: `RULES.md` + `rules/{profile}.md`)

**Backend:** {framework} / {language} / {database + ORM}
**Frontend:** {framework} / {styling} / {state management} *(or: backend-only)*
**Auth:** {auth approach}
**Validation:** {validation library}
**Logging:** {logger} → {logs backend}
**Testing:** {backend test framework} / {frontend test framework}

**Infra:** {iac tool} on {cloud}; state in {state backend}; secrets in {secrets manager}; CI/CD via {pipeline}
**Local dev:** {local dev setup}

**Compliance:** {framework or "none"}
**Data classes:** {scheme}
**Encryption:** at rest {approach} / in transit {TLS}

**Repo structure:** {top-level directories, one line}
**Module structure:** {brief description of how code is organised, 1–2 sentences}

**Key rules:** Standard rules from `RULES.md`. Project-specific additions:
- {any project-specific additions/overrides from Phase 5, or "_(none)_"}

**External integrations:** {list or "none"}
**Key entities:** {list with data classes, or "TBD"}
**Known gotchas:** {list or "none"}
**Jira:** {instance url, default project keys, AC location — or "none"}
```

---

## After Output

The post-output workflow has seven steps. Run them strictly in order. If any step fails,
stop and report the failure to the user before continuing — do not paper over a broken
scaffold by moving on.

### Step 1 — Detect local skills

Check whether skills are local to the project:

- Look for `.opencode/skills/` in the project root
- If it exists, list which SKILL.md files are present

### Step 2 — Insert Project Context into local skills

If `.opencode/skills/` exists, for each SKILL.md found, replace the `## Project Context`
placeholder block — the block that begins with the `> Fill in before use:` blockquote
and ends at the `---` rule that follows it — with the generated Project Context block
from Output 2. Do this for every skill file present.

Confirm to the user which files were updated, e.g.:
> "Updated Project Context in: architect, developer, reviewer, infosec, create-feature"

If `.opencode/skills/` does not exist, tell the user:

> "Skills are not local to this project. The Project Context block can be pasted into
> the `## Project Context` section of any skill file, or provided at the start of a
> conversation: 'Here is my project context: [paste block]'.
>
> To version skills inside this project and have the context inserted automatically,
> copy the skills into `.opencode/skills/` — see the skills README for instructions."

### Step 3 — Scaffold the Project

**Driving principle:** every file and directory created in this step must be derivable
from an answer the user gave in Phases 1–8. Do not invent structure, dependencies, or
config that the user did not select. Where the user accepted a default, use the expanded
default value (not the literal word "default").

**Inputs you must read before doing anything else:**

| Decision | Source |
|---|---|
| Repo layout (monorepo vs single-app, top-level dirs) | Phase 4 |
| Backend framework, language, ORM, validation, logger, test runner, auth | Phase 2 Round A |
| Frontend present? If so framework, styling, state, test runner | Phase 2 Round B |
| Local dev approach (Docker Compose? what services?) | Phase 3 |
| IaC tool, state backend, environments | Phase 3 |
| Task runner (Makefile, just, npm scripts only, etc.) | Phase 3 |
| Internal module structure (per-app folder layout) | Phase 4 |

State these inputs back to the user as a one-line summary before scaffolding, e.g.
"Scaffolding: monorepo with `backend/` (NestJS) and `frontend/` (Next.js); Docker Compose
for Postgres; OpenTofu under `infra/`; Makefile as task runner."

#### 3.1 Prefer official scaffolders

Where the chosen framework ships a first-party scaffolder, use it instead of
hand-writing files — it produces a known-good project file, linter config, and entry
point that the framework will keep in sync over time.

The exact command list lives in **`profiles/{profile}/scaffolders.md`**. Read the
table for the active profile and run the commands matching the framework choices
captured in Phase 2.

For convenience, the typical commands per profile:

**`typescript`** (full table in [`profiles/typescript/scaffolders.md`](../profiles/typescript/scaffolders.md)):

| Framework | Command |
|---|---|
| NestJS | `nest new <dir> --package-manager npm --skip-git` |
| Next.js | `npx create-next-app@latest <dir> --typescript --eslint --app --src-dir=false --tailwind=<yes\|no> --import-alias='@/*'` |
| Vite + React | `npm create vite@latest <dir> -- --template react-ts` |
| SvelteKit | `npx sv create <dir>` |

**`dotnet`** (full table in [`profiles/dotnet/scaffolders.md`](../profiles/dotnet/scaffolders.md)):

| Asset | Command |
|---|---|
| Solution | `dotnet new sln -n <Project>` |
| Web API (controllers) | `dotnet new webapi -n <Project>.Api --use-controllers` |
| Class library | `dotnet new classlib -n <Project>.<Layer>` |
| xUnit test project | `dotnet new xunit -n <Project>.Tests` |
| Blazor Server | `dotnet new blazorserver -n <Project>.Web` |

If the user chose something not listed, search the framework docs for an official
scaffolder before falling back to hand-written files.

After the scaffolder runs, **only then** layer on project-specific additions
(extra dependencies, the chosen ORM, the chosen logger, the chosen state library,
etc.) on top of the scaffolded baseline.

#### 3.2 Repo layout

Create the top-level structure exactly as captured in Phase 4. Do not assume
`backend/` + `frontend/` — a single-app repo has no such split, and a different
monorepo layout (e.g. `apps/api`, `apps/web`, `packages/shared`) must be honoured.

#### 3.3 IaC layout

Only create IaC directories if Phase 3 specified an IaC tool. If yes:

- Create the directory structure the user described (default: `infra/modules/` and
  one directory under `infra/envs/` per environment they listed)
- Create `infra/.gitignore` with patterns for the chosen tool:
  - OpenTofu / Terraform: `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfvars` (except `*.example.tfvars`), `.terraform.lock.hcl` is **kept** (committed)
  - Pulumi: `Pulumi.*.yaml` secrets, `node_modules/`
  - AWS CDK: `cdk.out/`, `*.js` (if TypeScript), `node_modules/`
- Pin provider versions where the chosen tool supports it (per `RULES.md#infrastructure-as-code`)

#### 3.4 Local dev

Only create `docker-compose.yml` if the user said Docker Compose in Phase 3. The
services in it must exactly match what the user said they need (e.g. only Postgres
if no Redis was mentioned). For non-Docker local dev (Devbox, Nix, native install),
follow whatever the user described.

#### 3.5 Task runner

Generate task-runner files **only for the runner the user chose** in Phase 3:

- **Makefile**: create one Makefile per app directory plus a root Makefile that delegates
- **just**: create a `justfile` instead of a Makefile
- **npm scripts only**: put everything in `package.json` `scripts`, no Makefile

Targets must be derived from what actually exists in the project. Don't include
`migrate` if there's no ORM with migrations. Don't include `dev-web` if there's no
frontend. Don't include `plan`/`apply` if there's no IaC. A reasonable default set
for a backend with a database and IaC is:

```
up        # start local dependencies (compose up -d, etc.)
down      # stop local dependencies
dev       # run the app in dev mode
test      # run the test suite
lint      # run linter + formatter check
build     # produce a production build
migrate   # only if migrations exist
plan      # only if IaC exists
apply     # only if IaC exists
```

In a monorepo, prefix targets with the app name (`dev-api`, `test-web`, etc.) and
make the root targets fan out.

#### 3.6 Lint & format config

Lint/format setup is profile-specific. See `profiles/{profile}/scaffolders.md` for the
exact tooling.

**`typescript`:**

- **ESLint**: flat-config format (`eslint.config.mjs`), not `.eslintrc.*`. If the
  framework's scaffolder produced a config, leave it in place and only add rules. At
  minimum, enable `@typescript-eslint` strict + the framework's recommended preset.
- **Prettier**: `.prettierrc.json` with `singleQuote: true`, `trailingComma: "all"`,
  `printWidth: 100`. Add `prettier-plugin-tailwindcss` only if Tailwind is in the stack.
  `.prettierignore` should list `dist/`, `build/`, `coverage/`, `.next/`,
  `node_modules/`.

**`dotnet`:**

- `.editorconfig` at the repo root enabling the .NET analyzers ruleset and code style
  rules.
- `dotnet format` (built-in) as the canonical formatter — wired into CI as
  `dotnet format --verify-no-changes`.
- `Directory.Build.props` with `<Nullable>enable</Nullable>` and
  `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`.
- Optional: `Roslynator.Analyzers` and `Microsoft.CodeAnalysis.NetAnalyzers`.

If the user has overridden any formatting choice in Phase 5, honour the override.

#### 3.7 Config & env

For each app:

- Create `.env.example` listing every env var the app needs, with safe placeholder
  values and a one-line comment per var. Variables come from the user's answers
  (database URL if there's a database, JWT secret if auth was selected, third-party
  API keys from Phase 7, etc.) — do not invent variables.
- Add `.env`, `.env.local`, `.env.*.local` to `.gitignore` per `RULES.md#configuration--secrets`.
- Wire env access through the typed config mechanism specified by the active overlay
  (`rules/{profile}.md` § *Configuration & Secrets*) — e.g. `ConfigService` for NestJS,
  a Zod-validated `config/` module for Next.js, `IOptions<T>` bound from
  `IConfiguration` for ASP.NET Core. Raw env-var access (`process.env`,
  `Environment.GetEnvironmentVariable`, etc.) must not happen outside that module.

#### 3.8 Docs directories

Create `docs/proposals/` and `docs/decisions/` regardless of stack — these are required
by the proposal/ADR workflow that all generated `CLAUDE.md` files reference. Add a
single `.gitkeep` in each so git tracks them while empty.

Also create `docs/features/` (written by `create-feature` / `jira-feature`) and, if the
project has a frontend, `docs/design/` (written by the `design` skill) — same `.gitkeep`
treatment.

Then install the process documents from the skills' [`templates/`](../templates/)
directory (see its README). They are found next to `rules/`: `.opencode/skills/templates/`,
or `.claude/templates/` / `.github/templates/` after the agent installers have run:

| Template | Install to |
|---|---|
| `templates/docs/corrections-log.md` | `docs/corrections-log.md` |
| `templates/docs/risk-register.md` | `docs/risk-register.md` |
| `templates/docs/privacy/README.md`, `TEMPLATE-pia.md`, `data-inventory.md` | `docs/privacy/` |
| `templates/scripts/privacy-screening.guard.mjs.template` | `scripts/__tests__/privacy-screening.test.mjs` (renamed), **only if the user said yes in Phase 7**; `FIRST_SCREENED_*` stay `1` for a new project |

Replace `{product owner}` with the privacy decision owner from Phase 7, and the README's
adoption-point placeholders with `0001` (a new project screens from its first document).
Never overwrite a file that already exists. If the guard was installed, run it once and
confirm it passes. Then write `9999-no-screening.md` (a heading and one line of text, no
screening; the number must be at or after `FIRST_SCREENED_FEATURE`) in a scratch
directory, run the guard with `PRIVACY_FEATURES_DIR` pointing at that directory, and
confirm the test for `9999-no-screening.md` fails. If the project's own test runner
would also collect `scripts/__tests__/*.test.mjs`, add it to that runner's exclude list.

#### 3.9 Install / restore dependencies

Run the install command appropriate to the active profile:

- **`typescript`:** `npm install` (or `pnpm install` / `yarn install` / `bun install`)
  in each app directory, or once at the root for a workspace-style monorepo.
- **`dotnet`:** `dotnet restore --use-lock-file` at the solution root to generate and
  commit `packages.lock.json`, then `dotnet restore --locked-mode` for subsequent
  installs.

Capture the output. If install/restore fails, stop and report the error — do not
proceed to the README or smoke test.

### Step 4 — Create Project README

Generate `README.md` at the repo root, populated from the user's actual answers and
the files just scaffolded. Do **not** invent commands — read the generated `Makefile` /
`justfile` / `package.json` `scripts` and document only what exists.

Sections (omit any that don't apply):

```markdown
# {project name}

{one-line description from Phase 1.2}

## Prerequisites

- Node {version pinned in package.json `engines.node`, or current LTS}
- {package manager} {version}
- Docker + Docker Compose *(only if Phase 3 uses it)*
- {IaC tool} {version} *(only if Phase 3 uses one)*
- {cloud CLI, e.g. AWS CLI v2} *(only if deploying to that cloud)*

## Quick Start

\```bash
# 1. Copy environment template
cp .env.example .env  # then fill in any [REQUIRED] values

# 2. Start local dependencies
{the actual command from the generated task runner, e.g. `make up`}

# 3. Install dependencies (skip if already done)
{the actual install command}

# 4. Run database migrations  *(only if ORM with migrations)*
{the actual migrate command}

# 5. Start the app(s)
{the actual dev command(s)}
\```

The {backend|app} will be available at http://localhost:{port from config}.
{If frontend: The frontend will be available at http://localhost:{frontend port}.}

## Available Commands

{Render a table of every target in the generated Makefile/justfile/scripts with
its one-line description.}

## Architecture

{1–2 sentences derived from the Project Context block.}

## Documentation

- [`CLAUDE.md`](./CLAUDE.md) — authoritative project context, conventions, and rules
- [`docs/features/`](./docs/features/) — feature briefs
- [`docs/proposals/`](./docs/proposals/) — technical design proposals
- [`docs/decisions/`](./docs/decisions/) — architecture decision records (ADRs)
- [`docs/design/`](./docs/design/) — UI design plans *(frontend projects)*
- [`docs/privacy/`](./docs/privacy/) — privacy screening, PIAs and the data inventory
- [`docs/risk-register.md`](./docs/risk-register.md) — accepted and deferred risks
- [`docs/corrections-log.md`](./docs/corrections-log.md) — what agents got wrong, and the checks that catch it

## Contributing

This project follows the conventions in [`CLAUDE.md`](./CLAUDE.md), which references
the canonical engineering rules. Please read it before opening a PR.
```

### Step 5 — Smoke test the scaffold

Verify the scaffold actually works before handing back to the user. Use the smoke-test
commands listed in `profiles/{profile}/scaffolders.md`. Run, in order, and stop at the
first failure:

1. **Typecheck / build:** for `typescript`, `npm run typecheck` (or `tsc --noEmit`)
   per app; for `dotnet`, `dotnet build --configuration Release --no-restore` at the
   solution root.
2. **Lint / format check:** for `typescript`, `npm run lint`; for `dotnet`,
   `dotnet format --verify-no-changes`.
3. **Build artefact** (if applicable): for `typescript`, `npm run build` per app. For
   `dotnet`, this is covered by step 1.
4. **Start local dependencies**: run the equivalent of `make up` (only if a local
   dependency stack exists). Wait for services to become healthy.
5. **Run migrations** (only if migrations exist) against the local database — for
   `typescript`, the TypeORM CLI command; for `dotnet`,
   `dotnet ef database update --project src/<Project>.Infrastructure --startup-project src/<Project>.Api`.
6. **Start the app(s)** in dev mode in the background, wait up to 30 seconds for
   readiness (e.g. poll `GET /health` for a backend with that endpoint, or watch
   for the framework's "ready on port X" log line). Then stop them.

Report each step's outcome to the user. If a step fails, surface the exact error
output and ask the user how they want to proceed (fix-and-retry vs. accept-and-move-on)
— do not silently continue.

### Step 6 — MCP Setup

Now that the project exists on disk, invoke the `mcp-setup` skill to let the user
choose which MCP servers to add. The mcp-setup skill will handle reading/writing
`opencode.json` and explaining each option.

### Step 7 — Finish

Tell the user:

> "Your project is bootstrapped, installed, and verified.
>
> Suggested next steps:
> 1. Commit `CLAUDE.md`, `README.md`, `opencode.json`, the `docs/` process documents
>    (privacy, risk register, corrections log), and any updated skill files to version control
> 2. Start developing — the dev command is `{actual dev command from the scaffold}`
> 3. If you have existing architectural decisions, run: `use the decision-log skill to seed the initial ADRs`
> 4. For your first feature, run: `use the create-feature skill`"
