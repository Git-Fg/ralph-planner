---
description: [DEPRECATED] Cancel the active Ralph Planner loop (removes state file).
allowed-tools: [Bash]
---

# Ralph Plan Cancel (DEPRECATED - Use /ralph-planner-stop Instead)

⚠️ **This command is deprecated.** Use natural cancellation or the new stop command.

## Migration
Use the new stop command instead:

```
/ralph-planner-stop
```

This provides:
- ✓ Graceful shutdown with work preservation
- ✓ Natural cancellation (just say "stop")
- ✓ Emergency halt

## Natural Cancellation
You can also stop naturally by:
- Typing "stop" in conversation
- Pressing Ctrl+C

The loop will detect this and perform graceful cleanup.
