---
name: nahj
description: Runs nahj — a methodical multi-agent pipeline that picks open GitHub issues by label, implements them in parallel git worktrees with project-appropriate isolation, polishes each via a reviewer pass, and merges back to the project's default branch with tests + migrations between merges. Use when the user says "/nahj", asks to process several labeled GitHub issues end-to-end, wants to fan out parallel implementer agents, or needs the planner→implementer→reviewer→merger flow.
---

# nahj

`nahj` (نهج, "method / approach") orchestrates a caravan of agent teammates that picks open GitHub issues by label, implements them in parallel (each in its own git worktree + isolated scratch environment), reviews the work, and merges back to the project's default branch.

## Quick start

```
> /nahj                        # process up to 5 open issues labeled `nahj`
> /nahj label=feature max=3    # custom label + cap
```

First run in a new repo: ~30s of one-time setup (profile detection + agent install). Every run after: zero prompts.

## Args

- **label** — GitHub label filter (default: from project profile, falls back to `nahj`)
- **max** — maximum issues to pick (default: `5`)
- **--reconfigure** — discard cached profile and re-detect

Parse `$ARGUMENTS` for `label=...` and `max=...` key-value pairs.

## First-run setup (skip if already done in this repo)

1. **Install agent definitions** — check `.claude/agents/nahj-{planner,implementer,reviewer,merger}.md`. If any are missing or older than the bundled versions:
   ```bash
   bash <skill-dir>/scripts/install-agents.sh           # project-scoped
   # or, for user-wide install:
   bash <skill-dir>/scripts/install-agents.sh --global
   ```
2. **Build the project profile** — check for `.nahj/profile.yaml`. If missing:
   ```bash
   mkdir -p .nahj && bash <skill-dir>/scripts/detect-profile.sh > .nahj/profile.yaml.draft
   ```
   Show the draft to the user, ask them to fill any `TODO` fields, save as `.nahj/profile.yaml`. Ask once whether to commit it (recommended) or add `.nahj/` to `.gitignore`.

The profile is the orchestrator's source of truth for everything project-specific. **Subsequent runs skip both steps entirely** — load the profile and proceed.

## Prerequisites (check before starting)

1. **Agent Teams enabled** — `.claude/settings.json` has `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
2. **tmux split panes** (recommended) — `~/.claude.json` has `"teammateMode": "auto"` or `"tmux"` and `$TMUX` is set.
3. **`gh` authenticated** — `gh auth status`.
4. **Clean working tree on default branch** — `git status --porcelain` empty (or modifications scoped to `.claude/`/`.nahj/` only — those don't leak into worktrees).
5. **Profile loaded** — `.nahj/profile.yaml` exists and parses; agent files installed.

If a blocker fails, tell the user exactly what's missing and stop.

## Pre-flight: skip the planner for small batches

Before creating the team and spawning a planner, fetch the list directly:
```bash
gh issue list --label "<label>" --state open --json number,title,body,labels
```

Branch on the count:

- **0 issues** → tell the user "no open `<label>` issues" and stop.
- **1 issue** → do the planner's work inline (PRD check + branch-ahead check). See [PROCEDURE.md § Single-issue shortcut](PROCEDURE.md#single-issue-shortcut). Saves ~45s.
- **2+ issues** → create the team and spawn the planner.

## Procedure overview

Detailed step bodies in [PROCEDURE.md](PROCEDURE.md).

0. **Create the team** (`TeamCreate`, `agent_type: "team-lead"`) — REQUIRED before any spawn. Skipping is the #1 cause of teammates not appearing in panes.
1. **Plan** — spawn one `nahj-planner` teammate, wait for `<plan>JSON</plan>`.
2. **Prepare worktrees** under `<profile.worktrees_dir>/` — one per branch.
3. **Spawn implementers in parallel** — single message, all `Agent(...)` calls together. Pass each one its branch, worktree path, and the relevant profile fields (`TEST_CMDS`, `LINT_CMDS`, `MIGRATE_CMD`, `SCRATCH_SETUP`, `SCRATCH_TEARDOWN`).
4. **Watch for completion** — implementer's `<promise>COMPLETE</promise>` SendMessage is the authoritative signal. Idle ≠ done. Fallback signals in [TROUBLESHOOTING.md § Idle vs done](TROUBLESHOOTING.md#idle-vs-done).
5. **Reviewers** — spawn ONE `nahj-reviewer` per branch as each implementer finishes. **Shutdown the implementer first** (pane quota — see [TROUBLESHOOTING.md § Tmux pane quota](TROUBLESHOOTING.md#tmux-pane-quota)).
6. **Shutdown teammates** — `SendMessage` with `message` as a `shutdown_request` object. Expect to resend.
7. **Merge** — single `nahj-merger` teammate, sequential merges, tests + migrations after each. **Do NOT push.**
8. **Cleanup** — for each worktree: `bash <skill-dir>/scripts/cleanup.sh <worktree_path>`. The script invokes the implementer's recorded `.nahj-teardown.sh` and removes the worktree (with docker-rm fallback for permission-denied cases).

## Report back

- Issues merged (number + title), blocked (number + reason), skipped (number + last state)
- Any teammates that failed to shut down gracefully — include ready-to-paste `tmux kill-pane -t %A \; kill-pane -t %B` with actual pane IDs from `~/.claude/teams/<team>/config.json`
- Integration branch HEAD sha + confirmation nothing was pushed to origin
- Wall-clock observations for next run (see [NOTES.md § Timing](NOTES.md#timing))

## Other reading

- [PROCEDURE.md](PROCEDURE.md) — full step bodies with snippets
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — idle signals, shutdown quirks, pane quota, worktree permission fallback
- [NOTES.md](NOTES.md) — guardrails, known issues, expected timings
