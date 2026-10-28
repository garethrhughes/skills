# templates/

Starter files for the process documents the skills read and write. `project-bootstrap`
installs them into a new project, and `project-onboard` installs any the project does not
already have. Each one is copied to the path under `docs/` or `scripts/` that mirrors
its path here. An installed copy belongs to the project: `update-skills` refreshes this
directory, never the project's copies.

| Template | Installed to | Used by |
|---|---|---|
| [`docs/corrections-log.md`](docs/corrections-log.md) | `docs/corrections-log.md` | every agent reads its **Patterns** before deciding; `developer` and the feature cycle append to its ledger; `reviewer` and `infosec` (read-only) report new cases for the caller to append ([`RULES.md#evidence-corrections--decisions`](../RULES.md#evidence-corrections--decisions)) |
| [`docs/risk-register.md`](docs/risk-register.md) | `docs/risk-register.md` | residual risks left open on purpose, including every `APPROVED WITH EXCEPTION` ([`RULES.md#risk-register`](../RULES.md#risk-register)) |
| [`docs/privacy/README.md`](docs/privacy/README.md) | `docs/privacy/README.md` | the five-question privacy screening, who does what, and the PIA index ([`RULES.md#privacy`](../RULES.md#privacy)) |
| [`docs/privacy/TEMPLATE-pia.md`](docs/privacy/TEMPLATE-pia.md) | `docs/privacy/TEMPLATE-pia.md` | copied by `architect` / `create-feature` to `docs/privacy/NNNN-title.md` for any screening with a Yes |
| [`docs/privacy/data-inventory.md`](docs/privacy/data-inventory.md) | `docs/privacy/data-inventory.md` | the standing list of personal data, seeded from the code at onboarding |
| [`scripts/privacy-screening.test.mjs`](scripts/privacy-screening.test.mjs) | `scripts/__tests__/privacy-screening.test.mjs` | **optional**: a dependency-free `node --test` guard for the screening and PIA mechanics. Installed only when the user asks for it |

When installing, replace `{product owner}` with the name the user gives in the
bootstrap/onboard security phase. The corrections log's Patterns come from many
projects and are a starting point: the project's own ledger is what makes them its own.
