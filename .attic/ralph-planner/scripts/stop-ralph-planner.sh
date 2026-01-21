#!/usr/bin/env bash
set -euo pipefail

# Stop Ralph Planner - Graceful halt with work preservation
# Removes state file and allows normal exit

HYBRID_STATE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-hybrid.local.md"
PLANNING_STATE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-loop.local.md"
ORCHESTRATOR_STATE="${CLAUDEPROJECTDIR}/.claude.ralph-orchestrator.local.md"

echo "Ralph Planner Stop - Graceful Halt"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check which state file exists (priority: Hybrid → Orchestrator → Planning)
if [[ -f "$HYBRID_STATE" ]]; then
  STATE_FILE="$HYBRID_STATE"
  echo "✓ Hybrid mode loop detected"
elif [[ -f "$ORCHESTRATOR_STATE" ]]; then
  STATE_FILE="$ORCHESTRATOR_STATE"
  echo "✓ Orchestrator mode loop detected"
elif [[ -f "$PLANNING_STATE" ]]; then
  STATE_FILE="$PLANNING_STATE"
  echo "✓ Planning mode loop detected"
else
  echo "⚠ No active Ralph Planner loop found."
  exit 0
fi

# Extract phase info if hybrid state
if [[ "$STATE_FILE" == "$HYBRID_STATE" ]]; then
  PHASE=$(sed -n '1,/^---$/p' "$STATE_FILE" | sed '1d;$d' | awk -F': ' '$1=="phase" {print substr($0, length($1)+3)}' | head -n1)
  echo "📍 Current phase: ${PHASE}"
fi

echo ""
echo "Preserving work artifacts:"
echo "  • .planning/ directory (if exists)"
echo "  • .ralph/goals.xml (if exists)"
echo "  • All planning artifacts"
echo ""

# Remove state file to allow stop
rm -f "$STATE_FILE"
echo "✓ State file removed"
echo ""
echo "Ralph Planner loop stopped successfully."
echo "Run /ralph-planner-start to resume work."
