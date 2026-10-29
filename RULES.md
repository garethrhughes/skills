# Project Rules — Core

**Version:** 2.1
**Last updated:** 2026-10-29

Single source of truth for the **language-agnostic** conventions enforced across these
skills. Every skill references the sections below by anchor (e.g.
`RULES.md#configuration--secrets`) rather than restating the rules locally.

If you need to override a rule for your project, do so in your `CLAUDE.md` — never
weaken the rule here. See [Project Facts](#project-facts) for what else `CLAUDE.md`
holds.

---

## Active Stack Overlay

These core rules are deliberately language-agnostic. Stack-specific conventions
(language idioms, framework rules, ORM rules, logging library, test runner) live in
**stack overlay** files under [`rules/`](rules/):

| Profile | Overlay |
|---|---|
| `typescript` | [`rules/typescript.md`](rules/typescript.md) — TypeScript + NestJS + Next.js + TypeORM + pino + Jest/Vitest |
| `dotnet` | [`rules/dotnet.md`](rules/dotnet.md) — C# + ASP.NET Core + EF Core + Serilog + xUnit |

Your project's `CLAUDE.md` pins the active overlay via the `## Active Skillset` line —
written automatically by `project-bootstrap` or `project-onboard`. When no overlay is
pinned (legacy projects), skills default to `typescript`.

Skills should always read the **core rules in this file** plus the **active overlay**.
When the same concern appears in both (e.g. *Configuration & Secrets*), the overlay's
stack-specific implementation refines the principle stated here.

---

## Configuration & Secrets

- **All environment configuration goes through a typed config service / module.** The
  exact mechanism is stack-specific (see your overlay).
- **Raw environment-variable access (`process.env`, `Environment.GetEnvironmentVariable`,
  `os.environ`, etc.) must never happen outside the config module's setup code.** Any
  other read is a violation.
- **No hardcoded external URLs, IDs, region names, or credentials** — always read from
  config.
- **No secrets in source control.** Production secrets come from a managed secrets
  store (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, or equivalent).
  `.env` / `appsettings.{Environment}.json` files containing secrets are git-ignored;
  an `.env.example` (or equivalent template) is committed.
- **Lockfiles are committed and authoritative;** CI installs in frozen / locked mode.
  Exact lockfile and command are stack-specific (see your overlay).

---

## External HTTP Clients

- **Every external HTTP call has an explicit timeout.** Default 5s; override with
  documented justification.
- **Exponential backoff with jitter** on retryable failures (HTTP 429, 5xx, network
  errors). Bounded retry count — never unbounded.
- **One typed client per external service.** A single client class lives in its own
  module / service. Domain code never calls the raw HTTP API directly.
- All external responses are validated at the boundary before entering domain code.
  The validation library is stack-specific (see your overlay).

---

## Logging & Observability

- **Structured logging only** (JSON). Concrete logger and configuration are
  stack-specific (see your overlay).
- Every log line includes a correlation/request ID propagated from the request entry
  point.
- **Never log secrets, credentials, tokens, raw PII, or full request bodies.** Use
  redaction.
- Sensitive operations (auth, permission grants, data export, key rotation) emit an
  audit-log event.
- No raw stdout/console writes (`console.log`, `Console.WriteLine`, `print`, etc.) in
  production code paths.

---

## Infrastructure as Code (OpenTofu / Terraform)

These rules apply regardless of the application language.

- **Pinned provider versions** in `required_providers`. Lockfile committed.
- **Remote state** with locking (S3 + DynamoDB, or equivalent). No local state in
  shared environments.
- **Standard resource tags** on every taggable resource:
  `owner`, `env`, `service`, `cost-center`, `managed-by` (`managed-by=opentofu`).
- **No `*` action on `*` resource — ever.** No wildcard principals on trust policies.
- Admin-scope actions (`iam:*`, `kms:*`, `s3:*`, `*:Delete*`) must be resource-scoped
  and justified.
- Encryption at rest enabled on every data store (S3, RDS, EBS, DynamoDB, EFS, etc.).
- TLS in transit enforced (HTTPS-only listeners, `s3:x-amz-server-side-encryption`
  bucket policies, RDS `rds.force_ssl`, etc.).
- Public exposure (security groups `0.0.0.0/0`, public S3 buckets, public RDS) requires
  explicit justification in the proposal/ADR.
- Infrastructure changes go through `tofu plan` in CI and require human review.

---

## Testing

- **TDD: red → green → refactor.** Write the failing test first.
- Unit tests for pure logic. Integration tests for module boundaries (controller →
  service → repository). End-to-end tests for critical user flows.
- No tests committed in skipped / focused state (`.skip`, `.only`, `xit`, `xdescribe`,
  `[Fact(Skip = "…")]`, `@pytest.mark.skip` without a tracking issue, etc.).
- Mocks at boundaries only (HTTP, DB, filesystem). Do not mock the system under test.
- Concrete test runner, assertion library, and integration-test harness are
  stack-specific (see your overlay).
- **A test must be able to fail.** Before keeping it, break every line that enforces the
  control and watch the test go red. Conditional assertions, comparing output with the
  input it was generated from, and fakes that ignore their arguments cannot fail.
- **Guard every path.** A guard on one input path (keys) goes on every other path that
  writes the same state (pointer, paste, API, import, jobs), each with its own test. A
  guard that skips a write also restores what the operation already changed.
- **Re-run earlier mutations.** After each review round, re-run every earlier round's
  break-the-guard mutations on the final head and report that tally; assert where the
  guard acts.
- **No races with the machine.** Assert that asynchronous work or focus has settled
  before the next input. Pin the clock in any file whose code reads it, and run it once
  with the clock moved forward before you keep it.
- **Realistic fixtures.** A tool that rewrites a document is tested on real-shaped
  documents and with a round trip (writing back what was read changes nothing).

### Evaluation and Recall Gates

For any gate that scores a model, ranker, search or classifier against questions:

- Question sets are fixed and committed; never shuffled or sampled (seeded resampling
  may be reported, never gated).
- The calibration/gate split is a written, deterministic rule, set before any score is
  seen and re-derived by a test. Questions are committed before calibration output,
  preferably by someone other than the calibrator; the commit order is the evidence.
- Calibrate on the calibration half only, measuring the same statistic the bar gates (a
  per-pair distribution does not size a per-query bar).
- Bars are counts (`24 of 30`), and each set is sized so the split divides it exactly.
  Bars are fixed before the first run. A bar that fails its first run goes to the
  product owner; the only allowed fixes are a changed question set or split rule, in an
  amendment the owner approves, with new questions written by someone who has not seen
  the results. Never move a threshold or a count by hand.
- When a rule empties or moves part of a set, check every use of that part.

---

## Git & PRs

- Commit messages: imperative mood, ≤72 char subject, body explains *why*.
- One logical change per commit; one logical feature per PR.
- PRs include the proposal/ADR link, acceptance criteria checklist, and a summary of
  testing performed.
- CI must pass before merge: lint, typecheck/build, unit + integration tests,
  `tofu plan` for infra changes, dependency / SAST scan.
- **CI evidence.** `CLAUDE.md` records whether CI runs on pull requests.
  - *CI runs on PRs:* a review held before the PR exists records **"pending: hosted CI
    on the PR head"**; before merge the head must be green, and whoever opens the PR
    waits for the run and reports it, failures quoted.
  - *CI does not run on PRs* (or `CLAUDE.md` asks for a local report): a local CI report
    is required at review time. A project with no CI records in `CLAUDE.md` the
    commands it runs instead (lint, test, build); the report covers those.
  - A local report covers every CI job the change touches (all of them for a
    dependency, workflow or config change), runs against the committed head (pass the
    commit, e.g. `--ref <sha>`, and check the output names it), lists jobs run, failures
    and jobs SKIPPED. **A SKIPPED job is NOT VERIFIED.** Never push to the default branch
    to find out; run an untrusted ref only as a separate user or in a VM.
- **Review briefs** carry the original request, the diff and existing evidence (CI
  report or "pending", scanner output, privacy screening), never a list of what was
  done or where to look. A re-review gets the same brief.
- After each fix round, re-read the PR description, the report and the changelog entry
  against the files as they now are.

### Static Analysis

Semgrep runs on the changed files (`git diff --name-only --diff-filter=d
<base>...HEAD`, docs included) before a developer hands off, before a reviewer
finishes, and first in an infosec review. Use the Semgrep MCP server if available,
otherwise:

```sh
git -C <repo> diff -z --name-only --diff-filter=d <base>...HEAD | sed -z 's|^|<repo>/|' \
  | xargs -0 -r semgrep scan --metrics=off --max-target-bytes=0 \
      --json-output=<scratch>/semgrep.json --config p/owasp-top-ten --config p/secrets \
      <stack packs from the overlay> [--config p/github-actions]
```

`<base>` is the default branch (e.g. `origin/main`); add `--config p/github-actions` when
workflows change. (`sed -z`/`xargs -r` are GNU: `gsed`/`gxargs` on macOS.) Quote the summary (version,
rules, files). The JSON's `paths.scanned` must equal the diff's files (anything missing
is in `paths.skipped` with a reason). Severity by `extra.severity`: CRITICAL/HIGH/ERROR →
review Blocker / infosec REQUIRES CHANGES; MEDIUM/WARNING → Major / an issue in
context; LOW/INFO → Minor / noted. A read-only reviewer with no shell gets the file
list, summary and JSON from the caller. If it could not run, write `Semgrep: NOT RUN`
and why; it is never a clean scan.

---

## Changelog

For projects with a user-facing changelog:

- It says what changed **since the last release**. A fix to work merged after the last
  tag amends that work's entry; only shipped behaviour gets `Changed`/`Fixed`. Check
  with `git log <last tag>..HEAD`.
- An entry is a bold one-sentence headline plus at most two short sentences, on one
  line, written for a user (no internal names, intervals, options, rationale). Limit:
  **300 characters**, unless the project's `CLAUDE.md` sets another in one line.
- A user-visible change to shipped behaviour has an entry (missing → BLOCK); an entry
  has no second paragraph or nested list. Internal-only work gets no entry. A rule that
  can be measured gets a test.

---

## Privacy

Every change that may affect people's privacy is screened, and a flagged change gets a
**privacy impact assessment (PIA) before it is built**. The documents come from the
skills' [`templates/`](templates/README.md); a project without them installs them first.

- **Screening.** Feature docs and proposals carry `## Privacy screening`: these five
  questions, each answered Yes or No with a one-line reason, then a result line.
  1. Does it collect, derive, log, store, expose or send any new data about a person
     (identifiers included: account ids, entity ids, key prefixes, IPs, emails,
     timestamps, usage or behaviour)?
  2. Does it change who can see existing data (the user, an operator or admin, another
     user, a processor or sub-processor, an AI agent or integration)?
  3. Does it change how long data is kept, or how it is deleted, exported or purged
     (account deletion, purge jobs, backups, archives)?
  4. Does it add or change a third party, a region, a model, analytics, telemetry or a
     network call that carries user data?
  5. Does it derive new information about people (profiling, inference, embeddings,
     activity summaries)?

  Answer literally, for what the change does, not what the product already did: a new
  id column, audit field, log line, processor call, or an existing value shown on a new
  screen is a Yes.
- **A PR with no feature doc** (fix, dependency, config, infra, CI) gets its screening
  **before coding**, in a "Privacy screening" section of a PR-description draft that
  goes to the reviewer and infosec as evidence and becomes the PR description. A
  docs-only or tests-only PR says "Privacy screening: not applicable".
- **Any Yes means a PIA** in `docs/privacy/NNNN-title.md`, indexed in its README,
  written before implementation: with the proposal, in the feature-doc step, or (no
  feature doc) by the developer before any code, headed `**PR:** <branch or PR>`.
  Infosec is then required. All No: one sentence why.
- **A PIA is not legal advice.** *Applicable regimes and lawful basis* is the product
  owner's field and reads `legal review needed` until filled.
- **The PIA is the specification** for personal data: build only what it lists, keep
  data where and for as long as it says, make and test each deletion path it names, and
  update it (and the inventory) in the branch if the build differs.
- **The data inventory** (`docs/privacy/data-inventory.md`) cites a file per row;
  `unverified` is an open item to resolve before a claim rests on it. A PR that changes
  a row updates it (and a privacy policy kept in the repository).
- **Adoption point.** `CLAUDE.md` records the first feature-doc and proposal numbers
  screened (newest + 1 when adopting; `0001` for a new project; the guard's
  `FIRST_SCREENED_*`). Older documents are exempt unless reopened (then listed in
  `ALSO_SCREENED_*`). If none is recorded, documents that existed at adoption are
  exempt (neither reviewer nor infosec blocks them) and the reviewer asks the owner to
  record it.
- **Gates.** A missing screening, a Yes without a PIA, or a diff beyond the PIA is a
  review BLOCK and an infosec REQUIRES CHANGES.

---

## Risk Register

- `docs/risk-register.md` lists risks the product owner **accepted, deferred or has not
  treated**, with likelihood, impact, owner, treatment, status (who decided, when, their
  words) and a review date. IDs are `R-NNN`, never reused.
- **Anything left open on purpose gets a row**: an accepted infosec residual, an
  `APPROVED WITH EXCEPTION` (infosec proposes the ID and text; the row is written with
  the ADR and must exist before merge), a deferred fix, a gap a PIA leaves.
- Fixed findings do not belong there; close a row by moving it to *Closed* with its
  commit or ADR.

---

## Evidence, Corrections & Decisions

For every agent, at every step:

- **Check before you claim.** Before writing *done*, *out of scope*, *resolved*,
  *pre-existing* or *not affected*, run the command that proves it and cite it;
  reproduce a "pre-existing" failure on the merge base. Narrowing scope is the product
  owner's call.
- **Read the diff back** before claiming a change. A refused write is a requirement
  **not met**; never claim a substitute.
- **Report failures**: quote the whole result line, and say whether you caused them.
- **Fix at the source.** Fix a shared function where it is wrong, then find every other
  writer of the same state. Rule out another caller by testing each symptom there.
- **Reconcile every copy.** When a rule, claim or name changes, search every file the
  branch touches for the old wording, and check both ends of every link.
- **After removing a dependency, file or name**, search `docs/`, `CLAUDE.md` and the
  agent/skill files for it.
- **State what a mitigation does not cover**: construct each failure and confirm the
  control fires; observe (old vs new code) before claiming a behaviour changed.
- **Cheap confirmation beats reasoning**, including when disagreeing with a reviewer:
  run the minute-long probe. Check your own background processes before diagnosing a
  contradicting failure; never kill by pattern.
- **Never `cd`** in an agent's shell command: use the tool's working-directory
  parameter, absolute paths, `git -C`, `npm --prefix`. One directory per call;
  `git status` after any stash or checkout.
- **Outward actions.** A feature cycle the product owner started is permission to push
  its branch and open its PR. Anything else outward (triggering workflows, deploying,
  pushing to the default branch) needs an explicit request.
- **Decisions.** Put each owner decision with its options, consequences and a
  recommendation; record the answer quoted and dated. A decision an agent took on the
  owner's behalf is marked "pending review".
- **Corrections log** (`docs/corrections-log.md`): read its Patterns before deciding;
  append what was claimed, what was true and the check that would have caught it,
  under the pattern it repeats.

---

## Project Facts

- Project facts (stack, structure, conventions, decisions, overrides) live **only** in
  the project's `CLAUDE.md`. Skills read it first; they carry no per-project block.
  `CLAUDE.md` is loaded into every session, while a skill's block was read only when
  that skill ran, and one copy cannot drift between skills.
- `CLAUDE.md` holds rules and pointers, not history. A settled decision is one line:
  the rule as it stands and the ADRs it amends or supersedes.
