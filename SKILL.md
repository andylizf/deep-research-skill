---
name: deep-research-skill
description: Execute OpenAI Deep Research via ChatGPT browser GUI. Uses web-plane to operate a real browser, navigates ChatGPT's Deep Research mode, and returns the full research report. Use when the user says "/deep-research" followed by a research topic or question.
---

# Deep Research via ChatGPT GUI

You are a GUI automation sub-agent. Your job is to operate ChatGPT's Deep Research
through a real browser and return the research report to the user.

## Last verified

- **Date:** 2026-03-25
- **ChatGPT version:** ChatGPT web (chatgpt.com), free + Plus tiers
- **Browser:** Chrome 146.0.7680.164 (macOS, headed via web-plane)
- **web-plane:** v0.1.0 (wraps @playwright/cli@0.1.1, real Chrome, zero-flash)
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

## Setup (one-time)

**Before doing anything else**, check if web-plane is installed:

```bash
which web-plane && web-plane status && echo "READY" || echo "SETUP_NEEDED"
```

If SETUP_NEEDED:

```bash
npm install -g web-plane
web-plane install
```

## Arguments

```
/deep-research [options] <query>
```

Options:
- `--lang <language>` — request report in a specific language (default: match query language)
- `--sites <domains>` — restrict research to specific sites (e.g. `--sites arxiv.org,scholar.google.com`)

Parse these from the user's input before starting. Everything after options is the query.

## web-plane Quick Reference

All commands use the named session `-s=deep`.
Shorthand: `wp` = `web-plane -s=deep`

| Command | Purpose |
|---------|---------|
| `wp open <url>` | Launch browser + navigate (zero flash, auto --headed/--profile/--config) |
| `wp goto <url>` | Navigate to URL |
| `wp snapshot` | Get page structure with element refs (e1, e2...) |
| `wp screenshot` | Take a screenshot |
| `wp click <ref>` | Click an element by ref (e.g. `e3`) |
| `wp fill <ref> "text"` | Fill an input field |
| `wp type "text"` | Type into focused element |
| `wp hover <ref>` | Hover over element |
| `wp eval "js"` | Execute JavaScript on the page |
| `wp close` | End browser session |
| `web-plane show` | Show browser window (for auth) |
| `web-plane hide` | Hide browser window (screenshots still work) |
| `web-plane toggle` | Toggle window visibility |
| `web-plane status` | Check browser status |

**Snapshots** return the accessibility tree with element references like `e1`, `e5`, `e12`.
Use these refs for subsequent click/fill/type commands. Always `snapshot` before interacting.

**Important:** In actual commands, always use the full form:
```bash
web-plane -s=deep <command>
```
`wp` is just shorthand for this document's readability.

## Window Control — Zero Flash

web-plane handles all window management automatically:

- **Launch:** `web-plane open` starts Chrome with zero flash (DYLD hook suppresses window)
- **Hidden by default:** After CDP connects, window moves offscreen (screenshots work)
- **Show:** `web-plane show` makes window visible (for user auth)
- **Hide:** `web-plane hide` makes window transparent (screenshots still work)

### Window Control Strategy

1. **Launch** → zero flash (automatic)
2. **Auth needed** → `web-plane show` so user can interact
3. **Auth done** → `web-plane hide`
4. **Researching** → stays hidden, poll with snapshots
5. **Done** → extract results while hidden, then close

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
# Launch browser — window starts hidden automatically (zero flash)
web-plane -s=deep open https://chatgpt.com

# Snapshot to assess state
web-plane -s=deep snapshot
```

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
   web-plane show
   ```
4. Tell user which login options are available and ask them to complete login
5. **Wait for user confirmation** — do NOT proceed until they reply
6. `web-plane -s=deep snapshot` → verify `idle`
7. **Hide again** after auth is complete:
   ```bash
   web-plane hide
   ```

### Phase 1: New Chat

1. `web-plane -s=deep snapshot` to find the "New chat" button or use shortcut
2. Look for a "New chat" element in the snapshot, `web-plane -s=deep click <ref>`
3. Or try: `web-plane -s=deep eval "document.querySelector('[data-testid=\"new-chat-button\"]')?.click()"`
4. `web-plane -s=deep snapshot` → confirm empty conversation

### Phase 2: Navigate to Deep Research

Deep Research has a dedicated page at `chatgpt.com/deep-research`. Two approaches:

**Option A** (preferred): Look for "Deep research" link in the sidebar snapshot
```bash
web-plane -s=deep click <deep_research_sidebar_ref>
```

**Option B** (fallback): Navigate directly
```bash
web-plane -s=deep goto https://chatgpt.com/deep-research
```

Verify: snapshot should show URL `/deep-research` and placeholder "Ask a complex question.
Get a full report, with sources."

If Deep Research page shows upgrade prompt or is unavailable:
- Tell user: "Deep Research not available. Check your ChatGPT subscription."
- `web-plane -s=deep close`
- Abort

### Phase 3: Configure Site Restrictions (if --sites)

If `--sites` provided:
1. Look for "Sites" or "Manage sites" in snapshot
2. If found, click and add domains
3. If not found, prepend to query: "Focus research on: {domains}."

### Phase 4: Submit Query

1. `web-plane -s=deep snapshot` — find the textbox (placeholder "Ask a complex question")
2. Build prompt:
   - If `--lang`: prepend "Write the report in {language}."
   - Append the user's research query
3. `web-plane -s=deep fill <input_ref> "{full_prompt}"`
4. Find "Send prompt" button in snapshot and click it
5. `web-plane -s=deep snapshot` → should show `plan_review` or `researching`

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
7. `web-plane -s=deep snapshot` → confirm `researching`

### Phase 6: Wait for Completion

Typical duration: **5-20 minutes**. Poll every 60 seconds.

```
elapsed = 0
while elapsed < 1800:  # 30 min max
    sleep 60
    elapsed += 60
    snapshot = web-plane -s=deep snapshot

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
        web-plane show
        tell user what happened
        abort

tell user: "Deep Research timed out after 30 minutes."
try to extract partial results
```

The browser stays hidden during polling. Snapshots work fine while hidden.

### Phase 7: Extract Results

The report is inside an **iframe**. ChatGPT provides built-in export buttons.

**Step 1: Export to Markdown** (gets a clean .md file with full content)
1. `web-plane -s=deep snapshot` — find `button "Export"` inside the iframe
2. `web-plane -s=deep click <export_ref>` — opens export menu
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
- Or use `web-plane -s=deep screenshot` + vision extraction

### Phase 8: Return Results

1. Read the downloaded markdown file (`.playwright-cli/deep-research-report.md`)
2. Clean up artifacts: remove `citeturn...` citation markers, `entity[...]` tags,
   `image_group{...}` blocks
3. Include the metadata line (e.g. "Research completed in 17m, 46 sources, 186 searches")
4. Present the clean report to the user
5. Close the browser session:
   ```bash
   web-plane -s=deep close
   ```

## Error Handling

| Scenario | Action |
|----------|--------|
| web-plane not found | `npm install -g web-plane && web-plane install`, abort |
| Login needed | Click "Log in" button, `web-plane show`, tell user to enter credentials |
| Captcha / Cloudflare | `web-plane show` → tell user to solve → wait |
| Rate limited | Return error with details |
| Network error | Wait 10s, retry `goto` once, then abort |
| Timeout (30min) | Extract partial results if any, note timeout |
| Plan misaligned | Cancel research, explain to user, adjust query |
| Snapshot ref stale | Take new snapshot — refs change after page updates |
| Unknown state | `screenshot` + describe to user, ask how to proceed |
| Browser crashed | Tell user, suggest re-running |
| Chrome updated | `web-plane install` (re-clones and re-signs Chrome) |

## Important Rules

- **Never enter credentials.** Only the user handles login.
- **Keep window hidden.** Use `web-plane hide` after page loads; `web-plane show`
  only when user interaction is needed (auth, clarification).
- **Use named session** (`-s=deep`) so the session persists across commands.
- **Prefer `snapshot` over `screenshot`.** Snapshots are structured text — cheaper,
  faster, and give you element refs. Snapshots work while window is hidden.
- **Be patient.** Deep Research takes 5-30 minutes. Update user every 2 minutes.
- **Preserve session.** Close tabs, not the browser. Cookies persist for next use.
