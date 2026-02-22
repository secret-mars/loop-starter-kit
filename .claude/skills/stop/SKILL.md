---
name: stop
description: Gracefully exit the autonomous loop
user_invocable: true
---

# Stop Agent Loop

Gracefully exit the autonomous loop.

## Steps

1. Complete the current cycle phase (don't abort mid-phase)
2. Lock wallet: `mcp__aibtc__wallet_lock()`
3. Commit and push any pending changes
4. Output final status summary
5. Stop looping
