# Corrections log

Every time an agent was wrong on this project, and every time the product owner had to
push back on a decision, with the cheapest check that would have caught it
([`RULES.md#evidence-corrections--decisions`](https://github.com/garethrhughes/skills/blob/main/RULES.md#evidence-corrections--decisions)).
**Read the Patterns before making a decision**; the Ledger is the evidence.

## Patterns

Seed patterns, generalised from one project's log and from the skills repository's own
review rounds. They are starting points: file this project's cases under them, drop
what never applies, and add a pattern only when none fits.

1. **Check scope and state before asserting them.** *Example:* an item called "out of
   scope" had a real contact point; an "is this a source checkout?" test answered yes for
   the project repository the skills were vendored into. **Check:** run the command that proves "done / out of
   scope / pre-existing"; test every symptom before ruling out another caller.
2. **Read the diff back.** *Example:* a commit said a section was amended; it was
   byte-identical. **Check:** `git diff` the passage; a refused write is not met.
3. **A test that cannot fail is worse than none.** *Example:* a conditional assertion
   never ran; a later guard made an earlier guard's test unable to fail; a "still the
   default?" test matched one marker string, so facts added under it were deleted. **Check:** break
   every enforcing line and watch it fail; re-run earlier mutations on the final head.
4. **Say what a mitigation does not cover.** *Example:* a check meant to cover two risks
   covered one. **Check:** construct each failure; trace what updates the field a
   retention rule keys on.
5. **Report failures, not the passing count.** *Example:* "235 passed" hid 5 failed.
   **Check:** quote the whole result line.
6. **A fix is a change.** *Example:* a fix replaced where it should have merged; a gate
   asked for evidence that only existed after the review it gated (a hosted CI run, a
   PR description, a PIA a fix PR had no step to write). **Check:** ask what else reads
   what you wrote and when each piece of evidence exists; grep every copy of a changed
   rule.
7. **Generating from a source of truth moves the risk.** *Example:* one conversion bug
   broke every generated item. **Check:** list the new failure modes first.
8. **Parse records before matching inside them.** *Example:* a regex crossed into the
   next entry. **Check:** split first; give every parser a count it must hit.
9. **Clean up what you start.** *Example:* a stray server made tests time out; a test
   harness built a path into a shell string, and `->` in a case name redirected its
   output into the owner's checkout. **Check:** list your own processes and ports; never
   kill by pattern; run subprocesses with argument lists and a scratch working directory.
10. **Cheap confirmation beats reasoning.** *Example:* three confident diagnoses, each
    refuted by a one-minute probe. **Check:** run the probe first.
11. **Never `cd`.** *Example:* a `cd` chain halted an unattended run after the rule was
    acknowledged. **Check:** absolute paths, `git -C`, `npm --prefix`; `git status` after
    a stash.
12. **Act outward only when asked.** *Example:* a push the owner had not asked for.
    **Check:** name the request (an owner-started feature cycle counts for its branch
    and PR); offer the lighter option.
13. **Local CI tests what you point it at.** *Example:* a runner tested the main
    checkout, not the branch; a test raced only on a loaded CI machine. **Check:** pass
    `--ref`, read the commit line; SKIPPED is NOT VERIFIED; assert async work settled.
14. **Gates are fixed before they run.** *Example:* a bar sized on a statistic its
    calibration never measured. **Check:** fixed sets, written split, held-out
    calibration; a first-run failure goes to the owner.
15. **Tools have defaults that change what they check.** *Example:* Vitest collected a
    `*.test.mjs` template under `.claude/`; Semgrep dropped files over 1 MB. **Check:**
    ship such files as `*.template`; compare `paths.scanned` with the diff; lift size
    limits.

16. **Moving a file moves its status too.** *Example:* a migration copied a git-ignored
    (private) `CLAUDE.md` into a new, shared `AGENTS.md` and said "commit"; a symlinked
    directory made it migrate the repository on the other side of the link. **Check:**
    before moving or rewriting, ask git about both ends (`git check-ignore`, tracked or
    not) and resolve paths the way the caller sees them; refuse and report when either
    end differs.

## Ledger

Append, do not rewrite. File a recurrence under its pattern.

| # | What was claimed or done, and what was true | Pattern | The check that would have caught it |
|---|---|---|---|
