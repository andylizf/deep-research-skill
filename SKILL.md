---
name: deep-research-skill
description: Run OpenAI Deep Research through ChatGPT's web GUI — drives chatgpt.com in a real browser, submits the query, waits out the run, and returns the finished report. Use when the user says "/deep-research" followed by a topic, and equally when they ask for ChatGPT's Deep Research on a question without typing the command. Needs a ChatGPT Plus or Pro subscription; no API key is involved. The report comes back without its source addresses — those stay in the ChatGPT conversation.
---

# Deep Research via ChatGPT's GUI

Load the `browser` skill, attach a lane, then:

## Profile

Run `web-plane profiles` and drive a profile whose name appears in that output — never a
name you have not seen there. `-s=<unseen-name>` does not fail; it creates a fresh,
logged-out profile. That is the expensive mistake: on a logged-out
ChatGPT the obvious next control is the login modal's *Continue with Google* / *Continue with Apple*,
and if the account is not that OAuth identity the click does not fail with "no such
account" — it registers a second account, with no subscription, no history and no Deep
Research, and there is no undo. Never click an OAuth button yourself: staging the login
screen is your job, choosing on it is the human's.

## Arguments

```
/deep-research [--lang <language>] [--sites <domains>] <query>
```

`--lang` prepends `Write the report in <language>.` to the prompt; `--sites` prepends
`Focus research on: <domains>.` Everything after the options is the query.

## Attach

```bash
web-plane -s=<profile> attach --as deepresearch https://chatgpt.com/deep-research
web-plane lane deepresearch snapshot
```

Plain `attach` is enough — chatgpt.com reaches network idle in a few seconds. Go straight
to the `/deep-research` URL. Every command from here is `web-plane lane deepresearch <cmd>`.

Resuming a handed-off run attaches to the conversation URL that handoff carried, never to
`/deep-research`: that page starts a *new* run, so a clarifying answer typed there is
submitted as a fresh query against the un-clarified question.

## Submit

```bash
web-plane lane deepresearch fill <composer-ref> "<prompt>"
web-plane lane deepresearch click <send-button-ref>
```

Sending is not a commit reserved for the parent — the text is the user's own query and
the run spends a slot they asked to spend. Send it.

Snapshot after sending. What comes back is usually a research plan with a countdown of
about ten seconds, or a clarifying question. If it is neither, match the landmark table.

## The plan

The countdown auto-starts the run, so there is nothing to approve — click `button "Start"`
to skip the wait, or let it expire. If the plan misses the point, wait for the run to
begin (the control exists only then), click `button "Stop research"`, and return the plan
text and what it missed, with no report. Otherwise your return names the plan in one line
and says that it matched.

## A clarifying question

Return the question verbatim as a handoff, together with the output of `web-plane lane
deepresearch get url` — that conversation URL is the only way back to this run. Nothing
continues in this invocation. A later one attaches to that URL and sends the user's words
verbatim, or `Proceed with your best judgment. Be thorough and comprehensive.` when they
said to skip.

## Waiting

Record the wall-clock time of the first poll, then poll with the cheap probe rather than
with snapshots — thirty accessibility trees is the bulk of what this run would cost:

```bash
sleep 60
web-plane lane deepresearch eval "['Research completed in','Something went wrong','limit'].filter(s=>document.body.innerText.includes(s))"
```

That returns a few bytes. Snapshot only when it comes back non-empty, to see which of the
three fired. If 30 minutes pass with the run still going, that is a handoff and not a timeout:
the run continues in the browser, so return the conversation URL, the profile and the
lane, and say it is still running. There is nothing to extract at that point — the report
frame does not exist until the run finishes.

## Extracting the report

The report is not in the page snapshot. It sits two frames down: the top document holds
`iframe[title="internal://deep-research"]`, whose document holds `iframe#root`, whose
document holds the report and its `button "Export"`. A lane snapshot stops at that
boundary, and neither a CSS selector nor `find role` reaches inside. `eval --all-frames`
does:

```bash
web-plane lane deepresearch eval --all-frames "(document.querySelector('main')||document.body).innerText"
```

Two of the three results are wanted. The report is much the longest. The frame whose `url`
is a chatgpt.com address holds the sidebar, the composer and the metadata line —
"Research completed in Nm", "N sources" — which goes into the return. The frame between
them returns nothing.

Driving that frame's Export menu to "Export to Markdown" the same way produces a cleaner
file, but where a lane-driven Chrome writes that download is **unverified**, so extract
the text.

## Cleaning the report

Write the extracted text to a file and substitute there; by hand over several thousand
words this step gets skipped with nothing in the output to show it. Three artifact
classes come out:

- citation markers of the shape `citeturn0search5` — `cite`, then one or more
  `turn<N><kind><N>` runs, `<kind>` being `search`, `news` or `view`
- `entity[...]` tags
- `image_group{...}` blocks

Each arrives wrapped in non-printing characters from U+E000–U+F8FF; remove each wrapped
run whole, delimiters and payload together. Done means no character in U+E000–U+F8FF
survives and no line contains `cite`, `entity[` or `image_group{`.

The markers are opaque tokens, not URLs, and the addresses are in neither the export nor
the frame DOM — `a[href]` inside the report frames returns no external link. So the return
says the sources stayed behind, and whoever wants them opens the conversation and clicks
the "N sources" affordance. Never hand over a stripped report as though it had never
carried citations.

## Handoffs

Login, a Cloudflare challenge, a clarifying question, a run still going at 30 minutes:
hand each back per the `browser` skill's handoff contract, naming this profile and this
lane, with the lane re-pinned so the parent's `show` raises the right tab. Run this in a
subagent, as that skill requires — a reply cannot reach you there, so never wait for one.

## Return

A completed run returns the cleaned report, the metadata line and the one line about the
plan. A stopped plan returns the plan and what it missed; a handoff returns the request
and the conversation URL. Neither of those returns a report. No snapshots, no
accessibility trees, no file dumps.

Then `web-plane lane deepresearch close`, which closes this tab and this lane's driver
and leaves the profile's Chrome and every sibling lane running. **Never
`web-plane -s=<profile> close`** — that kills the browser every other lane shares. On a
handoff close nothing: the lane is what holds the human's screen in front.

## UI landmarks (compare against these when a step cannot find its element)

| State | What is on the page | What it means here |
|---|---|---|
| Deep Research page | URL `chatgpt.com/deep-research`; "Ask a complex question. Get a full report, with sources."; composer textbox "Chat with ChatGPT"; `button "Send prompt"`, disabled until the box has text | Submit |
| Logged out | `button "Log in"` in sidebar and header; modal offers "Continue with Google" / "Continue with Apple" and an email field | Handoff |
| Cloudflare | "Verify you are human"; page title "Just a moment..." | Handoff |
| Plan review | plan steps, "Plan starts in N seconds", `button "Start"` | Read the plan |
| Researching | "Researching..." and `button "Stop research"` | Keep polling |
| Done | "Research completed in Nm", "N sources", `button "Copy response"` | Extract |
| Report frames | `iframe[title="internal://deep-research"]` → `iframe#root`; inside them `button "Export"`, `button "Expand"`, `button "Copy table"` | Where the report is |
| Export menu | "Copy contents", "Export to Markdown", "Export to Word", "Export to PDF" | Reached only through `eval --all-frames` |
| Error | "Something went wrong", or a banner over the conversation | Return the banner text; do not retry blind |
| Rate limited | a usage notice naming the limit and when it resets | Return the notice verbatim, reset time included. Do not retry — the quota is monthly |
| No Deep Research | an upgrade prompt where the composer belongs | Report what is on screen. It may be an exhausted quota rather than an absent subscription — do not diagnose the account |
