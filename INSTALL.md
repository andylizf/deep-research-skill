# Install Deep Research Skill

You are installing the **Deep Research** skill for Claude Code. Follow these steps exactly:

## Step 1: Clone the skill

```bash
git clone https://github.com/andylizf/deep-research-skill.git ~/.claude/skills/deep-research-skill
```

## Step 2: Run setup

The setup script installs all dependencies locally (no global pollution):

```bash
bash ~/.claude/skills/deep-research-skill/setup.sh
```

This will:
- Install `@playwright/cli` locally at `~/.deep-research/` and apply patches for zero-flash window management
- Create an APFS clone of Chrome and re-sign it for DYLD injection
- Compile the native window suppression hook
- Create the browser profile directory and config

## Step 3: Verify

```bash
test -f "$HOME/.deep-research/pw" && test -f "$HOME/.deep-research/window_suppress.dylib" && test -d "$HOME/.deep-research/Chrome.app" && echo "Installation successful!" || echo "Something went wrong — check the output above for errors."
```

## Step 4: Confirm to the user

Tell the user: "Deep Research skill installed! Use `/deep-research <your question>` to run a research query through ChatGPT's Deep Research. First run will require ChatGPT login."

## Requirements

This skill requires **macOS**, **Google Chrome**, **Node.js ≥ 18**, and **Xcode Command Line Tools**. If any are missing, tell the user what to install before proceeding.
