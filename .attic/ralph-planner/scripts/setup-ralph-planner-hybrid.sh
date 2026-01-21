#!/usr/bin/env bash
set -euo pipefail

# Use CLAUDEPROJECTDIR for all project-relative paths
STATE_FILE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-hybrid.local.md"
PLANNING_STATE_FILE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-loop.local.md"
ORCHESTRATOR_STATE_FILE="${CLAUDEPROJECTDIR}/.claude.ralph-orchestrator.local.md"
RALPH_DIR="${CLAUDEPROJECTDIR}/.ralph"
PLANNING_DIR="${CLAUDEPROJECTDIR}/.planning"
GOALS_XML="${RALPH_DIR}/goals.xml"

MAX_ITERATIONS="0"
COMPLETION_PROMISE="null"

CONSTANT_PROMPT="Ralph Planner - Unified Continuous Execution

You are Ralph Wiggum. You create planning artifacts AND execute them in a continuous loop.

WORKFLOW:

## CONTINUOUS EXECUTION
- Create and maintain .planning/ hierarchy (BRIEF/ROADMAP/PLANS)
- Update .ralph/goals.xml in real-time as you work
- Work on goals from goals.xml sequentially
- Mark goals as done when complete: <goal id=\"...\" status=\"done\"> + timestamp
- Output: promiseGOAL {ID} DONEpromise when each goal completes
- When ALL goals complete, output: promise${COMPLETION_PROMISE}promise

## REAL-TIME UPDATES
- As you create BRIEF.md → Add goal to goals.xml
- As you create ROADMAP.md → Add phase goals to goals.xml
- As you create PLAN.md → Add execution goal to goals.xml
- goals.xml is ALWAYS current and authoritative

## EXECUTION RULES
- Always work on the first incomplete goal in goals.xml
- Satisfy ALL acceptance criteria before marking done
- Run verification commands until they pass
- Update goals.xml immediately when marking complete
- Loop continues until ALL goals are done

CRITICAL:
- No phases - just continuous execution
- goals.xml is your single source of truth
- Built-in status shows progress each iteration
- Type \"stop\" or press Ctrl+C to halt gracefully (work preserved)"

usage() {
  cat <<'EOF'
Ralph Planner Unified Loop - setup
USAGE:
  setup-ralph-planner-hybrid.sh [--max-iterations N] [--completion-promise "TEXT"] PROMPT...

OPTIONS:
  --max-iterations N    Maximum iterations (0 = unlimited)
  --completion-promise "TEXT"  Global completion promise (default: "ALL GOALS COMPLETE")

NOTES:
- Unified continuous execution (planning + execution in one loop)
- Real-time goals.xml updates
- Completion promise will stop when assistant outputs: promiseTEXTpromise
- Built-in status display shows progress each iteration
- State file: .claude.ralph-planner-hybrid.local.md
EOF
}

PROMPT_PARTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --max-iterations)
      [[ -n "${2:-}" ]] || { echo "Error: --max-iterations requires a number" >&2; exit 1; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "Error: max-iterations must be integer >= 0" >&2; exit 1; }
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      [[ -n "${2:-}" ]] || { echo "Error: --completion-promise requires text" >&2; exit 1; }
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PROMPT_PARTS[@]} -eq 0 ]]; then
  echo "Error: No prompt provided." >&2
  usage >&2
  exit 1
fi

# Create necessary directories
mkdir -p "$RALPH_DIR"
mkdir -p "$PLANNING_DIR"
mkdir -p "${PLANNING_DIR}/phases"

PROMPT_TEXT="${PROMPT_PARTS[*]}"

# YAML-safe quoting for completion promise when set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML=$(python3 - <<PY
import json, sys
print(json.dumps(sys.argv[1]))
PY
"$COMPLETION_PROMISE")
else
  COMPLETION_PROMISE_YAML="null"
fi

# Check for existing state files and migrate
if [[ -f "$PLANNING_STATE_FILE" ]]; then
  echo "Detected existing planning state, migrating to unified mode..."
elif [[ -f "$ORCHESTRATOR_STATE_FILE" ]]; then
  echo "Detected existing orchestrator state, migrating to unified mode..."
else
  echo "Starting fresh unified mode session..."
fi

# Create unified state file
cat > "$STATE_FILE" <<EOF
---
active: true
iteration: 1
max_iterations: ${MAX_ITERATIONS}
started_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
completion_promise: ${COMPLETION_PROMISE_YAML}
goals_file: "${GOALS_XML}"
goals_completed: 0
total_goals: 0
---

${PROMPT_TEXT}
EOF

# Create initial goals.xml if it doesn't exist
if [[ ! -f "$GOALS_XML" ]]; then
  cat > "$GOALS_XML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<goals project="project" version="1">
</goals>
EOF
fi

cat <<EOF
Ralph Planner Unified Mode activated!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 State: ${STATE_FILE}
🔄 Iteration: 1
📊 Max Iterations: ${MAX_ITERATIONS} (0 = unlimited)
🎯 Completion Promise: ${COMPLETION_PROMISE}

📁 Files:
   • Planning: ${PLANNING_DIR}
   • Goals: ${GOALS_XML}

🔄 CONTINUOUS EXECUTION: Planning and execution in one unified loop

When you try to exit, the Stop hook will:
1. Check for completion promises
2. Display built-in status
3. Continue the loop or allow exit

Type "stop" to halt gracefully (work preserved).
EOF
