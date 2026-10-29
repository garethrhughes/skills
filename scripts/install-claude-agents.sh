#!/usr/bin/env bash
# install-claude-agents.sh
#
# Generates .claude/agents/<skill-name>.md for each skill so they are available
# as Claude Code custom subagents. Run from your project root; the skills live
# in the project (default .opencode/skills).
#
# Usage:
#   bash .opencode/skills/scripts/install-claude-agents.sh [skills-dir]
#
# Arguments:
#   skills-dir   Path to the project-local skills directory
#                (default: <project root>/.opencode/skills)
#
# The script:
#   1. Resolves the skills directory
#   2. Creates .claude/agents/ if it does not exist
#   3. For each SKILL.md, strips OpenCode-specific frontmatter (compatibility,
#      permission) and writes a Claude Code-compatible .md with the correct
#      'name', 'description', and 'tools' fields
#   4. Prints a summary of what was written
#
# Re-running overwrites previously generated files so they stay in sync with
# the upstream skill content.

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
AGENTS_DIR="${PROJECT_ROOT}/.claude/agents"

mkdir -p "$AGENTS_DIR"

echo "Skills dir : $SKILLS_DIR"
echo "Agents dir : $AGENTS_DIR"
echo ""

# ── Per-skill configuration ──────────────────────────────────────────────────
# Returns the tools restriction for a given skill name, or empty string for
# no restriction (all tools).
skill_tools() {
  case "$1" in
    # infosec is read-only; needs WebFetch (CVE/security advisory lookups) and
    # MCP filesystem access for reading docs/features/.
    infosec)           echo "Read, Grep, Glob, WebFetch" ;;
    # reviewer needs Bash for running tests/linters and verifying the build.
    reviewer)          echo "Read, Grep, Glob, Bash, WebFetch" ;;
    architect)         echo "Read, Grep, Glob, Write, Edit, WebFetch" ;;
    decision-log)      echo "Read, Grep, Glob, Write, Edit" ;;
    # mcp-setup writes opencode.json.
    mcp-setup)         echo "Read, Grep, Glob, Write, Edit" ;;
    # jira-feature reads/writes feature docs and uses the Jira MCP server.
    jira-feature)      echo "Read, Grep, Glob, Write, Edit, WebFetch" ;;
    create-skill)      echo "Read, Grep, Glob, Write, Edit" ;;
    update-skills)     echo "Read, Grep, Glob, Bash" ;;
    project-onboard)   echo "Read, Grep, Glob, Write, Edit, Bash, WebFetch" ;;
    # design writes design plans and UI code, runs a dev server, and drives a
    # browser via the Playwright MCP server — deliberately unrestricted, since an
    # explicit tools list would exclude MCP tools.
    design)            echo "" ;;
    # developer, create-feature, project-bootstrap: all tools (no restriction).
    *)                 echo "" ;;
  esac
}

# Returns a Claude Code-tuned description for a given skill name, or empty
# string to fall back to the description in the skill's own frontmatter.
skill_description() {
  case "$1" in
    architect)
      echo "Use when designing modules, defining API contracts, planning schema changes, evaluating infrastructure topology, or writing a proposal before a significant change."
      ;;
    developer)
      echo "Use when implementing features or bug fixes. Follows TDD (red-green-refactor), the active stack overlay's language conventions, IaC conventions, and project observability/supply-chain rules."
      ;;
    design)
      echo "Use for design-heavy frontend work: porting a Claude design handover (artifact HTML/React) into the project's stack, or making the visual decisions for a new or reshaped UI. Extracts a token system, writes a design plan to docs/design/, gets sign-off, implements it, then critiques it against an accessibility floor."
      ;;
    reviewer)
      echo "Use to review staged changes or a pull request. Checks security, IaC safety, correctness, observability, performance, and convention adherence. Returns a PASS / PASS WITH COMMENTS / BLOCK verdict with Acceptance Criteria traceability."
      ;;
    infosec)
      echo "Use for a security and compliance audit of staged changes or a PR — especially when the change touches auth, encryption, user data, IAM, logging, secrets, or external integrations. Read-only: produces a verdict, never edits files."
      ;;
    decision-log)
      echo "Use to record an architectural or technical decision as an ADR in docs/decisions/. Triggered after a technology is chosen, a pattern adopted, a trade-off made, or a proposal accepted."
      ;;
    create-feature)
      echo "Use to walk through the full feature development cycle: proposal → implementation → code review → infosec sign-off → decision logging → PR."
      ;;
    project-bootstrap)
      echo "Use once at the start of a new project to generate a complete CLAUDE.md (the only home of project facts). Covers app stack, IaC, observability, and security/compliance posture."
      ;;
    *)
      echo ""
      ;;
  esac
}

# ── Copy RULES.md, rules/, profiles/ and templates/ alongside the agents ──
# Skill files reference RULES.md, rules/<profile>.md, and profiles/<profile>/
# by relative path (../RULES.md, ../rules/, ../profiles/). The installed
# agents live at .claude/agents/<skill>.md, so those relative links resolve
# to the *parent* of agents/ — i.e. .claude/. Copy there.
RULES_PARENT_DIR="$(dirname "$AGENTS_DIR")"

# Clean up legacy copies from older installer versions that put these inside
# .claude/agents/ instead of .claude/.
rm -f "$AGENTS_DIR/RULES.md" "$AGENTS_DIR/.rules-version"
rm -rf "$AGENTS_DIR/rules" "$AGENTS_DIR/profiles"

if [[ -f "$SKILLS_DIR/RULES.md" ]]; then
  cp "$SKILLS_DIR/RULES.md" "$RULES_PARENT_DIR/RULES.md"
  # Sidecar: pin the RULES.md version so update-skills can detect drift.
  # RULES.md carries "**Version:** X.Y" (bold); accept a plain "Version:" too.
  rules_version="$(sed -n 's/^\(\*\*\)\{0,1\}Version:\(\*\*\)\{0,1\}[[:space:]]*//p' "$SKILLS_DIR/RULES.md" | head -n 1 | tr -d '[:space:]')"
  if [[ -n "$rules_version" ]]; then
    printf '%s\n' "$rules_version" > "$RULES_PARENT_DIR/.rules-version"
    echo "  RULES.md (v$rules_version) copied to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/RULES.md"
  else
    echo "  RULES.md copied to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/RULES.md"
  fi
fi

# Record the RULES.md this install used, so update-skills can tell a local
# edit from an upstream change later. Written only when no record exists yet AND
# the skills dir is its own git checkout (its top level, not a directory vendored
# into the project's repository) with RULES.md unmodified from what it checked
# out, i.e. the copy is the source's. Otherwise a local edit made before the
# record existed would be recorded as upstream; update-skills then prints a note
# on its first run instead.
skills_real="$(cd "$SKILLS_DIR" && pwd -P)"
skills_top="$(git -C "$SKILLS_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$skills_top" ]] && skills_top="$(cd "$skills_top" && pwd -P)"
if [[ -f "$SKILLS_DIR/RULES.md" && ! -f "$SKILLS_DIR/.rules-upstream.cksum" ]]; then
  if [[ "$skills_top" == "$skills_real" ]] \
     && git -C "$SKILLS_DIR" ls-files --error-unmatch RULES.md >/dev/null 2>&1 \
     && git -C "$SKILLS_DIR" diff --quiet HEAD -- RULES.md 2>/dev/null; then
    if cksum < "$SKILLS_DIR/RULES.md" > "$SKILLS_DIR/.rules-upstream.cksum" 2>/dev/null; then
      echo "  RULES.md record written to ${SKILLS_DIR}/.rules-upstream.cksum"
    else
      rm -f "$SKILLS_DIR/.rules-upstream.cksum"
    fi
  else
    echo "  RULES.md record not written: the skills dir is not its own unmodified git checkout"
  fi
fi

if [[ -d "$SKILLS_DIR/rules" ]]; then
  rm -rf "$RULES_PARENT_DIR/rules"
  cp -R "$SKILLS_DIR/rules" "$RULES_PARENT_DIR/rules"
  overlay_count="$(find "$RULES_PARENT_DIR/rules" -maxdepth 1 -name '*.md' | wc -l | tr -d '[:space:]')"
  echo "  rules/ copied ($overlay_count stack overlay(s)) to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/rules/"
fi

if [[ -d "$SKILLS_DIR/profiles" ]]; then
  rm -rf "$RULES_PARENT_DIR/profiles"
  cp -R "$SKILLS_DIR/profiles" "$RULES_PARENT_DIR/profiles"
  profile_count="$(find "$RULES_PARENT_DIR/profiles" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"
  echo "  profiles/ copied ($profile_count profile(s)) to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/profiles/"
fi

# templates/ holds the process-document starters (corrections log, risk register,
# privacy screening + PIA) that project-bootstrap / project-onboard install into
# docs/. Skills reference them as ../templates/, so copy them next to rules/.
# A templates/ directory this script did not write (no .from-skills marker) is
# left alone: it may be the project's own.
if [[ -d "$SKILLS_DIR/templates" && ! -f "$SKILLS_DIR/templates/.from-skills" ]]; then
  echo "  skip : $SKILLS_DIR/templates has no .from-skills marker, so it is not the skills' templates; not copied"
elif [[ -d "$SKILLS_DIR/templates" ]]; then
  if [[ -e "$RULES_PARENT_DIR/templates" && ! -f "$RULES_PARENT_DIR/templates/.from-skills" ]]; then
    echo "  skip : ${RULES_PARENT_DIR#$PROJECT_ROOT/}/templates/ exists and was not installed by this script; move it aside to install the skills' templates"
  else
    rm -rf "$RULES_PARENT_DIR/templates"
    cp -R "$SKILLS_DIR/templates" "$RULES_PARENT_DIR/templates"
    # templates/.from-skills ships in the skills repo (a fixed text, no local paths).
    template_count="$(find "$RULES_PARENT_DIR/templates" -type f ! -name .from-skills | wc -l | tr -d '[:space:]')"
    echo "  templates/ copied ($template_count file(s)) to ${RULES_PARENT_DIR#$PROJECT_ROOT/}/templates/"
  fi
fi
echo ""

# ── Process each skill ───────────────────────────────────────────────────────
written=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_file" ]] || continue

  skill_name="$(basename "$(dirname "$skill_file")")"
  target="${AGENTS_DIR}/${skill_name}.md"

  # Skip non-skill directories
  case "$skill_name" in
    scripts|templates|README*) continue ;;
  esac

  # ── Resolve description ────────────────────────────────────────────────────
  description="$(skill_description "$skill_name")"
  if [[ -z "$description" ]]; then
    # Fall back to the description field in the skill's own frontmatter
    description="$(awk '/^---/{p++} p==1 && /^description:/{sub(/^description: */,""); print; exit}' "$skill_file")"
    description="${description#\"}"
    description="${description%\"}"
  fi

  # ── Resolve tools line ─────────────────────────────────────────────────────
  tools="$(skill_tools "$skill_name")"
  tools_line=""
  [[ -n "$tools" ]] && tools_line="tools: $tools"

  # ── Extract body (everything after the closing --- of the frontmatter) ─────
  body="$(awk '/^---/{p++; if(p==2){found=1; next}} found{print}' "$skill_file")"

  # ── Write the agent file ───────────────────────────────────────────────────
  {
    echo "---"
    echo "name: ${skill_name}"
    echo "description: ${description}"
    [[ -n "$tools_line" ]] && echo "$tools_line"
    echo "---"
    echo ""
    printf '%s\n' "$body"
  } > "$target"

  echo "  wrote : $skill_name  →  .claude/agents/${skill_name}.md"
  written=$((written + 1))
done

echo ""
echo "Done — $written agent file(s) written to .claude/agents/."
echo ""
echo "Tips:"
echo "  • Re-run this script any time the upstream skills change."
echo "  • The infosec agent is restricted to read-only tools — it will never edit"
echo "    files or run commands."
echo "  • Add .claude/agents/ to version control so your team shares the same agents."
echo "  • Claude Code loads agents from .claude/agents/ automatically at session start."
