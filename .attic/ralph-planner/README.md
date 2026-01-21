# Ralph Planner Plugin

A sophisticated planning and orchestration system for Claude Code that enables iterative, goal-driven development with automatic state management and verification.

## Overview

Ralph Planner implements a **Ralph Wiggum-style iterative loop** that orchestrates multiple sequential goals stored in `.ralph/goals.xml` with dynamic prompt injection and verification gates. It combines **executive planning** (BRIEF/ROADMAP/PLAN) with **goal-based execution** for complete project lifecycle management.

## Features

### 🎯 Goal-Based Orchestration
- Sequential goal management via XML configuration
- Automatic verification of acceptance criteria
- Iterative execution with loop control
- Auto-compaction support for long-running sessions

### 📋 Planning Hierarchy
- **BRIEF**: Human vision (what/why/success/out-of-scope)
- **ROADMAP**: 3-6 phases with clear dependencies
- **PLAN**: Executable prompts with tasks and verification
- **SUMMARY**: Post-execution documentation

### 🔄 Loop Systems
- **Ralph Planner Loop**: Planning artifact creation and iteration
- **Ralph Orchestrator Loop**: Goal-based execution with verification
- Automatic state persistence across sessions
- Minimal stop hooks for clean exit control

### ✅ Verification Engine
- XML-defined verification commands
- Automatic test execution
- Color-coded pass/fail reporting
- Goal completion tracking

## Installation

### Local Installation

1. Copy the plugin to your Claude Code plugins directory:
```bash
cp -r ralph-planner ~/.claude-plugins/
```

2. Or use the plugin directory directly:
```bash
cc --plugin-dir /path/to/ralph-planner
```

### Development Installation

For development, link the plugin:
```bash
ln -s /path/to/ralph-planner ~/.claude-plugins/ralph-planner
```

## Quick Start

### 1. Initialize Goals (Orchestrator Mode)

Start with goal-based orchestration:
```bash
/ralph-goals-init "My Project"
```

This creates `.ralph/goals.xml` with a template goal queue.

### 2. Start Orchestration Loop

Begin the iterative goal execution:
```bash
/ralph-orchestrate --max-iterations 10 --completion-promise "PROJECT COMPLETE"
```

Claude will now work through your goals sequentially, with the Stop hook blocking exit until all goals are complete.

### 3. Track Progress

Check your current status:
```bash
/ralph-orchestrate-status
```

Cancel if needed:
```bash
/ralph-orchestrate-cancel
```

### Alternative: Planning Mode

For planning artifact creation:
```bash
/ralph-plan "Build a todo app with React" --max-iterations 5
```

## Commands Reference

### Planning Commands

#### `/ralph-plan`
Start a Ralph Wiggum-style iterative loop to create/maintain BRIEF/ROADMAP/PLAN planning artifacts.

**Usage:**
```bash
/ralph-plan "Project goal and constraints" --max-iterations N --completion-promise "PLANNING COMPLETE"
```

#### `/ralph-run-plan`
Execute a single PLAN.md using checkpoint-aware routing (autonomous vs segmented vs decision-dependent).

**Usage:**
```bash
/ralph-run-plan path/to/XX-YY-PLAN.md
```

#### `/ralph-plan-status`
Show current Ralph Planner loop status.

**Usage:**
```bash
/ralph-plan-status
```

#### `/ralph-plan-cancel`
Cancel the active Ralph Planner loop (removes state file).

**Usage:**
```bash
/ralph-plan-cancel
```

### Orchestration Commands

#### `/ralph-orchestrate`
Start the Ralph Orchestrator loop (dynamic prompt from .ralph/goals.xml, sequential goals, verify gate).

**Usage:**
```bash
/ralph-orchestrate --max-iterations N --completion-promise "ALL GOALS COMPLETE"
```

#### `/ralph-orchestrate-status`
Show current orchestrator loop status and goal progress.

**Usage:**
```bash
/ralph-orchestrate-status
```

#### `/ralph-orchestrate-cancel`
Cancel the active Ralph Orchestrator loop (removes state file, preserves goals.xml).

**Usage:**
```bash
/ralph-orchestrate-cancel
```

#### `/ralph-goals-init`
Initialize .ralph/goals.xml with a sequential goal queue (edit it to match your project).

**Usage:**
```bash
/ralph-goals-init optional-project-name
```

## Hook System

Ralph Planner includes four hooks for seamless integration:

### PreCompact Hook
Runs before auto-compaction to persist minimal loop state. Creates `.ralph/context.md` anchor file with:
- Current iteration and goal ID
- Verification commands
- State file locations

### SessionStart Hook
Runs when session starts from auto-compaction. Reads context anchor and bootstraps Ralph with:
- Current goal information
- Iteration count
- Continuation instructions

### PostToolUse Hook
Runs after Write/Edit operations to keep context anchor fresh. Updates iteration metadata and current goal state.

### Stop Hook
Minimal loop primitive that:
- Checks for completion promises in transcript
- Verifies goal completion against goals.xml
- Blocks exit until all goals are done
- Allows clean exit on completion

## File Structure

### State Files
- `.claude.ralph-planner.local.md` - Planning loop state
- `.claude.ralph-orchestrator.local.md` - Orchestration loop state
- `.ralph/context.md` - Auto-compaction context anchor

### Planning Artifacts
```
.planning/
├── BRIEF.md          # Human vision and constraints
├── ROADMAP.md        # Phase structure
└── phases/
    └── 01-phase-name/
        ├── 01-01-PLAN.md     # Executable plan
        └── 01-01-SUMMARY.md  # Post-execution summary
```

### Goals Configuration
```
.ralph/
└── goals.xml         # Sequential goal queue
```

## Examples

### Example: goals.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<goals project="Todo App" version="1">
  <goal id="G1" status="todo">
    <title>Set up project foundation</title>
    <description>Initialize React app with TypeScript and required dependencies.</description>
    <acceptance>
      <item>package.json exists with React, TypeScript, and Vite</item>
      <item>App runs with `npm run dev`</item>
    </acceptance>
    <verify>
      <cmd>test -f package.json</cmd>
      <cmd>npm run dev &</cmd>
      <cmd>sleep 3 && curl -s http://localhost:5173 | grep -q React</cmd>
    </verify>
    <notes></notes>
  </goal>

  <goal id="G2" status="todo">
    <title>Implement todo list component</title>
    <description>Create UI for displaying and managing todos.</description>
    <acceptance>
      <item>TodoList component displays todos</item>
      <item>Can add new todos</item>
      <item>Can mark todos as complete</item>
    </acceptance>
    <verify>
      <cmd>test -f src/components/TodoList.tsx</cmd>
      <cmd>grep -q "addTodo" src/components/TodoList.tsx</cmd>
    </verify>
    <notes></notes>
  </goal>
</goals>
```

### Example: Executable Plan

```yaml
---
phase: 01-foundation
plan: 01-01-PLAN
type: execute
---

# Objective
Set up the React + TypeScript project foundation

# Context
- .planning/BRIEF.md (project vision)
- .planning/ROADMAP.md (phase structure)

# Tasks

## Task 1
type: auto
name: Initialize project
files:
- package.json
action:
- Run `npm create vite@latest . -- --template react-ts`
- Install dependencies: `npm install`
verify:
- test -f package.json
- test -f src/main.tsx
done_when:
- package.json exists
- src/main.tsx exists

## Task 2
type: checkpoint/human-verify
name: Verify dev server
files:
- package.json
action:
- Run `npm run dev` in background
- Wait for server to start
- Open http://localhost:5173 in browser
- Take screenshot showing React app running
verify:
- Ask user to confirm server is running
done_when:
- User confirms server is accessible
```

### Example: PLAN Execution

```bash
# Execute the plan
/ralph-run-plan .planning/phases/01-foundation/01-01-PLAN.md

# If plan has checkpoints, Claude will pause for user verification
# After all tasks complete, a SUMMARY.md is automatically created
```

## Templates

Ralph Planner includes four built-in templates:

### BRIEF Template
Located: `skills/ralph-planner/templates/BRIEF.template.md`
Purpose: Define project vision, success criteria, and constraints

### ROADMAP Template
Located: `skills/ralph-planner/templates/ROADMAP.template.md`
Purpose: Structure project into 3-6 phases

### PLAN Template
Located: `skills/ralph-planner/templates/PLAN.template.md`
Purpose: Create executable tasks with verification

### SUMMARY Template
Located: `skills/ralph-planner/templates/SUMMARY.template.md`
Purpose: Document execution outcomes

## Troubleshooting

### Loop Won't Stop

**Problem:** Stop hook keeps blocking exit

**Solution:**
1. Check if all goals are marked `status="done"` in goals.xml
2. Verify completion promise was output: `promiseGOAL {ID} DONEpromise`
3. Cancel manually: `/ralph-orchestrate-cancel`

### Goals Not Progressing

**Problem:** Iteration count increases but goals remain todo

**Solution:**
1. Check goal acceptance criteria are satisfiable
2. Verify commands in `<verify>` section are valid
3. Review `.ralph/context.md` for current goal ID

### State File Errors

**Problem:** Corrupted or missing state file

**Solution:**
1. Cancel loop: `/ralph-orchestrate-cancel`
2. Remove state: `rm -f .claude.ralph-orchestrator.local.md`
3. Re-initialize: `/ralph-orchestrate`

### Auto-Compaction Issues

**Problem:** Session restart loses context

**Solution:**
1. Verify PreCompact hook is configured
2. Check `.ralph/context.md` exists after compaction
3. Review SessionStart hook bootstrap output

## Advanced Usage

### Custom Verification Scripts

Create standalone verification scripts:
```bash
#!/usr/bin/env bash
# verify-goal-1.sh

echo "Running verification for Goal 1..."

# Run your tests
npm test

if [ $? -eq 0 ]; then
  echo "✓ Verification passed"
  exit 0
else
  echo "✗ Verification failed"
  exit 1
fi
```

Reference in goals.xml:
```xml
<verify>
  <cmd>./scripts/verify-goal-1.sh</cmd>
</verify>
```

### Multiple Planning Modes

Use both planning and orchestration:
```bash
# 1. Create planning artifacts
/ralph-plan "Build a REST API" --completion-promise "PLANNING DONE"

# 2. Convert plans to goals
# Edit .planning/ROADMAP.md and extract phases as goals

# 3. Execute goals
/ralph-orchestrate --completion-promise "API COMPLETE"
```

### Checkpoint Strategies

PLANNING mode supports different checkpoint types:
- `type: auto` - Claude executes autonomously
- `type: checkpoint/human-verify` - User must confirm verification
- `type: checkpoint/decision` - User must decide before continuing
- `type: checkpoint/human-action` - User must do something external

## Architecture

### Ralph Planner Skill

The core planning agent that:
- Creates and maintains planning hierarchy
- Uses templates for consistency
- Manages phase execution
- Produces executable prompts

### Orchestrator Loop

The execution engine that:
- Parses goals.xml for current objective
- Drives iterative completion
- Manages state persistence
- Handles auto-compaction

### Hook Integration

Seamless integration via four hooks:
- PreCompact: State persistence
- SessionStart: Context restoration
- PostToolUse: State updates
- Stop: Loop control

### State Management

Minimal state files for reliability:
- YAML frontmatter for metadata
- Constant prompt for loop body
- Context anchor for compaction
- XML goals for authoritative state

## Contributing

Contributions welcome! Please:
1. Follow existing code style
2. Add tests for new features
3. Update documentation
4. Ensure hooks are secure

## License

MIT

## Support

Issues: https://github.com/ralph-planner/ralph-planner/issues

---

**Ralph Planner** - Where planning meets execution. 🎯
