---
name: create-feature
description: The full feature development cycle as a numbered checklist — from proposal through implementation, review, infosec sign-off, decision logging, and PR. Defines when each agent handoff happens, the dedicated path for infrastructure changes, and how to handle iteration loops.
compatibility: opencode
---

# Create Feature Skill

This skill describes the complete feature development cycle used in this project. Follow
these steps in order for any non-trivial piece of work. Each step maps to a specific skill.

## Project Context

> Fill in before use: Replace this section with your project's conventions, repository
> locations for proposals and decisions, and any team-specific workflow notes.
>
> Example: "Proposals: docs/proposals/. Decisions: docs/decisions/. Branches: feature/NNNN-short-title.
> PRs target main. CI runs Jest + Vitest + `tofu plan`. Compliance: ISO27001."

---

## Authoritative Rules

Project-wide engineering conventions enforced across every step of this cycle live in two
layers:

1. The language-agnostic core in [`RULES.md`](../RULES.md).
2. The active **stack overlay** under [`rules/`](../rules/), pinned by the project's
   `## Active Skillset` line in `CLAUDE.md` — e.g.
   [`rules/typescript.md`](../rules/typescript.md) or
   [`rules/dotnet.md`](../rules/dotnet.md).

Each downstream skill (`architect`, `design`, `developer`, `reviewer`, `infosec`) reads the
same two files. When orchestrating a feature, treat (`RULES.md` + the active overlay) as the
contract that all output must satisfy.

If `CLAUDE.md` does not declare an active skillset, downstream skills default to the
[`typescript`](../rules/typescript.md) overlay.

---

## Feature Intake

Before starting the cycle, gather the feature brief from the user.

Ask the following in a single prompt — do not drip-feed one question at a time:

> "Before we start, I need a brief for this feature:
>
> 1. **Feature description** — What should this feature do? Describe the desired behaviour from the user's or system's perspective.
> 2. **Acceptance criteria** — What conditions must be true for this feature to be considered complete? List them as bullet points if possible (e.g. "Given X, when Y, then Z").
>
> You can be as concise or detailed as you like — I'll use this to drive the proposal in Step 1."

Wait for the user's response. Do not proceed until both a description and at least one acceptance criterion have been provided.

Once received, reflect the brief back in a compact summary table:

```
| Field                | Provided value                              |
|----------------------|---------------------------------------------|
| Feature description  | {description}                               |
| Acceptance criteria  | {criterion 1}                               |
|                      | {criterion 2}                               |
|                      | ...                                         |
```

Ask: "Does this capture what you need? Confirm to proceed, or correct anything above."

Wait for confirmation before moving to Step 1.

---

## Feature Document

Once the brief is confirmed, write a feature document to `docs/features/` **before**
invoking the architect skill. This document is the canonical record of what was requested
and why, and it persists independently of the proposal (which describes *how* to implement it).

### File naming

```
docs/features/NNNN-short-kebab-case-title.md
```

Increment NNNN sequentially from the highest existing number in `docs/features/`. Start
at 0001 if no files exist yet.

### Feature document format

```markdown
# NNNN — Feature Title

**Date:** YYYY-MM-DD
**Status:** Draft | In Progress | Implemented | Cancelled
**Source:** Manual | Jira:{KEY} | GitHub:{issue-url}
**Related proposal:** docs/proposals/NNNN-short-title.md *(populated after Step 1)*

## Summary

One or two sentences describing what this feature does from the user's or system's
perspective.

## Background / Motivation

Why is this feature needed? What problem does it solve or what opportunity does it
capture? Reference any relevant context (user feedback, error rates, product requirement,
linked ticket, etc.).

## Scope

**In scope**
- Bullet list of what this feature covers.

**Out of scope**
- Anything explicitly excluded, to prevent scope creep.

## Acceptance Criteria

- Given {context}, when {action}, then {outcome}
- *(one bullet per criterion — specific and testable)*

## Privacy screening

| # | Question | Answer | Why |
|---|---|---|---|
| 1 … 5 | *(copy the five rows from `docs/privacy/README.md`, questions word for word)* | Yes / No | one line each |

**Result:** No PIA: one sentence why. *(or)* PIA: [docs/privacy/NNNN-title.md](../privacy/NNNN-title.md)

## Open Questions

List anything that needs answering before or during design. If none, write "None."
Each question for the product owner gives the options with their consequences and a
recommendation.

## Decisions

The product owner's answers, quoted with the date ("{name}, YYYY-MM-DD: …"). A decision
taken on their behalf is marked "on {name}'s behalf, pending their review".

## Notes

Any additional context, constraints, or decisions that should inform the architect.
```

**Privacy** ([`RULES.md#privacy`](../RULES.md#privacy)): answer the screening for what
this feature does, literally. Any Yes means a PIA in `docs/privacy/` from
`docs/privacy/TEMPLATE-pia.md`, written **before implementation**: by the architect with
the proposal, here when there is no proposal, or, for a PR with no feature doc, by the
developer before any code (header line `**PR:** <branch or PR>, screening in the
PR-description draft`). Infosec then becomes required in Step 4. Leave *Applicable
regimes and lawful basis* to the product owner. If `docs/privacy/` does not exist yet (a
project set up before these rules), install it from the skills' `../templates/` as
[`../templates/README.md`](../templates/README.md) describes (replace `{product owner}`
and the adoption-point placeholders), and say so in the PR. If the project installed the
privacy-screening guard, run it.

After writing the file, confirm to the user:

> "Feature document written to `docs/features/NNNN-short-title.md`. Proceeding to design."

---

## The Full Feature Development Cycle

### Step 1 — Design (Architect skill)

**When:** Before writing any code for a non-trivial change.

Use the **architect** skill to:
1. Determine whether the change warrants a proposal (see the architect skill's "When to Write
   a Proposal" section — note this includes infra-only changes such as new IAM policies,
   network changes, new resources)
2. If yes: write a proposal in `docs/proposals/NNNN-short-title.md` with its
   **Privacy screening** (and the PIA for any Yes), including the
   **Infrastructure Addendum** if any infra is touched
3. **Present the completed proposal to the user as a structured summary table, then ask for sign-off:**

   ```
   | Section                  | Summary                                      |
   |--------------------------|----------------------------------------------|
   | Problem / motivation     | {one-line summary}                           |
   | Proposed solution        | {one-line summary}                           |
   | Acceptance criteria      | {criterion 1}                                |
   |                          | {criterion 2}                                |
   | Key design decisions     | {decision 1}                                 |
   |                          | {decision 2}                                 |
   | Infrastructure changes   | {yes — {summary} / no}                       |
   | Security considerations  | {yes — {summary} / none identified}          |
   | Privacy                  | {screening all No / PIA docs/privacy/NNNN}   |
   | Proposal file            | docs/proposals/NNNN-short-title.md           |
   ```

   Then ask:

   > "Does this proposal meet the brief? Reply **accept** to proceed to implementation,
   > or provide feedback and I'll revise and re-present."

   Do not proceed until the user explicitly accepts. If the user provides feedback, incorporate
   it, update the proposal, update the summary table, and ask again. Repeat until the user accepts.
4. Once accepted: update the proposal status to `Accepted`
5. Update the feature document's **Related proposal** field with the proposal file path

Any ADR(s) the accepted proposal produces are created in **Step 5** by the `decision-log`
skill, which is the sole owner of ADR creation. The architect hands off to it rather than
writing `docs/decisions/` files directly.

**Skip this step only for:** trivial bug fixes, copy changes, or configuration tweaks that
do not affect architecture, module boundaries, schema, infra, or security posture.

**Handoff to Step 2 when:** the user has explicitly accepted the proposal (or the change is
confirmed as trivial) — via Step 1.5 first if the feature has UI surface.

---

### Step 1.5 — Design Direction (Design skill)

**When:** The proposal is accepted **and** the feature introduces or reshapes user-facing
UI, or a design handover from Claude exists for it.

Skip this step for backend-only, infra-only, or docs-only features, and for routine UI work
that only consumes tokens and components the project already has.

Use the **design** skill to:
1. Classify the work (handover port / net-new / restyle) and read the project's styling
   system and existing design system
2. For a handover: extract the token system from the artifact and produce the port report
   listing everything that cannot cross into the codebase as-is
3. Write a design plan to `docs/design/NNNN-short-title.md` — tokens, layout, component
   map, copy, accessibility floor, divergences — and update `docs/design/README.md`
4. Audit the plan for genericness and restraint, then present it and get explicit sign-off
5. Set the plan's status to `Accepted` and back-link it from the feature document

**Handoff to Step 2 when:** the user has explicitly accepted the design plan. The developer
implements against the accepted plan; the reviewer traces the built UI back to it in Step 3.

---

### Step 2 — Implementation (Developer skill)

**When:** Proposal is accepted (or change is confirmed trivial), and — for UI-bearing work
— the design plan from Step 1.5 is accepted.

Use the **developer** skill to:
1. Create a new branch: `git checkout -b feature/NNNN-short-title` *(adjust the branch
   naming convention to match your project's standard, or use the convention defined in
   your CLAUDE.md)*
2. Follow the red-green-refactor TDD cycle for every unit of behaviour:
   - Write a failing test first
   - Write the minimum code to make it pass
   - Refactor while keeping tests green
3. Follow all project conventions (thin controllers, typed API client, ConfigService,
   no `any`, no implicit returns, structured logging, validated DTOs)
4. **For infra changes:** edit IaC under `infra/`, run `terraform plan` (or equivalent)
   locally, capture the plan summary for the PR description. Never apply to a shared
   environment from a developer machine
5. Call out any new dependencies (npm packages, Terraform modules, providers) explicitly
   before adding them
6. **For UI changes:** implement against the accepted design plan from Step 1.5 — tokens
   into the token layer first, then components. The `design` skill owns Phase 4/5 of that
   work (implementation and the accessibility/visual critique); record any divergence from
   the plan in the plan's Divergences section
7. **Privacy:** build only what the PIA lists; update the PIA and the data inventory in
   the branch if the build differs
8. **Changelog** (if the project keeps one) per [`RULES.md#changelog`](../RULES.md#changelog):
   amend the entry of unreleased work rather than adding one; short, one line
9. Run the full test suite and Semgrep on the changed files. **CI evidence**
   ([`RULES.md#git--prs`](../RULES.md#git--prs)): Where hosted CI runs on pull requests,
   a review held before the PR exists records the CI evidence as **"pending: hosted CI
   on the PR head"**; the gate is re-checked on the PR head before merge: green is
   required to merge, and the agent that opens the PR waits for the run and reports it,
   failures quoted. Where CI does not run on pull requests (or the project's `CLAUDE.md`
   requires a local report), the local CI report is required at review time. A project
   with no CI at all records in `CLAUDE.md` the commands it runs instead (lint, test,
   build), and the local report covers those. Run **CI locally** then, on the committed
   branch, for every job the change touches, and record the jobs that ran, with failures
   quoted, and those SKIPPED (**NOT VERIFIED**)

10. **PR-description draft.** For a PR with no feature doc (a fix, dependency,
    configuration, infrastructure or CI change), the developer writes the screening
    **before coding**, as the first action of implementation, in a "Privacy screening"
    section of a **PR-description draft**, which is handed to the reviewer and infosec
    as evidence and later becomes the PR description verbatim. Any Yes: the developer
    writes the PIA then, before any code, with the header line `**PR:** <branch or PR>,
    screening in the PR-description draft`, and infosec (Step 4) is required. Start the
    draft here in any case (summary, tests, CI evidence) so Steps 3 and 4 receive it and
    Step 6 uses it.

**Handoff to Step 3 when:** all tests pass and the branch is ready for review.

---

### Step 3 — Code Review (Reviewer skill)

**When:** Implementation is complete and tests are green.

**CI evidence at review time:** where CI runs on pull requests, the PR does not exist yet,
so the reviewer records "pending: hosted CI on the PR head" and Step 6 re-checks it
before merge. Where it does not, the local CI report from Step 2 goes to the reviewer.

**Brief the reviewer** ([`RULES.md#git--prs`](../RULES.md#git--prs)): Brief reviewers
with the original request, the diff, and existing evidence (the local CI report or
"pending: hosted CI on the PR head", scanner output, and the privacy screening), never a
list of what was done or where to look. A reviewer given the fixes confirms the fixes. A
re-review after a fix round gets the same brief as the first review. For a PR with no
feature doc, the evidence includes the PR-description draft from Step 2 with its
"Privacy screening" section.

Use the **reviewer** skill to:
1. Trace each Acceptance Criterion from the proposal to a covering test
2. Review all staged / branch changes for correctness, security, performance, IaC safety,
   observability, and convention adherence
3. For UI changes: check the built UI against the accepted design plan, and against the
   accessibility floor
4. Return a verdict: PASS / PASS WITH COMMENTS / BLOCK

**If BLOCK or Major findings:**
- Return to **Step 2** (developer) to address all Blocker and Major findings
- Re-run the reviewer skill after fixes
- Repeat until the verdict is PASS or PASS WITH COMMENTS

**If PASS or PASS WITH COMMENTS:**
- Acknowledge Minor/Suggestion items (fix or consciously defer)
- Proceed to Step 4

**Handoff to Step 4 when:** reviewer verdict is PASS or PASS WITH COMMENTS with all
Blockers and Majors resolved.

---

### Step 4 — Infosec Sign-Off (Infosec skill)

**When:** Code review has passed AND the change touches any of:

- Authentication, authorisation, or session handling
- User data (read, write, export, deletion)
- Cryptography (encryption, hashing, key management, secrets)
- Logging or audit trails (added, removed, or modified)
- Infrastructure (IAM, network, secrets manager, KMS, public endpoints)
- A new external integration
- A new dependency that handles credentials, crypto, or PII
- A privacy impact assessment (any Yes in the privacy screening)

For pure UI / pure refactor / pure docs changes with none of the above, **skip this step**.

If infosec has no shell or Semgrep tool (it is read-only), run Semgrep on the changed
files first (the CLI command in the `reviewer` skill) and hand infosec three things: the
diff's file list, the text summary and the JSON, with the same brief the reviewer got
(the original request, the diff, and the existing evidence, including the PR-description
draft for a PR with no feature doc). If Semgrep cannot run, say so and why. Infosec
then records `Semgrep: NOT RUN`.

Use the **infosec** skill to:
1. Run the project's compliance review against the diff (e.g. ISO27001 controls if applicable)
2. Verify no plaintext secrets, no over-broad IAM, no PII in logs, no missing auth guards,
   no insecure crypto choices
3. Return a verdict: APPROVED / REQUIRES CHANGES / APPROVED WITH EXCEPTION

**If REQUIRES CHANGES:**
- Return to **Step 2** to fix
- Re-run infosec after fixes
- Document any APPROVED WITH EXCEPTION findings as ADRs in Step 5, and each as a row in
  `docs/risk-register.md`

**Handoff to Step 5 when:** infosec verdict is APPROVED or APPROVED WITH EXCEPTION
(with exceptions queued for ADR).

---

### Step 5 — Decision Logging (Decision Log skill)

**When:** Implementation is reviewed, infosec-approved, and accepted.

Use the **decision-log** skill to log any significant decisions made during Steps 1–4:
- Technology or library chosen
- Architectural pattern adopted
- Infrastructure topology choice
- Trade-off made between approaches
- Edge case resolution agreed
- Security exception accepted (each one becomes an ADR)
- Proposal accepted (if not already logged in Step 1)

Update any proposals in `docs/proposals/` whose status is still `Draft` or `Under Review`
to `Accepted`, linking the ADR numbers. Add a **one-line** row per new settled decision
to `CLAUDE.md` (the rule as it stands, plus which ADRs it amends or supersedes). If
anything went wrong along the way (a claim that was untrue, a decision pushed back),
append it to `docs/corrections-log.md`.

**Handoff to Step 6 when:** all relevant ADRs are written and the index is updated.

---

### Step 6 — Pull Request

**When:** Steps 1–5 are complete.

1. Push the branch to remote: `git push -u origin feature/NNNN-short-title`
2. Open a PR targeting `main` (or the project's default branch)
3. In the PR description, include:
   - A summary of what changed and why
   - Link to the feature document (`docs/features/NNNN-short-title.md`)
   - Link to the accepted proposal (if one exists)
   - Link to the accepted design plan and the Phase 5 screenshots (for UI changes)
   - Link to any new ADRs created
   - Test coverage summary (new tests added, the full result line with failures)
   - The CI evidence: where CI does not run on pull requests, the local CI report (jobs
     run and results, jobs SKIPPED = NOT VERIFIED); where it does, "pending: hosted CI on
     the PR head", replaced by the result once the run finishes
   - The Semgrep summary, or `Semgrep: NOT RUN` and why
   - For infra changes: the `terraform plan` (or equivalent) summary
   - For a PR with no feature doc (fix, dependency, config, infra or CI change): the
     "Privacy screening" section of the Step 2 PR-description draft, verbatim; for a
     docs-only or tests-only PR, "not applicable"
   - Reviewer verdict, and the infosec verdict (APPROVED / APPROVED WITH EXCEPTION + ADR
     link + risk-register row)
4. Ensure CI passes (including infra `plan` and any IaC tests). Where hosted CI runs on
   pull requests, a review held before the PR exists records the CI evidence as
   **"pending: hosted CI on the PR head"**; the gate is re-checked on the PR head before
   merge: green is required to merge, and the agent that opens the PR waits for the run
   and reports it, failures quoted. Where CI does not run on pull requests, the local CI
   report is the only check before merge; never push to the default branch to find out.
   Never trigger a workflow or deploy without asking
5. After every fix round, re-read the PR description against the files as they now are

---

## MCP Tools Available Across the Cycle

The following MCP servers are available to the skills invoked during this workflow. This
section summarises where each is most relevant:

| MCP Server | Most relevant steps | Primary use |
|---|---|---|
| **context7** | Step 1, Step 1.5, Step 2 | Look up live framework/provider/styling docs before designing or coding |
| **github** | Step 2, Step 3, Step 6 | Branch/PR operations, CI status checks, diff access for review |
| **filesystem** | Intake, Step 1, Step 1.5, Step 2, Step 5 | Read/write feature docs, proposals, design plans, ADRs, and source files |
| **semgrep** | Step 2, Step 3, Step 4 | Static analysis — run before handoff at each gate |
| **playwright** | Step 1.5, Step 2, Step 3 | Screenshots per breakpoint and accessibility snapshots for UI work |

Each skill in the cycle is responsible for using these tools appropriately — the guidance
above is a cross-step reference to avoid duplication. See each individual skill for
step-specific instructions.

---

## Iteration Reference

| Situation | Action |
|---|---|
| Reviewer returns BLOCK | Fix all Blockers → re-review (Step 3 → Step 2 → Step 3) |
| Infosec returns REQUIRES CHANGES | Fix → re-run infosec (Step 4 → Step 2 → Step 4) |
| Implementation reveals an architectural flaw | Write a new proposal or amend the existing one (Step 1) before proceeding |
| User rejects the design plan | Revise and re-present via the `design` skill (Step 1.5) — no UI code until accepted |
| Implementation reveals the design won't work | Return to Step 1.5, amend the plan, re-confirm, then resume Step 2 |
| Design handover conflicts with the project design system | The design system wins unless the user decides otherwise; record the decision in the plan's Divergences (Step 1.5) |
| Accessibility floor conflicts with the design | Change the design, not the floor (Step 1.5 → Step 2) |
| New dependency needed | Call it out explicitly in Step 2; reviewer checks supply-chain in Step 3; infosec checks crypto/secrets handling in Step 4 |
| Infra-only change | Same flow — proposal must include Infrastructure Addendum; PR must include `plan` output |
| Trivial fix (no design impact, no infra, no security) | Start at Step 2; skip Step 1. Step 2 begins, before any code, with the privacy screening in a PR-description draft, which goes to the reviewer (and infosec) as evidence and becomes the PR description verbatim (none for a docs-only or tests-only change). Any Yes: the developer writes the PIA (header `**PR:** <branch or PR>, screening in the PR-description draft`) before any code, and **Step 4 is required**; otherwise skip Step 4 |
| A step is refused (e.g. a write is not permitted) | The requirement is **not met**: say so in every status line. Narrowing scope is the product owner's call |
| A question needs the product owner | Give the options with their consequences and a recommendation; quote the answer and date in the feature doc's Decisions |
| An evaluation bar fails its first run | Stop and take it to the product owner; never re-tune the bar ([`RULES.md#evaluation-and-recall-gates`](../RULES.md#evaluation-and-recall-gates)) |
| Bug fix | Write regression test first (TDD red step), then fix (green), then review |
| Security exception accepted | Must be documented as an ADR in Step 5; reference it in the PR |

## Quick Reference

```
Feature doc → docs/features/NNNN-short-title.md (written before Step 1; privacy screening, PIA if any Yes)
Step 1   → architect skill     (propose; include Infra Addendum if relevant; back-link feature doc)
Step 1.5 → design skill        (UI-bearing work only: token plan in docs/design/, sign-off)
Step 2   → developer skill     (TDD; changelog; Semgrep; CI evidence — local report only without PR CI; plan output for infra)
Step 3   → reviewer skill      (brief = request + diff + existing evidence, never a list of fixes; loop back to Step 2 if blocked)
Step 4   → infosec skill       (security/compliance sign-off; required with a PIA; exceptions → risk register)
Step 5   → decision-log skill  (log ADRs, update proposal statuses, log any exceptions)
Step 6   → open PR             (feature doc, proposal, design plan + screenshots, ADRs, CI evidence, plan output, verdicts)
```
