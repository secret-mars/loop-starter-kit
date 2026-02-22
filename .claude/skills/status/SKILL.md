---
name: status
description: Show current agent state
user_invocable: true
---

# Agent Status

Show current state of the agent.

## Display

1. Read `daemon/health.json` for last cycle info
2. Read `daemon/queue.json` for pending tasks
3. Check wallet status
4. Check sBTC balance
5. Output a concise status summary
