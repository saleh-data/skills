# Notes & guardrails

Background context for the [nahj](SKILL.md) skill.

## Guardrails

- **One team per session** is the guidance, but a sequential second run works fine if the first team was cleanly `TeamDelete`d. The failure mode is overlapping teams, not reuse — pick a fresh `team_name` (e.g. suffix `-2`) to avoid any residual state collision.
- **Tmux pane quota is the silent failure mode.** ≈5 concurrent teammates is the practical ceiling. Shutdown upstream teammates BEFORE spawning reviewers or the merger. See [TROUBLESHOOTING.md § Tmux pane quota](TROUBLESHOOTING.md#tmux-pane-quota).
- **Split panes require tmux or iTerm2.** In VS Code's integrated terminal you'll get in-process cycling (still works, but no visible panes).
- `/resume` and `/rewind` are known to break in-process teammates. Avoid during a run.
- **Bypass-permissions mode is compatible** with Agent Teams — no known interaction. Teammates inherit the parent session's permission mode unless you pass `mode: "bypassPermissions"` explicitly.
- **The skill never pushes.** Even after a clean merge, `git push` is the user's call. The merger is told this in its prompt.

## Profile cache

The `.nahj/profile.yaml` file is the orchestrator's source of truth for project-specific values (default branch, test commands, scratch environment setup/teardown). It's built once via `scripts/detect-profile.sh` + user confirmation, then re-used silently on every run. See [SKILL.md § First-run setup](SKILL.md#first-run-setup-skip-if-already-done-in-this-repo).

If the profile is missing on a given run, the orchestrator treats it as a first run. If detection finds the project shape has drifted from the cached profile, it surfaces a one-line warning and continues with the cache — see [TROUBLESHOOTING.md § Profile drift](TROUBLESHOOTING.md#profile-drift).

## Composability with other skills

`nahj` deliberately doesn't bake in DB-specific or framework-specific knowledge. The implementer agent reads the project's own context to figure out isolation, and records its teardown commands in `<worktree>/.nahj-teardown.sh` so cleanup stays project-agnostic. This means:

- If a future skill provides reusable scratch-env setup for a specific stack (Postgres-in-docker, Prisma migrations, etc.), the implementer can invoke it instead of figuring isolation out from scratch.
- The user can hand-edit the `isolation:` block of `.nahj/profile.yaml` to embed any setup they want — there's no need to teach the skill new tricks for each stack.

## Timing

Reusable wall-clock expectations:

| Stage | Typical duration |
|---|---|
| Planner | 30–45s |
| Implementer (small/medium slice, ~300–400 LOC) | 25–45 min |
| Implementer (large slice, ~800 LOC) | 45–70 min |
| Reviewer | 5–15 min |
| Merger (single-branch batch) | 15–25 min |
| Merger (3+ branches) | 25–45 min |

Test suite duration dominates merger time. If the project's tests take >60s, expect merger times at the upper end of these ranges; if they're under 10s, the lower end.
