#!/usr/bin/env bash
set -euo pipefail

# Built-in status display with rich progress output
# Shows current phase, iteration, progress bars, and file status

STATE_FILE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-hybrid.local.md"
PLANNING_DIR="${CLAUDEPROJECTDIR}/.planning"
RALPH_DIR="${CLAUDEPROJECTDIR}/.ralph"
GOALS_XML="${RALPH_DIR}/goals.xml"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Extract YAML frontmatter
if [[ ! -f "$STATE_FILE" ]]; then
  echo "No active Ralph Planner session found." >&2
  exit 1
fi

FRONTMATTER="$(sed -n '1,/^---$/p' "$STATE_FILE" | sed '1d;$d' || true)"

get_field() {
  local key="$1"
  echo "$FRONTMATTER" | awk -F': ' -v k="$key" '$1==k {print substr($0, length(k)+3)}' | head -n1
}

PHASE=$(get_field 'phase')
ITERATION=$(get_field 'iteration')
STARTED_AT=$(get_field 'started_at')
MAX_ITERATIONS=$(get_field 'max_iterations')

# Calculate elapsed time
if [[ -n "$STARTED_AT" ]]; then
  START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED_AT" +%s 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  ELAPSED_SEC=$((NOW_EPOCH - START_EPOCH))

  # Format elapsed time
  HOURS=$((ELAPSED_SEC / 3600))
  MINUTES=$(( (ELAPSED_SEC % 3600) / 60 ))
  SECONDS=$((ELAPSED_SEC % 60))
  ELAPSED_STR=$(printf "%02d:%02d:%02d" $HOURS $MINUTES $SECONDS)
else
  ELAPSED_STR="--:--:--"
fi

# Header
echo -e "${CYAN}🔄 Ralph Planner - Iteration ${ITERATION}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Current activity
if [[ -f "$GOALS_XML" ]]; then
  TOTAL_GOALS=$(grep -c '<goal id=' "$GOALS_XML" 2>/dev/null || echo "0")
  DONE_GOALS=$(grep -c 'status="done"' "$GOALS_XML" 2>/dev/null || echo "0")

  if [[ "$TOTAL_GOALS" -gt 0 ]]; then
    CURRENT_GOAL=$(grep -A 2 '<goal' "$GOALS_XML" | grep -B 2 'status="todo"' | head -n1 | sed 's/.*<title>\(.*\)<\/title>.*/\1/' || echo "Unknown")
    echo -e "${YELLOW}🎯 Current Goal:${NC} ${CURRENT_GOAL}"
    echo -e "${GREEN}✓${NC} Progress: ${DONE_GOALS}/${TOTAL_GOALS} goals completed"
  else
    echo -e "${YELLOW}📋 Current Activity:${NC} Creating planning artifacts and goals"
  fi
else
  echo -e "${YELLOW}📋 Current Activity:${NC} Setting up Ralph Planner"
fi

echo ""

# File status
echo "📁 Files:"
if [[ -d "$PLANNING_DIR" ]]; then
  BRIEF_STATUS=$([ -f "${PLANNING_DIR}/BRIEF.md" ] && echo "✓" || echo "○")
  ROADMAP_STATUS=$([ -f "${PLANNING_DIR}/ROADMAP.md" ] && echo "✓" || echo "○")
  echo "   • BRIEF.md: ${BRIEF_STATUS} | ROADMAP.md: ${ROADMAP_STATUS}"

  PLAN_FILES=$(find "${PLANNING_DIR}/phases" -name "*-PLAN.md" 2>/dev/null | wc -l | tr -d ' ')
  SUM_FILES=$(find "${PLANNING_DIR}/phases" -name "*-SUMMARY.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "   • PLAN files: ${PLAN_FILES} | SUMMARY files: ${SUM_FILES}"
else
  echo "   • .planning/: ○ (not created)"
fi

if [[ -d "$RALPH_DIR" ]]; then
  GOALS_STATUS=$([ -f "$GOALS_XML" ] && echo "✓" || echo "○")
  echo "   • goals.xml: ${GOALS_STATUS}"
else
  echo "   • .ralph/: ○ (not created)"
fi

echo ""
echo "⏱️  Elapsed: ${ELAPSED_STR}"

# Progress bar
if [[ -f "$GOALS_XML" ]]; then
  TOTAL_GOALS=$(grep -c '<goal id=' "$GOALS_XML" 2>/dev/null || echo "0")
  DONE_GOALS=$(grep -c 'status="done"' "$GOALS_XML" 2>/dev/null || echo "0")

  if [[ "$TOTAL_GOALS" -gt 0 ]]; then
    PROGRESS=$((DONE_GOALS * 100 / TOTAL_GOALS))
    BAR_LEN=50
    FILLED_LEN=$((PROGRESS * BAR_LEN / 100))
    EMPTY_LEN=$((BAR_LEN - FILLED_LEN))

    BAR=$(printf '█%.0s' $(seq 1 $FILLED_LEN))
    EMPTY=$(printf '░%.0s' $(seq 1 $EMPTY_LEN))

    echo -e "[${BAR}${EMPTY}] ${PROGRESS}% Complete"
  fi
fi

echo ""
echo "Type \"stop\" to halt, or continue..."
