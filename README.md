# Claude Skills

A collection of reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for enhancing AI-assisted development workflows.

Created by [Tech Tavern](https://github.com/TechTavern).

## Available Skills

| Skill | Description |
|-------|-------------|
| [project-audit](./project-audit/SKILL.md) | Systematic security and orientation audit for unfamiliar codebases. Checks for malicious install scripts, supply chain risks, environment compatibility, and project structure before you run anything. |

## Installation

Claude Code skills are Markdown files that live in a `.claude/skills/` directory. You can install these skills globally (available in all projects) or per-project.

### Global Installation (Recommended)

Global skills are available across all your Claude Code projects.

```bash
# Create the global skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Clone this repo into your global skills directory
git clone https://github.com/TechTavern/claude-skills.git ~/.claude/skills/claude-skills
```

**Important:** Claude Code only discovers skills in **direct subdirectories** of `~/.claude/skills/` — it does not recurse into nested directories. Run the setup script to create symlinks and register any Claude Code hooks:

```bash
~/.claude/skills/claude-skills/setup.sh
```

The script is idempotent — safe to re-run after pulling new skills. Restart Claude Code afterward.

### Per-Project Installation

To add skills to a specific project, clone into the project's `.claude/skills/` directory.

```bash
cd /path/to/your/project

# Create the project skills directory if it doesn't exist
mkdir -p .claude/skills

# Clone this repo into the project skills directory
git clone https://github.com/TechTavern/claude-skills.git .claude/skills/claude-skills
```

If you go this route, consider adding `.claude/skills/claude-skills/` to your `.gitignore` to avoid nesting repos.

As with global installation, run the setup script:

```bash
.claude/skills/claude-skills/setup.sh
```

### Updating

To pull the latest skills:

```bash
# Global
cd ~/.claude/skills/claude-skills && git pull

# Per-project
cd /path/to/your/project/.claude/skills/claude-skills && git pull
```

## Usage

Once installed, Claude Code automatically discovers skills based on their trigger descriptions. You don't need to do anything special — just use Claude Code as normal and it will invoke the relevant skill when the situation matches.

For example, the **project-audit** skill triggers when you open a newly cloned or unfamiliar project, or when you ask something like "is this safe to run?"

You can also reference a skill directly by name in your prompt (e.g., "run the project-audit skill on this repo").

## Contributing

Contributions are welcome! If you have a skill you'd like to add, please open a pull request.

Each skill should:
- Live in its own directory (e.g., `my-skill/`)
- Contain a `SKILL.md` file with valid frontmatter (`name` and `description` fields)
- Include a clear description of when the skill should and shouldn't trigger
- Be general-purpose enough to be useful across different projects

## License

MIT License — see [LICENSE](./LICENSE) for details.

If you use these skills, please credit [Tech Tavern](https://github.com/TechTavern) as the original creator.
