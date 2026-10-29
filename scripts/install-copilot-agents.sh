#!/usr/bin/env bash
# install-copilot-agents.sh
#
# Symlinks all skills into .github/agents/ so they are available as GitHub
# Copilot custom agents. Run from your project root; the skills live in the
# project (default .opencode/skills).
#
# Usage:
#   bash .opencode/skills/scripts/install-copilot-agents.sh [skills-dir]
#
# Arguments:
#   skills-dir   Path to the project-local skills directory
#                (default: <project root>/.opencode/skills)
#
# The script:
#   1. Resolves the skills directory
#   2. Creates .github/agents/ if it does not exist
#   3. Symlinks each SKILL.md as <skill-name>.md inside .github/agents/
#   4. Prints a summary of what was linked / skipped

set -euo pipefail

# ── Resolve project root (cwd) ──────────────────────────────────────────────
PROJECT_ROOT="$(pwd)"

# ── Resolve skills directory ────────────────────────────────────────────────
SKILLS_DIR="${1:-${PROJECT_ROOT}/.opencode/skills}"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "Error: skills directory not found: $SKILLS_DIR" >&2
  echo "Usage: $0 [skills-dir]" >&2
  exit 1
fi

# ── Resolve agents directory ────────────────────────────────────────────────
AGENTS_DIR="${PROJECT_ROOT}/.github/agents"

mkdir -p "$AGENTS_DIR"

echo "Skills dir : $SKILLS_DIR"
echo "Agents dir : $AGENTS_DIR"
echo ""

# ── Copy RULES.md, rules/, profiles/ and templates/ alongside the agents ──
# Skill files reference RULES.md, rules/<profile>.md, and profiles/<profile>/
# by relative path (../RULES.md, ../rules/, ../profiles/). The installed
# agents live at .github/agents/<skill>.md, so those relative links resolve
# to the *parent* of agents/ — i.e. .github/. Copy there.
RULES_PARENT_DIR="$(dirname "$AGENTS_DIR")"

# Clean up legacy copies from older installer versions that put these inside
# .github/agents/ instead of .github/.
rm -f "$AGENTS_DIR/RULES.md" "$AGENTS_DIR/.rules-version"
rm -rf "$AGENTS_DIR/rules" "$AGENTS_DIR/profiles"

if [[ -f "$SKILLS_DIR/RULES.md" ]]; then
  cp "$SKILLS_DIR/RULES.md" "$RULES_PARENT_DIR/RULES.md"
  # RULES.md carries "**Version:** X.Y" (bold); accept a plain "Version:" too.
  rules_version="$(sed -n 's/^\(\*\*\)\{0,1\}Version:\(\*\*\)\{0,1\}[[:space:]]*//p' "$SKILLS_DIR/RULES.md" | head -n 1 | tr -d '[:space:]')"
  if [[ -n "$rules_version" ]]; then
    printf '%s\n' "$rules_version" > "$RULES_PARENT_DIR/.rules-version"
    echo "RULES.md (v$rules_version) copied to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/RULES.md"
  else
    echo "RULES.md copied to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/RULES.md"
  fi
fi

# Record the RULES.md this install used, so update-skills can tell a local
# edit from an upstream change later. Written only when no record exists yet AND
# the skills dir is a git checkout whose RULES.md is unmodified from what it
# checked out, i.e. the copy is the source's. Otherwise a local edit made before
# the record existed would be recorded as upstream; update-skills then prints a
# note on its first run instead.
if [[ -f "$SKILLS_DIR/RULES.md" && ! -f "$SKILLS_DIR/.rules-upstream.cksum" ]]; then
  if git -C "$SKILLS_DIR" ls-files --error-unmatch RULES.md >/dev/null 2>&1 \
     && git -C "$SKILLS_DIR" diff --quiet HEAD -- RULES.md 2>/dev/null; then
    if cksum < "$SKILLS_DIR/RULES.md" > "$SKILLS_DIR/.rules-upstream.cksum" 2>/dev/null; then
      echo "RULES.md record written to ${SKILLS_DIR}/.rules-upstream.cksum"
    else
      rm -f "$SKILLS_DIR/.rules-upstream.cksum"
    fi
  else
    echo "RULES.md record not written: the skills dir is not an unmodified git checkout"
  fi
fi

if [[ -d "$SKILLS_DIR/rules" ]]; then
  rm -rf "$RULES_PARENT_DIR/rules"
  cp -R "$SKILLS_DIR/rules" "$RULES_PARENT_DIR/rules"
  overlay_count="$(find "$RULES_PARENT_DIR/rules" -maxdepth 1 -name '*.md' | wc -l | tr -d '[:space:]')"
  echo "rules/ copied ($overlay_count stack overlay(s)) to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/rules/"
fi

if [[ -d "$SKILLS_DIR/profiles" ]]; then
  rm -rf "$RULES_PARENT_DIR/profiles"
  cp -R "$SKILLS_DIR/profiles" "$RULES_PARENT_DIR/profiles"
  profile_count="$(find "$RULES_PARENT_DIR/profiles" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"
  echo "profiles/ copied ($profile_count profile(s)) to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/profiles/"
fi

# templates/ holds the process-document starters (corrections log, risk register,
# privacy screening + PIA) that project-bootstrap / project-onboard install into
# docs/. Skills reference them as ../templates/, so copy them next to rules/.
# A templates/ directory this script did not write (no .from-skills marker) is
# left alone: it may be the project's own.
if [[ -d "$SKILLS_DIR/templates" ]]; then
  if [[ -e "$RULES_PARENT_DIR/templates" && ! -f "$RULES_PARENT_DIR/templates/.from-skills" ]]; then
    echo "skip : ${RULES_PARENT_DIR#$PROJECT_ROOT/}/templates/ exists and was not installed by this script; move it aside to install the skills' templates"
  else
    rm -rf "$RULES_PARENT_DIR/templates"
    cp -R "$SKILLS_DIR/templates" "$RULES_PARENT_DIR/templates"
    # templates/.from-skills ships in the skills repo (a fixed text, no local paths).
    template_count="$(find "$RULES_PARENT_DIR/templates" -type f ! -name .from-skills | wc -l | tr -d '[:space:]')"
    echo "templates/ copied ($template_count file(s)) to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/templates/"
  fi
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
    scripts|templates|README*) continue ;;
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
