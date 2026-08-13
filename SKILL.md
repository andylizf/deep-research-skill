---
name: deep-research-skill
description: Execute OpenAI Deep Research via ChatGPT browser GUI. Uses web-plane to operate a real browser, navigates ChatGPT's Deep Research mode, and returns the full research report. Use when the user says "/deep-research" followed by a research topic or question.
---

# Deep Research via ChatGPT GUI

You are a GUI automation sub-agent. Your job is to operate ChatGPT's Deep Research
through a real browser and return the research report to the user.

## Run this in a subagent

Do the browser driving inside a **subagent**, not in the main conversation.

A run polls for 5-30 minutes and every poll produces an accessibility-tree snapshot —
hundreds of lines of YAML each, plus any screenshots. All of it lands in whichever
context is doing the driving, and almost none of it matters once the next snapshot
supersedes it. Drive from the main conversation and you fill it with page dumps it
will never read again; drive from a subagent and the main conversation receives the
finished report and nothing else.

So the contract for the subagent is:

- **Return conclusions, never raw material.** The extracted report and a one-line
  status. No snapshots, no accessibility trees, no `.playwright-cli/` file dumps.
- **The one thing a subagent cannot do is hand over the keyboard.** Login, a captcha,
  an OS-level block — for any of these, stop and return a *request*: what is on
  screen, exactly what the human has to do, and which session to look at. The parent
  relays it, the human acts, and the subagent picks up where it left off.

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

Every command carries the session picked in Phase 0. Throughout this document
`<profile>` is a **placeholder**: substitute the actual profile name you chose, and
use the same one in every command for the whole run.

Shorthand: `wp` = `web-plane -s=<profile>`

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
| `wp show` | Show browser window (for auth) |
| `wp hide` | Hide browser window (screenshots still work) |
| `wp toggle` | Toggle window visibility |
| `wp status` | Check browser status (PID, session, visibility) |

**Snapshots** return the accessibility tree with element references like `e1`, `e5`, `e12`.
Use these refs for subsequent click/fill/type commands. Always `snapshot` before interacting.

**Important:** In actual commands, always use the full form:
```bash
web-plane -s=<profile> <command>
```
`wp` is just shorthand for this document's readability.

**`-s` is not optional on `show`/`hide`/`status` either** — this is the one people
drop, because those commands read like they act on "the browser". They don't. With
more than one web-plane session running, an unqualified `web-plane show` picks a
browser by process order and then prints `Window shown` about *that* one, while the
session you are driving stays parked offscreen at alpha 0. You get a success message
and an invisible browser, and the cause is nowhere in the output. Recent web-plane
refuses the ambiguous case instead of guessing; older versions guess silently. Name
the session every time.

## Window Control — Zero Flash

web-plane handles all window management automatically:

- **Launch:** `wp open` starts Chrome with zero flash (DYLD hook suppresses window)
- **Hidden by default:** After CDP connects, window moves offscreen (screenshots work)
- **Show:** `wp show` makes window visible (for user auth)
- **Hide:** `wp hide` makes window transparent (screenshots still work)

### Window Control Strategy

1. **Launch** → zero flash (automatic)
2. **Auth needed** → `wp show` so user can interact
3. **Auth done** → `wp hide`
4. **Researching** → stays hidden, poll with snapshots
5. **Done** → extract results while hidden, then close

### When `show` says it worked but nothing is visible

`Window shown` is a claim, not a receipt. Two different failures produce it, and the
screen looks identical in both:

1. **You showed a different browser.** Run `web-plane -s=<profile> status` and check
   the PID against the session you are driving. This is what an unqualified
   `web-plane show` does when several sessions are running.
2. **A macOS Screen Time / parental-control block.** This one is genuinely invisible:
   the "you've reached your limit" sheet is drawn **on the Chrome window**, so while
   the window is transparent the notice is transparent too. You can see neither
   Chrome nor the reason Chrome isn't there, and every web-plane command keeps
   reporting success. A page `screenshot` cannot reveal it either — that captures the
   page, not the screen. Take a real screen grab and look at it:

   ```bash
   screencapture -x ./tmp/screen.png
   ```

   If a Screen Time sheet is on it, only the human can clear it — surface it as a
   handoff request with what you saw. Do not try to click through it.

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

### Phase 0: Pick the profile, then launch

**Never hardcode the session name.** `-s=<name>` selects a *login identity* — a Chrome
profile on disk with its own cookies — and web-plane will happily create an empty one
for any name you invent. Ask the disk which profile holds the identity instead:

```bash
web-plane profiles chatgpt.com
```

Two possible answers:

- **A profile is named** (`main (running) — chatgpt.com`) → that is your session.
- **`No profile holds a session for: chatgpt.com`** → it then lists the profiles with
  how many sites each is logged into. Take the one with the **most logins**. That is
  the user's real identity. Do *not* take one marked `(empty)`, and do *not* invent a
  new name however well it describes the task.

```
No profile holds a session for: chatgpt.com
A login is needed. Pick the identity profile you already use, not a new one:
  main  (logged into 22 site(s))     ← this one
  pton  (logged into 2 site(s))
  deep  (empty)                      ← never this one, however apt the name
```

Substitute that name for `<profile>` in every command from here on.

**Why the empty profile is the expensive mistake.** A fresh profile is a browser the
site has never seen: logged out, and a new device even after you log in. From a
logged-out ChatGPT the obvious next control is the login modal's *Continue with
Google* / *Continue with Apple* button — and if the user's ChatGPT account is not that
OAuth identity, clicking it does not fail with "no such account". It silently
**registers a brand-new account**: no history, no subscription, no Deep Research, and
no way to undo it. Never click an OAuth button, and never open a fresh profile to
"start clean".

**`profiles` under-reports, so do not read a "no" as proof.** It decides whether a
profile holds a session from a fixed list of well-known cookie names, and ChatGPT's
(`__Secure-next-auth.session-token`) is not on it — a profile that is genuinely logged
into ChatGPT still prints as holding no chatgpt.com session. So treat that answer as
"start from the user's main identity and go look", not as "a login is required". The
page is the authority; the snapshot below is what settles it.

```bash
# Launch browser — window starts hidden automatically (zero flash)
web-plane -s=<profile> open https://chatgpt.com

# Snapshot to assess state
web-plane -s=<profile> snapshot
```

Snapshot output is written to `.playwright-cli/page-*.yml` files. Read the latest
snapshot file to get the accessibility tree.

Assess state from snapshot:
- If `idle` → proceed to Phase 1
- If `login_required` or `cloudflare` → go to Auth phase
- If previous conversation visible → proceed to Phase 1 (will create new chat)

### Auth (only if needed)

Before anything else, re-check that you are on the right profile — a `login_required`
snapshot from the user's main identity means something very different (session
expired) than the same snapshot from an empty profile (wrong profile, go back to
Phase 0).

1. **Click the "Log in" button** yourself — find it in snapshot (e.g. `button "Log in"`)
2. Snapshot the login page — look for "Continue with Google", "Continue with Apple",
   email input, etc.
3. **Never click any of them.** Which identity the account uses is not visible from
   the page, and the wrong OAuth button creates a second account instead of failing.
   Staging the login screen is your job; choosing on it is the human's.
4. **Show the browser window** so the user can see and interact:
   ```bash
   web-plane -s=<profile> show
   ```
5. Tell the user which login options are on screen and ask them to complete login.
   From a subagent this is a handoff: return the request and stop, don't poll.
6. **Wait for user confirmation** — do NOT proceed until they reply
7. `web-plane -s=<profile> snapshot` → verify `idle`
8. **Hide again** after auth is complete:
   ```bash
   web-plane -s=<profile> hide
   ```

### Phase 1: New Chat

1. `web-plane -s=<profile> snapshot` to find the "New chat" button or use shortcut
2. Look for a "New chat" element in the snapshot, `web-plane -s=<profile> click <ref>`
3. Or try: `web-plane -s=<profile> eval "document.querySelector('[data-testid=\"new-chat-button\"]')?.click()"`
4. `web-plane -s=<profile> snapshot` → confirm empty conversation

### Phase 2: Navigate to Deep Research

Deep Research has a dedicated page at `chatgpt.com/deep-research`. Two approaches:

**Option A** (preferred): Look for "Deep research" link in the sidebar snapshot
```bash
web-plane -s=<profile> click <deep_research_sidebar_ref>
```

**Option B** (fallback): Navigate directly
```bash
web-plane -s=<profile> goto https://chatgpt.com/deep-research
```

Verify: snapshot should show URL `/deep-research` and placeholder "Ask a complex question.
Get a full report, with sources."

If Deep Research page shows upgrade prompt or is unavailable:
- Tell user: "Deep Research not available. Check your ChatGPT subscription."
- `web-plane -s=<profile> close`
- Abort

### Phase 3: Configure Site Restrictions (if --sites)

If `--sites` provided:
1. Look for "Sites" or "Manage sites" in snapshot
2. If found, click and add domains
3. If not found, prepend to query: "Focus research on: {domains}."

### Phase 4: Submit Query

1. `web-plane -s=<profile> snapshot` — find the textbox (placeholder "Ask a complex question")
2. Build prompt:
   - If `--lang`: prepend "Write the report in {language}."
   - Append the user's research query
3. `web-plane -s=<profile> fill <input_ref> "{full_prompt}"`
4. Find "Send prompt" button in snapshot and click it
5. `web-plane -s=<profile> snapshot` → should show `plan_review` or `researching`

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
7. `web-plane -s=<profile> snapshot` → confirm `researching`

### Phase 6: Wait for Completion

Typical duration: **5-20 minutes**. Poll every 60 seconds.

```
elapsed = 0
while elapsed < 1800:  # 30 min max
    sleep 60
    elapsed += 60
    snapshot = web-plane -s=<profile> snapshot

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
        web-plane -s=<profile> show
        tell user what happened
        abort

tell user: "Deep Research timed out after 30 minutes."
try to extract partial results
```

The browser stays hidden during polling. Snapshots work fine while hidden.

### Phase 7: Extract Results

The report is inside an **iframe**. ChatGPT provides built-in export buttons.

**Step 1: Export to Markdown** (gets a clean .md file with full content)
1. `web-plane -s=<profile> snapshot` — find `button "Export"` inside the iframe
2. `web-plane -s=<profile> click <export_ref>` — opens export menu
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
- Or use `web-plane -s=<profile> screenshot` + vision extraction

### Phase 8: Return Results

1. Read the downloaded markdown file (`.playwright-cli/deep-research-report.md`)
2. Clean up artifacts: remove `citeturn...` citation markers, `entity[...]` tags,
   `image_group{...}` blocks
3. Include the metadata line (e.g. "Research completed in 17m, 46 sources, 186 searches")
4. Present the clean report to the user
5. Close the browser session:
   ```bash
   web-plane -s=<profile> close
   ```

Running as a subagent, this is your entire return value: the cleaned report, the
metadata line, and one line of status. The snapshots, the accessibility trees, and
the `.playwright-cli/` files stay here — the parent context has no use for them and
they are the bulk of what this skill generates.

## Error Handling

| Scenario | Action |
|----------|--------|
| web-plane not found | `npm install -g web-plane && web-plane install`, abort |
| Login needed | Click "Log in" button, `wp show`, tell user to enter credentials |
| Captcha / Cloudflare | `wp show` → tell user to solve → wait |
| No profile logged into ChatGPT | Use the profile with the most logins — never an empty one, never a new name (Phase 0) |
| `wp show` succeeds, screen blank | Check the PID with `wp status`; then `screencapture -x` for a Screen Time overlay |
| "N sessions are running — say which one" | You dropped `-s=<profile>`. Add it |
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
- **Never click an OAuth button** ("Continue with Google/Apple"). On the wrong
  identity it creates a second account instead of failing.
- **Keep window hidden.** Use `wp hide` after page loads; `wp show`
  only when user interaction is needed (auth, clarification).
- **Every command carries `-s=<profile>`**, including `show`, `hide`, and `status`.
  The profile comes from Phase 0's `web-plane profiles chatgpt.com`, never from a
  name written in this document.
- **Prefer `snapshot` over `screenshot`.** Snapshots are structured text — cheaper,
  faster, and give you element refs. Snapshots work while window is hidden.
- **Be patient.** Deep Research takes 5-30 minutes. Update user every 2 minutes.
- **Preserve session.** Close tabs, not the browser. Cookies persist for next use.
