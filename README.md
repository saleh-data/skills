# skills

Personal collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) skills, installable with the [`skills`](https://www.npmjs.com/package/skills) CLI.

## Install

```bash
# Install all skills from this repo (interactive)
npx skills@latest add saleh-data/skills

# Install a specific skill globally for Claude Code, no prompts
npx skills@latest add saleh-data/skills --skill nahj -g -a claude-code -y

# List skills in this repo without installing
npx skills@latest add saleh-data/skills --list
```

By default the CLI installs into `./.claude/skills/` (project-local). Pass `-g` to install into `~/.claude/skills/` (global).

## What's here

| Skill | Purpose |
|---|---|
| [`nahj/`](skills/nahj/) | Multi-agent pipeline (نهج, "method") that picks open GitHub issues by label, implements them in parallel git worktrees with project-appropriate isolation, polishes each via a reviewer pass, and merges back to the project's default branch with tests + migrations between merges. Caches a project profile on first run so subsequent runs are zero-prompt. Invoke via `/nahj`. |

### nahj — first-run setup

`nahj` orchestrates four teammate agents (`nahj-planner`, `nahj-implementer`, `nahj-reviewer`, `nahj-merger`) and stores a per-project profile under `.nahj/profile.yaml`. After `npx skills add`, the orchestrator handles both on first invocation:

1. **Agents** — copies `skills/nahj/agents/nahj-*.md` to your `.claude/agents/` directory (project- or user-scoped). Compares versions on subsequent runs and prompts to update if newer copies exist.
2. **Profile** — runs `scripts/detect-profile.sh` to draft `.nahj/profile.yaml`, then asks you to confirm/fill `TODO` fields once. Committed by default so your team shares the same setup; can be gitignored if you prefer per-developer config.

You can invoke either step manually if you want to seed things ahead of time:

```bash
bash skills/nahj/scripts/install-agents.sh           # project-scoped agents
bash skills/nahj/scripts/install-agents.sh --global  # user-scoped agents
bash skills/nahj/scripts/detect-profile.sh > .nahj/profile.yaml
```

## Layout

Each skill is a directory under `skills/` with at minimum a `SKILL.md` (frontmatter + instructions). Larger skills split detail into sibling files (`PROCEDURE.md`, `TROUBLESHOOTING.md`, `NOTES.md`) so the always-loaded `SKILL.md` stays under ~100 lines. Skills that ship companion artifacts (agents, utility scripts) include them under `agents/` and `scripts/` subdirs.

```
skills/
└── <skill-name>/
    ├── SKILL.md           # required — frontmatter + main instructions
    ├── PROCEDURE.md       # optional — long step-by-step bodies
    ├── TROUBLESHOOTING.md # optional — failure modes
    ├── NOTES.md           # optional — background, timing, guardrails
    ├── agents/            # optional — companion agent definitions
    └── scripts/           # optional — utility scripts the skill invokes
```
