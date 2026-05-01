#!/usr/bin/env bash
# update.sh — pull the latest skills and report changes
#
# This script is bundled with the update-skills skill and is executed via
# the run_skill_script tool. It must be run from the skill's own directory;
# the skills repo root is one level up.
#
# Compatible with bash 3 (macOS default).
#
# After pulling, any ## Project Context section that was already present in a
# SKILL.md is preserved — the upstream version of that section is never written
# back to disk.
#
# Exit codes:
#   0  success (updated or already up to date)
#   1  error (git failure, dirty tree, etc.)

set -euo pipefail

# ── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "ERROR: skills directory is not a git repository: $REPO_DIR" >&2
  exit 1
fi

# ── Remote / branch info ─────────────────────────────────────────────────────
REMOTE_URL="https://github.com/garethrhughes/skills.git"
BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(unknown)')"

echo "Repository : $REMOTE_URL"
echo "Branch     : $BRANCH"
echo ""

# ── Helper: extract the ## Project Context block from a SKILL.md ─────────────
# Prints everything from the "## Project Context" heading up to (but not
# including) the next "## " heading, or end of file.
extract_project_context() {
  local file="$1"
  awk '
    /^## Project Context/ { in_block=1 }
    in_block && /^## / && !/^## Project Context/ { in_block=0 }
    in_block { print }
  ' "$file"
}

# ── Helper: replace the ## Project Context block in a SKILL.md ───────────────
# Writes the file back with the saved context substituted in.
# $1 = skill file path, $2 = file containing the saved context block
replace_project_context() {
  local file="$1"
  local ctx_file="$2"
  local tmp
  tmp="$(mktemp)"

  awk '
    /^## Project Context/ {
      in_block=1
      # Print the saved context from the external file
      while ((getline line < ctx_file) > 0) print line
      close(ctx_file)
      next
    }
    in_block && /^## / && !/^## Project Context/ { in_block=0 }
    !in_block { print }
  ' ctx_file="$ctx_file" "$file" > "$tmp"

  mv "$tmp" "$file"
}

# ── Temp dirs for before/after snapshots ─────────────────────────────────────
BEFORE_DIR="$(mktemp -d)"
AFTER_DIR="$(mktemp -d)"
CONTEXT_DIR="$(mktemp -d)"
trap 'rm -rf "$BEFORE_DIR" "$AFTER_DIR" "$CONTEXT_DIR"' EXIT

# ── Snapshot SKILL.md contents before pull (and save any Project Context) ────
for f in "$REPO_DIR"/*/SKILL.md; do
  [[ -f "$f" ]] || continue
  skill="$(basename "$(dirname "$f")")"
  cp "$f" "$BEFORE_DIR/$skill.md"
  # Save the existing Project Context (may be empty / just the placeholder)
  extract_project_context "$f" > "$CONTEXT_DIR/$skill.ctx"
done

# ── git pull ─────────────────────────────────────────────────────────────────
PULL_OUTPUT="$(git -C "$REPO_DIR" pull --ff-only 2>&1)"
echo "$PULL_OUTPUT"
echo ""

# ── Restore Project Context sections ─────────────────────────────────────────
# For every skill that existed before the pull, put the user's context back.
for ctx_file in "$CONTEXT_DIR"/*.ctx; do
  [[ -f "$ctx_file" ]] || continue
  skill="$(basename "$ctx_file" .ctx)"
  skill_file="$REPO_DIR/$skill/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  saved_ctx="$(cat "$ctx_file")"
  [[ -z "$saved_ctx" ]] && continue   # no context to restore

  replace_project_context "$skill_file" "$ctx_file"
done

# ── Snapshot SKILL.md contents after pull + context restore ──────────────────
for f in "$REPO_DIR"/*/SKILL.md; do
  [[ -f "$f" ]] || continue
  skill="$(basename "$(dirname "$f")")"
  cp "$f" "$AFTER_DIR/$skill.md"
done

# ── Detect added, removed, modified skills ───────────────────────────────────
ADDED=()
REMOVED=()
MODIFIED=()

# Skills present after pull — check if new or changed
for after_file in "$AFTER_DIR"/*.md; do
  [[ -f "$after_file" ]] || continue
  skill="$(basename "$after_file" .md)"
  before_file="$BEFORE_DIR/$skill.md"
  if [[ ! -f "$before_file" ]]; then
    ADDED+=("$skill")
  elif ! diff -q "$before_file" "$after_file" > /dev/null 2>&1; then
    MODIFIED+=("$skill")
  fi
done

# Skills that disappeared
for before_file in "$BEFORE_DIR"/*.md; do
  [[ -f "$before_file" ]] || continue
  skill="$(basename "$before_file" .md)"
  if [[ ! -f "$AFTER_DIR/$skill.md" ]]; then
    REMOVED+=("$skill")
  fi
done

# ── Report ───────────────────────────────────────────────────────────────────
TOTAL=$(( ${#ADDED[@]} + ${#REMOVED[@]} + ${#MODIFIED[@]} ))

if [[ $TOTAL -eq 0 ]]; then
  echo "STATUS: up-to-date"
  echo "All skills are already up to date. No changes pulled."
  exit 0
fi

echo "STATUS: updated"
echo "CHANGES: $TOTAL skill(s) affected"
echo ""

if [[ ${#ADDED[@]} -gt 0 ]]; then
  echo "--- ADDED (${#ADDED[@]}) ---"
  for skill in "${ADDED[@]}"; do
    echo "  + $skill"
  done
  echo ""
fi

if [[ ${#REMOVED[@]} -gt 0 ]]; then
  echo "--- REMOVED (${#REMOVED[@]}) ---"
  for skill in "${REMOVED[@]}"; do
    echo "  - $skill"
  done
  echo ""
fi

if [[ ${#MODIFIED[@]} -gt 0 ]]; then
  echo "--- MODIFIED (${#MODIFIED[@]}) ---"
  for skill in "${MODIFIED[@]}"; do
    echo ""
    echo "  skill: $skill"
    echo "  diff (## Project Context excluded):"
    diff \
      --unified=3 \
      --label "before/$skill/SKILL.md" \
      --label "after/$skill/SKILL.md" \
      "$BEFORE_DIR/$skill.md" "$AFTER_DIR/$skill.md" \
      | sed 's/^/    /' || true
  done
  echo ""
fi
