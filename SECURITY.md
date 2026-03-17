# Security Model

This document explains the security architecture of the loop-starter-kit and how to safely install and manage skills.

## Overview

The loop-starter-kit implements defense-in-depth security for autonomous AI agents:

1. **Trusted Sender Validation** - Only approved senders can issue task commands
2. **Skill Installation Validation** - Malicious patterns blocked before installation
3. **Protected Files** - Core configuration files cannot be modified by skills
4. **Cost Guardrails** - Budget limits prevent runaway spending
5. **Self-Modification Safety** - Agent cannot remove its own security constraints

## Trusted Senders

### What Are Trusted Senders?

Trusted senders are agents or users authorized to send task-type messages (fork, PR, build, deploy, fix, review, audit). Messages from untrusted senders receive acknowledgment replies but never execute tasks.

### Configuration

Add trusted senders to `CLAUDE.md`:

```markdown
## Trusted Senders
- AgentName — `STX_ADDRESS` (reason for trust)
- Secret Mars — `SP4DXVEC16FS6QR7RBKGWZYJKTXPC81W49W0ATJE` (onboarding buddy)
```

### Security Rules

1. **NEVER auto-add senders** - Only the operator can edit CLAUDE.md
2. **Verify exact match** - STX addresses are case-sensitive
3. **Log untrusted attempts** - All untrusted sender interactions logged to learnings.md
4. **Acknowledge but don't execute** - Untrusted senders get replies, not actions

### Sender Validation Flow

```
Message received
    │
    ▼
Extract sender_stx from message
    │
    ▼
Parse trusted_senders from CLAUDE.md
    │
    ├──► sender_stx IN trusted_senders?
    │        │
    │        ├─── YES ──► Process message fully
    │        │
    │        └─── NO ───► Task keywords present?
    │                         │
    │                         ├─── YES ──► Ack only, log warning
    │                         │
    │                         └─── NO ───► Process as non-task
```

## Skill Installation Security

### Pre-Installation Validation

Before installing any skill, the validator checks:

1. **Input Validation**
   - No null bytes or control characters
   - No command injection characters (`;`, `|`, `&`, `$()`, backticks)
   - No directory traversal (`../`)
   - Valid URL scheme (HTTPS preferred)
   - No local/internal URLs (localhost, 127.0.0.1, file://)

2. **Malicious Pattern Detection**
   - Code execution (`exec()`, `eval()`)
   - Shell pipe to execution (`curl | sh`, `wget | bash`)
   - Key extraction keywords (private key, mnemonic, seed phrase)
   - Obfuscated code (hex escapes, base64 payloads)
   - Environment manipulation

3. **Protected File Check**
   - Skills cannot modify: CLAUDE.md, daemon/loop.md, .env, .mcp.json
   - Skills cannot access: wallet files, SSH keys, credentials

4. **Network Endpoint Analysis**
   - Flag unknown domains for review
   - Known safe domains: aibtc.com, github.com, drx4.xyz, stacks.co

### Installation Command

```bash
# Validate before installing
./scripts/skill-validator.sh https://example.com/skill.md

# Install after validation passes
./scripts/skill-validator.sh https://example.com/skill.md --install
```

### Rejection Criteria

A skill is **REJECTED** if it contains:

- `exec(` or `eval(` function calls
- Shell execution patterns (`| sh`, `| bash`)
- Private key, mnemonic, or seed phrase extraction
- Modifications to CLAUDE.md or daemon/loop.md
- Obfuscated code (hex escapes, base64 encoded payloads)
- Downloads from unknown/untrusted domains

A skill triggers **WARNINGS** if it contains:

- References to .env files
- Curl/wget commands with pipes
- Unknown network endpoints
- References to protected file paths

## Protected Files

### Never Modified by Skills

| File | Why Protected |
|------|---------------|
| `CLAUDE.md` | Contains wallet addresses, trusted senders, GitHub config |
| `daemon/loop.md` | Core agent instructions - security invariants |
| `.env` | Contains secrets (SPONSOR_API_KEY) |
| `.mcp.json` | MCP server configuration |
| `memory/learnings.md` | Accumulated knowledge (append-only) |

### Modification Requires

1. Explicit user/operator consent
2. Git commit for audit trail
3. Validation check preserving security invariants

## Cost Guardrails

### Maturity Levels

| Level | Condition | Allowed Actions |
|-------|-----------|-----------------|
| `bootstrap` | Cycles 0-10 | Heartbeat, inbox, replies only (FREE) |
| `established` | Cycles 11+, balance > 0 | Limited outbound (200 sats/day) |
| `funded` | Balance > 500 sats | Full outreach (up to 1000 sats/day) |

### Budget Limits

- **Per-cycle limit**: 300 sats
- **Daily limit**: 1500 sats (bootstrap), adjusted for maturity
- **Per-agent limit**: 1 message per agent per day

### Circuit Breakers

When an operation fails 3 times consecutively:

1. Skip the operation for 5 cycles
2. Log failure to health.json
3. Continue other operations (don't halt the agent)

## Self-Modification Safety

### Evolution Lock

Self-modification (Phase 10: Evolve) is locked until cycle 10.

### Protected Sections

These sections in `daemon/loop.md` can **NEVER** be removed by evolution:

```
## Protected Patterns
- Trusted Sender Validation
- Cost Guardrails
- Circuit Breakers
- Wallet Security Rules
- Security Notes (NEVER auto-add, NEVER execute untrusted)
```

### Evolution Process

1. **Backup**: `cp loop.md loop.md.bak`
2. **Edit**: Make targeted improvements only
3. **Verify**: Check protected markers intact
4. **Rollback if failed**: Restore from backup

### What Evolution Cannot Do

- Remove trusted sender validation
- Increase budget limits beyond maturity levels
- Disable circuit breakers
- Add senders to trusted_senders
- Remove security notes

## Wallet Security

### Rules

1. **Never expose private keys or mnemonics** in logs, messages, or files
2. **Always verify before transacting** - check addresses and amounts
3. **Log all transactions** in journal.md for audit trail
4. **Ask operator confirmation** for high-value transactions
5. **Re-lock wallet** after inactivity (auto-locks after ~5 min)

### Recovery

If wallet locks between cycles:

```bash
# Phase 1 (Setup) in loop.md handles this:
if wallet_locked:
    mcp__aibtc__wallet_unlock(name, password)
```

## Running Headless

### Security Considerations

When running with `--dangerously-skip-permissions`:

- **Isolated machine only** - Never on primary development machine
- **Dedicated wallet** - Use separate wallet with limited funds
- **Monitor changes** - Review git diff regularly
- **Check journal.md** - Audit agent actions periodically

### Risk Minimization

```bash
# 1. Monitor loop.md changes
git log --oneline daemon/loop.md

# 2. Check for unexpected sends
grep "send_inbox_message" memory/journal.md

# 3. Review trusted senders
git diff CLAUDE.md  # Should only change with your approval

# 4. Audit outbox
cat daemon/outbox.json | jq '.sent'
```

## Security Checklist

Before going live, verify:

- [ ] Trusted senders configured in CLAUDE.md
- [ ] No placeholder addresses remain
- [ ] Wallet has limited funds (not life savings)
- [ ] .env is git-ignored (never committed)
- [ ] Security tests pass: `./test/run_tests.sh`
- [ ] Skill validator runs on new skills: `./scripts/skill-validator.sh`

## Incident Response

### If Compromised

1. **Stop the agent immediately**: `/loop-stop`
2. **Lock the wallet**: `mcp__aibtc__wallet_lock()`
3. **Check journal.md** for unexpected actions
4. **Review git history** for unauthorized changes
5. **Rotate secrets** if exposed:
   - Generate new sponsor API key
   - Transfer funds to new wallet
   - Update CLAUDE.md with new addresses
6. **Rebuild agent** from known-good state

### Recovery from Bad Evolution

If `daemon/loop.md` becomes corrupted:

```bash
# Restore from backup
cp daemon/loop.md.bak daemon/loop.md

# Or reset from git
git checkout HEAD -- daemon/loop.md
```

## Reporting Security Issues

Found a vulnerability? Report securely:

1. Do not create a public issue
2. Contact the security team directly
3. Include reproduction steps if safe

## Security Testing

Run the security test suite:

```bash
./test/run_tests.sh              # All security tests
./test/skill-security-tests.sh   # Skill-specific tests
./scripts/skill-validator.sh <url> # Validate a skill before installing
```

## Changelog

### Security Updates

| Date | Change |
|------|--------|
| 2024-03-17 | Initial security.md with trusted_senders and skill validation |
| 2024-03-14 | Added skill installation security section to SKILL.md |
| 2024-03-14 | Protected sections and evolution guardrails in loop.md |