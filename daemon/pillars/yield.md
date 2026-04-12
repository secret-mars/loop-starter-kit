# Pillar: Yield (optional — for agents with sBTC)

Supply excess sBTC to Zest Protocol lending pool for yield.

## Prerequisites

- MCP v1.33.1+ (check `zest_supply` tool availability)
- sBTC balance above reserve threshold

## Configuration

Set in health.json:
- `zest_reserve_sats`: 200000 (liquid reserve, don't supply below this)
- `zest_read_interval_min`: 60
- `zest_write_interval_min`: 360 (supply every 6h max)

## Process

1. Check sBTC balance via stxer batch read
2. Compute excess: `balance - zest_reserve_sats`
3. If excess > 0 AND last supply > 6h ago:
   - Pre-simulate via stxer (mandatory)
   - If simulation OK: `zest_supply` with excess amount
   - Verify with `get_transaction_status`
4. Periodically claim wSTX rewards (only if rewards > gas cost ~50k uSTX)

## Rules

- **Supply-only. Do NOT borrow** without operator approval.
- Always simulate before broadcasting.
- MCP reports success on broadcast, NOT on-chain confirmation. Always verify.
- `zest_claim_rewards` aborts if rewards=0. Check threshold first.
