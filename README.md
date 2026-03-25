# Deep Research Skill for Claude Code

Run [ChatGPT Deep Research](https://openai.com/index/introducing-deep-research/) from Claude Code. The skill automates a real browser to navigate ChatGPT's Deep Research mode and returns the full report — with zero window flash on macOS.

## Install

Paste this into Claude Code:

```
Fetch and follow the instructions at https://raw.githubusercontent.com/andylizf/deep-research-skill/main/INSTALL.md
```

Or install manually:

```bash
git clone https://github.com/andylizf/deep-research-skill.git ~/.claude/skills/deep-research-skill
bash ~/.claude/skills/deep-research-skill/setup.sh
```

## Usage

```
/deep-research What are the latest advances in protein structure prediction?
```

Options:
- `--lang <language>` — request report in a specific language
- `--sites <domains>` — restrict to specific sites (e.g. `--sites arxiv.org,scholar.google.com`)

## What It Does

1. Launches a headed Chrome instance (invisible — no window flash, no focus steal)
2. Navigates to ChatGPT's Deep Research page
3. Submits your query, shows the research plan
4. Polls until research completes (5–30 min), updates you every 2 minutes
5. Exports the report as Markdown and returns it to you
6. If login is needed, shows the browser window for you to authenticate

## How It Works

Cloudflare blocks headless browsers, so Deep Research requires a real headed Chrome. The skill uses a multi-phase approach to keep the window invisible:

| Phase | Mechanism | Purpose |
|-------|-----------|---------|
| Launch | DYLD injection (`window_suppress.dylib`) | Hooks `NSWindow` methods to miniaturize on creation — zero flash |
| CDP ready | Playwright patches (`crBrowser.js`) | Removes DYLD signal, un-minimizes, moves offscreen — screenshots work |
| Hide/Show | Unix signals (`SIGUSR1`/`SIGUSR2`) | Sets window alpha to 0/1 via injected hook — no permissions needed |

### Setup Details

`setup.sh` handles everything automatically:

- Installs `@playwright/cli` **locally** at `~/.deep-research/` (no global pollution) and applies two small patches
- Creates an APFS clone of Chrome and re-signs the binary (removes `library-validation` for DYLD injection)
- Compiles the native DYLD hook from source

The Chrome clone is copy-on-write (~5 MB extra disk for the re-signed binary). Re-run `setup.sh` after Chrome updates.

## Requirements

- **macOS** (DYLD injection is macOS-specific)
- **Google Chrome** installed at `/Applications/Google Chrome.app`
- **Node.js** ≥ 18 (for playwright-cli)
- **Xcode Command Line Tools** (`xcode-select --install`) for compiling native code
- **ChatGPT account** with Deep Research access

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill instructions for Claude Code |
| `INSTALL.md` | Meta-install instructions (for one-line install) |
| `setup.sh` | One-command setup script (idempotent) |
| `window_suppress.m` | DYLD hook — miniaturize on launch + SIGUSR hide/show |
| `window_alpha.m` | CoreGraphics alpha tool (fallback) |
| `window-ctl.js` | Show/hide/toggle browser window via CDP + signals |
| `start-minimized-*.patch` | Playwright patches for zero-flash launch |

## License

MIT
