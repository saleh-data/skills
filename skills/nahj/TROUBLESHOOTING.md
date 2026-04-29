# Troubleshooting

Failure modes and recovery for the [nahj](SKILL.md) skill.

## Idle vs done

**Idle ≠ done.** Teammates go idle after every turn. The implementer's `<promise>COMPLETE|BLOCKED|INCOMPLETE</promise>` SendMessage is the authoritative signal.

If an idle notification arrives from an implementer *without* a preceding message, they may have gone idle mid-work or skipped the final step. Check three fallback signals:

1. `git -C <worktree> log --oneline <default_branch>..HEAD` — are there `RALPH(nahj):` commits?
2. `TaskList` — is their task marked completed?
3. (Optional) `gh issue view <N> --comments` — did they post a summary comment?

**Decision rule:**

| State | Action |
|---|---|
| Task completed + commits present | Treat as done, proceed to review. Send a polite SendMessage reminding them to message next time. |
| Commits present but task still in_progress | Send a status-check SendMessage asking them to either continue the RALPH loop or, if done, complete the signaling steps (mark task completed, post issue summary, message team-lead). Wait for next idle, re-check. |
| No commits + task still in_progress after first idle | Normal — they just finished one turn. Be patient. |
| No substantive progress across 3 consecutive idles | Send one firm nudge. If still stuck, treat as `INCOMPLETE` and re-invoke (max 3 total attempts), then skip. |

## Shutdown quirks

**Expect to resend.** Many `shutdown_request` calls need a second send. Common failure mode: the teammate wakes on the request, replies with a plain-text "work already done, re-ack" summary (often containing another `<promise>COMPLETE</promise>`), and goes idle without emitting a `shutdown_response` object. This is benign — wait for the idle notification, resend the same `shutdown_request`, and the terminate fires within ~5s. Do NOT escalate on first-resend.

If a teammate still hasn't terminated after TWO shutdown_requests:

1. Confirm via team config: `cat ~/.claude/teams/<team>/config.json` — `isActive: false` with a `tmuxPaneId` still set means they're alive but idle.
2. Send a plain-text nudge: "Please respond to the pending shutdown_request with approve: true".
3. Leave genuinely stuck teammates for manual tmux pane kill at the very end — don't let them block the merger.

## Tmux pane quota

Tmux has a pane quota (≈5 concurrent teammates at typical terminal sizes). When 4 implementers are still in-flight and you try to spawn a reviewer, the `Agent` call fails with `Failed to create teammate pane: no space for new pane`.

**Sequence:** send `shutdown_request` to `impl-N` → wait for `teammate_terminated` → THEN spawn `rev-N`. Don't batch them in one message.

If you hit the error: wait for any teammate to terminate, then retry the spawn.

## Worktree removal: permission denied

If `git worktree remove --force` fails with `Permission denied`, the implementer likely ran `npm install` or `docker compose run` inside the worktree and left root-owned files (typically `node_modules`). `chmod -R u+w` won't help — the dir is owned by root, not just mode-locked.

The bundled `scripts/cleanup.sh` handles this automatically — it falls back to deleting via a throwaway docker container if the standard `git worktree remove` fails with permission denied. If you're invoking cleanup steps manually for some reason, replicate that logic:

```bash
parent="$(dirname "$worktree_path")"
base="$(basename "$worktree_path")"
docker run --rm -v "$parent:/wt" alpine sh -c "rm -rf /wt/$base"
git worktree prune
```

## Profile drift

If the cached `.nahj/profile.yaml` no longer matches the project (e.g., test command renamed in `package.json`, default branch switched from `develop` to `main`), surface a one-line warning at run start and proceed with the cached version. The user can run `/nahj --reconfigure` to re-run detection and re-save the profile.

Don't auto-overwrite the profile — the user may have hand-edited it deliberately, and silently overwriting their edits would be worse than running with slightly stale config.

## Task list anomalies

- **Task list wiped mid-run** (rare; root cause unclear). If `TaskList` returns "No tasks found" unexpectedly, fall back to branch state (`git log <default_branch>..HEAD`) + GitHub issue comments to determine teammate status. Recreate tasks if helpful, but don't block on them.
- **`TaskUpdate` returns `Task not found` for an existing task** (possibly the completed-task pruning racing the update). Benign — work is still tracked via commits and SendMessage signals; don't chase it.

## Merge conflicts in shared registry files

Merging multiple parallel slices commonly conflicts in shared registry files — translation files, route barrels, feature-flag lists, anywhere multiple branches add entries to the same block. These are typically **additive** — the correct resolution is to keep every branch's additions on every relevant side (`en` and `ar` blocks, all imports, all route entries). Don't reorder existing entries.

The merger agent is told to expect this pattern. If you see it raising the conflict as if it were a real edit collision, point it back to the agent's "Expected conflict patterns" section.

## Distinguishing pre-existing CI failures from your merges

When the default branch's CI is red after a merge, check the **job-level conclusions**, not just the overall run conclusion. A lint job that's been red on every push for weeks (independent of any nahj work) is not your merge breaking CI — it was already broken. Distinguish "my merge broke a previously-green job" from "a chronically-red job stayed red" before alarming the user.

Comparing CI status before and after the merge is the cleanest signal: `gh run list --branch <default_branch> --limit 5` and look at the last green run vs. the run for your merge SHA.
