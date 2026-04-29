---
name: dev-workflow
description: The full feature development cycle as a numbered checklist — from proposal through implementation, review, decision logging, and PR. Defines when each agent handoff happens and how to handle iteration loops.
compatibility: opencode
---

# Dev Workflow Skill

This skill describes the complete feature development cycle used in this project. Follow
these steps in order for any non-trivial piece of work. Each step maps to a specific skill.

## Project Context

> Fill in before use: Replace this section with your project's conventions, repository
> locations for proposals and decisions, and any team-specific workflow notes.
>
> Example: "Proposals: docs/proposals/. Decisions: docs/decisions/. Branches: feature/NNNN-short-title.
> PRs target main. CI runs Jest + Vitest."

---

## The Full Feature Development Cycle

### Step 1 — Design (Architect skill)

**When:** Before writing any code for a non-trivial change.

Use the **architect** skill to:
1. Determine whether the change warrants a proposal (see the architect skill's "When to Write
   a Proposal" section)
2. If yes: write a proposal in `docs/proposals/NNNN-short-title.md`
3. Get the proposal reviewed (share with the team / another agent) and update status to
   `Accepted`
4. Create any ADR(s) that the proposal produces in `docs/decisions/`

**Skip this step only for:** trivial bug fixes, copy changes, or configuration tweaks that
do not affect architecture, module boundaries, or schema.

**Handoff to Step 2 when:** the proposal status is `Accepted` (or the change is confirmed
as trivial).

---

### Step 2 — Implementation (Developer skill)

**When:** Proposal is accepted (or change is confirmed trivial).

Use the **developer** skill to:
1. Create a new branch: `git checkout -b feature/NNNN-short-title` *(adjust the branch naming convention to match your project's standard, or use the convention defined in your CLAUDE.md)*
2. Follow the red-green-refactor TDD cycle for every unit of behaviour:
   - Write a failing test first
   - Write the minimum code to make it pass
   - Refactor while keeping tests green
3. Follow all project conventions (thin controllers, typed API client, ConfigService,
   no `any`, no implicit returns)
4. Call out any new dependencies explicitly before adding them
5. Run the full test suite before considering the implementation complete

**Handoff to Step 3 when:** all tests pass and the branch is ready for review.

---

### Step 3 — Review (Reviewer skill)

**When:** Implementation is complete and tests are green.

Use the **reviewer** skill to:
1. Review all staged / branch changes
2. Check for Blocker, Major, Minor, and Suggestion findings
3. Return a verdict: PASS / PASS WITH COMMENTS / BLOCK

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

### Step 4 — Decision Logging (Decision Log skill)

**When:** Implementation is reviewed and accepted.

Use the **decision-log** skill to log any significant decisions made during Steps 1–3:
- Technology or library chosen
- Architectural pattern adopted
- Trade-off made between approaches
- Edge case resolution agreed
- Proposal accepted (if not already logged in Step 1)

Update any proposals in `docs/proposals/` whose status is still `Draft` or `Under Review`
to `Accepted`, linking the ADR numbers.

**Handoff to Step 5 when:** all relevant ADRs are written and the index is updated.

---

### Step 5 — Pull Request

**When:** Steps 1–4 are complete.

1. Push the branch to remote: `git push -u origin feature/NNNN-short-title`
2. Open a PR targeting `main` (or the project's default branch)
3. In the PR description, include:
   - A summary of what changed and why
   - Link to the accepted proposal (if one exists)
   - Link to any new ADRs created
   - Test coverage summary (new tests added, all passing)
4. Ensure CI passes

---

## Iteration Reference

| Situation | Action |
|---|---|
| Reviewer returns BLOCK | Fix all Blockers → re-review (Step 3 → Step 2 → Step 3) |
| Implementation reveals design flaw | Write a new proposal or amend the existing one (Step 1) before proceeding |
| New dependency needed | Call it out explicitly in Step 2; reviewer checks it in Step 3 |
| Trivial fix (no design impact) | Start at Step 2; skip Step 1 |
| Bug fix | Write regression test first (TDD red step), then fix (green), then review |

## Quick Reference

```
Step 1 → architect skill   (propose)
Step 2 → developer skill   (implement with TDD)
Step 3 → reviewer skill    (review; loop back to Step 2 if blocked)
Step 4 → decision-log skill (log ADRs, update proposal statuses)
Step 5 → open PR
```
