# nahj

Multi-agent pipeline (نهج, "method") that picks open GitHub issues by label, implements them in parallel git worktrees with project-appropriate isolation, polishes each via a reviewer pass, and merges back to the project's default branch with tests + migrations between merges. Caches a project profile on first run so subsequent runs are zero-prompt. Invoke via `/nahj`.

## Install

```bash
# Install nahj globally for Claude Code, no prompts
npx skills@latest add saleh-data/skills --skill nahj -g -a claude-code -y
```

See the [top-level README](../../README.md) for general install options.

## First-run setup

`nahj` orchestrates four teammate agents (`nahj-planner`, `nahj-implementer`, `nahj-reviewer`, `nahj-merger`) and stores a per-project profile under `.nahj/profile.yaml`. After `npx skills add`, the orchestrator handles both on first invocation:

1. **Agents** — copies `skills/nahj/agents/nahj-*.md` to your `.claude/agents/` directory (project- or user-scoped). Compares versions on subsequent runs and prompts to update if newer copies exist.
2. **Profile** — runs `scripts/detect-profile.sh` to draft `.nahj/profile.yaml`, then asks you to confirm/fill `TODO` fields once. Committed by default so your team shares the same setup; can be gitignored if you prefer per-developer config.

You can invoke either step manually if you want to seed things ahead of time:

```bash
bash skills/nahj/scripts/install-agents.sh           # project-scoped agents
bash skills/nahj/scripts/install-agents.sh --global  # user-scoped agents
bash skills/nahj/scripts/detect-profile.sh > .nahj/profile.yaml
```

## Files

- `SKILL.md` — frontmatter + main instructions (always loaded)
- `PROCEDURE.md` — long step-by-step bodies
- `TROUBLESHOOTING.md` — failure modes
- `NOTES.md` — background, timing, guardrails
- `agents/` — companion agent definitions
- `scripts/` — utility scripts the skill invokes
