# skills

Personal collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) skills, installable with the [`skills`](https://www.npmjs.com/package/skills) CLI.

## Install

```bash
# Install all skills from this repo (interactive)
npx skills@latest add saleh-data/skills

# Install a specific skill globally for Claude Code, no prompts
npx skills@latest add saleh-data/skills --skill <skill-name> -g -a claude-code -y

# List skills in this repo without installing
npx skills@latest add saleh-data/skills --list
```

By default the CLI installs into `./.claude/skills/` (project-local). Pass `-g` to install into `~/.claude/skills/` (global).

## What's here

| Skill | Purpose |
|---|---|
| [`nahj/`](skills/nahj/README.md) | Multi-agent pipeline that picks GitHub issues by label, implements them in parallel worktrees, reviews, and merges. Invoke via `/nahj`. |

Each skill has its own `README.md` with install command and setup details.

## Layout

```
skills/
└── <skill-name>/
    ├── README.md          # skill-specific install + setup
    ├── SKILL.md           # frontmatter + main instructions
    ├── PROCEDURE.md       # step-by-step bodies
    ├── TROUBLESHOOTING.md # failure modes
    ├── NOTES.md           # background, timing, guardrails
    ├── agents/            # companion agent definitions
    └── scripts/           # utility scripts the skill invokes
```
