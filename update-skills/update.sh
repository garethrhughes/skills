#!/usr/bin/env bash
# update.sh - fetch the latest skills from upstream and merge into installed location
#
# The skills directory does NOT need to be a git repository. Clones upstream
# to a temp dir, diffs each SKILL.md against the installed version, copies
# in changes while preserving existing ## Project Context sections.
#
# Compatible with bash 3 (macOS default).

set -euo pipefail

UPSTREAM="https://github.com/garethrhughes/skills.git"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Upstream   : $UPSTREAM"
echo "Skills dir : $SKILLS_DIR"
echo ""

# Write awk programs to temp files to avoid quoting issues
AWK_EXTRACT="$(mktemp)"
AWK_REPLACE="$(mktemp)"

cat > "$AWK_EXTRACT" << 'AWK'
/^## Project Context/ { b=1 }
b && /^## / && !/^## Project Context/ { b=0 }
b { print }
AWK

cat > "$AWK_REPLACE" << 'AWK'
/^## Project Context/ {
  b=1
  while ((getline ln < ctx_file) > 0) print ln
  close(ctx_file)
  next
}
b && /^## / && !/^## Project Context/ { b=0 }
!b { print }
AWK

extract_project_context() {
  awk -f "$AWK_EXTRACT" "$1"
}

replace_project_context() {
  local file="$1"
  local ctx_file="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v ctx_file="$ctx_file" -f "$AWK_REPLACE" "$file" > "$tmp"
  mv "$tmp" "$file"
}

# Root-level files that are copied verbatim (no Project Context merging)
ROOT_FILES="README.md CLAUDE.md.template"

CLONE_DIR="$(mktemp -d)"
BEFORE_DIR="$(mktemp -d)"
AFTER_DIR="$(mktemp -d)"
CONTEXT_DIR="$(mktemp -d)"
cleanup() { rm -rf "$CLONE_DIR" "$BEFORE_DIR" "$AFTER_DIR" "$CONTEXT_DIR" "$AWK_EXTRACT" "$AWK_REPLACE"; }
trap cleanup EXIT

echo "Fetching upstream skills..."
git clone --depth 1 --quiet "$UPSTREAM" "$CLONE_DIR"
echo "Done."
echo ""

for f in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  skill="$(basename "$(dirname "$f")")"
  cp "$f" "$BEFORE_DIR/$skill.md"
  extract_project_context "$f" > "$CONTEXT_DIR/$skill.ctx"
done

# Snapshot root files before update
for rf in $ROOT_FILES; do
  [ -f "$SKILLS_DIR/$rf" ] && cp "$SKILLS_DIR/$rf" "$BEFORE_DIR/__root__$rf"
done

for upstream_skill_dir in "$CLONE_DIR"/*/; do
  [ -d "$upstream_skill_dir" ] || continue
  skill="$(basename "$upstream_skill_dir")"
  upstream_file="$upstream_skill_dir/SKILL.md"
  [ -f "$upstream_file" ] || continue

  installed_dir="$SKILLS_DIR/$skill"
  installed_file="$installed_dir/SKILL.md"

  if [ ! -d "$installed_dir" ]; then
    cp -r "$upstream_skill_dir" "$installed_dir"
  else
    cp "$upstream_file" "$installed_file"
    for upstream_extra in "$upstream_skill_dir"*; do
      [ -f "$upstream_extra" ] || continue
      fname="$(basename "$upstream_extra")"
      [ "$fname" = "SKILL.md" ] && continue
      cp "$upstream_extra" "$installed_dir/$fname"
    done
  fi

  ctx_file="$CONTEXT_DIR/$skill.ctx"
  if [ -f "$ctx_file" ] && [ -s "$ctx_file" ]; then
    replace_project_context "$installed_file" "$ctx_file"
  fi
done

# Copy root-level files from upstream
for rf in $ROOT_FILES; do
  [ -f "$CLONE_DIR/$rf" ] && cp "$CLONE_DIR/$rf" "$SKILLS_DIR/$rf"
done

for f in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  skill="$(basename "$(dirname "$f")")"
  cp "$f" "$AFTER_DIR/$skill.md"
done

# Snapshot root files after update
for rf in $ROOT_FILES; do
  [ -f "$SKILLS_DIR/$rf" ] && cp "$SKILLS_DIR/$rf" "$AFTER_DIR/__root__$rf"
done

ADDED=""
REMOVED=""
MODIFIED=""

for after_file in "$AFTER_DIR"/*.md; do
  [ -f "$after_file" ] || continue
  skill="$(basename "$after_file" .md)"
  before_file="$BEFORE_DIR/$skill.md"
  if [ ! -f "$before_file" ]; then
    ADDED="$ADDED $skill"
  elif ! diff -q "$before_file" "$after_file" > /dev/null 2>&1; then
    MODIFIED="$MODIFIED $skill"
  fi
done

for before_file in "$BEFORE_DIR"/*.md; do
  [ -f "$before_file" ] || continue
  skill="$(basename "$before_file" .md)"
  if [ ! -f "$AFTER_DIR/$skill.md" ]; then
    REMOVED="$REMOVED $skill"
  fi
done

added_count=0; removed_count=0; modified_count=0
for s in $ADDED;    do added_count=$((added_count+1));      done
for s in $REMOVED;  do removed_count=$((removed_count+1));  done
for s in $MODIFIED; do modified_count=$((modified_count+1));done

# Count modified root files
ROOT_MODIFIED=""
for rf in $ROOT_FILES; do
  before="$BEFORE_DIR/__root__$rf"
  after="$AFTER_DIR/__root__$rf"
  [ -f "$after" ] || continue
  if [ ! -f "$before" ]; then
    ROOT_MODIFIED="$ROOT_MODIFIED $rf"
  elif ! diff -q "$before" "$after" > /dev/null 2>&1; then
    ROOT_MODIFIED="$ROOT_MODIFIED $rf"
  fi
done
root_modified_count=0
for rf in $ROOT_MODIFIED; do root_modified_count=$((root_modified_count+1)); done

TOTAL=$(( added_count + removed_count + modified_count + root_modified_count ))

if [ $TOTAL -eq 0 ]; then
  echo "STATUS: up-to-date"
  echo "All skills are already up to date. No changes applied."
  exit 0
fi

echo "STATUS: updated"
echo "CHANGES: $TOTAL skill(s) affected"
echo ""

if [ $added_count -gt 0 ]; then
  echo "--- ADDED ($added_count) ---"
  for skill in $ADDED; do echo "  + $skill"; done
  echo ""
fi

if [ $removed_count -gt 0 ]; then
  echo "--- REMOVED ($removed_count) ---"
  for skill in $REMOVED; do echo "  - $skill"; done
  echo ""
fi

if [ $modified_count -gt 0 ]; then
  echo "--- MODIFIED ($modified_count) ---"
  for skill in $MODIFIED; do
    echo ""
    echo "  skill: $skill"
    echo "  diff (## Project Context excluded):"
    diff --unified=3 \
      --label "before/$skill/SKILL.md" \
      --label "after/$skill/SKILL.md" \
      "$BEFORE_DIR/$skill.md" "$AFTER_DIR/$skill.md" \
      | sed 's/^/    /' || true
  done
  echo ""
fi

if [ $root_modified_count -gt 0 ]; then
  echo "--- ROOT FILES UPDATED ($root_modified_count) ---"
  for rf in $ROOT_MODIFIED; do
    echo ""
    echo "  file: $rf"
    diff --unified=3 \
      --label "before/$rf" \
      --label "after/$rf" \
      "$BEFORE_DIR/__root__$rf" "$AFTER_DIR/__root__$rf" \
      | sed 's/^/    /' || true
  done
  echo ""
fi
