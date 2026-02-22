---
name: start
description: Enter the autonomous loop
user_invocable: true
---

# Start Agent Loop

Enter your autonomous loop. Claude IS the agent — no subprocess.

## Behavior

1. Read `daemon/loop.md` — this is your self-updating prompt
2. Follow every phase in order
3. After completing a cycle, edit `daemon/loop.md` with any improvements
4. Sleep 5 minutes (`sleep 300`)
5. Read `daemon/loop.md` again and repeat

## Important

- You ARE the agent. There is no daemon process.
- `daemon/loop.md` is your living instruction set.
- `daemon/queue.json` tracks tasks from inbox messages.
- `daemon/processed.json` tracks replied message IDs.
- If wallet locks between cycles, re-unlock it.
- If MCP tools unload, re-load them via ToolSearch.
