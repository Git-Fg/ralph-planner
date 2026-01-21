#!/usr/bin/env bash
set -euo pipefail

# Use CLAUDEPROJECTDIR for all project-relative paths
STATE_FILE="${CLAUDEPROJECTDIR}/.claude.ralph-orchestrator.local.md"
RALPH_DIR="${CLAUDEPROJECTDIR}/.ralph"
GOALS_XML="${RALPH_DIR}/goals.xml"

MAX_ITERATIONS="0"
COMPLETION_PROMISE="null"
GOALS_FILE="null"

CONSTANT_PROMPT="Ralph Orchestrator - Goal-Based Iteration System

You are working within the Ralph Orchestrator loop. This system uses .ralph/goals.xml as the single source of truth for all objectives.

YOUR WORKFLOW (YOU do all of this):
1. Read .ralph/goals.xml to find the first goal with status != 'done'
2. Review that goal's details: title, description, acceptance criteria, verification commands
3. Work to satisfy ALL acceptance criteria
4. Run the verification commands in <verify> section - fix failures and re-run until they pass
5. Update .ralph/goals.xml to mark the goal as done: <goal id="..." status="done">
6. Add a completion timestamp to the <notes> element
7. Repeat for the next goal until all are marked 'done'

COMPLETION SIGNALLING:
When a goal is complete, output exactly: promiseGOAL {ID} DONEpromise
- Replace {ID} with the goal's actual ID from goals.xml
- This signals the loop that you're done with that goal

GLOBAL COMPLETION:
When ALL goals in goals.xml are marked 'done', output: promise{TEXT}promise
- Replace {TEXT} with the configured completion promise
- This terminates the entire orchestrator loop

IMPORTANT:
- The Stop hook is MINIMAL - it only checks for completion promises
- ALL actual work (reading XML, editing files, running verifiers) is YOUR job
- goals.xml is the authoritative source - read it every iteration
- Never include iteration numbers in your responses
- The prompt never changes - only goals.xml evolves as you work"

usage() {
  cat <<'EOF'
Ralph Orchestrator Loop - setup
USAGE:
  setup-ralph-orchestrator.sh [--max-iterations N] [--completion-promise "TEXT"] [--goals FILE]

OPTIONS:
  --max-iterations N    Maximum iterations (0 = unlimited)
  --completion-promise "TEXT"  Global completion promise
  --goals FILE          Path to goals.xml file (default: .ralph/goals.xml)

NOTES:
- If --goals is not provided, a template goals.xml will be created
- Completion promise will stop only when assistant outputs: promiseTEXTpromise
- MINIMAL STOP HOOK architecture - the Stop hook is just a loop primitive
- All work (parsing goals, editing files, running verifiers) is done by Claude
- The prompt never changes between iterations - only goals.xml evolves
EOF
}

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
    --goals)
      [[ -n "${2:-}" ]] || { echo "Error: --goals requires a file path" >&2; exit 1; }
      GOALS_FILE="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Create .ralph directory if it doesn't exist
mkdir -p "$RALPH_DIR"

# If no goals file specified, create a template
if [[ "$GOALS_FILE" == "null" ]]; then
  if [[ ! -f "$GOALS_XML" ]]; then
    echo "Creating template goals.xml..."
    cat > "$GOALS_XML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<goals project="project" version="1">
  <goal id="G1" status="todo">
    <title>Create planning hierarchy</title>
    <description>Create .planning/BRIEF.md and .planning/ROADMAP.md and phase directories.</description>

    <acceptance>
      <item>.planning/BRIEF.md exists and includes success criteria + out of scope.</item>
      <item>.planning/ROADMAP.md exists with 3-6 phases and dependencies.</item>
      <item>.planning/phases/ contains numbered phase directories (01-*, 02-*, ...).</item>
    </acceptance>

    <verify>
      <cmd>test -f .planning/BRIEF.md</cmd>
      <cmd>test -f .planning/ROADMAP.md</cmd>
      <cmd>test -d .planning/phases</cmd>
    </verify>

    <notes></notes>
  </goal>

  <goal id="G2" status="todo">
    <title>Write executable PLAN.md for Phase 01</title>
    <description>Create the next .planning/phases/01-*/01-01-PLAN.md with tasks + verification + checkpoints.</description>

    <acceptance>
      <item>A Phase 01 directory exists under .planning/phases.</item>
      <item>A 01-01-PLAN.md exists in that directory.</item>
      <item>PLAN tasks include explicit files/action/verify/done_when.</item>
    </acceptance>

    <verify>
      <cmd>ls .planning/phases/01-*/01-01-PLAN.md 2>/dev/null</cmd>
      <cmd>grep -n "verify:" .planning/phases/01-*/01-01-PLAN.md 2>/dev/null</cmd>
      <cmd>grep -n "done_when:" .planning/phases/01-*/01-01-PLAN.md 2>/dev/null</cmd>
    </verify>

    <notes></notes>
  </goal>

  <goal id="G3" status="todo">
    <title>Execute Phase 01 Plan 01-01</title>
    <description>Run the plan with checkpoint-aware strategy and produce SUMMARY.md.</description>

    <acceptance>
      <item>A matching 01-01-SUMMARY.md exists for the plan.</item>
      <item>Verification commands in the plan have been executed successfully.</item>
    </acceptance>

    <verify>
      <cmd>ls .planning/phases/*/01-01-SUMMARY.md 2>/dev/null</cmd>
    </verify>

    <notes></notes>
  </goal>
</goals>
EOF
  fi
  GOALS_FILE="$GOALS_XML"
else
  # Validate provided goals file exists
  if [[ ! -f "$GOALS_FILE" ]]; then
    echo "Error: Goals file not found: $GOALS_FILE" >&2
    exit 1
  fi
  # If it's a relative path and not in .ralph/, copy it there
  if [[ "$GOALS_FILE" != /* ]] && [[ "$GOALS_FILE" != "${RALPH_DIR}/"* ]]; then
    cp "$GOALS_FILE" "$GOALS_XML"
    GOALS_FILE="$GOALS_XML"
  fi
fi

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

# Create orchestrator state file with constant prompt as body
cat > "$STATE_FILE" <<EOF
---
active: true
iteration: 1
max_iterations: ${MAX_ITERATIONS}
completion_promise: ${COMPLETION_PROMISE_YAML}
goals_file: "${GOALS_FILE}"
started_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
---

${CONSTANT_PROMPT}
EOF

# Create initial context anchor for auto-compact handling
# This is read by PreCompact and SessionStart hooks
cat > "${RALPH_DIR}/context.md" <<EOF
# Ralph Orchestrator Context (Auto-Compact Anchor)

## Loop State
- Active: true
- Iteration: 1
- Max Iterations: ${MAX_ITERATIONS}

## Files
- State File: ${STATE_FILE}
- Goals XML: ${GOALS_XML}
- Constant Prompt: in state file body

## Current Goal
- ID: UNKNOWN

## Completion
- Promise: ${COMPLETION_PROMISE}
- Pattern: promiseGOAL {ID} DONEpromise

## Verifier
- Command: (read from goals.xml)

---
Auto-generated by setup script. Updated by PreCompact and PostToolUse hooks.
EOF

cat <<EOF
Ralph Orchestrator Loop activated!
- State file: ${STATE_FILE}
- Iteration: 1
- Max iterations: ${MAX_ITERATIONS} (0 = unlimited)
- Completion promise: ${COMPLETION_PROMISE}
- Goals file: ${GOALS_FILE}
- Architecture: MINIMAL STOP HOOK (Claude does all the work)

The Stop hook is minimal - it only:
- Checks if completion promise was output
- Returns the constant prompt or allows stop

YOU (Claude) do ALL the work:
- Read .ralph/goals.xml to find current goal
- Edit files to satisfy acceptance criteria
- Run verification commands
- Update .ralph/goals.xml to mark goal as done (status="done" + timestamp)
- Output completion promise to signal completion

When you try to exit, the Stop hook will block and return the constant prompt.
EOF
