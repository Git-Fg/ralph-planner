#!/usr/bin/env bash
set -euo pipefail

# Unified Stop Hook - Ralph Planner Loop Primitive
# Checks completion promises and blocks until work is done
# SECURITY: All inputs validated, variables quoted, timeouts enforced

# Exit codes:
# 0 - Success (allow stop or continue loop)
# 2 - Blocking error (shown to user)

# Validate required environment
if [[ -z "${CLAUDEPROJECTDIR:-}" ]]; then
  echo "Error: CLAUDEPROJECTDIR not set" >&2
  exit 2
fi

# Set strict timeout for this script
readonly SCRIPT_TIMEOUT=60

# Build safe state file paths (validate no path traversal)
HYBRID_STATE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-hybrid.local.md"
PLANNING_STATE="${CLAUDEPROJECTDIR}/.claude.ralph-planner-loop.local.md"
ORCHESTRATOR_STATE="${CLAUDEPROJECTDIR}/.claude.ralph-orchestrator.local.md"

# Validate paths don't contain traversal
for path in "$HYBRID_STATE" "$PLANNING_STATE" "$ORCHESTRATOR_STATE"; do
  if [[ "$path" == *".."* ]]; then
    echo "Error: Path traversal detected" >&2
    exit 2
  fi
done

# Read and validate hook input JSON from stdin
HOOK_INPUT="$(cat || true)"
if [[ -z "$HOOK_INPUT" ]]; then
  exit 0
fi

# Determine which state file is active (priority: Hybrid → Orchestrator → Planning)
STATE_FILE=""
if [[ -f "$HYBRID_STATE" ]]; then
  STATE_FILE="$HYBRID_STATE"
elif [[ -f "$ORCHESTRATOR_STATE" ]]; then
  STATE_FILE="$ORCHESTRATOR_STATE"
elif [[ -f "$PLANNING_STATE" ]]; then
  STATE_FILE="$PLANNING_STATE"
else
  # No active loop, allow normal stop
  exit 0
fi

# Validate state file exists and is readable
if [[ ! -r "$STATE_FILE" ]]; then
  echo "Error: Cannot read state file" >&2
  exit 2
fi

# Extract YAML frontmatter from state file safely
FRONTMATTER="$(sed -n '1,/^---$/p' "$STATE_FILE" 2>/dev/null | sed '1d;$d' || true)"
if [[ -z "$FRONTMATTER" ]]; then
  echo "Error: Invalid state file format" >&2
  exit 2
fi

get_field() {
  local key="$1"
  echo "$FRONTMATTER" | awk -F': ' -v k="$key" '$1==k {print substr($0, length(k)+3)}' | head -n1
}

COMPLETION_PROMISE_RAW="$(get_field completion_promise)"
CONSTANT_PROMPT="$(awk 'BEGIN{s=0} /^---$/{s++; if(s==2){while(getline line){print line}}}' "$STATE_FILE" 2>/dev/null || echo "Ralph Planner loop active")"

# Decode completion promise safely
COMPLETION_PROMISE=""
if [[ "$COMPLETION_PROMISE_RAW" != "null" && -n "$COMPLETION_PROMISE_RAW" ]]; then
  COMPLETION_PROMISE="$(timeout 10 python3 - <<PY
import json, sys
try:
    print(json.loads(sys.argv[1]))
except:
    sys.exit(1)
PY
"$COMPLETION_PROMISE_RAW" 2>/dev/null || echo "")"
fi

# Try to find transcript path from hook input (sanitized)
TRANSCRIPT_PATH="$(echo "$HOOK_INPUT" | jq -er '.transcript_path // .transcriptpath // empty' 2>/dev/null || echo "")"
if [[ -n "$TRANSCRIPT_PATH" ]]; then
  # Sanitize transcript path
  if [[ "$TRANSCRIPT_PATH" == *".."* ]]; then
    echo "Error: Invalid transcript path" >&2
    exit 2
  fi
fi

# Check for completion promise in last assistant message
COMPLETION_DETECTED=false

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Extract last assistant message safely
  LAST_LINE="$(grep -E '"role"\s*:\s*"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -n1 || true)"
  if [[ -n "$LAST_LINE" ]]; then
    LAST_ASSISTANT_TEXT="$(echo "$LAST_LINE" | jq -er '
      if (.content|type)=="string" then .content
      elif (.content|type)=="array" then ([.content[]?.text?] | join("\n"))
      else "" end
    ' 2>/dev/null || echo "")"

    # Check for goal completion pattern (any goal completion)
    if echo "$LAST_ASSISTANT_TEXT" | grep -qE "promiseGOAL [A-Z0-9]+ DONEpromise"; then
      # Verify goals.xml was actually updated
      GOALS_XML="${CLAUDEPROJECTDIR}/.ralph/goals.xml"
      if [[ -f "$GOALS_XML" && -r "$GOALS_XML" ]]; then
        # Check if any goal is marked done
        if grep -q 'status="done"' "$GOALS_XML" 2>/dev/null; then
          # Check if ALL goals are done with timeout
          REMAINING=$(timeout 30 python3 - <<PY
import sys
import xml.etree.ElementTree as ET
try:
    tree = ET.parse(sys.argv[1])
    root = tree.getroot()
    for goal in root.findall('goal'):
        if goal.get('status') != 'done':
            sys.exit(1)  # Goals remain
    sys.exit(0)  # All done
except:
    sys.exit(2)  # Error
PY
            "$GOALS_XML" 2>/dev/null)
          if [[ $? -eq 0 ]]; then
            COMPLETION_DETECTED=true
          fi
        fi
      fi
    fi

    # Check for global completion promise (ALL GOALS COMPLETE)
    if [[ "$COMPLETION_DETECTED" == "false" && -n "$COMPLETION_PROMISE" ]]; then
      # Sanitize completion promise
      if [[ ! "$COMPLETION_PROMISE" =~ ^[A-Za-z0-9_ -]+$ ]]; then
        echo "Error: Invalid completion promise format" >&2
        exit 2
      fi
      GLOBAL_TAG="promise${COMPLETION_PROMISE}promise"
      if echo "$LAST_ASSISTANT_TEXT" | grep -Fq "$GLOBAL_TAG"; then
        COMPLETION_DETECTED=true
      fi
    fi
  fi
fi

# Display built-in status (if available)
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/scripts/display-status.sh" ]]; then
  bash -lc "${CLAUDE_PLUGIN_ROOT}/scripts/display-status.sh" 2>/dev/null || true
fi

# If completion detected, allow stop
if [[ "$COMPLETION_DETECTED" == "true" ]]; then
  echo "Ralph Planner work complete!"
  rm -f "$STATE_FILE" 2>/dev/null || true
  exit 0
fi

# Otherwise, block stopping and return constant prompt
CONSTANT_PROMPT_ESCAPED="$(echo "$CONSTANT_PROMPT" | jq -Rs .)"
jq -n --arg prompt "$CONSTANT_PROMPT" '
{
  decision: "block",
  reason: $prompt
}
'
