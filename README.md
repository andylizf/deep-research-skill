# deep-research-skill

[![CI](https://github.com/andylizf/deep-research-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/andylizf/deep-research-skill/actions/workflows/ci.yml)

A **CUI** (Computer Use Interface) that runs [ChatGPT Deep Research](https://openai.com/index/introducing-deep-research/) from Claude Code. Type `/deep-research <question>` and get a full report back.

CLI wraps functionality for humans in a terminal. CUI wraps GUI-only web products into something agents can drive. This one wraps ChatGPT's Deep Research -- all you need is a ChatGPT Plus or Pro subscription, no API keys.

## Why the web version?

OpenAI has a [Deep Research API](https://developers.openai.com/api/docs/guides/deep-research), but it's not the same thing. The API uses o3/o4-mini, bills per token, expects fully-formed prompts, and requires you to wire up data sources through the Responses API yourself. The web version runs their most powerful model, asks clarifying questions before it starts, supports site-scoping, and comes bundled with your existing ChatGPT subscription (25 queries/mo on Plus, 250 on Pro). Different model, different results.

<!-- TODO: add a GIF showing /deep-research in action -->

## Install

Paste this into Claude Code:

```
Fetch and follow the instructions at https://raw.githubusercontent.com/andylizf/deep-research-skill/main/INSTALL.md
```

Or manually:

```bash
# 1. Install web-plane (the browser layer)
npm install -g web-plane
web-plane install

# 2. Install the skill
git clone https://github.com/andylizf/deep-research-skill.git ~/.claude/skills/deep-research-skill
```

## Usage

```
/deep-research What are the latest advances in protein structure prediction?
```

```
/deep-research --lang zh --sites arxiv.org,scholar.google.com transformer architectures for time series
```

The skill opens a Chrome window you can't see, submits your query, waits 5-30 minutes, and brings back the Markdown report with sources. If you need to log in to ChatGPT, it'll pop the window up and wait for you.

## How it works

This skill uses [web-plane](https://github.com/andylizf/web-plane) as its browser layer. web-plane runs your real system Chrome (not Chrome for Testing), so Cloudflare can't tell it's automated. The browser window is invisible from the first frame via DYLD injection -- no flash, no distraction.

The skill itself is just SKILL.md: a set of instructions that tell Claude how to navigate ChatGPT's Deep Research UI, submit queries, wait for results, and extract the report.

## Requirements

- macOS
- Google Chrome
- Node.js >= 18
- Xcode Command Line Tools (`xcode-select --install`)
- ChatGPT Plus or Pro
- [web-plane](https://github.com/andylizf/web-plane) (`npm install -g web-plane`)

## Files

```
SKILL.md         # instructions Claude follows for /deep-research
INSTALL.md       # meta-install instructions for the one-liner
README.md        # this file
```

## License

MIT
