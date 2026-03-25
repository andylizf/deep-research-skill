# Install Deep Research Skill

You are installing the **Deep Research** skill for Claude Code. Follow these steps exactly:

## Step 1: Install web-plane

```bash
npm install -g web-plane
web-plane install
```

## Step 2: Clone the skill

```bash
git clone https://github.com/andylizf/deep-research-skill.git ~/.claude/skills/deep-research-skill
```

## Step 3: Verify

```bash
which web-plane && web-plane status && echo "Installation successful!" || echo "Something went wrong — check the output above for errors."
```

## Step 4: Confirm to the user

Tell the user: "Deep Research skill installed! Use `/deep-research <your question>` to run a research query through ChatGPT's Deep Research. First run will require ChatGPT login."

## Requirements

This skill requires **macOS**, **Google Chrome**, **Node.js >= 18**, and **Xcode Command Line Tools**. If any are missing, tell the user what to install before proceeding.
