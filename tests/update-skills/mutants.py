#!/usr/bin/env python3
"""Break-the-guard runner for the AGENTS.md migration.

Each mutant breaks one control in scripts/migrate-agents-md.sh or update.sh (a clone of
this repository's HEAD, one edit, committed in the clone) and runs harness.py's
migration group against it. A mutant that leaves every check green means the harness
cannot see that control fail: the runner reports it and exits 1.

    python3 tests/update-skills/mutants.py              # all mutants (about 20 minutes)
    python3 tests/update-skills/mutants.py M1 M18        # only these

Needs python3, git and bash; writes only to a fresh temporary directory.
"""
import os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
M = 'scripts/migrate-agents-md.sh'
U = 'update-skills/update.sh'

MUTANTS = [
    ('M1', 'no backup taken', [(M, 'if ! backup="$(backup_claude_md "$CL")"; then', 'if ! backup="(none)"; then')]),
    ('M2', 'migrate although AGENTS.md exists', [(M, 'elif [ -f "$CL" ] && [ -f "$AG" ]; then\n  if ! is_import "$CL"; then', 'elif false; then\n  if ! is_import "$CL"; then')]),
    ('M3', 'a symlinked CLAUDE.md is not refused', [(M, 'elif [ -L "$CL" ]; then', 'elif false; then')]),
    ('M4', 'the import is never recognised', [(M, 'is_import() { [ -r "$1" ] && [ "$(first_content_line "$1")" = "@AGENTS.md" ]; }', 'is_import() { false; }')]),
    ('M5', 'an ambiguous root is accepted', [(M, 'if [ -n "$by_layout" ] && [ -n "$by_git" ] && [ "$by_layout" != "$by_git" ]; then', 'if false; then')]),
    ('M6', 'a backup overwrites an older one', [(M, '  if [ -e "$target" ] || [ -L "$target" ]; then\n    if cmp', '  if false; then\n    if cmp')]),
    ('M7', 'uncommitted state not reported', [(M, 'git_state="$(git -C "$ROOT" status --porcelain -- CLAUDE.md 2>/dev/null | cut -c1-2 || true)"', 'git_state=""')]),
    ('M8', 'no root found: guess the parent', [(M, '    root_refused "the skills are not in <root>/.opencode/skills and not inside a git repository."', '    ROOT="$(dirname "$SKILLS_DIR")"; ROOT_HOW=guess')]),
    ('M9', 'MIGRATED not counted in STATUS', [(U, '+ migrated_count + ATTENTION ))', '+ ATTENTION ))')]),
    ('M10', 'the migration\'s ATTENTION not counted', [(U, 'ATTENTION=$(( TEMPLATES_SKIPPED + pc_pending_count + migrate_attention_count ))', 'ATTENTION=$(( TEMPLATES_SKIPPED + pc_pending_count ))')]),
    ('M11', 'PROJECT MIGRATED printed after the diffs', [(U, 'if [ "$migrated_count" -gt 0 ]; then\n  echo "--- PROJECT MIGRATED', 'if false; then\n  echo "--- PROJECT MIGRATED'), (U, 'if [ "$ATTENTION" -gt 0 ]; then\n  echo "NEEDS ATTENTION: $ATTENTION', 'if [ "$migrated_count" -gt 0 ]; then echo "--- PROJECT MIGRATED ($migrated_count) ---"; migrate_blocks MIGRATED; fi\nif [ "$ATTENTION" -gt 0 ]; then\n  echo "NEEDS ATTENTION: $ATTENTION')]),
    ('M12', 'AGENTS.md not byte-equal (a newline added)', [(M, 'copy_exact() { cp "$1" "$2" && chmod u+w "$2" && cmp -s "$1" "$2"; }', 'copy_exact() { { cat "$1"; echo; } > "$2"; }')]),
    ('M13', 'nested CLAUDE.md files not listed', [(M, 'if [ -n "$nested" ]; then', 'if false; then')]),
    ('M14', 'CLAUDE.local.md not noted', [(M, 'if [ -e "$ROOT/CLAUDE.local.md" ] || [ -L "$ROOT/CLAUDE.local.md" ]; then', 'if false; then')]),
    ('M15', 'code spans not stripped from imports', [(M, '      gsub(/`[^`]*`/, "", line)\n', '')]),
    ('M16', 'the home directory accepted as the root', [(M, 'if [ "$ROOT" = "/" ] || { [ -n "$home_l" ] && { [ "$ROOT" = "$home_l" ] || [ "$ROOT" = "$home_p" ]; }; }; then', 'if false; then')]),
    ('M17', 'a new root file diffed against nothing', [(U, 'if [ -f "$BEFORE_DIR/__root__$rf" ]; then', 'if true; then')]),
    ('M18', 'a git-ignored CLAUDE.md is migrated', [(M, '  elif git_ignored CLAUDE.md; then', '  elif false; then')]),
    ('M19', 'a git-ignored AGENTS.md is written', [(M, '  elif git_ignored AGENTS.md; then\n    echo "ATTENTION: AGENTS.md is ignored by git here', '  elif false; then\n    echo "ATTENTION: AGENTS.md is ignored by git here')]),
    ('M20', 'an import of a git-ignored AGENTS.md is created', [(M, '  elif git_ignored AGENTS.md; then\n    echo "ATTENTION: AGENTS.md is ignored by git, so', '  elif false; then\n    echo "ATTENTION: AGENTS.md is ignored by git, so')]),
    ('M21', 'a symlink on the skills path not refused', [(M, '  if link="$(symlink_on_path "$SKILLS_DIR")"; then', '  if false; then')]),
    ('M22', 'physical paths instead of the path as given', [(M, 'SKILLS_DIR="$(cd "$SKILLS_DIR" && pwd)"   # absolute, symlinks kept as given', 'SKILLS_DIR="$(cd "$SKILLS_DIR" && pwd -P)"'), (M, '  if link="$(symlink_on_path "$SKILLS_DIR")"; then', '  if false; then')]),
    ('M23', 'a byte order mark not skipped', [(M, 'NR == 1 { bom = sprintf("%c%c%c", 239, 187, 191); if (index($0, bom) == 1) $0 = substr($0, 4) }', 'NR == 0 { }')]),
    ('M24', 'multi-line HTML comments not skipped', [(M, '       incomment { if (index($0, "-->")) incomment = 0; next }\n', ''), (M, '/^[[:space:]]*<!--/ { if (!index($0, "-->")) incomment = 1; next }', '/^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }')]),
    ('M25', 'a self-importing CLAUDE.md is migrated', [(M, '  elif [ "$self_import" = "1" ]; then', '  elif false; then')]),
    ('M26', 'AGENTS.md keeps a read-only mode', [(M, 'copy_exact() { cp "$1" "$2" && chmod u+w "$2" && cmp -s "$1" "$2"; }', 'copy_exact() { cp -p "$1" "$2" && cmp -s "$1" "$2"; }')]),
    ('M27', '@mentions listed as imports', [(M, '      *) [ -f "$(resolve_import "$f" "$imp")" ] && echo "$imp" ;;', '      *) echo "$imp" ;;')]),
    ('M28', 'the import list is not capped', [(M, 'printf \'%s\\n\' "$hops" | head -n 20 | while', 'printf \'%s\\n\' "$hops" | while')]),
    ('M29', 'imports near the hop limit not flagged', [(M, '  if [ $((hop + 1)) -eq 4 ]; then note="$note (now at hop 4, Claude Code\'s limit)"; fi\n', ''), (M, '  if [ $((hop + 1)) -gt 4 ]; then note="$note (now at hop $((hop + 1)): Claude Code no longer loads it)"; fi\n', '')]),
    ('M30', 'awk runs in the user\'s locale', [(M, 'export LC_ALL=C   # byte-wise awk/grep/sort: no multibyte warnings on any content', ':')]),
    ('M31', 'an unreadable CLAUDE.md is not caught up front', [(M, 'elif [ -f "$CL" ] && [ ! -r "$CL" ]; then', 'elif false; then')]),
    ('M32', 'the temporary file outlives a failure', [(M, '  rm -f "$tmp"\n  return 1', '  return 1')]),
    ('M33', 'a dot-directory in the home directory accepted', [(M, '      .*) root_refused "that would make $ROOT, a dot-directory in the home directory, the project." ;;', '      .*) ;;')]),
    ('M34', 'the backup directory not ignored by git', [(M, '  [ -e "$dir/.gitignore" ] || printf', '  false && printf')]),
    ('M35', 'the CLAUDE.md opt-out ignored', [(M, '  if [ -n "${SKILLS_NO_CLAUDE_MD:-}" ] || [ -e "$SKILLS_DIR/.no-claude-md" ]; then', '  if false; then')]),
    ('M36', 'remaining CLAUDE.md mentions not listed', [(M, '      if [ -n "$mentions" ]; then', '      if false; then')]),
    ('M37', 'no reminder to re-run the installers or not to commit the backup', [(M, '      echo "  git ignores the backup directory (its own .gitignore): do not commit it, and"\n', ''), (M, '      echo "  Re-run scripts/install-claude-agents.sh / install-copilot-agents.sh if you use"\n', '')]),
    ('M38', 'the working-tree wording dropped', [(M, '        *) echo "  CLAUDE.md had uncommitted changes (git status \'$git_state\'): the working-tree"\n           echo "  version is what moved to AGENTS.md and the backup." ;;', '        *) echo "  CLAUDE.md had uncommitted changes." ;;')]),
    ('M39', '.claude/CLAUDE.md not reported', [(M, 'if [ -e "$ROOT/.claude/CLAUDE.md" ] || [ -L "$ROOT/.claude/CLAUDE.md" ]; then', 'if false; then')]),
    ('M40', 'update.sh leaves its self-copy in TMPDIR', [(U, '  if [ -n "${_UPDATE_SKILLS_TMP_SELF:-}" ]; then rm -f "$_UPDATE_SKILLS_TMP_SELF"; fi\n', '')]),
    ('M41', 'the self-update exec leaves its temporary files', [(U, '  rm -rf "$BEFORE_DIR" "$AFTER_DIR" "$CONTEXT_DIR" "$AWK_EXTRACT" "$MIGRATE_OUT"\n  _UPDATE_SKILLS_SELF_UPDATED=1', '  _UPDATE_SKILLS_SELF_UPDATED=1')]),
]

def run(args, cwd, **kw):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, **kw)

def main(argv):
    want = set(argv)
    chosen = [m for m in MUTANTS if not want or m[0] in want]
    scratch = tempfile.mkdtemp(prefix='update-skills-mutants-')
    env = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'SKILLS_'))}
    env.update(GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t', GIT_COMMITTER_EMAIL='t@t')
    survivors = []
    try:
        for mid, desc, edits in chosen:
            d = os.path.join(scratch, mid)
            r = run(['git', 'clone', '-q', '--no-hardlinks', REPO, d], cwd=scratch, env=env)
            assert r.returncode == 0, r.stderr
            for f, old, new in edits:
                p = os.path.join(d, f); t = open(p).read()
                if t.count(old) != 1:
                    print(f'{mid}: pattern not found once in {f}: {old[:60]!r}'); return 2
                open(p, 'w').write(t.replace(old, new))
            r = run(['git', 'commit', '-qam', 'mutant ' + mid], cwd=d, env=env)
            assert r.returncode == 0, r.stderr
            h = run([sys.executable, os.path.join(HERE, 'harness.py'), '--src-repo', d, '--groups', 'migration'], cwd=scratch, env=env)
            fails = [l[6:] for l in h.stdout.splitlines() if l.startswith('FAIL')]
            last = (h.stdout.strip().splitlines() or ['(no output) ' + h.stderr[-300:]])[-1]
            print(f'{mid} {desc}: {last}', flush=True)
            for f in fails[:3]: print('     FAIL', f)
            if len(fails) > 3: print(f'     ... {len(fails) - 3} more')
            if not fails: survivors.append(mid)
            shutil.rmtree(d, ignore_errors=True)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    print(f'{len(chosen) - len(survivors)} of {len(chosen)} mutants caught' + (f'; SURVIVED: {" ".join(survivors)}' if survivors else ''))
    return 1 if survivors else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
