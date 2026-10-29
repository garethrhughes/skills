# Privacy impact assessments

How this project screens changes for privacy and assesses the ones that need it:
[`RULES.md#privacy`](https://github.com/garethrhughes/skills/blob/main/RULES.md#privacy).
A PIA is an engineering and product assessment, not legal advice; *Applicable regimes
and lawful basis* is {product owner}'s field and reads `legal review needed` until filled.

- [`TEMPLATE-pia.md`](TEMPLATE-pia.md): copy to `NNNN-short-title.md` and add a row below.
- [`data-inventory.md`](data-inventory.md): the personal data the system holds.

**Adoption point:** feature documents from {first screened feature number}, proposals
from {first screened proposal number} (as recorded in `AGENTS.md`).

## The screening

Copy this into the feature doc or proposal (or, for a PR with no feature doc, its
PR-description draft) and answer every row:

```markdown
## Privacy screening

| # | Question | Answer | Why |
|---|---|---|---|
| 1 | Does it collect, derive, log, store, expose or send any new data about a person (identifiers included: account ids, entity ids, key prefixes, IPs, emails, timestamps, usage or behaviour)? | No | one line |
| 2 | Does it change who can see existing data (the user, an operator or admin, another user, a processor or sub-processor, an AI agent or integration)? | No | one line |
| 3 | Does it change how long data is kept, or how it is deleted, exported or purged (account deletion, purge jobs, backups, archives)? | No | one line |
| 4 | Does it add or change a third party, a region, a model, analytics, telemetry or a network call that carries user data? | No | one line |
| 5 | Does it derive new information about people (profiling, inference, embeddings, activity summaries)? | No | one line |

**Result:** No PIA: one sentence saying why nothing here touches personal data.
```

With any "yes": `**Result:** PIA: [docs/privacy/NNNN-short-title.md](../privacy/NNNN-short-title.md)`.

## Who does what

| Step | Who | What |
|---|---|---|
| Feature doc, proposal | `create-feature`, `architect` | Fill the screening; any "yes" → the PIA, before implementation |
| PR with no feature doc | `developer` | Screening (and any PIA, headed `**PR:**`) before coding, in the PR-description draft |
| Implementation | `developer` | Builds only what the PIA lists; updates the PIA and inventory if the build differs |
| Review | `reviewer` | Applies the privacy gates in `RULES.md#privacy` |
| Infosec | `infosec` | Required with any PIA; reads it against the diff |
| Decision | {product owner} | Fills the regimes field; confirms decisions taken on their behalf |

<!-- Optional guard: if scripts/__tests__/privacy-screening.test.mjs is installed, say so
here. It checks the mechanics, not that an answer is true. -->

## Open gaps

- *(what the inventory's seeding found that the product does not yet do, each with its
  risk-register row)*

## Index

| # | Title | Feature / proposal / PR | Decision | Date | Review by |
|---|---|---|---|---|---|
