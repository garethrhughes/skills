# Risk Register

Risks the product owner has **accepted, deferred or not yet treated**, in one place. A
finding that is fixed does not belong here; a finding that is left open on purpose does,
with who decided and when to look again
([`RULES.md#risk-register`](https://github.com/garethrhughes/skills/blob/main/RULES.md#risk-register)).

- **Likelihood / impact:** Low, Medium, High.
- **Status:** *Accepted* (living with it, no treatment planned), *Deferred* (treatment
  planned for a named release), *Open* (untreated, not yet decided). Quote the product
  owner's words and the date; keep earlier statuses after "Earlier:" rather than
  deleting them.
- Add a row when you leave something open on purpose: a residual an infosec review
  accepts, an `APPROVED WITH EXCEPTION`, a fix deferred to a later release, a gap a PIA
  leaves. Close a row by moving it to *Closed* below with the commit or ADR that closed
  it.

IDs are `R-NNN`: `R-` and a three-digit sequence number (`R-001`, `R-002`, …; four
digits after `R-999`), always the next free one. IDs are never reused. Record a gap in
the numbering here when one appears.

| ID | Risk | Likelihood | Impact | Owner | Mitigation / treatment | Status | Raised | Review |
|---|---|---|---|---|---|---|---|---|

## Closed

| ID | Risk | Closed by | Date |
|---|---|---|---|
