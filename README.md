# deep-research-skill

[![CI](https://github.com/andylizf/deep-research-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/andylizf/deep-research-skill/actions/workflows/ci.yml)

Use ChatGPT's [Deep Research](https://openai.com/index/introducing-deep-research/) from Claude Code. Type `/deep-research`, get a full report back.

The Deep Research API (o3/o4-mini) doesn't have the visual browser, GPT-5.2 model, or site-scoping that the ChatGPT GUI version has. This skill drives the real thing.

<!-- TODO: add a GIF showing /deep-research in action -->

## Install

Paste this into Claude Code:

```
Fetch and follow the instructions at https://raw.githubusercontent.com/andylizf/deep-research-skill/main/INSTALL.md
```

Or do it yourself:

```bash
git clone https://github.com/andylizf/deep-research-skill.git ~/.claude/skills/deep-research-skill
bash ~/.claude/skills/deep-research-skill/setup.sh
```

`setup.sh` installs everything locally under `~/.deep-research/`. Nothing goes into your global npm. Run it again after Chrome updates.

## Usage

```
/deep-research What are the latest advances in protein structure prediction?
```

```
/deep-research --lang zh --sites arxiv.org,scholar.google.com transformer architectures for time series
```

The skill opens an invisible Chrome, submits your query, waits 5-30 minutes, and brings back the full Markdown report with sources. If you need to log in to ChatGPT, it'll show you the browser window and wait.

## Why is this hard?

Cloudflare blocks headless Chrome, so the browser has to run headed. But you don't want a Chrome window popping up and stealing focus every time you run a query.

The trick: a DYLD-injected hook intercepts `NSWindow.makeKeyAndOrderFront:` inside Chrome's process and calls `miniaturize:` instead. The window never renders a single frame. After Playwright's CDP session is up, we un-minimize and move the window offscreen so screenshots work. To toggle visibility later, we send `SIGUSR1`/`SIGUSR2` to Chrome, which the hook handles by setting `NSWindow.alphaValue` to 0 or 1.

This requires a re-signed copy of Chrome (to strip `library-validation` for DYLD injection). `setup.sh` creates an APFS clone (~5 MB extra disk) and handles the signing.

## Requirements

- macOS (the window management is macOS-specific)
- Google Chrome
- Node.js >= 18
- Xcode Command Line Tools (`xcode-select --install`)
- A ChatGPT account with Deep Research access

## Files

```
SKILL.md                         # what Claude reads when you say /deep-research
INSTALL.md                       # meta-install instructions for the one-liner
setup.sh                         # sets up everything under ~/.deep-research/
window_suppress.m                # DYLD hook: zero-flash launch + SIGUSR hide/show
window_alpha.m                   # CoreGraphics alpha tool (fallback)
window-ctl.js                    # show/hide/toggle the browser window
start-minimized-*.patch          # two small patches for playwright-core
```

## License

MIT
