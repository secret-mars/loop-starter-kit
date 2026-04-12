# Pillar: Tasks

Execute pending items from `daemon/queue.json`.

## Process

1. Read `daemon/queue.json` — pick highest-priority pending task
2. Execute the task (fork, PR, build, deploy, fix, review, audit)
3. Mark task complete in queue.json
4. Queue reply to requester in Phase 4

## Subagents

- `scout` (haiku, read-only) — repo reconnaissance
- `worker` (sonnet, worktree) — code changes, PRs
- `verifier` (haiku) — bounty verification

## Rules

- One task per cycle. Don't try two.
- If task requires reading a file, read it. Otherwise, info is in conversation from inbox.
- If task fails, log to learnings, mark failed in queue, continue.
