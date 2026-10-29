#!/usr/bin/env python3
"""Scenario harness for update-skills/update.sh and scripts/migrate-agents-md.sh.

Every case builds a real scratch project (a git repository unless the case says
otherwise), installs the skills from an older commit of this repository, and runs that
install's update.sh with SKILLS_UPSTREAM pointing at the commit under test, so each run
goes through the self-update re-exec path, as a real /update-skills does. Checks compare
bytes, and stderr must stay empty.

Needs only python3 (3.8+), git and bash. Nothing is written outside a fresh temporary
directory: every subprocess gets an argument list (no shell), a working directory and a
HOME inside it, and git config from an empty file there.

    python3 tests/update-skills/harness.py                # test this repository's HEAD
    python3 tests/update-skills/harness.py --src-ref <rev>
    python3 tests/update-skills/harness.py --src-repo <clone> --groups migration

Exit status: 0 when every check passes, 1 when any fails, 2 when it could not run (for
example a shallow clone without the older commits it installs from).
"""
import argparse, hashlib, os, re, shutil, stat, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
# A commit before the AGENTS.md migration (main after PR #6): installs come from here,
# so the update re-execs into the new update.sh.
MIGRATION_BASE = '415f44a'
# The last commit whose skills still carry "## Project Context" blocks (before PR #6).
PROJECT_CONTEXT_BASE = '4dc02b1'
GROUPS = ('migration', 'project-context', 'templates', 'rules')

# ── Fixtures, built inline ───────────────────────────────────────────────────

def real_claude_md():
    """A real-shaped project CLAUDE.md: sections, tables, fences, non-ASCII text."""
    rows = ''.join(f'| ADR-{n:04d} | Decision {n} — keeps the rule “as it stands” → see the ADR |\n' for n in range(1, 61))
    return (
        '# CLAUDE.md — Acme Notes\n\n'
        '## STOP — how to run a command\n\n'
        '**Use absolute paths. Never `cd`.** If a command needs two directories, it needs two calls.\n\n'
        '---\n\n## Active Skillset: typescript\n\n'
        'This project follows [`RULES.md`](.opencode/skills/RULES.md) plus the overlay.\n\n'
        '## Tech Stack\n\n| Concern | Choice |\n|---|---|\n| Framework | NestJS 11 |\n'
        '| Database | PostgreSQL 16 (local) / Aurora DSQL (prod) |\n| Crypto | AES-256-GCM, PBKDF2 600k |\n\n'
        '## Repository Structure\n\n```\nacme/\n├── backend/      NestJS API\n│   └── src/\n'
        '├── frontend/     Next.js 16\n└── docs/\n```\n\n'
        '## Settled Decisions (do not revisit without a superseding ADR)\n\n| # | Decision |\n|---|---|\n'
        + rows +
        '\n## Edge Cases & Gotchas\n\n- DSQL has no foreign keys; use `createIndexSql()`.\n'
        '- Emoji-free, but naïve café façade text must survive byte for byte.\n'
    ).encode('utf-8')

REAL = real_claude_md()

# ── Plumbing ─────────────────────────────────────────────────────────────────

class Env:
    def __init__(self, root):
        self.root = root
        self.home = os.path.join(root, 'home'); os.makedirs(self.home)
        self.gitconfig = os.path.join(root, 'gitconfig'); open(self.gitconfig, 'w').close()
        self.base = dict(os.environ)
        for k in list(self.base):
            if k.startswith('GIT_') or k.startswith('SKILLS_') or k.startswith('_UPDATE_SKILLS'):
                del self.base[k]
        self.base.update(HOME=self.home, GIT_CONFIG_GLOBAL=self.gitconfig, GIT_CONFIG_NOSYSTEM='1',
                         GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
                         GIT_COMMITTER_EMAIL='t@t', LC_ALL='C.UTF-8', LANG='C.UTF-8')

    def run(self, args, cwd, env=None, stdin=None):
        assert os.path.realpath(cwd).startswith(os.path.realpath(self.root)) or cwd == '/', cwd
        e = dict(self.base); e.update(env or {})
        return subprocess.run(args, cwd=cwd, env=e, input=stdin, capture_output=True)

    def git(self, *args, cwd):
        r = self.run(['git'] + list(args), cwd=cwd)
        if r.returncode != 0:
            raise RuntimeError(f'git {args} failed: {r.stderr.decode()}')
        return r.stdout.decode()

def sha(b): return hashlib.sha256(b).hexdigest()[:12]

def mode(p):
    """The permission bits of p, or None when it does not exist."""
    return stat.S_IMODE(os.stat(p).st_mode) if os.path.exists(p) else None

def listdir(p): return sorted(os.listdir(p)) if os.path.isdir(p) else None

def rd(p):
    return open(p, 'rb').read() if os.path.lexists(p) and not os.path.islink(p) and os.path.isfile(p) else None

def tree(d):
    out = {}
    for root, dirs, files in os.walk(d):
        dirs[:] = [x for x in dirs if x != '.git']
        for f in files:
            p = os.path.join(root, f); r = os.path.relpath(p, d)
            out[r] = ('L:' + os.readlink(p)) if os.path.islink(p) else sha(open(p, 'rb').read())
    return out

def section(out, title):
    m = re.search(r'^--- ' + re.escape(title) + r'.*?(?=^--- |\Z)', out, re.M | re.S)
    return m.group(0) if m else ''

def first_diff_pos(out):
    pos = [m.start() for m in re.finditer(r'^--- (MODIFIED|ADDED|REMOVED|ROOT FILES|SCRIPTS|SKILL FILES|RULES OVERLAYS|PROFILES|TEMPLATES)', out, re.M)]
    return min(pos) if pos else len(out)

def status(out):
    m = re.search(r'^STATUS: (\S+)', out, re.M); return m.group(1) if m else None

def has_line(out, pattern): return re.search(pattern, out, re.M) is not None

class Harness:
    def __init__(self, env, src, tpl):
        self.env, self.src, self.tpl = env, src, tpl
        self.results = []

    def check(self, case, name, ok):
        self.results.append((case, name, bool(ok)))

    def install(self, dest, ref):
        os.makedirs(dest, exist_ok=True)
        tar = self.env.run(['git', '-C', REPO, 'archive', ref], cwd=self.env.root)
        assert tar.returncode == 0, tar.stderr
        r = self.env.run(['tar', '-x', '-C', dest], cwd=self.env.root, stdin=tar.stdout)
        assert r.returncode == 0, r.stderr

    def project(self, name, files=None, skills_rel='.opencode/skills', git=True, commit=True, ref=MIGRATION_BASE):
        P = os.path.join(self.env.root, 'cases', name, 'p'); os.makedirs(P)
        if git: self.env.git('init', '-q', cwd=P)
        S = os.path.join(P, skills_rel)
        if skills_rel: self.install(S, ref)
        for rel, content in (files or {}).items():
            fp = os.path.join(P, rel); os.makedirs(os.path.dirname(fp), exist_ok=True)
            if isinstance(content, tuple) and content[0] == 'symlink':
                os.symlink(content[1], fp)
            else:
                open(fp, 'wb').write(content)
        if git and commit:
            self.env.git('add', '-A', cwd=P); self.env.git('commit', '-qm', 'init', '--allow-empty', cwd=P)
        return P, S

    def update(self, P, skills_rel='.opencode/skills', env=None, cwd=None, src=None):
        """Run the project's own update.sh by its path relative to the project, as a user does."""
        # A fresh TMPDIR per run: what update.sh leaves there is checked by some cases.
        tmp = tempfile.mkdtemp(prefix='tmpdir-', dir=self.env.root)
        e = {'SKILLS_UPSTREAM': 'file://' + (src or self.src), 'TMPDIR': tmp}; e.update(env or {})
        script = os.path.join(skills_rel, 'update-skills', 'update.sh') if cwd is None else os.path.join(P, skills_rel, 'update-skills', 'update.sh')
        r = self.env.run(['bash', script], cwd=cwd or P, env=e)
        self.tmp_left = sorted(os.listdir(tmp))
        return r.returncode, r.stdout.decode('utf-8', 'replace'), r.stderr.decode('utf-8', 'replace')

    def common(self, case, rc, out, err, self_update=True):
        logdir = os.path.join(self.env.root, 'logs'); os.makedirs(logdir, exist_ok=True)
        open(os.path.join(logdir, case + '.log'), 'w').write(out + '\n--- stderr ---\n' + err)
        self.check(case, 'exit 0', rc == 0)
        if self_update: self.check(case, 'self-update re-exec path taken', 'update.sh changed upstream' in out)
        self.check(case, 'nothing on stderr', err.strip() == '')

# ── Migration cases ──────────────────────────────────────────────────────────

def migration(h):
    TPL, env = h.tpl, h.env
    att = lambda out: section(out, 'NEEDS ATTENTION')
    mig = lambda out: section(out, 'PROJECT MIGRATED')
    notes = lambda out: section(out, 'PROJECT NOTES')
    no_project_line = lambda out: not has_line(out, r'^PROJECT: ')

    # (a) only CLAUDE.md; also a doc that still names CLAUDE.md
    P, S = h.project('a', {'CLAUDE.md': REAL, 'docs/setup.md': b'Read CLAUDE.md first.\n'})
    rc, out, err = h.update(P); h.common('a', rc, out, err)
    bk = S + '/.agents-md-backup'
    h.check('a', 'AGENTS.md == original CLAUDE.md, byte for byte', rd(P + '/AGENTS.md') == REAL)
    h.check('a', 'CLAUDE.md == CLAUDE.md.template, byte for byte', rd(P + '/CLAUDE.md') == TPL)
    h.check('a', 'backup .agents-md-backup/CLAUDE.md.backup == original', rd(bk + '/CLAUDE.md.backup') == REAL)
    h.check('a', 'backup dir holds the backup and its .gitignore only', listdir(bk) == ['.gitignore', 'CLAUDE.md.backup'])
    h.check('a', 'git ignores the backup (not in git status, check-ignore says so)',
            env.run(['git', 'check-ignore', '-q', '.opencode/skills/.agents-md-backup/CLAUDE.md.backup'], cwd=P).returncode == 0
            and '.agents-md-backup' not in env.git('status', '--porcelain', '--untracked-files=all', cwd=P))
    h.check('a', 'STATUS: updated + PROJECT: line', status(out) == 'updated' and has_line(out, r'^PROJECT: 1 change'))
    h.check('a', 'PROJECT MIGRATED above every diff, with the backup path', mig(out) and out.find('--- PROJECT MIGRATED') < first_diff_pos(out) and '.agents-md-backup/CLAUDE.md.backup' in mig(out))
    h.check('a', 'report: do not commit the backup; re-run the installers', 'do not commit it' in mig(out) and 'install-claude-agents.sh' in mig(out))
    h.check('a', 'report lists docs/setup.md as still mentioning CLAUDE.md', 'still mention CLAUDE.md' in mig(out) and 'docs/setup.md' in mig(out))
    h.check('a', 'no NEEDS ATTENTION', '--- NEEDS ATTENTION' not in out)
    h.check('a', 'nothing under the skills dir is named CLAUDE.md', not any(f == 'CLAUDE.md' for _, _, fs in os.walk(S) for f in fs))
    a_P = P

    # (b) CLAUDE.md is the import: exact template; comment first + Claude-only text;
    #     a UTF-8 BOM and a multi-line HTML comment before the import
    for sub, cl in [('b1', TPL),
                    ('b2', b'<!-- Claude only below -->\n\n@AGENTS.md\n\n## Claude Code\n\nUse plan mode for billing.\n'),
                    ('b3', b'\xef\xbb\xbf<!--\n  maintainer notes\n  over several lines\n-->\n@AGENTS.md\n')]:
        P, S = h.project(sub, {'CLAUDE.md': cl, 'AGENTS.md': REAL})
        rc, out, err = h.update(P); h.common(sub, rc, out, err)
        h.check(sub, 'CLAUDE.md and AGENTS.md unchanged', rd(P + '/CLAUDE.md') == cl and rd(P + '/AGENTS.md') == REAL)
        h.check(sub, 'not reported (no PROJECT line, no project sections, no attention)', no_project_line(out) and not has_line(out, r'^--- PROJECT') and '--- NEEDS ATTENTION' not in out)
        h.check(sub, 'no backup dir', not os.path.exists(S + '/.agents-md-backup'))

    # (c) both exist, CLAUDE.md not the import
    P, S = h.project('c', {'CLAUDE.md': REAL, 'AGENTS.md': b'# other agents\n'})
    rc, out, err = h.update(P); h.common('c', rc, out, err)
    h.check('c', 'both files unchanged', rd(P + '/CLAUDE.md') == REAL and rd(P + '/AGENTS.md') == b'# other agents\n')
    h.check('c', 'NEEDS ATTENTION: merge, Claude reads only CLAUDE.md', 'both AGENTS.md and CLAUDE.md exist' in att(out) and 'reads only CLAUDE.md' in att(out) and 'Merge' in att(out))
    h.check('c', 'STATUS: needs-attention, attention above diffs', status(out) == 'needs-attention' and out.find('--- NEEDS ATTENTION') < first_diff_pos(out))
    h.check('c', 'no backup dir, no PROJECT line', not os.path.exists(S + '/.agents-md-backup') and no_project_line(out))

    # (d) only AGENTS.md
    P, S = h.project('d', {'AGENTS.md': REAL})
    rc, out, err = h.update(P); h.common('d', rc, out, err)
    h.check('d', 'CLAUDE.md created == template', rd(P + '/CLAUDE.md') == TPL)
    h.check('d', 'AGENTS.md unchanged', rd(P + '/AGENTS.md') == REAL)
    h.check('d', 'reported as created + PROJECT line', 'CLAUDE.md created as the import' in mig(out) and has_line(out, r'^PROJECT: 1'))

    # (d-opt) only AGENTS.md, opted out: a .no-claude-md marker, or SKILLS_NO_CLAUDE_MD=1
    for sub, files, extra in [('d-opt-marker', {'AGENTS.md': REAL, '.opencode/skills/.no-claude-md': b''}, None),
                              ('d-opt-env', {'AGENTS.md': REAL}, {'SKILLS_NO_CLAUDE_MD': '1'})]:
        P, S = h.project(sub, files)
        rc, out, err = h.update(P, env=extra); h.common(sub, rc, out, err)
        h.check(sub, 'CLAUDE.md not created, AGENTS.md unchanged', not os.path.lexists(P + '/CLAUDE.md') and rd(P + '/AGENTS.md') == REAL)
        h.check(sub, 'noted as opted out, no PROJECT line', 'CLAUDE.md not created (opted out' in notes(out) and no_project_line(out))

    # (e) neither
    P, S = h.project('e', {'README.md': b'# x\n'})
    rc, out, err = h.update(P); h.common('e', rc, out, err)
    h.check('e', 'no AGENTS.md / CLAUDE.md created', not os.path.lexists(P + '/AGENTS.md') and not os.path.lexists(P + '/CLAUDE.md'))
    h.check('e', 'exactly one note, saying bootstrap/onboard write them', len(re.findall(r'^  \S', notes(out), re.M)) == 1 and 'project-bootstrap or' in notes(out))
    h.check('e', 'STATUS: updated (skills only), no PROJECT line', status(out) == 'updated' and no_project_line(out))
    rc2, out2, err2 = h.update(P)
    h.check('e', 'second run: up-to-date and the note still printed', status(out2) == 'up-to-date' and 'no AGENTS.md or CLAUDE.md' in out2 and err2.strip() == '')

    # (f) CLAUDE.md is a symlink
    P, S = h.project('f', {'docs/real.md': REAL, 'CLAUDE.md': ('symlink', 'docs/real.md')})
    rc, out, err = h.update(P); h.common('f', rc, out, err)
    h.check('f', 'symlink untouched, target unchanged', os.path.islink(P + '/CLAUDE.md') and os.readlink(P + '/CLAUDE.md') == 'docs/real.md' and rd(P + '/docs/real.md') == REAL)
    h.check('f', 'no AGENTS.md, no backup', not os.path.lexists(P + '/AGENTS.md') and not os.path.exists(S + '/.agents-md-backup'))
    h.check('f', 'NEEDS ATTENTION names the symlink', 'CLAUDE.md is a symlink' in att(out) and status(out) == 'needs-attention')

    # (g) CLAUDE.local.md present
    LOCAL = b'my sandbox: http://localhost:3000\n'
    P, S = h.project('g', {'CLAUDE.md': REAL, 'CLAUDE.local.md': LOCAL})
    rc, out, err = h.update(P); h.common('g', rc, out, err)
    h.check('g', 'CLAUDE.local.md byte-equal', rd(P + '/CLAUDE.local.md') == LOCAL)
    h.check('g', 'noted as personal', 'CLAUDE.local.md left as it is' in notes(out))
    h.check('g', 'root CLAUDE.md still migrated', rd(P + '/AGENTS.md') == REAL and rd(P + '/CLAUDE.md') == TPL)

    # (h) @-imports (code spans, a span with spaces, a fence, a mention); nested CLAUDE.md files
    HX = (b'# Facts\n\nSee @docs/x.md and @README, not `@docs/code-span.md` or `run @docs/span-two.md now`.\n'
          b'Ask @gareth before a release.\n\n```\n@docs/in-fence.md\n```\n\n- git workflow @docs/git/flow.md\n')
    NESTED = b'# backend-only notes\n'
    P, S = h.project('h', {'CLAUDE.md': HX, 'docs/x.md': b'x\n', 'README': b'r\n', 'docs/git/flow.md': b'f\n',
                           'backend/CLAUDE.md': NESTED, 'frontend/src/CLAUDE.md': NESTED})
    rc, out, err = h.update(P); h.common('h', rc, out, err)
    ag = rd(P + '/AGENTS.md') or b''
    real = ['README', 'docs/git/flow.md', 'docs/x.md']
    h.check('h', 'AGENTS.md == original bytes', ag == HX)
    h.check('h', 'the real imports resolve relative to AGENTS.md (same dir)', all(os.path.exists(os.path.join(P, t)) for t in real))
    m = mig(out)
    h.check('h', 'report lists the 3 imports, not code spans, fences or @gareth', all('@' + t in m for t in real) and 'code-span' not in m and 'span-two' not in m and 'in-fence' not in m and '@gareth' not in m and 'not found' not in m)
    h.check('h', 'nested CLAUDE.md files unchanged and listed', rd(P + '/backend/CLAUDE.md') == NESTED and rd(P + '/frontend/src/CLAUDE.md') == NESTED and 'backend/CLAUDE.md' in notes(out) and 'frontend/src/CLAUDE.md' in notes(out))
    h.check('h', 'no AGENTS.md written in subdirectories', not os.path.exists(P + '/backend/AGENTS.md'))

    # (h-depth) a chain CLAUDE.md -> a -> b -> c -> d: c is now at hop 4, d at hop 5
    P, S = h.project('h-depth', {'CLAUDE.md': b'# F\n@docs/a.md\n', 'docs/a.md': b'@b.md\n', 'docs/b.md': b'@c.md\n', 'docs/c.md': b'@d.md\n', 'docs/d.md': b'deep\n'})
    rc, out, err = h.update(P); h.common('h-depth', rc, out, err)
    m = mig(out)
    h.check('h-depth', 'migrated', rd(P + '/AGENTS.md') == b'# F\n@docs/a.md\n')
    h.check('h-depth', 'c flagged at the limit, d flagged as no longer loaded, a/b not flagged',
            re.search(r'@docs/c\.md \(now at hop 4', m) and re.search(r'@docs/d\.md \(now at hop 5: Claude Code no longer loads it', m)
            and re.search(r'@docs/a\.md\n', m) and re.search(r'@docs/b\.md\n', m))

    # (h-cap) 25 imports: 20 listed and "... and 5 more"; invalid UTF-8 in the text
    many = b''.join(b'- @docs/f%02d.md\n' % i for i in range(25))
    files = {'CLAUDE.md': b'# Many\n\xff\xfe not UTF-8 \xe2\x80\n' + many}
    files.update({'docs/f%02d.md' % i: b'x\n' for i in range(25)})
    P, S = h.project('h-cap', files)
    rc, out, err = h.update(P); h.common('h-cap', rc, out, err)
    m = mig(out)
    h.check('h-cap', 'AGENTS.md byte-equal (invalid UTF-8 kept)', rd(P + '/AGENTS.md') == files['CLAUDE.md'])
    h.check('h-cap', '20 imports listed, then "... and 5 more"', len(re.findall(r'^      @docs/f\d\d\.md', m, re.M)) == 20 and '... and 5 more' in m)

    # (i) second run on (a): idempotent
    before = tree(a_P)
    rc, out, err = h.update(a_P)
    h.check('i', 'second run exit 0, STATUS: up-to-date, stderr empty', rc == 0 and status(out) == 'up-to-date' and err.strip() == '')
    h.check('i', 'project tree byte-identical (AGENTS, CLAUDE, backup)', tree(a_P) == before)
    h.check('i', 'no MIGRATED, no attention', 'MIGRATED' not in out and 'NEEDS ATTENTION' not in out)
    h.check('i', 'the installed (new) update.sh leaves nothing in TMPDIR', h.tmp_left == [])

    # (i2) a different backup already there
    P, S = h.project('i2', {'CLAUDE.md': REAL, '.opencode/skills/.agents-md-backup/CLAUDE.md.backup': b'older backup\n'})
    rc, out, err = h.update(P); h.common('i2', rc, out, err)
    h.check('i2', 'older backup kept byte-equal', rd(S + '/.agents-md-backup/CLAUDE.md.backup') == b'older backup\n')
    h.check('i2', 'new backup is CLAUDE.md.backup.2 == original, and reported', rd(S + '/.agents-md-backup/CLAUDE.md.backup.2') == REAL and 'CLAUDE.md.backup.2' in out)
    rc, out, err = h.update(P)
    h.check('i2', 'nothing new written on re-run', listdir(S + '/.agents-md-backup') == ['.gitignore', 'CLAUDE.md.backup', 'CLAUDE.md.backup.2'] and status(out) == 'up-to-date')

    # (j) uncommitted changes in CLAUDE.md
    P, S = h.project('j', {'CLAUDE.md': REAL})
    EDIT = REAL + b'\n- an uncommitted line\n'
    open(P + '/CLAUDE.md', 'wb').write(EDIT)
    rc, out, err = h.update(P); h.common('j', rc, out, err)
    h.check('j', 'AGENTS.md and backup == the working-tree version', rd(P + '/AGENTS.md') == EDIT and rd(S + '/.agents-md-backup/CLAUDE.md.backup') == EDIT)
    h.check('j', 'report: uncommitted changes, the working-tree version moved', 'uncommitted changes' in mig(out) and 'working-tree' in mig(out))

    # (k) no layout, no git: refused; with SKILLS_PROJECT_ROOT, migrated
    P, S = h.project('k', {'CLAUDE.md': REAL}, skills_rel='tools/skills', git=False)
    rc, out, err = h.update(P, skills_rel='tools/skills'); h.common('k', rc, out, err)
    h.check('k', 'nothing changed', rd(P + '/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md') and not os.path.exists(S + '/.agents-md-backup'))
    h.check('k', 'NEEDS ATTENTION: skipped, names SKILLS_PROJECT_ROOT', 'migration skipped' in att(out) and 'SKILLS_PROJECT_ROOT' in att(out))
    rc, out, err = h.update(P, skills_rel='tools/skills', env={'SKILLS_PROJECT_ROOT': P})
    h.check('k', 'with SKILLS_PROJECT_ROOT: migrated', rd(P + '/AGENTS.md') == REAL and rd(P + '/CLAUDE.md') == TPL and 'PROJECT MIGRATED' in out)

    # (l) ambiguous: <mono>/apps/web/.opencode/skills, git repository at <mono>
    P, S = h.project('l', {'CLAUDE.md': REAL, 'apps/web/CLAUDE.md': REAL}, skills_rel='apps/web/.opencode/skills')
    rc, out, err = h.update(P, skills_rel='apps/web/.opencode/skills'); h.common('l', rc, out, err)
    h.check('l', 'nothing changed at either candidate', rd(P + '/CLAUDE.md') == REAL and rd(P + '/apps/web/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md') and not os.path.lexists(P + '/apps/web/AGENTS.md'))
    h.check('l', 'NEEDS ATTENTION names both candidates', 'default layout gives' in att(out) and 'git repository is' in att(out) and status(out) == 'needs-attention')

    # (m) skills elsewhere inside a git repository, run from /: the git top is the root
    P, S = h.project('m', {'CLAUDE.md': REAL}, skills_rel='tools/skills')
    rc, out, err = h.update(P, skills_rel='tools/skills', cwd='/'); h.common('m', rc, out, err)
    h.check('m', 'migrated at the git top', rd(P + '/AGENTS.md') == REAL and rd(P + '/CLAUDE.md') == TPL)

    # (n) .claude/CLAUDE.md alone; (n2) with a root CLAUDE.md: root migrated, .claude/ left
    P, S = h.project('n', {'.claude/CLAUDE.md': REAL})
    rc, out, err = h.update(P); h.common('n', rc, out, err)
    h.check('n', '.claude/CLAUDE.md untouched + NEEDS ATTENTION', rd(P + '/.claude/CLAUDE.md') == REAL and '.claude/CLAUDE.md was left alone' in att(out))
    P, S = h.project('n2', {'.claude/CLAUDE.md': b'claude dir\n', 'CLAUDE.md': REAL})
    rc, out, err = h.update(P); h.common('n2', rc, out, err)
    h.check('n2', 'root migrated, .claude/CLAUDE.md untouched and reported', rd(P + '/AGENTS.md') == REAL and rd(P + '/CLAUDE.md') == TPL and rd(P + '/.claude/CLAUDE.md') == b'claude dir\n' and '.claude/CLAUDE.md was left alone' in att(out))

    # (o) AGENTS.md a symlink; (p) the import with no AGENTS.md
    P, S = h.project('o', {'CLAUDE.md': REAL, 'AGENTS.md': ('symlink', 'CLAUDE.md')})
    rc, out, err = h.update(P); h.common('o', rc, out, err)
    h.check('o', 'both untouched + NEEDS ATTENTION', rd(P + '/CLAUDE.md') == REAL and os.readlink(P + '/AGENTS.md') == 'CLAUDE.md' and 'AGENTS.md is a symlink' in att(out))
    P, S = h.project('p', {'CLAUDE.md': TPL})
    rc, out, err = h.update(P); h.common('p', rc, out, err)
    h.check('p', 'untouched + NEEDS ATTENTION', rd(P + '/CLAUDE.md') == TPL and not os.path.lexists(P + '/AGENTS.md') and 'which does not exist' in att(out))

    # (p-self) CLAUDE.md imports AGENTS.md further down: moving it would import itself
    SELF = b'# Facts\n\nShared rules: @AGENTS.md\n'
    P, S = h.project('p-self', {'CLAUDE.md': SELF})
    rc, out, err = h.update(P); h.common('p-self', rc, out, err)
    h.check('p-self', 'nothing changed, no backup', rd(P + '/CLAUDE.md') == SELF and not os.path.lexists(P + '/AGENTS.md') and not os.path.exists(S + '/.agents-md-backup'))
    h.check('p-self', 'NEEDS ATTENTION: would import itself', 'import itself' in att(out))

    # (r) home-directory install; (r2) a dot-directory in it (~/.claude)
    P, S = h.project('r', {'CLAUDE.md': REAL}, git=False)
    rc, out, err = h.update(P, env={'HOME': P}); h.common('r', rc, out, err)
    h.check('r', 'nothing changed in the home dir', rd(P + '/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md'))
    h.check('r', 'NEEDS ATTENTION: a skills install outside a project', 'outside a project' in att(out))
    H = os.path.join(env.root, 'cases', 'r2', 'home'); os.makedirs(H + '/.claude')
    open(H + '/.claude/CLAUDE.md', 'wb').write(REAL)
    h.install(H + '/.claude/.opencode/skills', MIGRATION_BASE)
    rc, out, err = h.update(H + '/.claude', env={'HOME': H}); h.common('r2', rc, out, err)
    h.check('r2', '~/.claude/CLAUDE.md untouched, no AGENTS.md', rd(H + '/.claude/CLAUDE.md') == REAL and not os.path.lexists(H + '/.claude/AGENTS.md'))
    h.check('r2', 'NEEDS ATTENTION: a dot-directory in the home directory', 'dot-directory in the home directory' in att(out))

    # (s) the skills dir is a symlink into another repository
    O = os.path.join(env.root, 'cases', 's', 'other'); os.makedirs(O); env.git('init', '-q', cwd=O)
    h.install(O + '/skills', MIGRATION_BASE)
    OTHER = b'# the other repository\n'
    open(O + '/CLAUDE.md', 'wb').write(OTHER); env.git('add', '-A', cwd=O); env.git('commit', '-qm', 'o', cwd=O)
    P, S = h.project('s', {'CLAUDE.md': REAL}, skills_rel='')
    os.makedirs(P + '/.opencode'); os.symlink(O + '/skills', P + '/.opencode/skills')
    rc, out, err = h.update(P); h.common('s', rc, out, err)
    h.check('s', 'neither repository changed', rd(P + '/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md') and rd(O + '/CLAUDE.md') == OTHER and not os.path.lexists(O + '/AGENTS.md'))
    h.check('s', 'NEEDS ATTENTION names the symlink and SKILLS_PROJECT_ROOT', 'is a symlink, so the project could be on either side' in att(out) and 'SKILLS_PROJECT_ROOT' in att(out))
    rc, out, err = h.update(P, env={'SKILLS_PROJECT_ROOT': P})
    h.check('s', 'with SKILLS_PROJECT_ROOT=<project>: the project migrated, the other repository untouched',
            rc == 0 and rd(P + '/AGENTS.md') == REAL and rd(P + '/CLAUDE.md') == TPL and rd(O + '/CLAUDE.md') == OTHER and not os.path.lexists(O + '/AGENTS.md'))

    # (u) git ignore state
    P, S = h.project('u1', {'CLAUDE.md': REAL, '.gitignore': b'CLAUDE.md\n'})
    rc, out, err = h.update(P); h.common('u1', rc, out, err)
    h.check('u1', 'ignored CLAUDE.md: nothing changed, no backup', rd(P + '/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md') and not os.path.exists(S + '/.agents-md-backup'))
    h.check('u1', 'NEEDS ATTENTION: ignored by git, private', 'CLAUDE.md is ignored by git' in att(out))
    P, S = h.project('u2', {'CLAUDE.md': REAL, '.gitignore': b'AGENTS.md\n'})
    rc, out, err = h.update(P); h.common('u2', rc, out, err)
    h.check('u2', 'AGENTS.md would be ignored: nothing changed', rd(P + '/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md'))
    h.check('u2', 'NEEDS ATTENTION: AGENTS.md ignored', 'AGENTS.md is ignored by git here' in att(out))
    P, S = h.project('u3', {'AGENTS.md': REAL, '.gitignore': b'AGENTS.md\n'})
    rc, out, err = h.update(P); h.common('u3', rc, out, err)
    h.check('u3', 'only an ignored AGENTS.md: CLAUDE.md not created', not os.path.lexists(P + '/CLAUDE.md') and 'AGENTS.md is ignored by git' in att(out))

    # (w) a read-only CLAUDE.md: AGENTS.md writable, the backup keeps the mode
    P, S = h.project('w', {'CLAUDE.md': REAL})
    os.chmod(P + '/CLAUDE.md', 0o444)
    rc, out, err = h.update(P); h.common('w', rc, out, err)
    h.check('w', 'AGENTS.md byte-equal and owner-writable', rd(P + '/AGENTS.md') == REAL and (mode(P + '/AGENTS.md') or 0) & stat.S_IWUSR)
    h.check('w', 'backup keeps the original mode (0444)', mode(S + '/.agents-md-backup/CLAUDE.md.backup') == 0o444)

    # (y) an unreadable CLAUDE.md
    P, S = h.project('y', {'CLAUDE.md': REAL})
    os.chmod(P + '/CLAUDE.md', 0)
    rc, out, err = h.update(P); h.common('y', rc, out, err)
    os.chmod(P + '/CLAUDE.md', 0o644)
    if os.geteuid() == 0:
        h.check('y', 'NOT VERIFIED: running as root, every file is readable', False)
    h.check('y', 'nothing changed; NEEDS ATTENTION says it cannot be read (not "stopped")', rd(P + '/CLAUDE.md') == REAL and not os.path.lexists(P + '/AGENTS.md') and 'cannot be read' in att(out) and 'stopped' not in out)

    # (z) CLAUDE.md cannot be replaced (mv fails): no temporary file left, CLAUDE.md intact
    P, S = h.project('z', {'CLAUDE.md': REAL})
    shim = os.path.join(env.root, 'cases', 'z', 'bin'); os.makedirs(shim)
    open(shim + '/mv', 'w').write('#!/bin/sh\nexit 1\n'); os.chmod(shim + '/mv', stat.S_IRWXU)  # a failing mv for this case only
    h.install(os.path.join(env.root, 'cases', 'z', 'new'), h.src_ref)
    r = env.run(['bash', os.path.join(env.root, 'cases', 'z', 'new', 'scripts', 'migrate-agents-md.sh'), '--skills-dir', S,
                 '--template', os.path.join(env.root, 'cases', 'z', 'new', 'CLAUDE.md.template')],
                cwd=P, env={'PATH': shim + os.pathsep + env.base['PATH']})
    o = r.stdout.decode()
    h.check('z', 'reported, CLAUDE.md unchanged, no .CLAUDE.md.agents-md.* left',
            'could not be' in o and rd(P + '/CLAUDE.md') == REAL and not [f for f in os.listdir(P) if f.startswith('.CLAUDE.md.agents-md')] and r.stderr.decode().strip() == '')

    # (q) skills already current: the migration alone sets STATUS
    P, S = h.project('q', {'CLAUDE.md': REAL}, ref=h.src_ref)
    rc, out, err = h.update(P); h.common('q', rc, out, err, self_update=False)
    h.check('q', 'migrated', rd(P + '/AGENTS.md') == REAL and rd(P + '/CLAUDE.md') == TPL)
    h.check('q', 'STATUS: updated with a PROJECT: line, no skill diff', status(out) == 'updated' and has_line(out, r'^PROJECT: 1 change') and first_diff_pos(out) == len(out))
    h.check('q', 'update.sh leaves nothing in TMPDIR', h.tmp_left == [])
    P, S = h.project('q-self', {}, ref=h.src_ref)
    newer = os.path.join(env.root, 'src-newer'); env.git('clone', '-q', h.src, newer, cwd=env.root)
    with open(newer + '/update-skills/update.sh', 'a') as f: f.write('# a later upstream change\n')
    env.git('commit', '-qam', 'newer', cwd=newer)
    rc, out, err = h.update(P, src=newer); h.common('q-self', rc, out, err)
    h.check('q-self', 'self-update from this version leaves nothing in TMPDIR', h.tmp_left == [])

# ── Earlier scenarios (PR #6): Project Context backups ───────────────────────

PLACE = re.compile(r'## Project Context\n\n> Fill in before use:.*?\n(?=\n---)', re.S)

def blk(text):
    """A skill's ## Project Context span, independent of the script's awk."""
    lines = text.split('\n'); out = []; b = False; fence = False
    for i, l in enumerate(lines):
        if i == len(lines) - 1 and l == '': break
        if re.match(r'^\s*(```|~~~)', l):
            fence = not fence
            if b: out.append(l)
            continue
        if not fence and l.startswith('## '): b = bool(re.match(r'^## Project Context\s*$', l))
        if b: out.append(l)
    return ''.join(x + '\n' for x in out)

def project_context(h):
    P, S = h.project('pc', {}, ref=PROJECT_CONTEXT_BASE)
    path = lambda s: f'{S}/{s}/SKILL.md'
    def setblock(s, new):
        t = open(path(s)).read(); m = PLACE.search(t); assert m, s
        open(path(s), 'w').write(t[:m.start()] + new + t[m.end():])
    setblock('developer', '## Project Context\n\n**Project:** Acme — NestJS + Next.js monorepo\n**Key rule:** money is integer cents\n')
    t = open(path('reviewer')).read(); m = PLACE.search(t)
    open(path('reviewer'), 'w').write(t[:m.end()] + '\nReviewers must check the FOO-17 invariant on every PR.\n' + t[m.end():])
    setblock('infosec', '## Project Context\n\n**Compliance:** SOC2\n\n```markdown\n## Not a heading\n---\nexample\n```\n\nAfter the fence: data classes are public / pii.\n')
    setblock('design', '## Project Context\n\n**Brand:** teal #0f766e, Inter.\n')
    t = open(path('decision-log')).read(); m = PLACE.search(t); t = t[:m.start()] + t[m.end():]
    open(path('decision-log'), 'w').write(t.rstrip('\n') + '\n\n## Project Context\n\nADRs live in docs/adr/, highest 0042.\nLast line with no newline at EOF')
    bk = S + '/.project-context-backup'; os.makedirs(bk)
    open(bk + '/developer.md', 'w').write('older content from an earlier run\n')
    h.env.git('add', '-A', cwd=P); h.env.git('commit', '-qm', 'filled', cwd=P)
    orig = {s: blk(open(path(s)).read()) for s in ['developer', 'reviewer', 'infosec', 'design', 'decision-log']}
    rc, out, err = h.update(P); h.common('pc', rc, out, err)
    r = lambda n: open(bk + '/' + n).read() if os.path.exists(bk + '/' + n) else None
    listed = lambda o: re.findall(r'^  \.project-context-backup/(\S+?):', o, re.M)
    h.check('pc', 'placeholder only (architect): no backup, not listed', not os.path.exists(bk + '/architect.md') and 'architect.md' not in listed(out))
    h.check('pc', 'fully filled (developer) -> developer.2.md, byte-equal, printed', r('developer.2.md') == orig['developer'] and 'integer cents' in out)
    h.check('pc', 'placeholder + facts (reviewer) byte-equal, printed', r('reviewer.md') == orig['reviewer'] and 'FOO-17' in out)
    h.check('pc', 'fenced ## and --- inside the block kept whole (infosec)', r('infosec.md') == orig['infosec'])
    h.check('pc', 'block at end of file, no newline at EOF (decision-log)', r('decision-log.md') == orig['decision-log'])
    h.check('pc', 'earlier backup with different content not overwritten', r('developer.md') == 'older content from an earlier run\n')
    h.check('pc', 'NEEDS ATTENTION printed before the diffs, STATUS needs-attention', status(out) == 'needs-attention' and out.find('--- NEEDS ATTENTION') < first_diff_pos(out))
    h.check('pc', 'no ## Project Context left in installed skills', all('## Project Context' not in blk(open(path(s)).read()) for s in os.listdir(S) if os.path.exists(path(s))))
    before = tree(bk)
    rc, out2, err2 = h.update(P)
    h.check('pc', 'second run: backups unchanged, each listed once as saved earlier', tree(bk) == before and sorted(listed(out2)) == sorted(os.listdir(bk)) and 'Saved this run' not in out2 and err2.strip() == '')
    os.remove(bk + '/design.md')
    rc, out3, err3 = h.update(P)
    h.check('pc', 'after deleting one backup: the rest listed, not that one', 'design.md' not in listed(out3) and sorted(listed(out3)) == sorted(os.listdir(bk)))

# ── Earlier scenarios (PR #6): templates/ marker ─────────────────────────────

def same_tree(a, b): return tree(a) == tree(b)

def templates(h):
    P, S = h.project('t1', {})
    os.remove(S + '/templates/.from-skills'); open(S + '/templates/mine.md', 'w').write('mine\n')
    before = tree(S + '/templates')
    rc, out, err = h.update(P); h.common('t1', rc, out, err)
    h.check('t1', 'no marker: templates/ byte-identical, NEEDS ATTENTION', tree(S + '/templates') == before and 'templates/ was not updated' in out and status(out) == 'needs-attention')
    P, S = h.project('t2', {})
    open(S + '/templates/stale.md', 'w').write('x\n')
    rc, out, err = h.update(P); h.common('t2', rc, out, err)
    h.check('t2', 'marker: templates/ == upstream templates/ (stale file removed)', same_tree(S + '/templates', h.src + '/templates'))
    src3 = os.path.join(h.env.root, 'src-no-templates')
    h.env.git('clone', '-q', h.src, src3, cwd=h.env.root)
    h.env.git('rm', '-rq', 'templates', cwd=src3); h.env.git('commit', '-qm', 'rm', cwd=src3)
    P, S = h.project('t3', {})
    rc, out, err = h.update(P, src=src3); h.common('t3', rc, out, err)
    h.check('t3', 'removed upstream: marked templates/ removed and reported', not os.path.exists(S + '/templates') and 'REMOVED upstream' in out)

# ── Earlier scenarios (PR #6): RULES.md record ───────────────────────────────

def rules(h):
    P = os.path.join(h.env.root, 'cases', 'r-rec', 'p'); os.makedirs(P); h.env.git('init', '-q', cwd=P)
    S = P + '/.opencode/skills'
    h.env.git('clone', '-q', REPO, S, cwd=P); h.env.git('checkout', '-q', MIGRATION_BASE, cwd=S)
    r = h.env.run(['bash', '.opencode/skills/scripts/install-claude-agents.sh'], cwd=P)
    had = os.path.exists(S + '/.rules-upstream.cksum')
    rc, out, err = h.update(P); h.common('r-rec', rc, out, err)
    new = h.env.run(['cksum'], cwd=P, stdin=open(h.src + '/RULES.md', 'rb').read()).stdout
    h.check('r-rec', 'installer wrote the record; update: no WARNING; record == new RULES.md', r.returncode == 0 and had and 'WARNING: installed RULES.md was edited locally' not in out and open(S + '/.rules-upstream.cksum', 'rb').read() == new)
    open(S + '/RULES.md', 'a').write('- local line\n')
    rc, out, err = h.update(P)
    h.check('r-rec', 'a local edit: WARNING printed, RULES.md restored', 'WARNING: installed RULES.md was edited locally' in out and rd(S + '/RULES.md') == rd(h.src + '/RULES.md'))
    P, S = h.project('r-vend', {})
    rc, out, err = h.update(P); h.common('r-vend', rc, out, err)
    rc2, out2, _ = h.update(P)
    h.check('r-vend', 'vendored, no record: Note once, record written, then quiet', 'No .rules-upstream.cksum record existed' in out and os.path.exists(S + '/.rules-upstream.cksum') and 'No .rules-upstream.cksum' not in out2 and 'WARNING' not in out2)

# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--src-ref', default='HEAD', help='commit of this repository to test (default HEAD)')
    ap.add_argument('--src-repo', help='test the HEAD of this git repository instead (the mutant runner uses it)')
    ap.add_argument('--groups', default=','.join(GROUPS), help='comma-separated: ' + ', '.join(GROUPS))
    ap.add_argument('--keep', action='store_true', help='keep the scratch directory and print its path')
    a = ap.parse_args()
    groups = [g for g in a.groups.split(',') if g]
    bad = [g for g in groups if g not in GROUPS]
    if bad: ap.error('unknown group(s): ' + ', '.join(bad))
    scratch = tempfile.mkdtemp(prefix='update-skills-harness-')
    env = Env(scratch)
    try:
        for ref in (MIGRATION_BASE, PROJECT_CONTEXT_BASE):
            if env.run(['git', '-C', REPO, 'cat-file', '-e', ref + '^{commit}'], cwd=scratch).returncode != 0:
                print(f'NOT RUN: commit {ref} is missing (shallow clone?); fetch the full history.'); return 2
        # The source under test: a clone with that commit checked out on its default branch.
        src = os.path.join(scratch, 'src')
        origin = a.src_repo or REPO
        env.git('clone', '-q', '--no-hardlinks', origin, src, cwd=scratch)
        ref = 'HEAD' if a.src_repo else a.src_ref
        commit = env.git('-C', origin, 'rev-parse', ref, cwd=scratch).strip()
        env.git('checkout', '-q', '-B', 'main', commit, cwd=src)
        tpl_path = os.path.join(src, 'CLAUDE.md.template')
        tpl = open(tpl_path, 'rb').read() if os.path.exists(tpl_path) else b'<no CLAUDE.md.template at the source>'
        h = Harness(env, src, tpl)
        h.src_ref = commit
        # (q) and (z) install the commit under test; it may exist only in the source clone
        # (a mutant), so archive it from there.
        orig_install = h.install
        def install(dest, ref, _orig=orig_install):
            if ref == commit:
                os.makedirs(dest, exist_ok=True)
                tar = env.run(['git', '-C', src, 'archive', commit], cwd=scratch)
                env.run(['tar', '-x', '-C', dest], cwd=scratch, stdin=tar.stdout)
            else:
                _orig(dest, ref)
        h.install = install
        print(f'source under test: {commit[:12]} ({origin}); installs from {MIGRATION_BASE}, {PROJECT_CONTEXT_BASE}')
        for g in groups:
            try:
                {'migration': migration, 'project-context': project_context, 'templates': templates, 'rules': rules}[g](h)
            except Exception as e:  # a crash is a failure, never a pass; later groups still run
                import traceback
                h.check(g, f'group crashed: {type(e).__name__}: {e} ({traceback.extract_tb(e.__traceback__)[-1].lineno})', False)
        fails = 0
        for c, n, ok in h.results:
            print(f'{"PASS" if ok else "FAIL"}  ({c}) {n}')
            fails += not ok
        print(f'{len(h.results) - fails} passed, {fails} failed, {len(h.results)} checks')
        return 1 if fails else 0
    finally:
        if a.keep: print('scratch kept:', scratch)
        else: shutil.rmtree(scratch, ignore_errors=True)

if __name__ == '__main__':
    sys.exit(main())
