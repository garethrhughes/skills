# Corrections log

Every time an agent was wrong on this project, and every time the product owner had to
push back on a decision an agent made. Kept because the same mistakes recur, and the
recurrence is only visible if it is written down
([`RULES.md#evidence-corrections--decisions`](https://github.com/garethrhughes/skills/blob/main/RULES.md#evidence-corrections--decisions)).

**Read the Patterns section before making a decision.** It is short on purpose. The
Ledger below is the evidence for it. Go to the Ledger when you want the detail of a
specific case.

Referenced by the `developer`, `reviewer` and `infosec` skills, and by `CLAUDE.md`.

---

## Patterns

These seed patterns are generalised from one project's corrections log and from the
skills repository's own review rounds, where each one recurred. They are starting
points, not evidence about this project. Replace them with this project's own as its
ledger grows: add its cases under the matching pattern, drop a pattern that never
applies here, and add a new pattern only when no existing one fits.

### 1. Do not assert scope, status or state without checking it

An agent said something was settled, out of scope, pre-existing or unaffected, having
reasoned about it rather than looked.

**The check:** before writing "already done", "out of scope", "resolved",
"pre-existing" or "not affected", run the command that proves it and cite what it
returned. Reproduce a "pre-existing" failure on the merge base. A scope reduction is the
product owner's call, never the agent's. Before ruling out another caller of a shared
defect, test every symptom the fix addresses at that caller: "it already does X" rules
out only X.

### 2. Never claim a file was changed without reading the diff back

A commit message said a section had been amended. The heading was byte-identical, and
the next round's fix addressed a different line.

**The check:** after editing a document, `git diff` the passage you claim to have
changed and confirm the words you removed are gone. A refused write is a requirement not
met: say so everywhere status is reported.

### 3. A test that cannot fail is worse than no test

It uses up the review budget that would have found the defect. Common shapes: a
conditional assertion that never runs; a check of generated output against the source
it was generated from; a harness that omits the one new surface; a fake that returns the
expected row whatever it was asked; a platform shim that pins the state the platform is
least likely to be in; a fixed fixture date next to code that reads the real clock; a
guard on one input path with none on its twin; a later guard that makes an earlier
guard's test unable to fail.

**The check:** before keeping a test, break what it guards and watch it fail. Break
every line that enforces the control, not one per control. After a later round adds a
guard downstream, re-run every earlier round's mutations on the final head and report
that tally. When a harness stands in for a specification, count what it compares
against what the specification contains.

### 4. State what a mitigation does not cover

A control was documented as mitigating two risks and covered one.

**The check:** for each risk a control is said to mitigate, construct the failure and
confirm the control fires. Attribute risks to controls one by one. Before a record says
what a retention or expiry rule removes, trace what updates the field it keys on.

### 5. Report failures, not the passing count

"235 passed" was 235 passed **and 5 failed**.

**The check:** quote the whole result line. If something fails, say whether you caused
it and how you know.

### 6. A fix is a change, and changes regress things

Every block-then-fix cycle introduced something new: a fix that replaced where it
should have merged, a removal of one untrusted field that kept another of the same
class, a PR description left describing the files as they were before the fix. One
fix made a review gate ask for evidence that could only exist after the review it gated:
the reviewer required a green hosted CI run on the PR head, while the workflow opened the
PR only after the review passed. The same shape recurred one round later: a fix PR's
privacy screening had to be "in the PR description", which the workflow wrote after the
review and infosec steps, and the review brief excluded it anyway. A round later still:
a fix PR whose screening had a Yes needed a PIA "before implementation", in a proposal
or feature step that such a PR never has, and its PIA header had no way to name it.

**The check:** after a fix, ask what else reads the thing you just wrote to, and add the
case that combines your change with its nearest neighbour. After correcting a claim or
rule, grep every file the branch adds or changes for the old wording and the names it
travels with (proposal, ADR, PIA, risk register, `CLAUDE.md`, agent files), and fix or
rule out each hit. For a gate, ask when its evidence comes into existence: if only after
the review it gates, record it as pending at review and re-check it before merge.

### 7. Generating from a source of truth moves the risk, it does not remove it

Replacing a hand-written step with a generated one created single points of failure for
every output at once.

**The check:** when you automate a manual step, write down the new failure modes before
you write the code, and do not close an open question because the mechanism changed.

### 8. Parse records before matching inside them

A pattern that reached for something inside one entry crossed into the next.

**The check:** split the text into records first, then match within each, and give any
parser a count it must hit.

### 9. Clean up what you start before concluding anything from a failing run

A stray background server from a probe made unrelated tests time out, and the clean-up
then killed a process that was not the agent's.

**The check:** before investigating a failure that contradicts an earlier pass, list
your own background processes and ports. Never kill by pattern. Resolve the PID and
confirm it is yours.

### 10. Cheap confirmation beats confident reasoning

Plausible diagnoses were wrong, one after another. Each one was refuted by a probe that
took about a minute.

**The check:** if a browser, shell command or probe can settle it in under a minute, do
that instead of reasoning about it. This applies to disagreeing with a reviewer as much
as to agreeing. Reading the code that draws a surface tells you what it intends. Only
the surface says what it does.

### 11. Use the tools the environment gives you; never `cd`

`cd` chains (even `cd /dev/null;`) raised permission prompts that halted unattended runs,
after the instruction had been acknowledged. A stash run from a subdirectory matched
nothing.

**The check:** name the directory in the command: the tool's working-directory
parameter, or absolute paths, `git -C`, `npm --prefix`. One directory per call. After
any stash or checkout, `git status`. An instruction that has to be repeated was not
followed, and acknowledging it is worth nothing on its own.

### 12. Do not act outward without asking

Pushing, opening PRs, triggering workflows and deploying are the product owner's calls.
Do them only when asked (a feature cycle the owner started that ends in a PR counts),
and offer the lighter option.

**The check:** before a push, PR, workflow run or deploy, name the request that asked
for it. If there is none, ask, and offer the lighter option first (commit locally,
draft the PR text).

### 13. Local CI tests what you point it at

A local CI runner resolved the repository from the working directory and reported on
the main checkout, not the branch. A test passed every time on an idle machine and raced
on a loaded CI runner.

**The check:** pass the commit explicitly (`--ref <sha>`) and read the line that names
the commit before trusting the summary. A SKIPPED job is NOT VERIFIED. Where hosted CI
runs on the PR, its result on the head is the evidence. After an action that settles
asynchronously, assert that it settled before driving the next input.

### 14. Gates are fixed before they are run

A gate was sized on a statistic its calibration did not measure. A split rule emptied a
calibration half that other measurements still used.

**The check:** use fixed, committed question sets and a deterministic split written
before any score is seen. Calibrate on the held-out half only, and measure the same
statistic the bar gates. A bar that fails its first run goes to the product owner, not
to a re-tune.

### 15. Tools have defaults that silently change what they check

A test runner collected a file it was never meant to run: Vitest's default include
matches `*.test.*` files under dot-directories such as `.claude/`, `.github/` and
`.opencode/`, so a `node:test` template copied there failed `vitest run`. Semgrep drops
files over 1 MB from a scan without an error (its default `--max-target-bytes`), and a
rule pack the registry cannot serve can leave a scan running zero files.

**The check:** ship files that a runner must not collect under a name no runner matches
(for example `*.template`), and rename them on install. For a scanner, compare the
files it says it scanned (`paths.scanned`) with the files you meant to scan, and lift
size limits you did not choose (`--max-target-bytes=0`).

---

## Ledger

Append, do not rewrite. One row per case.

| # | What was claimed or done, and what was true | The check that would have caught it |
|---|---|---|

---

## Adding to this log

An entry needs: what was claimed or done, what was actually true, and the cheapest check
that would have caught it. If the case is an instance of an existing pattern, add it
under that pattern rather than inventing a new one. The recurrence is the point.
