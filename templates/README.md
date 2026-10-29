# templates/

Starter files for the process documents in [`RULES.md`](../RULES.md). `project-bootstrap`
installs them; `project-onboard` installs what a project lacks; a project set up before
them installs them by hand from this table. Installed copies belong to the project:
`update-skills` refreshes only this directory.

| Template | Installed to |
|---|---|
| [`docs/corrections-log.md`](docs/corrections-log.md) | `docs/corrections-log.md` |
| [`docs/risk-register.md`](docs/risk-register.md) | `docs/risk-register.md` |
| [`docs/privacy/README.md`](docs/privacy/README.md), [`TEMPLATE-pia.md`](docs/privacy/TEMPLATE-pia.md), [`data-inventory.md`](docs/privacy/data-inventory.md) | `docs/privacy/` |
| [`scripts/privacy-screening.guard.mjs.template`](scripts/privacy-screening.guard.mjs.template) (optional) | `scripts/__tests__/privacy-screening.test.mjs` |

When installing: replace `{product owner}` and the adoption-point placeholders with the
values in `CLAUDE.md`; never overwrite an existing file. The guard ships as `*.template`
so no test runner collects it where the skills are installed; it is installed only on
request, renamed, with `FIRST_SCREENED_*` set to the adoption point.

`.from-skills` marks this directory as the skills' copy: the installers and
`update-skills` replace or remove a `templates/` only when it is present.
