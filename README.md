# deep-research-skill

[![CI](https://github.com/andylizf/deep-research-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/andylizf/deep-research-skill/actions/workflows/ci.yml)

A Claude Code skill that runs [ChatGPT Deep Research](https://openai.com/index/introducing-deep-research/) for you. Type `/deep-research <question>` and get a full report back.

It automates the real ChatGPT web UI, so all you need is a ChatGPT Plus or Pro subscription. No API keys needed.

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
git clone https://github.com/andylizf/deep-research-skill.git ~/.claude/skills/deep-research-skill
bash ~/.claude/skills/deep-research-skill/setup.sh
```

Everything gets installed locally under `~/.deep-research/`. Nothing touches your global npm. Run `setup.sh` again after Chrome updates.

## Usage

```
/deep-research What are the latest advances in protein structure prediction?
```

```
/deep-research --lang zh --sites arxiv.org,scholar.google.com transformer architectures for time series
```

The skill opens a Chrome window you can't see, submits your query, waits 5-30 minutes, and brings back the Markdown report with sources. If you need to log in to ChatGPT, it'll pop the window up and wait for you.

## How the invisible browser works

Cloudflare blocks headless Chrome, so the browser has to run headed. But nobody wants a Chrome window jumping in their face mid-work.

We use DYLD injection to hook `NSWindow.makeKeyAndOrderFront:` inside Chrome's process and replace it with `miniaturize:`. The window never appears. Once Playwright's CDP session connects, we remove the hook, un-minimize the window, and park it offscreen so screenshots still work. For toggling visibility later (e.g. when you need to log in), we send `SIGUSR1`/`SIGUSR2` to Chrome, and the injected hook sets `NSWindow.alphaValue` to 0 or 1.

This needs a re-signed Chrome binary (the stock one has `library-validation` which blocks DYLD injection). `setup.sh` makes an APFS clone of your Chrome (~5 MB extra disk) and handles the codesigning.

## Requirements

- macOS
- Google Chrome
- Node.js >= 18
- Xcode Command Line Tools (`xcode-select --install`)
- ChatGPT Plus or Pro

## Files

```
SKILL.md                         # instructions Claude follows for /deep-research
INSTALL.md                       # meta-install instructions for the one-liner
setup.sh                         # sets up ~/.deep-research/
window_suppress.m                # the DYLD hook (Objective-C)
window_alpha.m                   # CoreGraphics alpha helper
window-ctl.js                    # show/hide/toggle the browser window
start-minimized-*.patch          # two patches for playwright-core
```

## License

MIT
