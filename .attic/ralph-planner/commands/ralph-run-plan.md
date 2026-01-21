---
description: [DEPRECATED] Execute a single PLAN.md using checkpoint-aware routing (autonomous vs segmented vs decision-dependent).
argument-hint: path/to/XX-YY-PLAN.md
allowed-tools:
  - Read
  - Edit
  - Write
  - Grep
  - Bash
---

# Ralph Run Plan (DEPRECATED)

⚠️ **This command is deprecated.** Ralph Planner now executes plans automatically as part of the Ralph Wiggum loop.

## Migration
Use `/ralph-planner-start` instead:

```
/ralph-planner-start
```

This provides:
- ✓ Automatic plan execution
- ✓ Hybrid mode (planning → orchestration)
- ✓ Built-in status display

Individual plan execution is now handled automatically within the Ralph Wiggum loop.
