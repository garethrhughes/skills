# Privacy impact assessments

Every change that may affect the privacy of the people whose data this system holds is
screened, and any change the screening flags gets a privacy impact assessment (PIA)
before it is built ([`RULES.md#privacy`](https://github.com/garethrhughes/skills/blob/main/RULES.md#privacy)).

**This is an engineering and product assessment, not legal advice.** It records what data
a change touches, why, who can see it, how long it is kept and how it is deleted, and
what could go wrong for the person it is about. It states no legal conclusion. Which
privacy regimes apply and on what lawful basis is the product owner's field in each PIA,
and it reads `legal review needed` until {product owner} fills it.

- [`TEMPLATE-pia.md`](TEMPLATE-pia.md): the template. Copy it to `NNNN-short-title.md`.
- [`data-inventory.md`](data-inventory.md): the standing list of personal data the
  system holds, seeded from the code. A PIA builds on it, and the PR that changes a row
  updates it.

## The screening

Every feature document (`docs/features/`) and every proposal (`docs/proposals/`) carries
this section, filled in. For a PR with no feature doc (a fix, dependency, configuration,
infrastructure or CI change), the developer writes the screening **before coding**, as
the first action of implementation (create-feature Step 2), in a "Privacy screening"
section of a **PR-description draft**, which is handed to the reviewer and infosec as
evidence and later becomes the PR description verbatim. Any Yes: the developer writes
the PIA then, before any code, with the header line `**PR:** <branch or PR>, screening
in the PR-description draft`, and infosec (create-feature Step 4) is required. A PR that
changes only documentation or tests, with no runtime effect, needs none and says
"Privacy screening: not applicable (docs/tests only)".

**Adoption point:** feature documents from {first screened feature number} and proposals
from {first screened proposal number} (also recorded in `CLAUDE.md`). Older documents
are not checked unless they are reopened. **If `CLAUDE.md` records no adoption point**,
the newest feature-doc and proposal numbers that existed when the rule was adopted, and
every number below them, count as before it: neither the reviewer nor infosec blocks
them, and the reviewer asks the product owner to record the "first screened" numbers
(newest + 1) in `CLAUDE.md`. A "yes" to any question means a PIA. All "no": one sentence
saying why, and the screening is still recorded.

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

With any "yes", the result line links the PIA instead:

```markdown
**Result:** PIA: [docs/privacy/NNNN-short-title.md](../privacy/NNNN-short-title.md)
```

Answer for what the change does, not for what the product already did. Be literal: a
new column holding an account id, a new audit field, a new log line with a route or a
count, an existing value shown on a new screen, or a new call to a processor is a "yes".

## Who does what

| Step | Who | What |
|---|---|---|
| Feature document | the feature cycle (`create-feature`) | Fills the screening. With no proposal and any "yes", writes the PIA here too. |
| Proposal | `architect` | Fills the screening; with any "yes", writes the PIA with the proposal. |
| Implementation | `developer` | Builds what the PIA lists and nothing more; updates the PIA (and the inventory) if the build differs. |
| Implementation, PR with no feature doc | `developer` | Writes the screening before any code, as a "Privacy screening" section of the PR-description draft (the first action of Step 2); it goes to the reviewer and infosec as evidence and becomes the PR description verbatim. With any "yes", writes the PIA then, before any code, with the header line `**PR:** <branch or PR>, screening in the PR-description draft`; infosec is then required. |
| Code review | `reviewer` | BLOCKs a PR whose feature doc (or, with no feature doc, whose PR-description draft) has no screening, whose "yes" has no PIA link, or whose diff logs or stores data the PIA does not list. |
| Infosec | `infosec` | Required whenever a PIA exists. Reads the screening (feature doc, proposal or PR-description draft) and the PIA against the diff; a missing PIA or a data table that does not match the diff is REQUIRES CHANGES. |
| Decision | {product owner} | Fills *Applicable regimes and lawful basis*; confirms or overrides a decision taken on their behalf. |

<!-- Optional: if you installed scripts/__tests__/privacy-screening.test.mjs (from the
skills' templates/scripts/privacy-screening.guard.mjs.template), say so here: it checks
the mechanics (every screened document has five answers, a "yes" links a PIA that exists
and links back, every PIA has the template's headings and a decision, and this index
lists every PIA). It cannot check that an answer is true. -->

## Open gaps

- *(none yet: record here what the inventory's seeding found that the product does not
  yet do, with the risk-register row for each)*

## Index

| # | Title | Feature / proposal | Decision | Date | Review by |
|---|---|---|---|---|---|
