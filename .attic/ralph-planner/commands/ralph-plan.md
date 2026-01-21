---
description: [DEPRECATED] Start a Ralph Wiggum-style iterative loop to create/maintain BRIEF/ROADMAP/PLAN planning artifacts.
argument-hint: Project goal + constraints (quoted if long) --max-iterations N --completion-promise "PLANNING COMPLETE"
allowed-tools:
  - Bash
---

# Ralph Plan (DEPRECATED - Use /ralph-planner-start Instead)

⚠️ **This command is deprecated.** Ralph Planner now uses a unified approach.

## Migration
Use the new unified command instead:

```
/ralph-planner-start "$PROJECT_GOAL"
```

This provides:
- ✓ Hybrid mode (planning → orchestration automatically)
- ✓ Built-in status display
- ✓ Natural cancellation
- ✓ Smart detection

## Automatic Redirect
You are being redirected to `/ralph-planner-start`...

! bash -lc 'echo "⚠️  DEPRECATED: Use /ralph-planner-start instead"; /ralph-planner-start $ARGUMENTS'
