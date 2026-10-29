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
# directory, never from the current directory:
#   1. SKILLS_PROJECT_ROOT, if set (it must contain the skills directory);
#   2. otherwise the default layout, <root>/.opencode/skills, gives <root>; and the
#      top level of the git repository containing the skills directory (its own
#      .git, if the skills are a clone, is skipped) gives another candidate.
#      One candidate, or two that agree, is the root. Two that differ, none, the
#      home directory or / is not: the script changes nothing and reports why.
#
# What it does at the root:
#   only CLAUDE.md          -> AGENTS.md gets CLAUDE.md's bytes, CLAUDE.md becomes the
#                              import; the original is first copied to
#                              <skills>/.agents-md-backup/CLAUDE.md.backup (.backup.2,
#                              ... if that name holds different content) and compared;
#                              not named CLAUDE.md, which Claude Code would load from
#                              that directory as instructions
#   only AGENTS.md          -> CLAUDE.md is created as the import
#   CLAUDE.md is the import -> nothing (its first line that is not blank or an HTML
#                              comment is `@AGENTS.md`)
#   both, CLAUDE.md not the import, a symlink, .claude/CLAUDE.md, a missing import
#                           -> nothing changed; reported for the user to resolve
#   neither                 -> nothing (project-bootstrap / project-onboard write them)
# It never overwrites AGENTS.md, never follows or replaces a symlink, never deletes
# a file, and never touches CLAUDE.local.md or a CLAUDE.md below the root.
#
# Output: a "ROOT: <dir> (found from ...)" line once the root is known, then one
# item per block. A block starts with "MIGRATED: ", "ATTENTION: " or "INFO: " and
# continues on lines indented by two spaces. MIGRATED changed a project
# file and needs no action; ATTENTION needs the user; INFO is a note. The exit
# status is 0 unless the arguments are wrong.
#
# Compatible with bash 3 (macOS default).

set -euo pipefail

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
SKILLS_DIR="$(cd "$SKILLS_DIR" && pwd -P)"
[ -n "$TEMPLATE" ] || TEMPLATE="$SKILLS_DIR/CLAUDE.md.template"

# The first line that is neither blank nor a one-line HTML comment.
first_content_line() {
  awk '/^[[:space:]]*$/ { next }
       /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
       { sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}
is_import() { [ "$(first_content_line "$1")" = "@AGENTS.md" ]; }

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
  ROOT="$(cd "$SKILLS_PROJECT_ROOT" && pwd -P)"
  case "$SKILLS_DIR/" in
    "$ROOT"/*) ROOT_HOW="SKILLS_PROJECT_ROOT" ;;
    *) root_refused "SKILLS_PROJECT_ROOT ($ROOT) does not contain the skills directory." ;;
  esac
else
  by_layout=""
  case "$SKILLS_DIR" in
    */.opencode/skills) by_layout="$(cd "$SKILLS_DIR/../.." && pwd -P)" ;;
  esac
  by_git="$(git -C "$(dirname "$SKILLS_DIR")" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$by_git" ] && by_git="$(cd "$by_git" && pwd -P)"
  if [ -n "$by_layout" ] && [ -n "$by_git" ] && [ "$by_layout" != "$by_git" ]; then
    root_refused "the default layout gives $by_layout but the git repository is $by_git."
  elif [ -n "$by_layout" ]; then
    ROOT="$by_layout"; ROOT_HOW="the .opencode/skills layout${by_git:+, matching git}"
  elif [ -n "$by_git" ]; then
    ROOT="$by_git"; ROOT_HOW="the git repository holding the skills"
  else
    root_refused "the skills are not in <root>/.opencode/skills and not inside a git repository."
  fi
  home_real="$( (cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || true)"
  if [ "$ROOT" = "/" ] || { [ -n "$home_real" ] && [ "$ROOT" = "$home_real" ]; }; then
    root_refused "that would make $ROOT the project (a skills install outside a project)."
  fi
fi

CL="$ROOT/CLAUDE.md"
AG="$ROOT/AGENTS.md"
echo "ROOT: $ROOT (found from $ROOT_HOW)"

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
  echo "ATTENTION: .claude/CLAUDE.md exists and was not changed. Claude Code reads it as"
  echo "  project instructions; other agents do not. Move what it holds into AGENTS.md and"
  echo "  delete it (a CLAUDE.md at the root imports AGENTS.md)."
fi

# ── Template ─────────────────────────────────────────────────────────────────
template_ok=1
if [ ! -f "$TEMPLATE" ] || ! is_import "$TEMPLATE"; then
  template_ok=0
fi
need_template() {
  echo "ATTENTION: $1 skipped: the import template $TEMPLATE is missing or does not"
  echo "  start with @AGENTS.md. Nothing was changed."
}

# Copy $1 to a new file in <skills>/.agents-md-backup and print its path. An
# identical backup already there is reused; a different one is never replaced
# (the next free CLAUDE.md.backup.N is used).
backup_claude_md() {
  local dir="$SKILLS_DIR/.agents-md-backup" target n
  mkdir -p "$dir"
  target="$dir/CLAUDE.md.backup"
  if [ -e "$target" ]; then
    if cmp -s "$1" "$target"; then echo "$target"; return 0; fi
    n=2
    while [ -e "$target.$n" ]; do
      if cmp -s "$1" "$target.$n"; then echo "$target.$n"; return 0; fi
      n=$((n+1))
    done
    target="$target.$n"
  fi
  cp -p "$1" "$target"
  cmp -s "$1" "$target" || return 1
  echo "$target"
}

# Copy $1 to $2 (a new file) and confirm the copy is byte-equal.
copy_exact() { cp -p "$1" "$2" && cmp -s "$1" "$2"; }

# Write the template to $1 through a temporary file in the same directory.
write_import() {
  local tmp="$ROOT/.CLAUDE.md.agents-md.$$"
  cp "$TEMPLATE" "$tmp" && mv -f "$tmp" "$1" && cmp -s "$TEMPLATE" "$1"
}

# @-imports outside code spans and fenced blocks, one path per line.
list_imports() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      n = split(line, w, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (w[i] ~ /^@[^@[:space:]]/) {
        p = substr(w[i], 2); sub(/[.,;:!?)]+$/, "", p)   # sentence punctuation
        if (p != "") print p
      }
    }' "$1"
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
elif [ -f "$CL" ] && [ -f "$AG" ]; then
  if ! is_import "$CL"; then
    echo "ATTENTION: both AGENTS.md and CLAUDE.md exist and CLAUDE.md is not the import."
    echo "  Claude Code reads only CLAUDE.md when both exist, so it ignores AGENTS.md now."
    echo "  Merge what CLAUDE.md holds into AGENTS.md, then replace CLAUDE.md with the"
    echo "  import (CLAUDE.md.template; Claude-only instructions may follow the import)."
    echo "  Nothing was changed."
  fi
elif [ -f "$CL" ]; then
  if is_import "$CL"; then
    echo "ATTENTION: CLAUDE.md imports AGENTS.md, which does not exist. Write AGENTS.md"
    echo "  (project-onboard) so the project's facts load again."
  elif [ "$template_ok" = "0" ]; then
    need_template "Moving CLAUDE.md to AGENTS.md"
  else
    git_state=""
    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git_state="$(git -C "$ROOT" status --porcelain -- CLAUDE.md 2>/dev/null | cut -c1-2 || true)"
    fi
    imports="$(list_imports "$CL")"
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
      echo "  Commit AGENTS.md and CLAUDE.md; delete the backup once you have checked them."
      case "$git_state" in
        "") ;;
        "??") echo "  CLAUDE.md was not committed yet; its content is in AGENTS.md and the backup." ;;
        *) echo "  CLAUDE.md had uncommitted changes (git status '$git_state'); they are in"
           echo "  AGENTS.md and the backup, byte for byte." ;;
      esac
      if [ -n "$imports" ]; then
        echo "  Its @-imports moved with it and resolve from AGENTS.md as they did from"
        echo "  CLAUDE.md (same directory), one import hop deeper (Claude Code follows four);"
        echo "  agents other than Claude Code do not expand @-imports:"
        printf '%s\n' "$imports" | while IFS= read -r imp; do
          case "$imp" in
            "~/"*) p="${HOME:-}/${imp#\~/}" ;;
            /*) p="$imp" ;;
            *) p="$ROOT/$imp" ;;
          esac
          if [ -e "$p" ]; then echo "    @$imp"; else echo "    @$imp (not found, as before)"; fi
        done
      fi
    fi
  fi
elif [ -f "$AG" ]; then
  if [ "$template_ok" = "0" ]; then
    need_template "Creating CLAUDE.md"
  elif write_import "$CL"; then
    echo "MIGRATED: CLAUDE.md created as the import of AGENTS.md (@AGENTS.md), so Claude"
    echo "  Code sessions that do not read AGENTS.md themselves still load it. Commit it."
  else
    echo "ATTENTION: CLAUDE.md could not be created; copy CLAUDE.md.template to CLAUDE.md."
  fi
else
  echo "INFO: no AGENTS.md or CLAUDE.md at the project root; project-bootstrap or"
  echo "  project-onboard writes them."
fi
exit 0
