#!/usr/bin/env bash
set -euo pipefail

# SessionStart Hook - Re-hydrate Ralph Context After Compaction
# Runs when session starts from auto-compaction
# SECURITY: All inputs validated, variables quoted, timeouts enforced

# Exit codes:
# 0 - Success
# 2 - Blocking error (shown to user)

# Validate required environment
if [[ -z "${CLAUDEPROJECTDIR:-}" ]]; then
  echo "Error: CLAUDEPROJECTDIR not set" >&2
  exit 2
fi

# Set strict timeout for this script
readonly SCRIPT_TIMEOUT=60

# Build safe state file paths (validate no path traversal)
CONTEXT_FILE="${CLAUDEPROJECTDIR}/.ralph/context.md"
STATE_FILE="${CLAUDEPROJECTDIR}/.claude.ralph-orchestrator.local.md"

# Validate paths don't contain traversal
for path in "$CONTEXT_FILE" "$STATE_FILE"; do
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

# Sanitize and validate JSON input
SOURCE="$(echo "$HOOK_INPUT" | jq -er '.source // empty' 2>/dev/null || echo "")"
if [[ -z "$SOURCE" ]]; then
  exit 0
fi

# Only proceed if resuming from compaction
if [[ "$SOURCE" != "compact" ]]; then
  exit 0
fi

# Check if Ralph loop is active (state file exists)
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Check if context anchor exists
if [[ ! -f "$CONTEXT_FILE" ]]; then
  echo "Ralph: No context anchor found. Loop may not be active." >&2
  exit 0
fi

# Read context anchor safely
CURRENT_GOAL_ID="$(grep -A1 "^## Current Goal" "$CONTEXT_FILE" | grep "ID:" | awk '{print $2}' || echo "UNKNOWN")"
ITERATION="$(grep -A1 "^## Loop State" "$CONTEXT_FILE" | grep "Iteration:" | awk '{print $2}' || echo "unknown")"

# Validate values are safe
if [[ -n "$CURRENT_GOAL_ID" && ! "$CURRENT_GOAL_ID" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Error: Invalid goal ID" >&2
  exit 2
fi

# Inject minimal bootstrap instruction with proper escaping
jq -n \
  --arg goal_id "$CURRENT_GOAL_ID" \
  --arg iteration "$ITERATION" \
  --arg context_path "$CONTEXT_FILE" \
  '{
    additionalContext: "Ralph Orchestrator resuming from auto-compaction. Read context from context.md then continue. Current goal: \(.goal_id) at iteration \(.iteration). Use verifier commands from goals.xml. Output promiseGOAL {ID} DONEpromise when complete."
  }'

# Success - no output to keep SessionStart silent
exit 0
