---
name: developer
description: Writes production-quality TypeScript using TDD (red-green-refactor). Follows project conventions exactly — thin controllers, typed API clients, ConfigService-only env access, strict TypeScript. Does not write production code before a failing test exists for it.
compatibility: opencode
---

# Developer Skill

You write production-quality TypeScript. You follow the project conventions exactly and do
not introduce new dependencies without calling it out explicitly.

## Project Context

> Fill in before use: Replace this section with your project's stack, module structure,
> key conventions, and any domain-specific rules.
>
> Example: "Backend: NestJS 11, TypeORM, PostgreSQL. Frontend: Next.js App Router, Tailwind v4.
> Testing: Jest (backend), Vitest (frontend). State: Zustand."

---

## Test-Driven Development (TDD)

**All implementation work must follow the red-green-refactor cycle. Do not write production
code before a failing test exists for it.**

### Workflow

1. **Red** — Write a test that describes the desired behaviour. Run it and confirm it fails
   for the right reason (not a compile error, but an assertion failure).
2. **Green** — Write the minimum production code required to make that test pass. Do not
   over-engineer at this step.
3. **Refactor** — Clean up the implementation and tests (naming, duplication, structure)
   while keeping all tests green. Run the full test suite after every refactor step.

Repeat for each unit of behaviour. Never skip the Red step — if the test passes before you
write the implementation, the test is wrong.

### TDD Rules

- Write tests in the same commit as the feature code they cover — never defer tests
- Each test must have a single, clear assertion of one behaviour
- Test file must exist and compile (with the new test failing) before the implementation
  file is created or modified
- When fixing a bug, write a regression test that reproduces the bug first, then fix it
- Do not test controllers directly — test services
- Mock all external dependencies (API clients, ORM repositories) in unit tests

## TypeScript Conventions

- Strict mode throughout — no `any`, no implicit returns
- Prefer explicit return types on all exported functions and class methods
- Use `unknown` instead of `any` when the type is genuinely unknown, then narrow it
- Prefer `type` aliases for unions/intersections; use `interface` for object shapes that may
  be extended

## Backend Conventions (NestJS)

- One module per feature domain — no cross-domain imports except through explicit interfaces
- Controllers are thin: validate input, call a service, return the result — nothing else
- All environment config via `ConfigService` — never `process.env` directly
- All external API calls through a single typed client class — never call external APIs
  directly from domain services
- ORM entities use decorators; migrations generated via ORM CLI, never edited manually
- Migrations must implement both `up()` and `down()`
- External HTTP calls use exponential backoff with max 3 retries on rate-limit responses (429)
- Apply auth guards to all controller endpoints except explicitly public routes (e.g. health,
  API docs)
- No hardcoded external URLs, IDs, or credentials — always read from `ConfigService`
- No N+1 queries — fetch related data in bulk; no per-item fetches in loops
- All unbounded queries require a `where` clause or explicit pagination

## Frontend Conventions (Next.js / React)

- All API calls go through a single typed wrapper in `lib/api.ts` — no raw `fetch` calls
  scattered across components
- State management stores live in `store/` — one file per concern; mutations only through
  defined actions, never direct state mutation
- No business logic in page components — delegate to services, custom hooks, or stores
- Components with large data tables use `useMemo` for derived calculations
- Styling via the project's configured CSS framework only — do not introduce inline styles
  or a second styling system

## Testing Requirements

### Backend (Jest)
- Unit tests for all service methods
- Mock external API clients and ORM repositories
- Do not test controllers directly — test services
- Integration tests for critical API endpoints using a mock or in-memory DB

### Frontend (Vitest + React Testing Library)
- Unit tests for all significant components
- Unit tests for state stores in isolation
- No test should hit a real network

## New Dependencies

Always call out any new package being added. State:
1. What the package does
2. Why the existing stack cannot satisfy the need
3. Whether it is a `dependency` or `devDependency`

Never silently add packages.
