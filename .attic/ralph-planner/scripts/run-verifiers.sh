#!/usr/bin/env bash
set -euo pipefail

GOALS_XML=".ralph/goals.xml"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Ralph Verifiers ==="
echo "Checking goals.xml for verification commands..."
echo ""

# Check if goals.xml exists
if [[ ! -f "$GOALS_XML" ]]; then
  echo -e "${YELLOW}Warning: ${GOALS_XML} not found. No verifiers to run.${NC}"
  exit 0
fi

# Extract all verification commands from goals.xml
VERIFY_COMMANDS=$(python3 - <<'PYTHON_SCRIPT'
import sys
import xml.etree.ElementTree as ET

try:
    tree = ET.parse(sys.argv[1])
    root = tree.getroot()

    commands = []
    for goal in root.findall('goal'):
        verify_elem = goal.find('verify')
        if verify_elem is not None:
            for cmd in verify_elem.findall('cmd'):
                if cmd.text and cmd.text.strip():
                    goal_id = goal.get('id', 'unknown')
                    commands.append((goal_id, cmd.text.strip()))

    if not commands:
        print("NO_COMMANDS")
        sys.exit(0)

    for goal_id, cmd in commands:
        print(f"GOAL:{goal_id}|CMD:{cmd}")

except Exception as e:
    print(f"ERROR:{str(e)}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
"$GOALS_XML" 2>/dev/null || {
  echo -e "${RED}Error: Failed to parse goals.xml${NC}" >&2
  exit 1
}

if [[ "$VERIFY_COMMANDS" == "NO_COMMANDS" ]]; then
  echo -e "${YELLOW}No verification commands found in goals.xml${NC}"
  exit 0
fi

# Parse commands
declare -a CMD_ARRAY
while IFS= read -r line; do
  CMD_ARRAY+=("$line")
done <<< "$VERIFY_COMMANDS"

# Track results
TOTAL=0
PASSED=0
FAILED=0
declare -a FAILURES

echo "Found ${#CMD_ARRAY[@]} verification command(s)"
echo ""

# Run each verification command
for line in "${CMD_ARRAY[@]}"; do
  TOTAL=$((TOTAL + 1))

  # Parse goal ID and command
  GOAL_ID=$(echo "$line" | sed -n 's/^GOAL:\([^|]*\).*/\1/p')
  CMD=$(echo "$line" | sed -n 's/^GOAL:.*|CMD://p')

  echo -n "[$TOTAL/${#CMD_ARRAY[@]}] ${GOAL_ID}: "

  # Run the command
  if eval "$CMD" &>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}"
    FAILED=$((FAILED + 1))

    # Capture failure details
    FAILURE_OUTPUT=$(eval "$CMD" 2>&1 || true)
    FAILURES+=("${GOAL_ID}|${CMD}|${FAILURE_OUTPUT}")
  fi
done

echo ""
echo "=== Summary ==="
echo -e "Total: ${TOTAL}  ${GREEN}Passed: ${PASSED}${NC}  ${RED}Failed: ${FAILED}${NC}"
echo ""

# If there are failures, print detailed report
if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}=== FAILURE REPORT ===${NC}"
  echo ""

  for failure in "${FAILURES[@]}"; do
    GOAL_ID=$(echo "$failure" | cut -d'|' -f1)
    CMD=$(echo "$failure" | cut -d'|' -f2)
    OUTPUT=$(echo "$failure" | cut -d'|' -f3-)

    echo -e "${RED}Goal: ${GOAL_ID}${NC}"
    echo -e "Command: ${CMD}"
    echo "Output:"
    echo "$OUTPUT" | sed 's/^/  /'
    echo ""
  done

  echo -e "${RED}Verification failed: ${FAILED}/${TOTAL} checks failed${NC}"
  exit 1
else
  echo -e "${GREEN}All verifications passed!${NC}"
  exit 0
fi
