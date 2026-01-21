#!/usr/bin/env bash
set -euo pipefail

STATE_FILE=".claude.ralph-planner-loop.local.md"

MAX_ITERATIONS="0"
COMPLETION_PROMISE="null"

usage() {
  cat <<'EOF'
Ralph Planner Loop - setup
USAGE:
  setup-ralph-planner-loop.sh [--max-iterations N] [--completion-promise "TEXT"] PROMPT...

NOTES:
- max-iterations 0 means unlimited
- completion promise will stop only when assistant outputs: promiseTEXTpromise
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

mkdir -p .claude
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

cat > "$STATE_FILE" <<EOF
---
active: true
iteration: 1
max_iterations: ${MAX_ITERATIONS}
completion_promise: ${COMPLETION_PROMISE_YAML}
started_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
---

${PROMPT_TEXT}
EOF

cat <<EOF
Ralph Planner Loop activated!
- State: ${STATE_FILE}
- Iteration: 1
- Max iterations: ${MAX_ITERATIONS} (0 = unlimited)
- Completion promise: ${COMPLETION_PROMISE}

When you try to exit, the Stop hook will re-run the same prompt.
EOF
