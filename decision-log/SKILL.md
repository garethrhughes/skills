---
name: decision-log
description: Captures and maintains architectural and technical decisions in docs/decisions/ using the ADR format. Keeps the decision index up to date. Triggered whenever a technology is chosen, a pattern is adopted, a trade-off is made, or a proposal is accepted.
compatibility: opencode
---

# Decision Log Skill

You capture, format, and maintain architectural and technical decisions made during
development. You write in the ADR (Architecture Decision Record) format and keep a running
log in `docs/decisions/` so the team has a traceable history of why the system is built the
way it is.

## Project Context

> Fill in before use: Replace this section with your project's stack, conventions, and any
> existing ADRs that have already been logged.
>
> Example: "ADRs live in docs/decisions/. Proposals live in docs/proposals/. Current highest
> ADR number: 0005."

---

## Authoritative Rules

The project-wide engineering conventions live in two layers:

1. The language-agnostic core in [`RULES.md`](../RULES.md).
2. The active **stack overlay** under [`rules/`](../rules/), pinned by the project's
   `## Active Skillset` line in `CLAUDE.md` — e.g.
   [`rules/typescript.md`](../rules/typescript.md) or
   [`rules/dotnet.md`](../rules/dotnet.md).

This skill is the **sole owner of ADR creation** — the architect skill writes proposals and
hands off to this skill for the corresponding ADR.

If `CLAUDE.md` does not declare an active skillset, default to the
[`typescript`](../rules/typescript.md) overlay for backwards compatibility.

### ADRs that override a rule

If a decision overrides a rule in `RULES.md` **or in the active overlay**, the ADR **must**:

1. Cite the exact file, section, and rule being overridden (e.g.
   `RULES.md#external-http-clients` — "5s default timeout", or
   `rules/typescript.md` *TypeScript Conventions* — "never `enum`").
2. State the override explicitly in the **Decision** section.
3. Justify the override in the **Rationale** section — what makes this project's
   constraints different.
4. List the additional risk and mitigation in **Consequences → Risks**.
5. Be referenced from the project's `CLAUDE.md` "project-specific overrides" table so
   future skill runs see the deviation.

Never weaken a rule in `RULES.md` or an overlay itself — overrides are per-project and live
in ADRs.

---

## When to Log a Decision

Log a decision whenever any of the following occur:
- A technology, library, or framework is chosen or rejected
- An architectural pattern is adopted or explicitly avoided
- A domain-specific calculation approach is finalised
- A trade-off is made between simplicity and flexibility
- An external API limitation forces a workaround
- A configuration approach is chosen (per-entity rules vs global defaults)
- An edge case resolution is agreed
- A security or auth approach is confirmed
- A proposal in `docs/proposals/` is accepted

## ADR File Naming Convention

```
docs/decisions/NNNN-short-kebab-case-title.md
```

Example: `docs/decisions/0001-cache-external-data-in-postgres.md`

Increment NNNN sequentially from the highest existing number. Start at 0001.

## ADR Format

```markdown
# NNNN — Decision Title

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Deprecated | Superseded by [NNNN]
**Deciders:** who decided, with the product owner's words quoted and dated; name the parts
an agent chose on their behalf as "pending their review"
**Proposal:** link to docs/proposals/ file if this decision originated from a proposal
**Amends / Supersedes:** links to the ADRs this one changes, and what it changes in each
**Amended by:** links added later, when another ADR amends this one
**Privacy:** screening all No | PIA [docs/privacy/NNNN-title.md](../privacy/NNNN-title.md)
**Risks:** risk-register rows this decision raises, accepts or closes (R-NNN)

## Context

What is the problem or situation that requires a decision? Include any relevant
constraints — technical, operational, or business. Keep this to 3–5 sentences.

## Options Considered

### Option A — [Name]
- **Summary:** One sentence description
- **Pros:** bullet list
- **Cons:** bullet list

### Option B — [Name]
- **Summary:** One sentence description
- **Pros:** bullet list
- **Cons:** bullet list

*(Add further options as needed)*

## Decision

State the chosen option in one sentence. Example:
> We will cache external API data in Postgres rather than querying live per request.

## Rationale

2–4 sentences explaining why this option was chosen over the alternatives.
Reference specific constraints from the Context section.

## Consequences

- **Positive:** what this decision enables or simplifies
- **Negative / trade-offs:** what this decision costs or constrains
- **Risks:** anything that could cause this decision to be revisited

## Related Decisions

- Links to other ADRs that are affected by or influenced this decision
```

## Your Workflow

When asked to log a decision:
1. List `docs/decisions/` to identify the next available NNNN
2. Create the file at `docs/decisions/NNNN-title.md` using the format above
3. Set Status to `Accepted` unless explicitly told otherwise
4. Add a one-line entry to `docs/decisions/README.md` in the decision index table
5. **Link both ends.** When the new ADR amends or supersedes another, add an
   **Amended by** (or set **Status: Superseded by**) line to the older ADR in the same
   change. A one-way link leaves readers of the old ADR following a rule that has changed
6. Add **one line** to `CLAUDE.md`'s Settled Decisions table: the rule as it stands, plus
   which ADRs it amends or supersedes. Review rounds, measurements and risk rows stay in
   the ADR, because `CLAUDE.md` is loaded into every session and is kept small. If an
   existing row states the rule this ADR changes, rewrite that row
7. **Reconcile the copies.** Grep the proposal, PIA, risk register, `CLAUDE.md` and the
   other ADRs the change touches for the wording this ADR replaces, and make each agree
8. Each exception or residual the decision accepts has a row in `docs/risk-register.md`;
   name it in **Risks**
9. Before the ADR says a change alters some behaviour, make sure that was observed (old
   and new code run against the case), not reasoned. If it was not, leave the claim out

## Decision Index Format (docs/decisions/README.md)

```markdown
# Decision Log

| # | Title | Status | Date |
|---|---|---|---|
| [0001](0001-cache-external-data-in-postgres.md) | Cache external data in Postgres | Accepted | YYYY-MM-DD |
```

## MCP Tools

### filesystem — ADR File Operations
Use the Filesystem MCP server to:

- List `docs/decisions/` to find the highest existing NNNN before creating a new ADR
- Read existing ADRs to check for related decisions to link
- Write new ADR files directly to `docs/decisions/NNNN-title.md`
- Update the decision index at `docs/decisions/README.md`
- Read `docs/proposals/` to locate the originating proposal when logging an accepted decision

---

## Out of Scope

This skill does not review code. Flagging an implementation that contradicts an existing
ADR belongs to the **reviewer** skill, which blocks on it under *Documentation Checks*.
Your job ends at writing and indexing the ADR itself.
