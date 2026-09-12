# Diagram Studio — Human Tester Start Guide

Read this before you touch the application. It tells you what this test is, how to begin, and how to record what you find. It does **not** require any knowledge of how Diagram Studio is built.

## What this test is

You are testing the **product**, not the developer. The question this test answers is: *"Can a real person use Diagram Studio as an engineering tool?"* You are not being asked to confirm that the code is correct — you're being asked to describe what actually happens when you use it, from your own point of view, as if you'd never seen the source code (because you shouldn't look at it).

Use the full test procedure here: [DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md](DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md) (the practical, fill-it-out-as-you-go version). If you want the full explanation behind any step, the master document is [DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md](DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md).

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

Use the fillable form. For every numbered step:
- Write **PASS** if it worked as you'd expect.
- Write **FAIL** if it didn't.
- Write **BLOCKED** if you couldn't complete it (something else stopped you — a crash, a missing prerequisite, unclear how to proceed).
- Write **N/A** if the step doesn't apply to what you're looking at.

## How to record a bug

Use the Issue Capture Template (in the form or master doc). You do not need to explain *why* something is broken — only *what happened*, *what you expected instead*, and whether you can make it happen again. A developer will investigate the cause later.

## How to record something that's confusing — even if it works correctly

This matters as much as bugs. If a control technically does the right thing but you weren't sure what it would do before clicking it, or the result left you unsure what just happened, write it down as a **UX** finding. Don't wait for something to be "broken" before recording it.

## How to record a suggestion

If you think of a better way something could work, write it in the **Tester Suggestions** table, not as a bug. Suggestions and defects are tracked separately on purpose — an idea for improvement isn't a failure.

## How to capture a screenshot

Use your normal Windows screenshot tool (Win+Shift+S, or the Snipping Tool) whenever: a bug occurs, the UI is confusing, something renders incorrectly, an error appears, an unexpected state appears, or a written suggestion depends on seeing the screen. Save the file somewhere you can reference it by name in your notes (you don't need to embed it in the document itself — a filename/description reference is enough).

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
4. After each step in Section N (open Trace, close Trace, open DMM, add a module, etc.), check the console again. Write down the Primary lifecycle ID each time.
5. **It should never change.** If it does — if a new `CREATE` line appears for `instance=workspace-tab-diagram` with a different number — that is a bug. Record it immediately as a **P1 BUG**: the operation you just did, the old ID, the new ID, and the time. Take a screenshot of the console showing it. Then continue testing if you reasonably can.

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
