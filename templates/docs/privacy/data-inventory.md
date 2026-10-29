# Data inventory

The standing list of data the system holds about the people who use it: what, where,
who can read it, how long it is kept and what deletes it. A privacy impact assessment
([`README.md`](README.md)) builds on this file, and the PR that adds, changes or removes
a row updates it.

**Seeded from the code on YYYY-MM-DD** (`main` at `<sha>`). Every row cites the file it was
read from. **`unverified`** means the code in this repository could not show it (a cloud
default, a processor's own behaviour, a path not read to the end). It is never a guess,
and it is an open item: before any claim rests on it, read the code to the end and
replace the word with a file and line. This is an engineering inventory, not a legal
record of processing.

**Classes:** the project's data classification scheme (see `AGENTS.md`), for example
`public` / `internal` / `confidential` / `pii`, or `restricted` / `metadata` / `pii`.

**Where:** the accounts, regions and processors every store below lives in, with the
file that sets each (IaC, config). Processors' own regions and retention: `unverified`
until their documentation is cited.

## What the seeding found

Read these before relying on any "deleted" below. One numbered item per gap between what
the product says and what the code does (for example: account deletion that leaves some
tables behind, purge jobs written but not running, soft-deletes that keep a row, no
export, no backups configured), each with the file and the risk-register row.

1. *(none yet)*

## Account

| Record / field | Class | Where | Who can read it | Retention | Deletion path | Source |
|---|---|---|---|---|---|---|
| `users.email` | pii | primary database | operator (admin screen); identity provider is the source | life of the account | account deletion (`path/to/service:line`) | `path/to/entity:line` |

## Content

| Record / field | Class | Where | Who can read it | Retention | Deletion path | Source |
|---|---|---|---|---|---|---|

## Logs, audit and telemetry

| Record / field | Class | Where | Who can read it | Retention | Deletion path | Source |
|---|---|---|---|---|---|---|

## On the user's device

| Record / field | Class | Where | Who can read it | Retention | Deletion path | Source |
|---|---|---|---|---|---|---|

## Processors

| Processor | What it receives | Region | Retention | Source |
|---|---|---|---|---|
