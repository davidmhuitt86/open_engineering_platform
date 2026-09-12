# Diagram Studio — Human Tester Start Guide

Read this before you touch the application. It tells you what this test is, how to begin, and how to record what you find. It does **not** require any knowledge of how Diagram Studio is built.

## What this test is

You are testing the **product**, not the developer. The question this test answers is: *"Can a real person use Diagram Studio as an engineering tool?"* You are not being asked to confirm that the code is correct — you're being asked to describe what actually happens when you use it, from your own point of view, as if you'd never seen the source code (because you shouldn't look at it).

The recommended way to actually run the test is the interactive tool: [diagram-studio-human-acceptance-test.html](diagram-studio-human-acceptance-test.html) — see "Using the Interactive HTML Test Form" below. The practical checklist it's built from is [DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md](DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md); if you want the full explanation behind any step, the master document is [DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md](DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md).

## Using the Interactive HTML Test Form

`diagram-studio-human-acceptance-test.html` is a standalone tool — no internet connection, no install, nothing else needed. It runs entirely in your browser.

1. Double-click `diagram-studio-human-acceptance-test.html` (in this same folder) to open it in your default browser.
2. Fill in the **Tester information** panel at the top (tester, date, build, commit, OS, display, input device, test document).
3. Open Diagram Studio **separately**, in its own window, side by side with this tool.
4. Work through **Sections A–U** using the sidebar to jump between them. Each row has a **Result** dropdown (starts at `UNTESTED`) and a **Notes** field — set the result and type what you saw as you go.
5. Record each result the moment you observe it, not from memory afterward.
6. Use the **+ Quick note** button (top toolbar) any time something's worth flagging but you don't want to stop and fill out a full issue — it remembers which section/test you were on automatically. Quick notes land in the **Observations** list.
7. Use **+ Add issue** (in the Issues section, or the "+ Create P1 issue" button that appears automatically if Section N detects a lifecycle mismatch) for anything that's a real defect. The Issue ID is generated for you based on the type you pick (e.g. `BUG-001`, `UX-002`).
8. Use **+ Add suggestion** (in the Suggestions section) for ideas that aren't defects.
9. The tool autosaves to your browser as you type (watch the "Saved …" status next to the toolbar buttons) — you don't need to do anything to save, but use **Export JSON** periodically anyway for a portable backup. If you close the browser and come back later, it will offer to restore your session.
10. Complete the **Final scorecard** and **Release readiness checklist** sections at the bottom when you're done.
11. When the session is complete, use **Export JSON** (a full backup you or a developer can re-import later), **Export Markdown** (a developer-readable report), and/or **Export HTML report** (a clean, printable summary) — do all three if you're not sure which will be wanted.

## Test environment record

Fill this in before you start:
```
Tester:
Date:
Build:                (e.g. Windows debug build, commit below)
Commit:
Windows version:
Display:
Input device:
Test document:         samples/diagram7.json  (see "Which diagram to use" below)
```

## How to launch the build

1. From a terminal, in the repository root, run the app (or use whatever pre-built `.exe` you were given — ask if unsure which to use):
   ```
   cd platform/oep_studio
   flutter run -d windows --debug
   ```
2. Wait for the application window to appear.

## Which diagram to use

Use **`platform/oep_studio/samples/diagram7.json`** — this is the fullest real TRX300 vehicle sample (titled "TRX300", 47 modules) and the same file the project's own existing automated acceptance test treats as the primary real-world fixture. (There is also a smaller `samples/trx300.json` with the same title but fewer modules — don't use that one unless a specific test step asks you to.)

To open it: from the Home screen, open **Diagram Studio** (under Available Studios), then use the toolbar's **FILE** menu → **Open**, and browse to `platform/oep_studio/samples/diagram7.json`.

## How to record results

Every test row starts as **UNTESTED**. For every numbered step, set its dropdown to:
- **PASS** if it worked as you'd expect.
- **FAIL** if it didn't.
- **BLOCKED** if you couldn't complete it (something else stopped you — a crash, a missing prerequisite, unclear how to proceed).
- **N/A** if the step doesn't apply to what you're looking at.

Nothing is ever marked PASS automatically — only you, by selecting it, decide a result. The progress bar and counts at the top update live as you go, and the sidebar marks each section untested / in progress / complete / has-failures so you can always see what's left.

## How to record a bug

Click **+ Add issue**. You do not need to explain *why* something is broken — only *what happened*, *what you expected instead*, and whether you can make it happen again. A developer will investigate the cause later. The issue gets an ID automatically based on the type you pick.

## How to record something that's confusing — even if it works correctly

This matters as much as bugs. If a control technically does the right thing but you weren't sure what it would do before clicking it, or the result left you unsure what just happened, use **+ Quick note** (type: UX) or just say so in the row's own Notes field — you can still mark the row PASS. Don't wait for something to be "broken" before recording it.

## How to record a suggestion

If you think of a better way something could work, use **+ Add suggestion**, not an issue. Suggestions and defects are tracked separately on purpose — an idea for improvement isn't a failure.

## How to capture a screenshot

Use your normal Windows screenshot tool (Win+Shift+S, or the Snipping Tool), save it somewhere you'll remember, and reference its filename in the issue's **Screenshot / evidence reference** field (e.g. `IMG_0042.png`, or just `desktop capture 21:14`) whenever: a bug occurs, the UI is confusing, something renders incorrectly, an error appears, an unexpected state appears, or a written suggestion depends on seeing the screen. You don't need to embed the image anywhere — a filename/description reference is enough.

## How to record the WebView lifecycle ID (Section N)

This is a specific, important technical check, but it doesn't require understanding *why* it matters — just how to read one number.

1. Launch the app from a terminal (as above) so you can see its console output.
2. Look for lines like:
   ```
   [V2-WEBVIEW] CREATE lifecycle=1 instance=workspace-tab-diagram
   [V2-WEBVIEW] INIT lifecycle=1 instance=workspace-tab-diagram
   [V2-WEBVIEW] LOAD lifecycle=1 instance=workspace-tab-diagram
   ```
   The number after `lifecycle=` on the line ending `instance=workspace-tab-diagram` is the **Primary lifecycle ID**. Write it down.
3. A line with `instance=compare` instead is the **Compare** WebView (used by the "Compare Diagrams" feature) — it's expected to appear/disappear on its own and is **not** what you're tracking here. Only watch the `instance=workspace-tab-diagram` lines.
4. After each step in Section N (open Trace, close Trace, open DMM, add a module, etc.), check the console again and type the Primary lifecycle ID into that step's field in the tool.
5. **It should never change.** The tool compares every value you enter automatically — if it spots a difference, it shows a warning banner right there in Section N with a **+ Create P1 issue** button that pre-fills the old ID, the new ID, and the operation for you. The tool will never decide this is a bug on its own — you decide, by actually clicking that button (or not). Take a screenshot of the console showing the change either way.

## What NOT to do during the test

- Don't look at the application source code.
- Don't ask the developer how something works before you've tried it yourself.
- Don't assume a control exists or is supposed to work a particular way — test what's actually there.
- Don't excuse confusing behavior because you assume "it's probably technically correct."
- Don't fix anything yourself, and don't wait for someone else to fix something before continuing — record it and move on unless the app is genuinely unusable.
- For the First-Time-User test (Section S) specifically: if you're the one being tested there, you should be given only the single sentence in that section and nothing else. If you're running that test on someone else, don't explain any toolbar buttons, don't say "try Trace," and don't hint. Just watch and write down what they do.

## In your own words

- "If something doesn't work, record it."
- "If something works but is confusing, record it."
- "If you expected something different, record it."
- "If you can't find a feature, record that."
- "If you think the interface could be better, record it as a suggestion."
- "You are not expected to diagnose the cause."
- "You are not expected to know whether something is technically correct."
- "Your job is to describe what happened, from your own perspective."

That's it — open the form and begin with Section A.
