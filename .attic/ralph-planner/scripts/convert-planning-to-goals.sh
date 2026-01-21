#!/usr/bin/env bash
set -euo pipefail

# Auto-convert planning artifacts to goals.xml
# Reads .planning/ hierarchy and generates .ralph/goals.xml

PLANNING_DIR="${CLAUDEPROJECTDIR}/.planning"
RALPH_DIR="${CLAUDEPROJECTDIR}/.ralph"
GOALS_XML="${RALPH_DIR}/goals.xml"

usage() {
  cat <<'EOF'
Convert Planning to Goals
USAGE:
  convert-planning-to-goals.sh

Converts .planning/ artifacts to .ralph/goals.xml for orchestration phase.
EOF
}

# Ensure .ralph directory exists
mkdir -p "$RALPH_DIR"

# Check if planning artifacts exist
if [[ ! -d "$PLANNING_DIR" ]]; then
  echo "Error: Planning directory not found: $PLANNING_DIR" >&2
  exit 1
fi

# Read BRIEF for project info
BRIEF_FILE="${PLANNING_DIR}/BRIEF.md"
PROJECT_NAME="project"
if [[ -f "$BRIEF_FILE" ]]; then
  # Extract project name from BRIEF (first heading or title)
  PROJECT_NAME=$(grep -E '^#\s+' "$BRIEF_FILE" 2>/dev/null | head -n1 | sed 's/^#\s\+//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-\|-$//g' || echo "project")
fi

# Start building goals.xml
cat > "$GOALS_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<goals project="${PROJECT_NAME}" version="1">
EOF

# Add goals from ROADMAP phases
ROADMAP_FILE="${PLANNING_DIR}/ROADMAP.md"
if [[ -f "$ROADMAP_FILE" ]]; then
  echo "  Processing ROADMAP phases..." >&2

  # Extract phase sections from ROADMAP
  # Look for patterns like: "## Phase 1: Name" or "### 01-phase-name"
  PHASE_NUM=1
  while IFS= read -r line; do
    if [[ "$line" =~ ^##?\s+Phase[[:space:]0-9]*:[[:space:]]*(.*)$ ]] || [[ "$line" =~ ^##?\s+[0-9]+[-_](.*)$ ]]; then
      PHASE_NAME="${BASH_REMATCH[1]}"
      # Clean up phase name
      PHASE_NAME=$(echo "$PHASE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-\|-$//g')

      cat >> "$GOALS_XML" <<EOF

  <goal id="G${PHASE_NUM}" status="todo">
    <title>$(echo "${BASH_REMATCH[1]}" | sed 's/&/&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</title>
    <description>Execute Phase ${PHASE_NUM}: ${BASH_REMATCH[1]}</description>

    <acceptance>
      <item>Phase ${PHASE_NUM} plan executed successfully</item>
      <item>All verification commands pass</item>
      <item>SUMMARY.md created for the phase</item>
    </acceptance>

    <verify>
      <cmd>test -f ${PLANNING_DIR}/phases/*/${PHASE_NUM}-*.md</cmd>
    </verify>

    <notes></notes>
  </goal>
EOF
      ((PHASE_NUM++))
    fi
  done < "$ROADMAP_FILE"
fi

# Add goals from individual PLAN files
if [[ -d "${PLANNING_DIR}/phases" ]]; then
  echo "  Processing PLAN files..." >&2

  # Find all PLAN files
  PLAN_FILES=$(find "${PLANNING_DIR}/phases" -name "*-PLAN.md" -type f 2>/dev/null | sort)

  GOAL_ID=$((PHASE_NUM))
  for plan_file in $PLAN_FILES; do
    # Extract plan identifier (e.g., "01-01-setup" from path)
    PLAN_BASE=$(basename "$plan_file" .md | sed 's/-PLAN$//')
    PLAN_TITLE=$(echo "$PLAN_BASE" | sed 's/[0-9]\+-[0-9]\+-//' | tr '-' ' ' | sed 's/\b\w/\U&/g')

    # Read plan file to extract tasks
    TASK_COUNT=$(grep -c '^\s*-\s\+' "$plan_file" 2>/dev/null || echo "0")

    cat >> "$GOALS_XML" <<EOF

  <goal id="G${GOAL_ID}" status="todo">
    <title>${PLAN_TITLE}</title>
    <description>Execute ${plan_file} (${TASK_COUNT} tasks)</description>

    <acceptance>
      <item>All tasks in ${plan_file} completed</item>
      <item>Verification commands executed successfully</item>
      <item>Checkpoint tasks verified (if any)</item>
      <item>Summary created for the plan</item>
    </acceptance>

    <verify>
      <cmd>test -f "${plan_file}"</cmd>
      <cmd>test -f "${plan_file%PLAN.md}SUMMARY.md"</cmd>
    </verify>

    <notes></notes>
  </goal>
EOF
    ((GOAL_ID++))
  done
fi

# Close goals.xml
cat >> "$GOALS_XML" <<EOF

</goals>
EOF

# Report conversion
TOTAL_GOALS=$((GOAL_ID - 1))
echo "✓ Converted planning artifacts to goals.xml" >&2
echo "  • Goals file: ${GOALS_XML}" >&2
echo "  • Total goals: ${TOTAL_GOALS}" >&2
echo "  • Project: ${PROJECT_NAME}" >&2

if [[ -f "$GOALS_XML" ]]; then
  echo "" >&2
  echo "goals.xml created successfully!" >&2
  exit 0
else
  echo "Error: Failed to create goals.xml" >&2
  exit 1
fi
