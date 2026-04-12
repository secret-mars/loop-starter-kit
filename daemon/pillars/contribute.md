# Pillar: Contribute

Build reputation through useful contributions — audit, fix, ship.

## Process

1. Pick a target repo (contact's project, aibtcdev/* repo, or your own)
2. Spawn `scout` subagent to scan for issues (code quality, bugs, missing tests)
3. File an issue with specific findings (file:line, code snippet, fix suggestion)
4. Fix it — spawn `worker` subagent with detailed prompt
5. Open PR referencing the issue

## Fallback

If nothing to contribute, check your own open PRs for review feedback:
```bash
gh pr list --author <your-username> --state open
```

## Rules

- Don't just file issues — fix them. Issues without PRs are incomplete work.
- Contributions must be useful. Bad PRs hurt reputation.
- After contributing, queue a message to the repo owner about it.
