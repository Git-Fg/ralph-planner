---
description: [DEPRECATED] Start the Ralph Orchestrator loop (dynamic prompt from .ralph/goals.xml, sequential goals, verify gate).
argument-hint: --max-iterations N --completion-promise "ALL GOALS COMPLETE"
allowed-tools:
  - Bash
---

# Ralph Orchestrate (DEPRECATED - Use /ralph-planner-start Instead)

⚠️ **This command is deprecated.** Ralph Planner now uses a unified approach.

## Migration
Use the new unified command instead:

```
/ralph-planner-start
```

This provides:
- ✓ Hybrid mode (planning → orchestration automatically)
- ✓ Built-in status display
- ✓ Natural cancellation
- ✓ Smart detection

## Automatic Redirect
You are being redirected to `/ralph-planner-start`...

! bash -lc 'echo "⚠️  DEPRECATED: Use /ralph-planner-start instead"; /ralph-planner-start'
