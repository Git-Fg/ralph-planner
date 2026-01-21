# Ralph Planner Examples

This directory contains example files to help you understand and get started with Ralph Planner.

## Files Included

### Goals Configuration
- **example-goals.xml** - Sample XML configuration for goal-based orchestration

### Planning Artifacts
- **example-BRIEF.md** - Sample project brief with vision and constraints
- **example-ROADMAP.md** - Sample roadmap with phase structure
- **example-PLAN.md** - Sample executable plan with tasks and checkpoints
- **example-SUMMARY.md** - Sample post-execution summary

## How to Use These Examples

### For Planning Mode
1. Copy the planning artifacts to your project:
   ```bash
   cp examples/example-BRIEF.md .planning/BRIEF.md
   cp examples/example-ROADMAP.md .planning/ROADMAP.md
   cp examples/example-PLAN.md .planning/phases/01-foundation/01-01-PLAN.md
   ```

2. Start the planning loop:
   ```bash
   /ralph-plan "Your project goal" --max-iterations 5
   ```

3. Execute the plan:
   ```bash
   /ralph-run-plan .planning/phases/01-foundation/01-01-PLAN.md
   ```

### For Orchestration Mode
1. Copy the goals configuration:
   ```bash
   cp examples/example-goals.xml .ralph/goals.xml
   ```

2. Edit goals.xml to match your project
3. Start the orchestrator loop:
   ```bash
   /ralph-orchestrate --max-iterations 10
   ```

## Key Differences

**Planning Mode:**
- Creates planning artifacts (BRIEF, ROADMAP, PLAN)
- Focuses on breaking down work into executable tasks
- Good for initial project setup and structure

**Orchestration Mode:**
- Uses XML goals for sequential execution
- Includes verification commands
- Good for iterative development and completion tracking

## Customization

These examples are templates. Always:
- Update project names and descriptions
- Modify phases to match your workflow
- Adjust verification commands for your context
- Add your own acceptance criteria

## Next Steps

1. Choose your mode (Planning or Orchestration)
2. Copy relevant examples to your project
3. Customize for your specific use case
4. Run the appropriate commands
5. Iterate based on results
