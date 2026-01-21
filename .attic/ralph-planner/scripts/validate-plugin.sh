#!/usr/bin/env bash
set -euo pipefail

# Ralph Planner Plugin Validator
# Validates plugin structure, naming, and compliance

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PLUGIN_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo -e "${BLUE}=== Ralph Planner Plugin Validator ===${NC}"
echo ""

# Helper functions
error() {
  echo -e "${RED}✗ ERROR:${NC} $1" >&2
  ERRORS=$((ERRORS + 1))
}

warning() {
  echo -e "${YELLOW}⚠ WARNING:${NC} $1" >&2
  WARNINGS=$((WARNINGS + 1))
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

# 1. Validate plugin.json
echo -e "${BLUE}[1/7] Validating plugin manifest...${NC}"

if [[ ! -f ".claude-plugin/plugin.json" ]]; then
  error "plugin.json not found"
else
  if ! jq empty .claude-plugin/plugin.json 2>/dev/null; then
    error "plugin.json is not valid JSON"
  else
    success "plugin.json is valid JSON"

    # Check required fields
    if ! jq -e '.name' .claude-plugin/plugin.json >/dev/null 2>&1; then
      error "plugin.json missing 'name' field"
    fi

    if ! jq -e '.version' .claude-plugin/plugin.json >/dev/null 2>&1; then
      error "plugin.json missing 'version' field"
    fi

    if ! jq -e '.description' .claude-plugin/plugin.json >/dev/null 2>&1; then
      error "plugin.json missing 'description' field"
    fi

    # Check name consistency
    PLUGIN_NAME=$(jq -r '.name' .claude-plugin/plugin.json)
    if [[ "$PLUGIN_NAME" != "ralph-planner" ]]; then
      error "Plugin name should be 'ralph-planner', found '$PLUGIN_NAME'"
    else
      success "Plugin name is correct: $PLUGIN_NAME"
    fi

    # Check for recommended fields
    if ! jq -e '.author' .claude-plugin/plugin.json >/dev/null 2>&1; then
      warning "plugin.json missing 'author' field (recommended)"
    fi
  fi
fi

echo ""

# 2. Validate commands
echo -e "${BLUE}[2/7] Validating commands...${NC}"

if [[ ! -d "commands" ]]; then
  error "commands directory not found"
else
  COMMAND_COUNT=$(find commands -name "*.md" | wc -l)
  info "Found $COMMAND_COUNT command(s)"

  if [[ $COMMAND_COUNT -eq 0 ]]; then
    error "No commands found"
  else
    success "Commands directory exists with $COMMAND_COUNT command(s)"

    # Check each command
    for cmd in commands/*.md; do
      if [[ -f "$cmd" ]]; then
        CMD_NAME=$(basename "$cmd" .md)

        # Check for YAML frontmatter
        if ! head -n 1 "$cmd" | grep -q "^---$"; then
          error "Command $CMD_NAME missing YAML frontmatter"
        else
          success "  ✓ $CMD_NAME has frontmatter"
        fi

        # Check required frontmatter fields
        if ! grep -q "^description:" "$cmd"; then
          error "  ✗ $CMD_NAME missing 'description' field"
        fi

        if ! grep -q "^allowed-tools:" "$cmd"; then
          error "  ✗ $CMD_NAME missing 'allowed-tools' field"
        fi
      fi
    done
  fi
fi

echo ""

# 3. Validate hooks
echo -e "${BLUE}[3/7] Validating hooks...${NC}"

if [[ ! -f "hooks/hooks.json" ]]; then
  error "hooks/hooks.json not found"
else
  if ! jq empty hooks/hooks.json 2>/dev/null; then
    error "hooks/hooks.json is not valid JSON"
  else
    success "hooks/hooks.json is valid JSON"

    # Check for hook scripts
    for hook in hooks/*.sh; do
      if [[ -f "$hook" ]]; then
        HOOK_NAME=$(basename "$hook")
        if [[ -x "$hook" ]]; then
          success "  ✓ $HOOK_NAME is executable"
        else
          warning "  ⚠ $HOOK_NAME is not executable"
        fi
      fi
    done
  fi
fi

echo ""

# 4. Validate skills
echo -e "${BLUE}[4/7] Validating skills...${NC}"

if [[ ! -d "skills" ]]; then
  error "skills directory not found"
else
  SKILL_COUNT=$(find skills -name "SKILL.md" | wc -l)
  info "Found $SKILL_COUNT skill(s)"

  if [[ $SKILL_COUNT -eq 0 ]]; then
    error "No skills found"
  else
    success "Skills directory exists with $SKILL_COUNT skill(s)"

    # Check skill structure
    for skill in skills/*/SKILL.md; do
      if [[ -f "$skill" ]]; then
        SKILL_NAME=$(basename "$(dirname "$skill")")
        success "  ✓ $SKILL_NAME/SKILL.md exists"

        # Check for templates
        TEMPLATE_DIR="$(dirname "$skill")/templates"
        if [[ -d "$TEMPLATE_DIR" ]]; then
          TEMPLATE_COUNT=$(find "$TEMPLATE_DIR" -name "*.template.md" | wc -l)
          info "    Found $TEMPLATE_COUNT template(s)"
        fi
      fi
    done
  fi
fi

echo ""

# 5. Validate scripts
echo -e "${BLUE}[5/7] Validating scripts...${NC}"

if [[ ! -d "scripts" ]]; then
  warning "scripts directory not found (optional)"
else
  SCRIPT_COUNT=$(find scripts -name "*.sh" | wc -l)
  info "Found $SCRIPT_COUNT script(s)"

  for script in scripts/*.sh; do
    if [[ -f "$script" ]]; then
      SCRIPT_NAME=$(basename "$script")
      if [[ -x "$script" ]]; then
        success "  ✓ $SCRIPT_NAME is executable"
      else
        warning "  ⚠ $SCRIPT_NAME is not executable"
      fi

      # Check for shebang
      if ! head -n 1 "$script" | grep -q "^#!/usr/bin/env bash"; then
        warning "  ⚠ $SCRIPT_NAME missing proper shebang"
      fi

      # Check for set -euo pipefail
      if ! grep -q "set -euo pipefail" "$script"; then
        warning "  ⚠ $SCRIPT_NAME missing 'set -euo pipefail'"
      fi
    fi
  done
fi

echo ""

# 6. Validate documentation
echo -e "${BLUE}[6/7] Validating documentation...${NC}"

if [[ ! -f "README.md" ]]; then
  error "README.md not found"
else
  success "README.md exists"

  # Check README size
  README_LINES=$(wc -l < README.md)
  if [[ $README_LINES -lt 50 ]]; then
    warning "README.md seems short ($README_LINES lines, recommended: 50+)"
  else
    success "README.md has good length ($README_LINES lines)"
  fi

  # Check for key sections
  if ! grep -q "## Installation" README.md; then
    warning "README.md missing 'Installation' section"
  fi

  if ! grep -q "## Commands" README.md; then
    warning "README.md missing 'Commands' section"
  fi
fi

echo ""

# 7. Validate gitignore
echo -e "${BLUE}[7/7] Validating .gitignore...${NC}"

if [[ ! -f ".gitignore" ]]; then
  error ".gitignore not found"
else
  success ".gitignore exists"

  # Check for important patterns
  if ! grep -q "\.claude" .gitignore; then
    warning ".gitignore should include '.claude' pattern"
  fi

  if ! grep -q "\.ralph" .gitignore; then
    warning ".gitignore should include '.ralph' pattern"
  fi

  if ! grep -q "\.planning" .gitignore; then
    warning ".gitignore should include '.planning' pattern"
  fi
fi

echo ""
echo "========================================"
echo -e "${BLUE}Validation Summary${NC}"
echo "========================================"

if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}✓ No errors found${NC}"
else
  echo -e "${RED}✗ $ERRORS error(s) found${NC}"
fi

if [[ $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}✓ No warnings${NC}"
else
  echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
fi

echo ""

if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}Validation FAILED${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}Validation PASSED with warnings${NC}"
  exit 0
else
  echo -e "${GREEN}Validation PASSED${NC}"
  exit 0
fi
