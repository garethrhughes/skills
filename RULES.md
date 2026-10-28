# Project Rules — Core

**Version:** 2.1
**Last updated:** 2026-10-29

Single source of truth for the **language-agnostic** conventions enforced across these
skills. Every skill references the sections below by anchor (e.g.
`RULES.md#configuration--secrets`) rather than restating the rules locally.

If you need to override a rule for your project, do so in your `CLAUDE.md` and the
`## Project Context` block of the relevant skill — never weaken the rule here.

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
- **A test that cannot fail is worse than no test.** Before keeping a test, break what it
  guards and watch it fail. Break **every** line that enforces the control, not one per
  control. Conditional assertions (`if (x) expect(...)`), a check of generated output
  against the input it was generated from, and a fake that returns the expected answer
  whatever it was asked are the usual ways a test cannot fail.
- **A guard on one input path needs its twin.** When a guard is added to one path that
  writes some state (keyboard), list every other path that writes the same state
  (pointer, paste, API, import, a background job). Give each one the same guard and its
  own test. A guard that skips a write also restores anything the operation already
  changed before it decided.
- **Re-run earlier rounds' mutations on the final head.** A later fix can make an
  earlier guard's test unable to fail. After each review round, re-run every earlier
  round's break-the-guard mutations on the final commit and report that tally. Assert at
  the point where the guard acts, not only at the end.
- **Tests must not depend on an idle machine.** After an action that hands work or focus
  over asynchronously (a frame, a timer, an effect, a transition), assert that it settled
  before you drive the next input. Never focus an element and press a key in the same
  breath. A test whose code under test reads the clock (windows, expiry, staleness, TTLs)
  pins the clock for the whole file. Run it once with the clock moved forward before
  you keep it.
- **Test on fixtures shaped like real data.** A tool that rewrites part of a document is
  tested on documents with blank lines, lists and nesting, and asserts a round trip
  (writing back what was read changes nothing).

### Evaluation and recall gates

Applies to any gate that scores a model, ranker, search or classifier against a question
set:

- **Fixed, committed question sets.** Every run uses the same questions and gives the
  same result. Never shuffle or sample a set. Resampling (for example a bootstrap
  interval) uses a fixed, committed seed and is reported, never gated.
- **A written, deterministic calibration/gate split.** Write the split rule down before
  any score is seen (for example "every 3rd question per topic is calibration"). A test
  re-derives the split from the committed order and fails if the files differ.
  Questions are written, and committed, before the calibration output exists, ideally
  by someone other than the person who calibrates. The commit order is the evidence.
- **Calibrate on the held-out calibration split only.** Never fit thresholds on the
  questions the gate grades. The calibration measures **the same statistic the bar
  gates** (a per-query maximum, a rank, a share). A per-pair distribution does not size
  a per-query bar.
- **Size bars for their counts.** On 10–30 questions a rate moves in large steps, so
  state bars as counts ("24 of 30") or paired tests, and size each set so the split
  divides it exactly.
- **Bars are fixed before the first run.** A bar that fails its first run goes to the
  product owner. It may be a real problem or a set that is too strict, and only a person
  can tell which. The only fixes allowed are a changed question set or split rule. Each
  one is recorded in an amendment the product owner approves, and a person who has not
  seen the per-query results writes the replacement set. Never move a threshold or
  count by hand to make a bar pass.
- When a rule empties or moves part of a set (for example making it gate-only), search
  every use of that part and make each agree.

---

## Git & PRs

- Commit messages: imperative mood, ≤72 char subject, body explains *why*.
- One logical change per commit; one logical feature per PR.
- PRs include the proposal/ADR link, acceptance criteria checklist, and a summary of
  testing performed.
- CI must pass before merge: lint, typecheck/build, unit + integration tests,
  `tofu plan` for infra changes, dependency / SAST scan.
- **Run CI locally before every PR**, and always when CI does not run on pull requests.
  Run every CI job the change touches, and all of them for a dependency, workflow or
  config change. Run against the **committed** branch: pass the commit explicitly (for
  example `--ref <sha>`) when the runner resolves the repository from the working
  directory, and check that its output names the commit you meant. A worktree run can
  otherwise test the main checkout. The PR carries the report: the jobs that ran, their
  results with failures quoted, and the jobs **SKIPPED**. A SKIPPED job is **NOT
  VERIFIED**, never "passing". Never use a hosted CI run to find out whether a change
  passes.
- **Brief reviewers with the original request and the diff only.** Never send a list of
  what was done or where to look. A reviewer given the fixes confirms the fixes. A
  re-review gets the same brief as the first review.
- The PR description is another writer of the change's claims. After each fix round,
  re-read it, the report and the changelog entry against the files as they now are.

---

## Changelog

For projects that keep a user-facing changelog (`CHANGELOG.md` or equivalent):

- **The changelog says what changed since the last release.** Its reader is a user of
  that release. A fix to, or a change in, something merged after the last release tag
  gets no entry of its own: amend the entry that introduced it so it describes the final
  behaviour. Only a change to behaviour a release shipped gets `Changed`, and only a bug
  that shipped gets `Fixed`. Test: would a user of the last release see this as new, or
  as a change? Check with `git log <last tag>..HEAD` over what the entry modifies.
- **Entries are short.** A bold one-sentence headline (what the user can now do, or what
  changed for them), plus at most one or two short sentences. Default limit **300
  characters**, on one line, with no second paragraph and no nested list. Write it for a
  user: no intervals, internal or component names, option lists, rationale or caveats.
  That detail goes in the help article, feature doc or ADR. Test: would a user read this
  to the end?
- Internal-only work (refactors, tests, CI, docs for developers) gets no entry.
- A rule that can be measured gets a check, not only prose: a test over the
  unreleased section (length, headline, one line) is cheap and stops the drift.

---

## Privacy

Every change that may affect the privacy of the people whose data the system holds is
screened, and any change the screening flags gets a **privacy impact assessment (PIA)
before it is built**.

- **Screening.** Every feature document and every proposal carries a `## Privacy
  screening` section. A fix PR with no feature doc carries it in the PR description.
  It holds five questions, each answered Yes or No with a one-line reason, and a result
  line:
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

  Answer for what the change does, not for what the product already did, and be
  literal. A new column holding an account id, a new audit field, a log line with a
  route or a count, an existing value on a new screen, or a new call to a processor is
  a Yes.
- **Any Yes means a PIA** in `docs/privacy/NNNN-short-title.md`, from the template,
  indexed in `docs/privacy/README.md`. It is written before implementation: by the
  architect with the proposal, or in the feature-document step when there is no
  proposal. All No: one sentence why, and the screening is still recorded.
- **A PIA is an engineering and product assessment, not legal advice.** No agent states a
  legal conclusion. *Applicable regimes and lawful basis* is the product owner's field.
  It reads `legal review needed` until they fill it.
- **The PIA is the specification for personal data.** Build only what its data table
  lists: record, log, store, expose and send nothing more, keep it where and for as long
  as it says, and make and test each deletion path it names. If the build has to differ,
  update the PIA in the same branch before review.
- **A data inventory** (`docs/privacy/data-inventory.md`) is the standing list of
  personal data the system holds. It cites a file for each row and says `unverified`
  where the code could not show it. An `unverified` is an open item, not a footnote:
  read the code to the end before any claim rests on it. The PR that changes a row
  updates the inventory, and the privacy policy if one is kept in the repository.
- **Gates.** A missing screening, a Yes with no PIA, or a diff that logs or stores
  something the PIA does not list is a review BLOCK and an infosec REQUIRES CHANGES.
  Infosec sign-off is required on every PR that has a PIA.

---

## Risk Register

- `docs/risk-register.md` lists every risk the product owner has **accepted, deferred
  or not yet treated**: ID, risk, likelihood, impact, owner, mitigation or treatment,
  status (with who decided, when, and their words), when raised, and when to review.
- **Leaving something open on purpose means a row**: a residual an infosec review
  accepts, an `APPROVED WITH EXCEPTION`, a fix deferred to a later release, or a gap a
  PIA leaves. Mentioning it in a PR or a report is not enough.
- A fixed finding does not belong there. A row is closed by moving it to *Closed* with
  the commit or ADR that closed it. IDs are never reused.

---

## Evidence, Corrections & Decisions

Process rules for every agent, at every step. Each is here because the opposite shipped
past review more than once.

- **Check before you claim.** Before you write *already done*, *out of scope*,
  *resolved*, *pre-existing* or *not affected*, run the command that proves it and cite
  the output. Reproduce a "pre-existing" failure on the merge base. Narrowing scope is
  the product owner's call, never the agent's.
- **Read the diff back.** Before you claim a document or file was changed, `git diff`
  the passage. A refused write is a requirement **not met**: say so wherever status is
  reported, and never claim a substitute.
- **Report failures, not the passing count.** Quote the whole result line. If something
  fails, say whether you caused it and how you know.
- **Fix a shared function at the source.** When a shared function returns a wrong
  answer, reproduce it at that function and fix it there, not at the caller that
  noticed. After fixing a write, find every other writer of the same state and fix or
  rule out each one. To rule out another caller of a shared defect, test every symptom
  the fix addresses at that caller.
- **Reconcile every copy.** When a rule, claim or name changes, grep every file the
  branch adds or changes (proposal, ADR, PIA, risk register, `CLAUDE.md`, agent and
  skill files) for the old wording and the names it travels with. Fix or rule out each
  hit. When a guard checks a link, check both ends of it.
- **After removing a dependency, file or name**, search the docs, `CLAUDE.md` and the
  agent/skill files for it.
- **State what a mitigation does not cover.** For each risk a control is said to
  mitigate, construct the failure and confirm the control fires. Before a record says a
  change alters a behaviour, run the old and the new code against that case.
- **Cheap confirmation beats confident reasoning.** If a probe, browser or command can
  settle a question in under a minute, run it instead of reasoning, and that includes
  disagreeing with a reviewer. Before you investigate a failure that contradicts an
  earlier pass, list your own background processes and ports, and never kill
  processes by pattern.
- **Never `cd` in an agent's shell command.** Name the directory in the command: the
  shell tool's working-directory parameter where it has one, otherwise absolute paths,
  `git -C <dir>`, `npm --prefix <dir>` or `dotnet --project <path>`. A `cd`, even in a
  chain, can raise a permission prompt that halts an unattended run. Use one directory
  per call. After any stash or checkout, run `git status` and confirm the tree is what
  you think it is.
- **Do not act outward without asking.** Pushing, opening PRs, triggering workflows and
  deploying are the product owner's calls. Do them only when asked (a feature cycle the
  owner started that ends in a PR counts), and offer the lighter option.
- **Record decisions with their options.** A question for the product owner sets out the
  options with their consequences and a recommendation. Record the answer quoted, with
  the date. Mark a decision an agent took on the owner's behalf as "pending review".
- **Keep a corrections log** (`docs/corrections-log.md`). Its **Patterns** section is read
  before deciding. Its ledger records each time an agent was wrong or a decision was
  pushed back: what was claimed, what was true, and the cheapest check that would have
  caught it. Append an entry when you get something wrong, and file a recurrence under
  its existing pattern.
