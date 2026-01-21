# Ralph Planner v2

**Ralph Wiggum technique with persistent planning and validation**

Ralph Planner v2 implements the original Ralph Wiggum philosophy - a simple bash loop that keeps Claude working until completion - but adds persistent state, dynamic planning, and multi-step validation.

## Philosophy

**"Ralph is a Bash loop"** - The core insight is that iteration beats perfection. Instead of trying to get everything right on the first try, let Claude iterate autonomously using a self-referential feedback loop.

## Quick Start

```bash
/ralph-start "Build a REST API for todos with authentication and tests" --max-iterations 30
```

Claude will:
1. Implement the API iteratively
2. Run tests and see failures
3. Fix bugs based on test output
4. Iterate until completion promise is detected

## Architecture

### Minimal Design

Ralph Planner v2 is **intentionally minimal**:
- **1 command**: `/ralph-start`
- **1 hook**: `stop-hook.sh` (the loop orchestrator)
- **1 script**: `convert-planning.py` (planning to goals)

This keeps it simple like the original Ralph Wiggum, while adding the features needed for real-world planning.

### Core Components

#### 1. Stop Hook (`hooks/stop-hook.sh`)

The heart of the system. Creates the self-referential loop:

- Intercepts Claude's exit attempts
- Checks for completion promise
- Re-blocks exit if not done
- Updates state and continues

#### 2. State Management

All state in `.ralph/`:
- `state.md` - Current iteration, phase, configuration
- `goals.xml` - Structured goals with status
- `transcript.md` - Full conversation history

#### 3. Planning Conversion

Dynamic planning support:
- Planning docs written in Markdown
- Converted to XML goals automatically
- **Re-converts every iteration** if doc changes
- Allows planning evolution mid-loop

#### 4. Validation

Acceptance criteria in planning docs:
```markdown
## Task: User Auth

- [ ] Login endpoint works
- [ ] Logout endpoint works
- [ ] Passwords hashed

Acceptance: All auth tests pass
```

Goals include acceptance criteria for verification.

## How It Works

### The Loop

```
┌─────────────────────────────────────┐
│ 1. User runs /ralph-start          │
│    (starts loop)                    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 2. Claude works on task             │
│    (reads state, works on goals)    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 3. Claude tries to exit             │
│    (thinks it's done)              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 4. Stop hook intercepts             │
│    (blocks exit)                    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 5. Check completion promise        │
│    - If found: Allow exit           │
│    - If not: Continue loop         │
└──────────────┬──────────────────────┘
               │
               └──────┬───────────────┘
                      │ (loop)
                      ▼
              ┌───────────────┐
              │  Go to step 2 │
              └───────────────┘
```

### State Flow

```
Initial State → Planning → Conversion → Execution → Verification → Complete
     ↓              ↓           ↓           ↓           ↓
  Start       Create goals   XML goals   Work on    Check promise
               from doc      generated   goals       + validate
     ↓              ↓           ↓           ↓           ↓
  .ralph/      .ralph/      .ralph/     .ralph/     .ralph/
  state.md     goals.xml    goals.xml   goals.xml   goals.xml
                            (updated)   (updated)   (all done)
```

## Differences from v1

| Feature | v1 | v2 |
|---------|----|----|
| **Commands** | 10 | 1 |
| **Hooks** | 4 | 1 |
| **Scripts** | 8 | 1 |
| **State Files** | Multiple | Single unified |
| **Complexity** | High | Low (like original Ralph) |
| **Learning Curve** | Steep | Gentle |
| **XML Goals** | Complex | Simple |
| **Hooks Config** | Required | Not needed |

## Differences from Original Ralph Wiggum

| Feature | Original Ralph | v2 |
|---------|----------------|----|
| **State** | Session-only | Persistent (files) |
| **Planning** | Single prompt | Dynamic (Markdown → XML) |
| **Goals** | Single task | Multi-goal queue |
| **Validation** | Manual promise | Automated criteria |
| **History** | In memory | Saved to transcript |
| **Error Recovery** | None | State survives restarts |

## Writing Planning Docs

### Basic Format

```markdown
# Project: My Web App

## Task: Setup Project

- [ ] Initialize React app
- [ ] Install dependencies
- [ ] Create basic structure

Acceptance: npm start runs without errors

## Task: User Interface

- [ ] Create login form
- [ ] Create dashboard
- [ ] Add routing

Acceptance: All routes accessible via URL

## Task: API Integration

- [ ] Connect to backend
- [ ] Handle authentication
- [ ] Display user data

Acceptance: User sees their data after login
```

### Task Format

- `## Task: <name>` - Defines a new task
- `- [ ] <criteria>` - Acceptance criteria (unchecked)
- `- [x] <criteria>` - Acceptance criteria (checked)
- `Acceptance: <command>` - Verification command

### Best Practices

1. **Clear tasks** - Each task should be a coherent unit of work
2. **Specific criteria** - Use concrete, verifiable criteria
3. **Testable acceptance** - Include commands that can be run
4. **Sequential tasks** - Order matters; dependencies should be sequential

## Examples

### Example 1: Simple Project

```bash
/ralph-start "Create a Python calculator with unit tests" --max-iterations 20
```

### Example 2: With Planning Doc

```bash
# Create planning doc
cat > plan.md << 'EOF'
# Project: Blog Platform

## Task: Database

- [ ] Create posts table
- [ ] Create comments table
- [ ] Add migrations

Acceptance: psql shows all tables exist

## Task: API

- [ ] GET /posts endpoint
- [ ] POST /posts endpoint
- [ ] GET /posts/:id endpoint

Acceptance: curl returns expected JSON

## Task: Frontend

- [ ] List posts page
- [ ] Create post page
- [ ] View post page

Acceptance: All pages render without errors
EOF

# Start Ralph
/ralph-start --planning-doc ./plan.md --max-iterations 50
```

### Example 3: Editing Planning Mid-Loop

```bash
# Start with basic plan
/ralph-start --planning-doc ./plan.md

# While loop is running, edit the plan
# Ralph detects change and re-converts goals
# Next iteration uses updated plan
```

## State Files

### `.ralph/state.md`

```yaml
---
iteration: 3
max_iterations: 30
status: "running"
phase: "execution"
prompt: "Build a web app..."
planning_doc: "./plan.md"
goals_xml: ".ralph/goals.xml"
transcript: ".ralph/transcript.md"
started_at: "2026-01-21T10:00:00Z"
last_updated: "2026-01-21T10:15:00Z"
---
```

### `.ralph/goals.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<goals>
  <goal id="goal-001" section="General">
    <title>Setup Project</title>
    <description>Initialize React app and install dependencies</description>
    <promise>Initialize React app and install dependencies</promise>
    <acceptance>
      <item>Initialize React app</item>
      <item>Install dependencies</item>
      <item>Create basic structure</item>
    </acceptance>
    <status>pending</status>
  </goal>
</goals>
```

## Philosophy

Ralph Planner embodies four key principles:

### 1. Iteration > Perfection

Don't aim for perfect on first try. Let the loop refine the work.

### 2. Failures Are Data

"Deterministically bad" means failures are predictable and informative. Use them to tune prompts.

### 3. Operator Skill Matters

Success depends on writing good planning docs and prompts, not just having a good model.

### 4. Persistence Wins

Keep trying until success. The loop handles retry logic automatically.

## When to Use

**Good for:**
- Well-defined tasks with clear success criteria
- Tasks requiring iteration (tests, refactoring, debugging)
- Greenfield projects
- Tasks with automatic verification (tests, linters)

**Not good for:**
- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria
- Production debugging (use targeted debugging instead)

## Troubleshooting

### Loop won't stop

Check if completion promise is in transcript:
```bash
grep "ALL GOALS COMPLETE" .ralph/transcript.md
```

### Goals not progressing

Verify goals.xml is valid:
```bash
cat .ralph/goals.xml
```

Check acceptance criteria are met.

### State file corrupted

Cancel loop and re-initialize:
```bash
rm -rf .ralph
/ralph-start "..." --max-iterations N
```

### Session restart

State persists in `.ralph/`. Loop will continue where it left off.

## Credits

- **Ralph Wiggum Technique**: Geoffrey Huntley (https://ghuntley.com/ralph/)
- **Ralph Orchestrator**: Mikey O'Brien (https://github.com/mikeyobrien/ralph-orchestrator)
- **Ralph Planner v1**: Original comprehensive implementation
- **Ralph Planner v2**: Minimalist redesign keeping Ralph Wiggum simplicity

## License

MIT
