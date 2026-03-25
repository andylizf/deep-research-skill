---
name: deep-research-skill
description: Execute OpenAI Deep Research via ChatGPT browser GUI. Uses playwright-cli to operate a real browser, navigates ChatGPT's Deep Research mode, and returns the full research report. Use when the user says "/deep-research" followed by a research topic or question.
---

# Deep Research via ChatGPT GUI

You are a GUI automation sub-agent. Your job is to operate ChatGPT's Deep Research
through a real browser and return the research report to the user.

## Last verified

- **Date:** 2026-03-25
- **ChatGPT version:** ChatGPT web (chatgpt.com), free + Plus tiers
- **Browser:** Chrome 146.0.7680.164 (macOS, headed via playwright-cli)
- **playwright-cli:** v1.59.0-alpha (locally installed + patched at `~/.deep-research/`)
- **Key UI landmarks observed:**
  - Sidebar: "Deep research" link → `/deep-research`
  - Deep Research page placeholder: "Ask a complex question. Get a full report, with sources."
  - Send button: `button "Send prompt"` (testid: `send-button`)
  - After submit: plan with countdown ("Plan starts in N seconds"), `button "Start"`
  - During research: `"Researching..."` text, `button "Stop research"`
  - On completion: `"Research completed in Nm"`, `"N sources"`, `button "Export"` (inside iframe)
  - Export menu: "Copy contents", "Export to Markdown", "Export to Word", "Export to PDF"
  - Report container: nested iframe (`iframe[title="internal://deep-research"]` → `#root` iframe)
  - Login state: `button "Log in"` in sidebar + header; login modal has "Continue with Google/Apple" + email input

If the skill fails, snapshot the page and compare against these landmarks to identify
what changed. Common breakage points: selector testids renamed, DOM restructured,
Deep Research moved to a different URL, export button relocated inside/outside iframe.

## Paths

All skill files live under `~/.deep-research/`. Define this alias for all commands:

```bash
PW="$HOME/.deep-research/pw"
```

| Path | Purpose |
|------|---------|
| `~/.deep-research/playwright-cli/` | Local @playwright/cli install (patched, not global) |
| `~/.deep-research/pw` | Symlink to playwright-cli binary |
| `~/.deep-research/Chrome.app/` | APFS clone of Chrome, re-signed for DYLD injection |
| `~/.deep-research/window_suppress.dylib` | DYLD hook for zero-flash window suppression |
| `~/.deep-research/cli.config.json` | Playwright launch config |
| `~/.deep-research/browser-profile/` | Persistent Chrome profile (login state) |
| `~/.deep-research/window_alpha` | Native tool for CGS window alpha (hide/show) |

## Setup (one-time)

**Before doing anything else**, check if setup is complete:

```bash
test -x "$HOME/.deep-research/pw" \
  && test -f "$HOME/.deep-research/window_suppress.dylib" \
  && test -d "$HOME/.deep-research/Chrome.app" \
  && echo "READY" || echo "SETUP_NEEDED"
```

If SETUP_NEEDED, run the setup script (from the skill repo):

```bash
bash ~/.tmp/deep-research-skill/setup.sh
```

The script is idempotent — safe to re-run after Chrome updates or source changes.
It installs `@playwright/cli` locally (no global pollution), applies patches, clones
and re-signs Chrome, and compiles native code.

## Arguments

```
/deep-research [options] <query>
```

Options:
- `--lang <language>` — request report in a specific language (default: match query language)
- `--sites <domains>` — restrict research to specific sites (e.g. `--sites arxiv.org,scholar.google.com`)

Parse these from the user's input before starting. Everything after options is the query.

## playwright-cli Quick Reference

All commands use the named session `-s=deep`.
Shorthand: `pw` = `$PW -s=deep` (where `PW="$HOME/.deep-research/pw"`)

| Command | Purpose |
|---------|---------|
| `pw open` | Launch browser session |
| `pw goto <url>` | Navigate to URL |
| `pw snapshot` | Get page structure with element refs (e1, e2...) |
| `pw screenshot` | Take a screenshot |
| `pw click <ref>` | Click an element by ref (e.g. `e3`) |
| `pw fill <ref> "text"` | Fill an input field |
| `pw type "text"` | Type into focused element |
| `pw hover <ref>` | Hover over element |
| `pw eval "js"` | Execute JavaScript on the page |
| `pw close` | End browser session |

**Snapshots** return the accessibility tree with element references like `e1`, `e5`, `e12`.
Use these refs for subsequent click/fill/type commands. Always `snapshot` before interacting.

**Important:** In actual commands, always use the full path:
```bash
"$HOME/.deep-research/pw" -s=deep <command>
```
`pw` is just shorthand for this document's readability. Only `open` needs the extra flags
(`--headed`, `--profile`, `--config`).

## Window Control — Zero Flash

The browser runs in **headed mode** (Cloudflare blocks headless). The DYLD hook
makes the window completely invisible from the first frame, then transitions to
SIGUSR-based alpha control for ongoing hide/show.

### How It Works

**Phase 1 — Launch (zero flash):**
- `browserType.js` detects `--start-minimized` on macOS
- Uses `~/.deep-research/Chrome.app` instead of system Chrome
- Sets `DYLD_INSERT_LIBRARIES=~/.deep-research/window_suppress.dylib`
- DYLD hook creates `/tmp/.chrome-suppress-<pid>` signal file
- Every `makeKeyAndOrderFront:` call → `miniaturize:` instead (window never visible)

**Phase 2 — CDP takeover (screenshots work):**
- `crBrowser.js` runs after CDP session is established
- Deletes `/tmp/.chrome-suppress-*` signal files (disables launch suppression)
- CDP `Browser.setWindowBounds({windowState: "normal"})` — un-minimizes
- CDP `Browser.setWindowBounds({left: -9999, top: -9999})` — moves offscreen
- Window is in "normal" state → Chrome renders → screenshots work

**Phase 3 — Show/Hide (post-launch):**
- **Hide**: `kill -SIGUSR1 <chrome-pid>` → DYLD hook sets all windows `alphaValue=0`
  (window is transparent but still "on screen", Chrome keeps rendering, screenshots work)
- **Show**: `kill -SIGUSR2 <chrome-pid>` → DYLD hook sets `alphaValue=1` + CDP positions on-screen

### Window Control Script

```bash
node ~/.tmp/deep-research-skill/window-ctl.js show|hide|toggle [cdp-port]
```

- `show` — SIGUSR2 + CDP un-minimize + position at (100,100)
- `hide` — SIGUSR1 (alpha=0, screenshots still work)
- `toggle` — switch between show/hide

### Window Control Strategy

1. **Launch** → DYLD miniaturize (zero flash)
2. **CDP ready** → un-minimize + move offscreen (screenshots enabled)
3. **Auth needed** → `window-ctl.js show` so user can interact
4. **Auth done** → `window-ctl.js hide`
5. **Researching** → stays hidden, poll with snapshots
6. **Done** → extract results while hidden, then close

## State Recognition

After each `snapshot`, identify the current state from the accessibility tree:

| State | What to look for in snapshot |
|-------|------------------------------|
| `login_required` | "Log in", "Sign up" buttons; sidebar shows "Log in to get answers..." |
| `cloudflare` | "Verify you are human", challenge iframe; page title "Just a moment..." |
| `idle` | Input with placeholder "Ask anything" or "Message ChatGPT" |
| `deep_research_page` | URL is `/deep-research`; placeholder "Ask a complex question" |
| `plan_review` | "Start" button with countdown ("Plan starts in N seconds"); plan steps visible |
| `researching` | "Researching..." text; "Stop research" button visible |
| `done` | "Research completed in Nm"; "N sources"; "Copy response" / "Good response" buttons |
| `rate_limited` | "limit", "try again", usage warning |
| `error` | "Something went wrong", error banner |

## Execution Flow

### Phase 0: Launch & Check Session

```bash
PW="$HOME/.deep-research/pw"

# Launch browser — window starts hidden automatically (zero flash)
"$PW" -s=deep --headed --profile ~/.deep-research/browser-profile --config ~/.deep-research/cli.config.json open

# Navigate (happens while hidden)
"$PW" -s=deep goto https://chatgpt.com
"$PW" -s=deep snapshot
```

Note: `--headed`, `--profile`, and `--config` are only needed on `open`. Subsequent
commands only need `-s=deep` to reference the session.

Snapshot output is written to `.playwright-cli/page-*.yml` files. Read the latest
snapshot file to get the accessibility tree.

Assess state from snapshot:
- If `idle` → proceed to Phase 1
- If `login_required` or `cloudflare` → go to Auth phase
- If previous conversation visible → proceed to Phase 1 (will create new chat)

### Auth (only if needed)

1. **Click the "Log in" button** yourself — find it in snapshot (e.g. `button "Log in"`)
2. Snapshot the login page — look for "Continue with Google", "Continue with Apple",
   email input, etc.
3. **Show the browser window** so the user can see and interact:
   ```bash
   node ~/.tmp/deep-research-skill/window-ctl.js show
   ```
4. Tell user which login options are available and ask them to complete login
5. **Wait for user confirmation** — do NOT proceed until they reply
6. `"$PW" -s=deep snapshot` → verify `idle`
7. **Hide again** after auth is complete:
   ```bash
   node ~/.tmp/deep-research-skill/window-ctl.js hide
   ```

### Phase 1: New Chat

1. `"$PW" -s=deep snapshot` to find the "New chat" button or use shortcut
2. Look for a "New chat" element in the snapshot, `"$PW" -s=deep click <ref>`
3. Or try: `"$PW" -s=deep eval "document.querySelector('[data-testid=\"new-chat-button\"]')?.click()"`
4. `"$PW" -s=deep snapshot` → confirm empty conversation

### Phase 2: Navigate to Deep Research

Deep Research has a dedicated page at `chatgpt.com/deep-research`. Two approaches:

**Option A** (preferred): Look for "Deep research" link in the sidebar snapshot
```bash
"$PW" -s=deep click <deep_research_sidebar_ref>
```

**Option B** (fallback): Navigate directly
```bash
"$PW" -s=deep goto https://chatgpt.com/deep-research
```

Verify: snapshot should show URL `/deep-research` and placeholder "Ask a complex question.
Get a full report, with sources."

If Deep Research page shows upgrade prompt or is unavailable:
- Tell user: "Deep Research not available. Check your ChatGPT subscription."
- `"$PW" -s=deep close`
- Abort

### Phase 3: Configure Site Restrictions (if --sites)

If `--sites` provided:
1. Look for "Sites" or "Manage sites" in snapshot
2. If found, click and add domains
3. If not found, prepend to query: "Focus research on: {domains}."

### Phase 4: Submit Query

1. `"$PW" -s=deep snapshot` — find the textbox (placeholder "Ask a complex question")
2. Build prompt:
   - If `--lang`: prepend "Write the report in {language}."
   - Append the user's research query
3. `"$PW" -s=deep fill <input_ref> "{full_prompt}"`
4. Find "Send prompt" button in snapshot and click it
5. `"$PW" -s=deep snapshot` → should show `plan_review` or `researching`

### Phase 5: Review Plan

After submitting, ChatGPT shows a **research plan** with a countdown timer
(e.g. "Plan starts in 9 seconds"). The plan auto-starts when the timer expires.

1. **Immediately snapshot** to capture the plan steps
2. **Show the plan to the user** — list the steps ChatGPT will follow
3. **Evaluate the plan yourself**:
   - If the plan aligns with the user's query → let the countdown expire (do nothing)
   - If the plan clearly misses the point → click "Stop" / cancel and explain to user
4. **Do NOT block waiting for user approval** — the countdown is short (~10s)
   and auto-starts. The user can interrupt if they want changes.
5. Once research starts, snapshot will show "Researching..." + "Stop research" button

### Phase 5b: Handle Clarification (if any)

If ChatGPT asks a clarifying question instead of showing a plan:

1. Extract the question text from snapshot
2. **Ask the user:**
   > "ChatGPT asks: '{question}'
   >
   > How should I respond? Say 'skip' to let it decide."
3. Wait for user reply
4. If "skip" → type "Proceed with your best judgment. Be thorough and comprehensive."
5. Otherwise → type user's response verbatim
6. Find input, fill, send
7. `"$PW" -s=deep snapshot` → confirm `researching`

### Phase 6: Wait for Completion

Typical duration: **5-20 minutes**. Poll every 60 seconds.

```
elapsed = 0
while elapsed < 1800:  # 30 min max
    sleep 60
    elapsed += 60
    snapshot = "$PW" -s=deep snapshot

    # Check for "Stop research" button → still researching
    if snapshot contains "Stop research":
        if elapsed % 120 == 0:  # every 2 min
            tell user: "Still researching... {elapsed/60} minutes elapsed."
        continue

    # Check for "Copy response" / "Good response" → done
    if snapshot contains "Copy response" or "Good response":
        go to Phase 7

    # Check for errors
    if snapshot contains "Something went wrong" or rate limit text:
        show browser window
        tell user what happened
        abort

tell user: "Deep Research timed out after 30 minutes."
try to extract partial results
```

The browser stays hidden during polling. Snapshots work fine while hidden.

### Phase 7: Extract Results

The report is inside an **iframe**. ChatGPT provides built-in export buttons.

**Step 1: Export to Markdown** (gets a clean .md file with full content)
1. `"$PW" -s=deep snapshot` — find `button "Export"` inside the iframe
2. `"$PW" -s=deep click <export_ref>` — opens export menu
3. Snapshot again — find `button "Export to Markdown"`, click it
4. The file downloads to `.playwright-cli/deep-research-report.md`
5. Read the downloaded file — this is the cleanest extraction method

**Step 2: Copy contents** (copies to clipboard as backup)
1. Click `button "Export"` again to reopen menu
2. Snapshot — find `button "Copy contents"`, click it
3. Content is now in the system clipboard

**Other export formats available:**
- `button "Export to Word"` — downloads .docx
- `button "Export to PDF"` — downloads .pdf
- `button "Copy table"` — copies just the comparison table

**Note:** Refs change after each interaction. Always snapshot before clicking.

**Fallback** (if Export buttons are not found):
- Parse the snapshot YAML directly — the accessibility tree contains full report text
- Or use `"$PW" -s=deep screenshot` + vision extraction

### Phase 8: Return Results

1. Read the downloaded markdown file (`.playwright-cli/deep-research-report.md`)
2. Clean up artifacts: remove `citeturn...` citation markers, `entity[...]` tags,
   `image_group{...}` blocks
3. Include the metadata line (e.g. "Research completed in 17m, 46 sources, 186 searches")
4. Present the clean report to the user
5. Close the browser session:
   ```bash
   "$PW" -s=deep close
   ```

## Error Handling

| Scenario | Action |
|----------|--------|
| playwright-cli not found | Run setup steps, abort |
| Chrome.app / dylib missing | Run setup steps 2-3, abort |
| Login needed | Click "Log in" button, `window-ctl.js show`, tell user to enter credentials |
| Captcha / Cloudflare | `window-ctl.js show` → tell user to solve → wait |
| Rate limited | Return error with details |
| Network error | Wait 10s, retry `goto` once, then abort |
| Timeout (30min) | Extract partial results if any, note timeout |
| Plan misaligned | Cancel research, explain to user, adjust query |
| Snapshot ref stale | Take new snapshot — refs change after page updates |
| Unknown state | `screenshot` + describe to user, ask how to proceed |
| Browser crashed | Tell user, suggest re-running |
| Chrome updated | Re-run setup Step 2 (APFS clone + re-sign) |

## Important Rules

- **Never enter credentials.** Only the user handles login.
- **Keep window hidden.** Use `window-ctl.js hide` after page loads; `window-ctl.js show`
  only when user interaction is needed (auth, clarification).
- **Use named session** (`-s=deep`) so the session persists across commands.
- **Use local playwright-cli** — always `"$HOME/.deep-research/pw"`,
  never the global `playwright-cli`.
- **Prefer `snapshot` over `screenshot`.** Snapshots are structured text — cheaper,
  faster, and give you element refs. Snapshots work while window is hidden.
- **Be patient.** Deep Research takes 5-30 minutes. Update user every 2 minutes.
- **Preserve session.** Close tabs, not the browser. Cookies persist for next use.
