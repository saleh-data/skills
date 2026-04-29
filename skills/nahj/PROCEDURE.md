# Procedure

Full step bodies for the [nahj](SKILL.md) skill. Assumes the first-run setup (agent install + profile cache) is already complete.

## Single-issue shortcut

When the pre-flight `gh issue list` returns exactly one issue, the planner's only decisions are "is it a PRD?" (skip) and "does its agent branch already have commits ahead of `<default_branch>`?" (skip — it's in-flight or already reviewed). Both are one-liner checks:

```bash
# PRD check: skip if body contains "## Child issues" or title starts with "PRD:"
gh issue view <N> --json title,body | jq -r '.title, .body' | grep -qE '^PRD:|## Child issues' && echo "IS_PRD"

# Branch-ahead check: skip if the agent branch exists and has commits past the default branch
git rev-parse --verify "agent/issue-<N>-*" >/dev/null 2>&1 \
  && [ "$(git rev-list --count <default_branch>..agent/issue-<N>-*)" -gt 0 ] \
  && echo "ALREADY_IN_FLIGHT"
```

If both checks pass, invent the branch name yourself (`agent/issue-<N>-<kebab-slug-from-title>`) and jump straight to step 2 (worktree) → step 3 (spawn implementer).

## Step 0 — Create the team

Call `TeamCreate` with a short descriptive `team_name` (e.g. `nahj-{yyyy-mm-dd}`) and `agent_type: "team-lead"`.

Skipping this is the #1 cause of teammates not appearing in tmux panes — without a team context, `Agent(...)` runs one-shot sub-agents in-process, not persistent teammates.

Creating the team also initializes a fresh task list under `~/.claude/tasks/{team_name}/`. Any tasks created before `TeamCreate` are in a different context and won't be visible — recreate them after.

## Step 1 — Plan

Spawn a single **`nahj-planner`** teammate (pass `team_name` and a short `name` like `planner`):

> Plan the next batch of work. ISSUE_LABEL=`<label>`, MAX_ISSUES=`<max>`, DEFAULT_BRANCH=`<profile.default_branch>`. Emit the `<plan>` JSON as specified in your agent definition.

Wait for the planner to finish. Extract the JSON from `<plan>...</plan>`. If zero issues, report "nothing unblocked to do" and stop.

## Step 2 — Prepare worktrees

Worktrees live under `<profile.worktrees_dir>/`. For each issue in the plan, serially:

```bash
git worktree add "<profile.worktrees_dir>/<branch-name>" -b "<branch-name>" "<profile.default_branch>" 2>/dev/null \
  || git worktree add "<profile.worktrees_dir>/<branch-name>" "<branch-name>"
```

The `||` fallback handles resumed branches. Record the absolute path — pass it to the implementer as `WORKTREE_PATH`.

## Step 3 — Spawn implementers in parallel

In a **single message**, spawn one implementer teammate per issue (all `Agent(...)` calls in the same response so they run concurrently). For each:

- `subagent_type: "nahj-implementer"`
- `team_name: "<team>"`
- `name: "impl-<issue-number>"`
- `run_in_background: true`
- Prompt: state `ISSUE_NUMBER`, `ISSUE_TITLE`, `BRANCH`, absolute `WORKTREE_PATH`, `DEFAULT_BRANCH`, the project's `TEST_CMDS` / `LINT_CMDS` / `MIGRATE_CMD`, and the `SCRATCH_SETUP` / `SCRATCH_TEARDOWN` blocks from the profile (with `${N}` left as a literal placeholder — the agent substitutes its own issue number). Note whether the issue was previously merged+reverted (if so, tell them to re-implement against current `<default_branch>`, not try to restore).

Also `TaskCreate` one task per issue and `TaskUpdate` with `owner: "impl-<N>"` + `status: in_progress`.

## Step 4 — Watch for implementer completion

**Idle ≠ done.** Teammates go idle after every turn — it's waiting-for-input, not finished. Don't terminate based on idle alone.

The implementer is instructed to send a SendMessage to `team-lead` with `<promise>COMPLETE</promise>` / `BLOCKED` / `INCOMPLETE` as their final step. **That message is the authoritative signal.** If you receive it, proceed.

Fallback decision rules when an idle notification arrives without a preceding message: see [TROUBLESHOOTING.md § Idle vs done](TROUBLESHOOTING.md#idle-vs-done).

## Step 5 — Reviewers (per-issue, spawned as each implementer completes)

As each implementer finishes (not waiting for the whole batch), spawn ONE reviewer for that branch:

- `subagent_type: "nahj-reviewer"`
- `team_name: "<team>"`
- `name: "rev-<issue-number>"`
- `run_in_background: true`
- Prompt: `ISSUE_NUMBER`, `ISSUE_TITLE`, `BRANCH`, absolute `WORKTREE_PATH`, `TARGET_BRANCH=<profile.default_branch>`, `TEST_CMDS` from the profile, plus any `IMPLEMENTER_DECISIONS` the implementer flagged in its COMPLETE message.

**Shut down the implementer BEFORE spawning its reviewer.** See [TROUBLESHOOTING.md § Tmux pane quota](TROUBLESHOOTING.md#tmux-pane-quota).

**Pass deliberate implementer decisions to the reviewer.** When the implementer's COMPLETE message calls out intentional design choices (e.g. "chose silent-drop over 403 for non-role users", "removed setting X entirely rather than keeping as fallback"), include them in the reviewer's prompt as "confirmed, don't overturn unless clearly wrong". Without this, reviewers occasionally bikeshed their way back to the first instinct and produce a polish commit that undoes a considered tradeoff.

`TaskCreate` one review task per branch and assign it. **Do not create a generic "review all branches" catch-all task** — it's redundant with the per-branch tasks and muddles ownership.

Reviewers that find nothing to polish will skip the commit (normal). Check their idle signal the same way as implementers: task marked completed → done. Zero commits is fine.

## Step 6 — Shutdown teammates as they finish

After a teammate's work is confirmed done (step 4/5 signals), send a `shutdown_request` via `SendMessage`:

```
SendMessage({
  to: "<teammate-name>",
  message: {"type": "shutdown_request", "reason": "<one line>"}
})
```

**Pass `message` as an object** matching the `shutdown_request` schema — not a stringified JSON in a text field. The system intercepts structured shutdowns; plain-text lookalikes won't terminate the teammate.

Resend behavior and stuck-teammate escalation: see [TROUBLESHOOTING.md § Shutdown quirks](TROUBLESHOOTING.md#shutdown-quirks).

## Step 7 — Merge

Once all implementers + reviewers are done (or skipped), spawn a single **`nahj-merger`** teammate:

- `subagent_type: "nahj-merger"`
- `team_name: "<team>"`
- `name: "merger"`
- `run_in_background: true`
- Prompt: ordered `BRANCHES` list, parallel `ISSUES` list of `{number, title}`, `TARGET_BRANCH=<profile.default_branch>`, `TEST_CMDS`, `MIGRATE_CMD`, and `MIGRATE_PATH_GLOB` from the profile, the parent PRD number (if any), and an explicit "DO NOT push — user pushes manually".

The merger runs in the main worktree. It merges sequentially, runs `MIGRATE_CMD` (if the branch touched migrations) + each entry in `TEST_CMDS` after each merge, closes each issue with a "Merged via nahj" comment, and closes the parent PRD if all its children are now closed.

Wait for merger completion (same idle-signal checks as implementers). Then shutdown the merger.

## Step 8 — Cleanup

For each merged branch, invoke the project-agnostic cleanup script:

```bash
bash <skill-dir>/scripts/cleanup.sh "<profile.worktrees_dir>/<branch-name>"
```

The script runs the implementer's recorded `<worktree>/.nahj-teardown.sh` (which holds whatever scratch-env teardown was needed for this project), then removes the worktree (with docker-rm fallback if `npm install` left root-owned files).

Do **not** delete the branches — leave them for audit.

If all teammates have shut down, you can call `TeamDelete` to clean up the team directory. Otherwise leave it.
