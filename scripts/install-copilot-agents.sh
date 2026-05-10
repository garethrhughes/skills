#!/usr/bin/env bash
# install-copilot-agents.sh
#
# Symlinks all skills into .github/agents/ so they are available as GitHub
# Copilot custom agents. Run from your project root.
#
# Usage:
#   bash path/to/skills/scripts/install-copilot-agents.sh [skills-dir]
#
# Arguments:
#   skills-dir   Path to the skills repository (default: ~/.config/opencode/skills)
#
# The script:
#   1. Resolves the skills directory
#   2. Creates .github/agents/ if it does not exist
#   3. Symlinks each SKILL.md as <skill-name>.md inside .github/agents/
#   4. Prints a summary of what was linked / skipped

set -euo pipefail

# ── Resolve skills directory ────────────────────────────────────────────────
SKILLS_DIR="${1:-${HOME}/.config/opencode/skills}"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "Error: skills directory not found: $SKILLS_DIR" >&2
  echo "Usage: $0 [skills-dir]" >&2
  exit 1
fi

# ── Resolve project root (cwd) ──────────────────────────────────────────────
PROJECT_ROOT="$(pwd)"
AGENTS_DIR="${PROJECT_ROOT}/.github/agents"

mkdir -p "$AGENTS_DIR"

echo "Skills dir : $SKILLS_DIR"
echo "Agents dir : $AGENTS_DIR"
echo ""

# ── Copy RULES.md, rules/ and profiles/ alongside the agents ────────────────
# Skill files reference RULES.md, rules/<profile>.md, and profiles/<profile>/
# by relative path; the installed agents need local copies so those links
# resolve.
if [[ -f "$SKILLS_DIR/RULES.md" ]]; then
  cp "$SKILLS_DIR/RULES.md" "$AGENTS_DIR/RULES.md"
  rules_version="$(awk -F': *' '/^Version:/{print $2; exit}' "$SKILLS_DIR/RULES.md" | tr -d '[:space:]')"
  if [[ -n "$rules_version" ]]; then
    printf '%s\n' "$rules_version" > "$AGENTS_DIR/.rules-version"
    echo "RULES.md (v$rules_version) copied to .github/agents/RULES.md"
  else
    echo "RULES.md copied to .github/agents/RULES.md"
  fi
fi

if [[ -d "$SKILLS_DIR/rules" ]]; then
  rm -rf "$AGENTS_DIR/rules"
  cp -R "$SKILLS_DIR/rules" "$AGENTS_DIR/rules"
  overlay_count="$(find "$AGENTS_DIR/rules" -maxdepth 1 -name '*.md' | wc -l | tr -d '[:space:]')"
  echo "rules/ copied ($overlay_count stack overlay(s)) to .github/agents/rules/"
fi

if [[ -d "$SKILLS_DIR/profiles" ]]; then
  rm -rf "$AGENTS_DIR/profiles"
  cp -R "$SKILLS_DIR/profiles" "$AGENTS_DIR/profiles"
  profile_count="$(find "$AGENTS_DIR/profiles" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"
  echo "profiles/ copied ($profile_count profile(s)) to .github/agents/profiles/"
fi
echo ""

# ── Symlink each skill ───────────────────────────────────────────────────────
linked=0
skipped=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_file" ]] || continue

  skill_name="$(basename "$(dirname "$skill_file")")"
  target="${AGENTS_DIR}/${skill_name}.md"

  # Skip non-skill directories (scripts, etc.)
  case "$skill_name" in
    scripts|README*) continue ;;
  esac

  if [[ -L "$target" ]]; then
    echo "  skip (already linked) : $skill_name"
    skipped=$((skipped + 1))
  elif [[ -e "$target" ]]; then
    echo "  skip (file exists)    : $skill_name  — remove manually to replace"
    skipped=$((skipped + 1))
  else
    ln -s "$skill_file" "$target"
    echo "  linked : $skill_name"
    linked=$((linked + 1))
  fi
done

echo ""
echo "Done — $linked linked, $skipped skipped."
echo ""
echo "Note: The 'compatibility: opencode' frontmatter and 'permission:' blocks in"
echo "the skill files are ignored by Copilot. For infosec, the read-only constraint"
echo "is advisory only — add 'Do not edit any files or run commands.' to the agent"
echo "body if you need to reinforce it."
