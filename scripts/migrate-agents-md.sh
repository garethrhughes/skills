#!/usr/bin/env bash
# migrate-agents-md.sh - make the project's AGENTS.md the source of truth
#
# The project's facts live in AGENTS.md at the project root, which every coding
# agent reads. Claude Code reads AGENTS.md itself only when there is no CLAUDE.md,
# so the project also keeps a CLAUDE.md that is the import from CLAUDE.md.template
# (`@AGENTS.md`). This script moves a project from the old layout (facts in
# CLAUDE.md) to that one. update.sh runs it on every update; project-onboard runs it
# on a project that has only a CLAUDE.md. It is safe to run any number of times.
#
# Usage:
#   bash <skills>/scripts/migrate-agents-md.sh [--skills-dir DIR] [--template FILE]
#
#   --skills-dir  the project-local skills directory (default: this script's ../)
#   --template    the CLAUDE.md import template (default: <skills>/CLAUDE.md.template)
#
# The project root (where AGENTS.md and CLAUDE.md live) is found from the skills
# directory's path as given (not the physical path), never from the current
# directory:
#   1. SKILLS_PROJECT_ROOT, if set: it must contain the skills directory (both
#      compared as given, so a symlinked skills directory is fine here);
#   2. otherwise, if any component of the skills path is a symlink, nothing is
#      changed (the root could be either side of the link: set SKILLS_PROJECT_ROOT);
#   3. otherwise the default layout, <root>/.opencode/skills, gives <root>, and the
#      top level of the git repository containing the skills directory (its own
#      .git, if the skills are a clone, is skipped) gives another candidate. One
#      candidate, or two that agree, is the root. Two that differ, none, /, the home
#      directory or a dot-directory directly under it (~/.claude) is not: the
#      script changes nothing and reports why.
#
# What it does at the root:
#   only CLAUDE.md          -> the original is copied to
#                              <skills>/.agents-md-backup/CLAUDE.md.backup (.backup.2,
#                              ... if that name holds different content; never named
#                              CLAUDE.md, which Claude Code would load as instructions;
#                              the directory gets a .gitignore so git ignores it) and
#                              compared; AGENTS.md gets CLAUDE.md's bytes (writable,
#                              whatever the original's mode); CLAUDE.md becomes the
#                              import
#   only AGENTS.md          -> CLAUDE.md is created as the import, unless opted out:
#                              SKILLS_NO_CLAUDE_MD=1 or a file <skills>/.no-claude-md
#                              (Claude Code v2.1.277+ reads AGENTS.md by itself)
#   CLAUDE.md is the import -> nothing (its first content line, after a UTF-8 BOM,
#                              blank lines and HTML comments, is `@AGENTS.md`)
#   refused, nothing changed, reported under ATTENTION:
#     both files and CLAUDE.md not the import; either one a symlink or not a regular
#     file; CLAUDE.md unreadable; CLAUDE.md git-ignored (private: moving it would
#     share it) or AGENTS.md git-ignored (the import would point at a file the
#     repository never has); CLAUDE.md already importing AGENTS.md (it would import
#     itself); the import with no AGENTS.md
#   neither                 -> nothing (project-bootstrap / project-onboard write them)
#   .claude/CLAUDE.md       -> left alone and reported; the root is still handled
# It never overwrites AGENTS.md, never follows or replaces a symlink, never deletes
# a file, and never touches CLAUDE.local.md or a CLAUDE.md below the root.
#
# Output: a "ROOT: <dir> (found from ...)" line once the root is known, then one
# item per block. A block starts with "MIGRATED: ", "ATTENTION: " or "INFO: " and
# continues on lines indented by two spaces. MIGRATED changed a project file and
# needs no action beyond committing; ATTENTION needs the user; INFO is a note. The
# exit status is 0 unless the arguments are wrong.
#
# Compatible with bash 3 (macOS default).

set -euo pipefail
export LC_ALL=C   # byte-wise awk/grep/sort: no multibyte warnings on any content

usage() { echo "Usage: $0 [--skills-dir DIR] [--template FILE]" >&2; exit 2; }

SKILLS_DIR=""
TEMPLATE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skills-dir) [ $# -ge 2 ] || usage; SKILLS_DIR="$2"; shift 2 ;;
    --template)   [ $# -ge 2 ] || usage; TEMPLATE="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$SKILLS_DIR" ] || SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -d "$SKILLS_DIR" ] || { echo "Error: skills directory not found: $SKILLS_DIR" >&2; exit 2; }
SKILLS_DIR="$(cd "$SKILLS_DIR" && pwd)"   # absolute, symlinks kept as given
[ -n "$TEMPLATE" ] || TEMPLATE="$SKILLS_DIR/CLAUDE.md.template"

# The first line that is not blank, not inside an HTML comment (one or several
# lines), with a leading UTF-8 byte order mark and trailing blanks removed.
first_content_line() {
  awk 'NR == 1 { bom = sprintf("%c%c%c", 239, 187, 191); if (index($0, bom) == 1) $0 = substr($0, 4) }
       incomment { if (index($0, "-->")) incomment = 0; next }
       /^[[:space:]]*$/ { next }
       /^[[:space:]]*<!--/ { if (!index($0, "-->")) incomment = 1; next }
       { sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}
is_import() { [ -r "$1" ] && [ "$(first_content_line "$1")" = "@AGENTS.md" ]; }

# Print the first directory or file on the absolute path $1 that is a symlink.
symlink_on_path() {
  local rest="${1#/}" cur="" part
  while [ -n "$rest" ]; do
    part="${rest%%/*}"
    if [ "$part" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    cur="$cur/$part"
    if [ -L "$cur" ]; then echo "$cur"; return 0; fi
  done
  return 1
}

# ── Project root ─────────────────────────────────────────────────────────────
ROOT=""
ROOT_HOW=""
root_refused() {
  echo "ATTENTION: AGENTS.md migration skipped: $1"
  echo "  The skills are in $SKILLS_DIR. The project root is <root> in the default"
  echo "  layout <root>/.opencode/skills, or the top of the git repository that holds the"
  echo "  skills; set SKILLS_PROJECT_ROOT=<root> to name it, then run the update again."
  exit 0
}
if [ -n "${SKILLS_PROJECT_ROOT:-}" ]; then
  [ -d "$SKILLS_PROJECT_ROOT" ] || root_refused "SKILLS_PROJECT_ROOT ($SKILLS_PROJECT_ROOT) is not a directory."
  ROOT="$(cd "$SKILLS_PROJECT_ROOT" && pwd)"
  case "$SKILLS_DIR/" in
    "$ROOT"/*) ROOT_HOW="SKILLS_PROJECT_ROOT" ;;
    *) root_refused "SKILLS_PROJECT_ROOT ($ROOT) does not contain the skills directory ($SKILLS_DIR)." ;;
  esac
else
  if link="$(symlink_on_path "$SKILLS_DIR")"; then
    root_refused "$link is a symlink, so the project could be on either side of it."
  fi
  by_layout=""
  case "$SKILLS_DIR" in
    */.opencode/skills) by_layout="$(cd "$SKILLS_DIR/../.." && pwd)" ;;
  esac
  by_git="$(git -C "$(dirname "$SKILLS_DIR")" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$by_git" ] && by_git="$(cd "$by_git" && pwd)"
  if [ -n "$by_layout" ] && [ -n "$by_git" ] && [ "$by_layout" != "$by_git" ]; then
    root_refused "the default layout gives $by_layout but the git repository is $by_git."
  elif [ -n "$by_layout" ]; then
    ROOT="$by_layout"; ROOT_HOW="the .opencode/skills layout${by_git:+, matching git}"
  elif [ -n "$by_git" ]; then
    ROOT="$by_git"; ROOT_HOW="the git repository holding the skills"
  else
    root_refused "the skills are not in <root>/.opencode/skills and not inside a git repository."
  fi
  home_l="$( (cd "${HOME:-/nonexistent}" 2>/dev/null && pwd) || true)"
  home_p="$( (cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || true)"
  root_parent="$(dirname "$ROOT")"; root_base="$(basename "$ROOT")"
  if [ "$ROOT" = "/" ] || { [ -n "$home_l" ] && { [ "$ROOT" = "$home_l" ] || [ "$ROOT" = "$home_p" ]; }; }; then
    root_refused "that would make $ROOT the project (a skills install outside a project)."
  fi
  if [ -n "$home_l" ] && { [ "$root_parent" = "$home_l" ] || [ "$root_parent" = "$home_p" ]; }; then
    case "$root_base" in
      .*) root_refused "that would make $ROOT, a dot-directory in the home directory, the project." ;;
    esac
  fi
fi

CL="$ROOT/CLAUDE.md"
AG="$ROOT/AGENTS.md"
echo "ROOT: $ROOT (found from $ROOT_HOW)"

IN_GIT=0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && IN_GIT=1
git_ignored() { [ "$IN_GIT" = "1" ] && git -C "$ROOT" check-ignore -q -- "$1" 2>/dev/null; }

# ── Notes that never change anything ─────────────────────────────────────────
if [ -e "$ROOT/CLAUDE.local.md" ] || [ -L "$ROOT/CLAUDE.local.md" ]; then
  echo "INFO: CLAUDE.local.md left as it is: it is personal, not shared, and Claude Code"
  echo "  reads it with CLAUDE.md. Other agents do not read it."
fi
nested="$(find "$ROOT" \( -name .git -o -name node_modules -o -path "$SKILLS_DIR" -o -path "$ROOT/.claude" \) -prune \
  -o -name CLAUDE.md -type f -print 2>/dev/null | grep -v -x -F "$CL" | sort | head -n 20 || true)"
if [ -n "$nested" ]; then
  echo "INFO: CLAUDE.md files below the root were not migrated (only the root's is):"
  printf '%s\n' "$nested" | sed "s|^$ROOT/|  |"
  echo "  Claude Code loads each when it works in that directory; other agents read an"
  echo "  AGENTS.md there instead. Move one by hand if other agents should see it."
fi
if [ -e "$ROOT/.claude/CLAUDE.md" ] || [ -L "$ROOT/.claude/CLAUDE.md" ]; then
  echo "ATTENTION: .claude/CLAUDE.md was left alone (the root's files are handled as"
  echo "  usual). Claude Code reads it as project instructions; other agents do not. Move"
  echo "  what it holds into AGENTS.md and delete it."
fi

# ── Template ─────────────────────────────────────────────────────────────────
template_ok=1
if [ ! -f "$TEMPLATE" ] || ! is_import "$TEMPLATE"; then
  template_ok=0
fi
need_template() {
  echo "ATTENTION: $1 skipped: the import template $TEMPLATE is missing, unreadable or"
  echo "  does not start with @AGENTS.md. Nothing was changed."
}

# Copy $1 to a new file in <skills>/.agents-md-backup and print its path. An
# identical backup already there is reused; a different one is never replaced
# (the next free CLAUDE.md.backup.N is used). The directory ignores itself in git.
backup_claude_md() {
  local dir="$SKILLS_DIR/.agents-md-backup" target n
  mkdir -p "$dir"
  [ -e "$dir/.gitignore" ] || printf '%s\n' '# Backups made by migrate-agents-md.sh: never commit them.' '*' > "$dir/.gitignore"
  target="$dir/CLAUDE.md.backup"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if cmp -s "$1" "$target"; then echo "$target"; return 0; fi
    n=2
    while [ -e "$target.$n" ] || [ -L "$target.$n" ]; do
      if cmp -s "$1" "$target.$n"; then echo "$target.$n"; return 0; fi
      n=$((n+1))
    done
    target="$target.$n"
  fi
  cp -p "$1" "$target"
  cmp -s "$1" "$target" || return 1
  echo "$target"
}

# Copy $1 to the new file $2, writable by its owner whatever $1's mode, and
# confirm the copy is byte-equal.
copy_exact() { cp "$1" "$2" && chmod u+w "$2" && cmp -s "$1" "$2"; }

# Write the template to $1 through a temporary file in the same directory; the
# temporary file never outlives a failure.
write_import() {
  local tmp="$ROOT/.CLAUDE.md.agents-md.$$"
  if cp "$TEMPLATE" "$tmp" && mv -f "$tmp" "$1" && cmp -s "$TEMPLATE" "$1"; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# @-imports in $1 outside code spans and fenced blocks, one per line, sentence
# punctuation removed. Claude Code expands `@path` anywhere in the text.
raw_imports() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      n = split(line, w, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (w[i] ~ /^@[^@[:space:]]/) {
        p = substr(w[i], 2); sub(/[.,;:!?)]+$/, "", p)
        if (p != "") print p
      }
    }' "$1"
}
# Resolve import $2 found in file $1 to a path (relative imports from $1's directory).
resolve_import() {
  case "$2" in
    "~/"*) echo "${HOME:-}/${2#\~/}" ;;
    /*) echo "$2" ;;
    *) echo "$(dirname "$1")/$2" ;;
  esac
}
# Only path-like tokens count: a "/", "." or "~" in them, or an existing file
# (`@README`). `@someone` is a mention, not an import.
imports_of() {
  local f="$1" imp
  raw_imports "$f" | while IFS= read -r imp; do
    case "$imp" in
      */*|*.*|"~"*) echo "$imp" ;;
      *) [ -f "$(resolve_import "$f" "$imp")" ] && echo "$imp" ;;
    esac
  done
}
# Print "<hop> <path>" for every file reached from $1 through imports, $1's own
# imports being hop $2. Stops at hop 5 (Claude Code follows four).
import_hops() {
  local f="$1" hop="$2" imp p
  [ "$hop" -le 5 ] || return 0
  imports_of "$f" | while IFS= read -r imp; do
    p="$(resolve_import "$f" "$imp")"
    echo "$hop ${p#$ROOT/}"
    [ -f "$p" ] && [ -r "$p" ] && import_hops "$p" $((hop+1))
  done
}

# One line of the import list: hop $1 (from CLAUDE.md, before the move), path $2
# (relative to the root unless absolute). After the move every hop is one deeper.
print_hop() {
  local hop="$1" path="$2" full="$2" note=""
  if [ "${path#/}" = "$path" ]; then full="$ROOT/$path"; fi
  if [ ! -e "$full" ]; then note=" (not found, as before)"; fi
  if [ $((hop + 1)) -eq 4 ]; then note="$note (now at hop 4, Claude Code's limit)"; fi
  if [ $((hop + 1)) -gt 4 ]; then note="$note (now at hop $((hop + 1)): Claude Code no longer loads it)"; fi
  echo "    @$path$note"
}

# Files, outside the skills and the installers' copies, that still mention CLAUDE.md.
claude_md_mentions() {
  local skills_rel="${SKILLS_DIR#$ROOT/}"
  if [ "$IN_GIT" = "1" ]; then
    git -C "$ROOT" grep --untracked -l -I -F 'CLAUDE.md' -- . \
      ":(exclude)CLAUDE.md" ":(exclude)CLAUDE.local.md" ":(exclude)$skills_rel" \
      ":(exclude).claude/agents" ":(exclude).claude/RULES.md" ":(exclude).claude/rules" \
      ":(exclude).claude/profiles" ":(exclude).claude/templates" \
      ":(exclude).github/agents" ":(exclude).github/RULES.md" ":(exclude).github/rules" \
      ":(exclude).github/profiles" ":(exclude).github/templates" 2>/dev/null || true
  else
    grep -rlI -F 'CLAUDE.md' "$ROOT" --exclude-dir=.git --exclude-dir=node_modules \
      --exclude-dir=.claude --exclude-dir=.opencode --exclude=CLAUDE.md --exclude=CLAUDE.local.md \
      2>/dev/null | sed "s|^$ROOT/||" || true
  fi
}

# ── The root's AGENTS.md and CLAUDE.md ───────────────────────────────────────
if [ -L "$AG" ]; then
  echo "ATTENTION: AGENTS.md is a symlink (to $(readlink "$AG")) and was not changed."
  echo "  Make AGENTS.md a regular file holding the project facts, and CLAUDE.md the"
  echo "  import (CLAUDE.md.template); then run the update again."
elif [ -L "$CL" ]; then
  echo "ATTENTION: CLAUDE.md is a symlink (to $(readlink "$CL")) and was not changed."
  echo "  Editors refuse to write through it and Windows checks it out as a one-line"
  echo "  file. Replace it with the import (copy CLAUDE.md.template to CLAUDE.md) once"
  echo "  AGENTS.md holds the project facts."
elif [ -e "$CL" ] && [ ! -f "$CL" ]; then
  echo "ATTENTION: CLAUDE.md is not a regular file and was not changed."
elif [ -e "$AG" ] && [ ! -f "$AG" ]; then
  echo "ATTENTION: AGENTS.md is not a regular file and was not changed."
elif [ -f "$CL" ] && [ ! -r "$CL" ]; then
  echo "ATTENTION: CLAUDE.md cannot be read, so it was not migrated. Make it readable"
  echo "  and run the update again. Nothing was changed."
elif [ -f "$CL" ] && [ -f "$AG" ]; then
  if ! is_import "$CL"; then
    echo "ATTENTION: both AGENTS.md and CLAUDE.md exist and CLAUDE.md is not the import."
    echo "  Claude Code reads only CLAUDE.md when both exist, so it ignores AGENTS.md now."
    echo "  Merge what CLAUDE.md holds into AGENTS.md, then replace CLAUDE.md with the"
    echo "  import (CLAUDE.md.template; Claude-only instructions may follow the import)."
    echo "  Nothing was changed."
  fi
elif [ -f "$CL" ]; then
  self_import=0
  while IFS= read -r imp; do
    [ "$(resolve_import "$CL" "$imp")" = "$ROOT/AGENTS.md" ] && self_import=1
    [ "$(resolve_import "$CL" "$imp")" = "$ROOT/./AGENTS.md" ] && self_import=1
  done < <(imports_of "$CL")
  if is_import "$CL"; then
    echo "ATTENTION: CLAUDE.md imports AGENTS.md, which does not exist. Write AGENTS.md"
    echo "  (project-onboard) so the project's facts load again."
  elif [ "$self_import" = "1" ]; then
    echo "ATTENTION: CLAUDE.md already imports AGENTS.md (not on its first line), so moving"
    echo "  it to AGENTS.md would make AGENTS.md import itself. Nothing was changed: move"
    echo "  the facts into AGENTS.md by hand and make CLAUDE.md the import."
  elif git_ignored CLAUDE.md; then
    echo "ATTENTION: CLAUDE.md is ignored by git, so it is private to this checkout."
    echo "  Moving it would put that content into AGENTS.md, which is shared. Nothing was"
    echo "  changed. If it should be shared, stop ignoring it and run the update again; if"
    echo "  it is personal, rename it to CLAUDE.local.md."
  elif git_ignored AGENTS.md; then
    echo "ATTENTION: AGENTS.md is ignored by git here, so the moved facts would never reach"
    echo "  the repository and CLAUDE.md would import a file other checkouts lack. Nothing"
    echo "  was changed. Stop ignoring AGENTS.md and run the update again."
  elif [ "$template_ok" = "0" ]; then
    need_template "Moving CLAUDE.md to AGENTS.md"
  else
    git_state=""
    if [ "$IN_GIT" = "1" ]; then
      git_state="$(git -C "$ROOT" status --porcelain -- CLAUDE.md 2>/dev/null | cut -c1-2 || true)"
    fi
    hops="$(import_hops "$CL" 1 | sort -u -k1,1n -k2)"
    if ! backup="$(backup_claude_md "$CL")"; then
      echo "ATTENTION: CLAUDE.md could not be backed up to $SKILLS_DIR/.agents-md-backup/;"
      echo "  nothing was changed."
    elif ! copy_exact "$CL" "$AG"; then
      echo "ATTENTION: AGENTS.md could not be written from CLAUDE.md; CLAUDE.md is unchanged"
      echo "  and backed up at ${backup#$ROOT/}. Remove any partial AGENTS.md and run again."
    elif ! write_import "$CL"; then
      echo "ATTENTION: AGENTS.md now holds CLAUDE.md's content, but CLAUDE.md could not be"
      echo "  replaced with the import. Copy CLAUDE.md.template to CLAUDE.md by hand"
      echo "  (backup: ${backup#$ROOT/})."
    else
      echo "MIGRATED: CLAUDE.md moved to AGENTS.md (byte for byte); CLAUDE.md is now the import"
      echo "  (@AGENTS.md), so Claude Code and every other agent read the same file."
      echo "  Backup of the original CLAUDE.md: ${backup#$ROOT/}"
      echo "  git ignores the backup directory (its own .gitignore): do not commit it, and"
      echo "  delete it once you have checked AGENTS.md. Commit AGENTS.md and CLAUDE.md."
      echo "  Re-run scripts/install-claude-agents.sh / install-copilot-agents.sh if you use"
      echo "  them."
      case "$git_state" in
        "") ;;
        "??") echo "  CLAUDE.md was not committed yet; its content is in AGENTS.md and the backup." ;;
        *) echo "  CLAUDE.md had uncommitted changes (git status '$git_state'): the working-tree"
           echo "  version is what moved to AGENTS.md and the backup." ;;
      esac
      mentions="$(claude_md_mentions | sort)"
      if [ -n "$mentions" ]; then
        n="$(printf '%s\n' "$mentions" | wc -l | tr -d ' ')"
        echo "  $n file(s) still mention CLAUDE.md; check whether each should say AGENTS.md:"
        printf '%s\n' "$mentions" | head -n 10 | sed 's/^/    /'
        [ "$n" -gt 10 ] && echo "    ... and $((n - 10)) more"
      fi
      if [ -n "$hops" ]; then
        n="$(printf '%s\n' "$hops" | wc -l | tr -d ' ')"
        echo "  Its @-imports moved with it and resolve from AGENTS.md as they did from"
        echo "  CLAUDE.md (same directory), one hop deeper; agents other than Claude Code do"
        echo "  not expand @-imports:"
        printf '%s\n' "$hops" | head -n 20 | while read -r hop path; do
          print_hop "$hop" "$path"
        done
        [ "$n" -gt 20 ] && echo "    ... and $((n - 20)) more"
      fi
    fi
  fi
elif [ -f "$AG" ]; then
  if [ -n "${SKILLS_NO_CLAUDE_MD:-}" ] || [ -e "$SKILLS_DIR/.no-claude-md" ]; then
    echo "INFO: CLAUDE.md not created (opted out with SKILLS_NO_CLAUDE_MD or"
    echo "  .no-claude-md in the skills dir); Claude Code v2.1.277+ reads AGENTS.md itself."
  elif git_ignored AGENTS.md; then
    echo "ATTENTION: AGENTS.md is ignored by git, so a CLAUDE.md importing it would point at"
    echo "  a file other checkouts lack. Nothing was changed."
  elif [ "$template_ok" = "0" ]; then
    need_template "Creating CLAUDE.md"
  elif write_import "$CL"; then
    echo "MIGRATED: CLAUDE.md created as the import of AGENTS.md (@AGENTS.md), so Claude"
    echo "  Code sessions that do not read AGENTS.md themselves still load it. Commit it,"
    echo "  or delete it and add .no-claude-md to the skills dir to stop it coming back."
  else
    echo "ATTENTION: CLAUDE.md could not be created; copy CLAUDE.md.template to CLAUDE.md."
  fi
else
  echo "INFO: no AGENTS.md or CLAUDE.md at the project root; project-bootstrap or"
  echo "  project-onboard writes them."
fi
exit 0
