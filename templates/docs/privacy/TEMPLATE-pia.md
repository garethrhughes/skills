# NNNN — Privacy impact assessment: Short title

<!--
Copy this file to docs/privacy/NNNN-short-kebab-title.md (NNNN = the next free number in
docs/privacy/README.md), fill it in, delete these comments and add a row to the README.

A PIA is written when any answer in a Privacy screening is "yes", before implementation
starts: by the architect with the proposal, or in the feature-document step when there
is no proposal. The developer updates it if the build differs.

This is an engineering and product assessment. It states no legal conclusion. Keep it
short: a small change is one page and an hour's work. Build on
docs/privacy/data-inventory.md rather than re-describing what is already there, and
update the inventory in the same PR when a row is added, changed or removed.

Every "## " heading below is required. If the project installed the optional
privacy-screening guard, it fails a PIA that drops one.
-->

**Feature:** [NNNN](../features/NNNN-title.md) · **Proposal:** [NNNN](../proposals/NNNN-title.md) or none
**Date:** YYYY-MM-DD
**Author:** the agent or person who wrote it
**Screening answers that triggered it:** 1, 3 (the question numbers answered "yes")

## What changes

Two sentences: what the change does with data about people that it did not do before.

## Data

One row per field or record the change collects, derives, logs, stores, exposes or
sends. Identifiers count (account ids, entity ids, key prefixes, IPs, emails,
timestamps, counts of use). Class is one of the project's data classes (see
`CLAUDE.md`). Name the code for each claim.

| Field / record | Class | Source | Purpose | Who can read it | Where stored (service, region) | Retention and how it is deleted | Protection |
|---|---|---|---|---|---|---|---|
| `table.column` or log line | metadata | set by `path/to/file` | why it is needed | user / operator / processor / agent | database, region | 30 days, `path/to/cleanup-job` | encrypted at rest, admin-only route |

## Necessity and proportionality

- **Why this data:** what breaks or is lost without it.
- **What less would do:** a coarser value, a shorter retention, a count instead of a
  list, client-side only, encrypted instead of readable by the server.
- **Alternatives considered and rejected:** each with one line on why.

## Transparency

Where the user is told, and the exact change needed in this PR (quote the new wording):

- In the UI:
- Help or documentation:
- Terms or privacy policy:
- Changelog:

If the user is not told, say why, and add a risk-register row.

## User rights

- **See it:** can the user see this data in the product? Where?
- **Export it:**
- **Correct it:**
- **Delete it:** what deletes it on request, and on account deletion. Name the code
  (the account-deletion service, a purge or cleanup job), and say whether the existing
  purge covers the new rows. "Covered" needs the line that touches the new table or
  field.

## Harms to individuals

Harm to the people the data is about, not to the company.

| Harm | Likelihood | Severity | Mitigation |
|---|---|---|---|
| Exposure to the operator (what they can now see) | Low / Medium / High | Low / Medium / High | |
| Re-identification or linking across records | | | |
| Inference from metadata (what ids, sizes, timing or relationships reveal) | | | |
| Profiling | | | |
| Insider access (cloud console, database, logs) | | | |
| A leak of this data | | | |

Drop rows that do not apply only with a one-line reason.

## Confidentiality checks

Adapt these to the project's own guarantees (for example zero-knowledge or client-side
encryption, see `CLAUDE.md`):

- Does any user content, or anything derived from it, reach a place the project says it
  must not (the server, a log, an audit row, an error, a processor)? (must be no)
- Do ids, sizes, counts, timing or relationships reveal content, and how much?
- Are derived values (embeddings, vectors, summaries, search indexes) treated with the
  same protection as the content they come from?
- Is anything new decrypted or readable outside where it already was?

## Processors and transfers

Which processors receive or store the data (identity provider, payment provider, cloud
services, an AI agent or integration the user connects, others), in which region, and
whether any of it is new. Name any cross-border transfer that is new.

## Applicable regimes and lawful basis

legal review needed

<!-- The product owner fills this: which privacy regimes apply (for example UK GDPR, EU GDPR,
the Australian Privacy Act 1988, CCPA) and the lawful basis or permitted purpose relied on.
Agents never fill it and never state a legal conclusion. -->

## Residual risk and decision

- **Residual risk:** what is left after the mitigations, with risk-register ids (R-NNN).
- **Decision:** proceed | proceed with conditions | stop
- **Conditions:** (if any)
- **Decided by:** name, date, and the words of the decision; "on {product owner}'s
  behalf, pending their review" when an agent chose.

## Review

**Review by:** the next release, or 12 months from the date above, whichever is sooner;
or earlier when the data in the table changes.
