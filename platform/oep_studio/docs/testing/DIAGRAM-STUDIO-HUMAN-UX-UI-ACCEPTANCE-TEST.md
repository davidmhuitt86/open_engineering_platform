# Diagram Studio — Human UX/UI Acceptance Test (Master Specification)

**PRODUCT-READINESS-015**

This is a human-run usability and engineering-workflow test for OEP Diagram Studio. It is **not** a unit test, and it is **not** a developer-only regression checklist — it is designed to be executed by a person sitting at a real Windows machine, using the real, built application, exactly as a technician, installer, engineer, or new user would.

This document is the **master specification** — the complete, authoritative test. A shorter, checkbox-style version optimized for actually filling out during a live session is [DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md](DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md). Use the form during testing; use this document as the reference when you need the full instructions for a step, the issue-classification rules, or the issue template.

No knowledge of Diagram Studio's source code, architecture, or implementation is required to run this test.

---

## How to use this document

1. Fill in the **Tester Information** block below before you start.
2. Work through the sections in order (A through U). Each numbered test step has a **Steps** description and an **Expected** result. Record **PASS / FAIL / BLOCKED / N/A** (defined below) plus notes.
3. Whenever you notice something worth flagging — a defect, confusing behavior, a slow response, a good idea, anything — capture it using the **Issue Capture Template**, even if it doesn't cleanly fit the specific test step you're on. Don't wait for a step to formally "fail" before recording something.
4. Use the **Tester Observation Log** for anything that doesn't fit a predefined test case at all.
5. Use the **Tester Suggestions** table for ideas and improvements that are not defects.
6. At the end, fill in the **Final Scorecard** and **Release Readiness** checklist.
7. Summarize everything in `PRODUCT-READINESS-015-HUMAN-UX-UI-TEST-REPORT.md`.

---

## Tester Information

```
Tester:
Date:
Build:
Commit:
Operating System:
Display resolution:
Input device:
Test environment:
Diagram/document used:

Experience level (optional): New user / Technician / Installer / Engineer / Developer / Other
```

---

## Test Result Vocabulary

Every test step is recorded using exactly one of these four results:

| Result | Meaning |
|---|---|
| **PASS** | The behavior worked as expected. |
| **FAIL** | The behavior did not meet the expected result. |
| **BLOCKED** | The test could not reasonably be completed because another defect, a missing prerequisite, a crash, unavailable data, or an environment issue prevented execution. |
| **N/A** | The test does not apply to the current environment or test scenario. |

If you are ever unsure whether something is a FAIL or just confusing/suboptimal, record it anyway (as a FAIL, or as a PASS with an issue noted) — see the philosophy note at the end of this document. Do not suppress a finding because you're unsure how to categorize it.

---

## Issue Classification

Every issue you capture is classified using **one** of the following. Not everything is a BUG — a feature that works correctly but is confusing to use is a **UX** finding, not a BUG.

| Classification | Use it for |
|---|---|
| **BUG** | The software does something incorrect: crashes, wrong output, broken function, data corruption. |
| **UX** | The feature works, but a reasonable user would be confused, misled, or slowed down by how it works. |
| **UI** | A visual/interaction element is wrong, inconsistent, or poorly presented (independent of whether the underlying function works). |
| **USABILITY** | Broader friction in accomplishing a real task — more than one UI/UX issue combined, or a workflow that's technically usable but painful. |
| **PERFORMANCE** | Something is slower than a user would reasonably expect. |
| **DATA/PERSISTENCE** | Something is lost, corrupted, or not saved/restored correctly. |
| **NAVIGATION** | Difficulty finding, reaching, or returning to a place, tab, object, or feature. |
| **ACCESSIBILITY** | Difficulty for a user relying on assistive technology, keyboard-only use, low vision, color perception, etc. |
| **VISUAL** | Purely cosmetic rendering issues (misalignment, clipping, wrong color, font issues) with no functional impact. |
| **ENGINEERING LOGIC** | The electrical/engineering result itself appears incorrect or cannot be trusted, independent of the UI presenting it. |
| **DOCUMENTATION** | Something is undocumented, mislabeled, or the in-app terminology/help text is wrong or missing. |
| **FEATURE REQUEST** | A capability that does not exist today and is being requested. |
| **SUGGESTION** | An idea for improvement that isn't a defect or a request for new functionality — a smaller tweak. |

---

## Severity

| Severity | Meaning |
|---|---|
| **P0 — BLOCKER** | The application cannot be meaningfully used, or the test cannot continue at all. |
| **P1 — CRITICAL** | A major workflow is broken, data loss is possible, behavior is seriously incorrect, or an engineering result cannot be trusted. |
| **P2 — MAJOR** | An important workflow is degraded, or there is a substantial UX/UI problem. |
| **P3 — MINOR** | A localized defect or inconvenience. |
| **P4 — COSMETIC / ENHANCEMENT** | Visual polish, wording, spacing, or a minor improvement. |
| **SUGGESTION** | Not a defect — an idea, not scored by severity. |

---

## Issue Capture Template

Use this for every issue. Copy the block below as many times as needed (also duplicated in the fillable form). You do **not** need to know any implementation detail to fill this out — describe only what you observed.

```
Issue ID:
Date:
Tester:
Test Section:
Test Case:
Step:
Classification:
Severity:
Title:

What happened:

Expected behavior:

Actual behavior:

Can it be reproduced?  YES / NO / UNKNOWN

Reproduction steps:

Impact:

Suggested improvement:

Screenshot / evidence:

Additional notes:
```

**Quick-capture shorthand** — if you need to jot something down mid-workflow without stopping to fill out the full template, use:

```
Issue: __________________________________________
(Step: _____   Type: _____   Severity: _____)
```

...and expand it into the full template afterward, before ending the session.

---

## Section-end Issue Log

At the end of every lettered section (A, B, C, ...) below, keep a small running log in this shape:

| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|
| | | | | | Open |

This is a summary index, not a replacement for the full Issue Capture Template — every row here should correspond to one fully-filled-out issue entry elsewhere.

---

# PART 2 — TEST SECTIONS

Test **workflows**, not just buttons. For every step: perform the action, observe the actual result, compare to the expected result, and record PASS/FAIL/BLOCKED/N/A plus any issues.

## Section A — Application Startup

**A-001 — Launch Diagram Studio**
Steps: Start the application from a fresh launch.
Observe: startup time; the initial screen; branding; visual hierarchy; whether it's clear what to do next.
Record: PASS/FAIL, notes, suggestions.

**A-002 — Launch with no Diagram document open**
Steps: From the initial screen, without any prior guidance, determine: what you're looking at; how to open or create a Diagram; where previous work can be found; what the major capabilities of the app are.
Do not assume prior knowledge of the app's architecture — if something isn't obvious from the screen itself, that's a valid finding.

**A-003 — Close and relaunch**
Steps: Close the application entirely, then relaunch it.
Observe: crashes; stale state; unexpected document reopening; UI corruption; whether the startup experience is consistent with A-001/A-002.

### Section A Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|
| | | | | | |

---

## Section B — Workspace / Tabs

**B-001** Open a Diagram.
**B-002** Open a second, different Diagram.
**B-003** Switch between the two Diagram tabs.
**B-004** Return to the original Diagram.
**B-005** For each Diagram, confirm it retained: visual state (pan/zoom), selection, edits, panel state where appropriate, WebView state, and document state.
**B-006** Open and close one or more additional Studio surfaces (e.g. Search, Objects, Settings — whatever is available) alongside the Diagram tabs.
**B-007** Close a Diagram tab.
**B-008** Reopen that Diagram.

Overall: does this feel like a normal desktop engineering application's tab behavior? Record confusion and friction, not only outright bugs.

### Section B Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|
| | | | | | |

---

## Section C — Primary Diagram Interaction

Using the TRX300 diagram:

**C-001** Pan the diagram.
**C-002** Zoom in.
**C-003** Zoom out.
**C-004** Use Fit/Center if available.
**C-005** Select a module.
**C-006** Select a wire.
**C-007** Click empty space.
**C-008** Move a module.
**C-009** Move several modules.
**C-010** Is the visual result predictable each time?
**C-011** Is a selected object obviously selected (visually)?
**C-012** Is it obvious how to deselect?

### Section C Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section D — Adding / Editing Engineering Objects

**D-001** Open ADD.
**D-002** Do the available categories make sense to a first-time user?
**D-003** Add a module.
**D-004** Move the module.
**D-005** Edit its properties.
**D-006** Change its label, if supported.
**D-007** Delete/remove it, if supported.
**D-008** Undo, if supported.
**D-009** Repeat the workflow once more.

**Specifically observe whether adding/editing an object causes the primary Legacy V2 WebView to reload** (a full page flash/reload, not just a redraw). If diagnostics are available (see Section N), record the PR-014 primary lifecycle ID before and after this section.

### Section D Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section E — Wire Creation / Routing

**E-001** Create a wire.
**E-002** Connect two valid terminals.
**E-003** Attempt an invalid connection.
**E-004** Select a wire.
**E-005** Move/edit the wire.
**E-006** Adjust its route.
**E-007** Reset its route.
**E-008** Move a connected module.
**E-009** Save immediately after moving the module.
**E-010** Close and reopen the document.
**E-011** Verify the route was preserved.

Observe: visual feedback; endpoint clarity; wire selection; route editing; errors; accidental operations; discoverability of these actions.

### Section E Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section F — File / Document Lifecycle

Test New, Open, Save, Save As (if available), Close, Reopen, Recovery (if available), unsaved-changes indication, repeated save, and immediate save after edit.

**F-001** Make a change.
**F-002** Immediately save.
**F-003** Close.
**F-004** Reopen.
**F-005** Verify the change persisted.
**F-006** Modify a wire route.
**F-007** Immediately save.
**F-008** Reopen.
**F-009** Verify the route persisted.
**F-010** Modify the diagram (without saving).
**F-011** Does the UI clearly communicate the unsaved state?

### Section F Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section G — Toolbar UX

Test every toolbar control **as a user, not a developer.** Current toolbar controls: **FILE, SELECT, WIRE, ADD, VIEW, SEARCH, TRACE, MEASURE, ANALYZE, EXPORT, INSPECT.**

Do not redesign or suggest redesigning the toolbar as part of this test — only evaluate the existing one.

For **each** control, answer:
1. What do you think it does, before clicking it?
2. Is the label understandable?
3. Is the icon understandable?
4. Does clicking it behave as you expected?
5. If it has a dropdown, is the dropdown understandable?
6. Are its secondary commands logically grouped?
7. Does the control give you feedback that something happened?
8. After using it, do you know what happened / what state you're now in?

Record suggestions (SUGGESTION classification) separately from defects (BUG/UX/UI).

### Section G Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section H — Trace

Use real TRX300 circuits.

**H-001** Select a component.
**H-002** Open Trace.
**H-003** Run Physical Trace.
**H-004** Run Conducting Trace.
**H-005** Run Current Flow Trace.
**H-006** Inspect the path results.
**H-007** Click a path step.
**H-008** Observe diagram highlighting.
**H-009** Fit the circuit.
**H-010** Change key/switch state.
**H-011** Repeat the trace.
**H-012** Does the result make engineering sense?
**H-013** Does the UI communicate: source, return, branches, blocked paths, current flow, and diagnostic information clearly?

Record anything technically correct but hard to understand.

### Section H Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section I — DMM / Measurement

**I-001** Open DMM.
**I-002** Observe its initial state.
**I-003** Select a measurement mode.
**I-004** Select probe points.
**I-005** Measure a known powered circuit.
**I-006** Measure an unpowered circuit.
**I-007** Measure continuity.
**I-008** Measure resistance.
**I-009** Measure diode behavior, where applicable.
**I-010** Change key state.
**I-011** Repeat the measurement.
**I-012** Observe OL (over-limit/open) behavior.
**I-013** Observe fault behavior.
**I-014** Observe unsupported-measurement behavior.
**I-015** Does the DMM feel like a real engineering instrument?

Specifically evaluate: readability, units, mode indication, probe indication, result stability, state changes, error communication, terminology, and workflow friction.

### Section I Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section J — Analysis

**J-001** Open Analysis.
**J-002** Is the panel understandable?
**J-003** Run the available analysis.
**J-004** Interpret the results.
**J-005** Change circuit state.
**J-006** Re-run analysis.
**J-007** Are stale (out-of-date) results clearly communicated as stale?

### Section J Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section K — Search

Search for: a module, a component, a terminal, a wire, a relationship, a partial name, an exact name, and an unknown/nonexistent object.

**K-001** Search.
**K-002** Select a result.
**K-003** Navigate to the result.
**K-004** Does the diagram visibly identify the result?
**K-005** Clear the search.
**K-006** Search again.

Does Search feel like an engineering navigation tool, or a generic text search?

### Section K Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section L — Export

Test every available export format (e.g. SVG, PNG, PDF, or whatever the build actually supports).

For each format: export it; locate the file; open the file; inspect visual fidelity, wire routing, labels, symbols, clipping, and scaling.

Record defects (BUG/VISUAL) separately from desired future improvements (FEATURE REQUEST/SUGGESTION).

### Section L Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section M — Inspect / Property UX

Select each of the different object types available (module, terminal, wire, splice, relationship, other engineering objects) and inspect its properties.

Determine: what information is shown; whether terminology makes sense; whether identifiers are useful; whether engineering information is exposed clearly; whether irrelevant implementation details overwhelm the user.

### Section M Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section N — Panel Lifecycle / PR-014 (WebView Lifetime Acceptance)

This is a **dedicated WebView lifetime acceptance test**, completing PR-014's real-world validation. **Diagnostics**: the running debug build prints lines like `[V2-WEBVIEW] CREATE lifecycle=<n> instance=workspace-tab-diagram` to its console (visible if launched via `flutter run -d windows --debug` from a terminal, or in the IDE's Run console). The number after `lifecycle=` for `instance=workspace-tab-diagram` is the **Primary lifecycle ID** referenced below.

```
Primary WebView lifecycle (at start of this section): ____________
```

Perform each of the following, and after **each one**, check the console and record the Primary lifecycle ID again:

| # | Operation | Primary lifecycle ID after | Changed? |
|---|---|---|---|
| N-001 | Open Trace | | |
| N-002 | Close Trace | | |
| N-003 | Open DMM | | |
| N-004 | Close DMM | | |
| N-005 | Open Analysis | | |
| N-006 | Close Analysis | | |
| N-007 | Open Compare | | |
| N-008 | Close Compare | | |
| N-009 | Add module | | |
| N-010 | Add wire | | |
| N-011 | Move module | | |
| N-012 | Edit wire | | |
| N-013 | Search | | |
| N-014 | Trace | | |
| N-015 | Measure | | |
| N-016 | Change switch/key state | | |
| N-017 | Switch workspace tab (away) | | |
| N-018 | Return to original Diagram | | |

**Expected:** the Primary lifecycle ID never changes across this entire table.

**If the ID changes at any point:** stop, and immediately create a full BUG issue entry (Issue Capture Template) including: the previous ID, the new ID, the exact operation that triggered it, a timestamp, and a screenshot of the console output showing the change.

**Section result:**
```
Primary lifecycle remained stable across all of N-001–N-018:  YES / NO
```

### Section N Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section O — Error Handling

Intentionally perform reasonable invalid actions, e.g.: an invalid wire connection; an action with no selection; an unsupported measurement; a nonsense search; closing a document with unsaved work; another invalid operation; targeting something unavailable.

For each, observe whether the application: prevents the action; explains why; gives useful feedback; silently does nothing; crashes; or leaves confusing state.

**"Nothing happened" is itself a finding** if you reasonably expected some feedback — record it.

### Section O Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section P — Persistence / Data Integrity

Perform a realistic editing session:
1. Open TRX300. 2. Add a module. 3. Move the module. 4. Add/edit a wire. 5. Change its route. 6. Change labels/properties. 7. Save. 8. Close. 9. Reopen. 10. Verify everything.

Repeat with at least one more document if time allows.

Specifically verify: diagram geometry, module positions, wire routes, relationships, labels, and any other relevant persisted state.

### Section P Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section Q — Performance

No benchmarking equipment needed — record **human-perceived** performance for: application startup; opening a document; switching tabs; opening a panel; running Trace; Search; DMM measurements; module creation; wire creation; save; reopen; zoom; pan.

Use: **Fast / Acceptable / Slow / Unusable**, plus a note on what happened.

| Action | Rating | Notes |
|---|---|---|
| Application startup | | |
| Opening a document | | |
| Switching tabs | | |
| Opening a panel | | |
| Trace execution | | |
| Search | | |
| DMM measurement | | |
| Module creation | | |
| Wire creation | | |
| Save | | |
| Reopen | | |
| Zoom | | |
| Pan | | |

### Section Q Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section R — Visual / UI Consistency

Review: typography, spacing, alignment, icons, button states, dropdowns, panels, borders, selected states, disabled states, error states, empty states, dark-theme consistency, and visual hierarchy.

Personal preference alone is not automatically a bug — record subjective feedback as **UX**, **UI**, or **SUGGESTION** as appropriate, not BUG, unless something is objectively broken (e.g. unreadable text, overlapping elements).

### Section R Issue Log
| Issue ID | Step | Type | Severity | Description | Status |
|---|---|---|---|---|---|

---

## Section S — First-Time User Test

**This section is especially important.** Find a tester who did **not** build Diagram Studio. Give them only this objective, with no further explanation:

> "Open the TRX300 diagram and investigate how the headlight circuit works."

Do **not** explain Trace, DMM, Search, toolbar organization, or operating states beforehand. Observe and record:

```
What did they click first?
What did they expect?
Where did they hesitate?
What did they misunderstand?
What did they discover?
What did they fail to discover?
What terminology confused them?
What did they expect to happen (that didn't)?
```

This section produces qualitative UX findings — record them in the Observation Log, not forced into pass/fail.

---

## Section T — Real Installer Workflow

Simulate an actual aftermarket electrical installation investigation.

**Scenario:** An installer needs to determine how a circuit behaves and verify correct wiring.

Have the tester: 1. Open the vehicle diagram. 2. Locate the relevant component. 3. Identify its terminals. 4. Identify connected wires. 5. Trace the circuit. 6. Determine source. 7. Determine return. 8. Inspect branches/splices. 9. Change operating state. 10. Measure voltage. 11. Measure continuity/resistance. 12. Inspect the circuit again. 13. Save notes/work. 14. Move to another circuit. 15. Return to the original circuit.

Do not coach the tester unless they are genuinely blocked. Record every point where the workflow was confusing, in the Observation Log.

---

## Section U — Full Real-World Session

Conduct a 30–60 minute **uninterrupted** session using Diagram Studio as though it were a real engineering application. Explore naturally. Record issues immediately, not from memory afterward.

At the end, answer:
```
1. What worked especially well?
2. What was confusing?
3. What felt slow?
4. What felt unnecessary?
5. What did you expect but could not find?
6. What feature did you discover accidentally?
7. What would you change first?
8. What would prevent you from using this professionally?
9. What would make this substantially better?
10. Would you use it on a real job?
```

---

# Tester Observation Log

Use freely, throughout the session, for anything that doesn't fit a specific test case above.

```
Time:
Test:
Observation:
________________________________________________
```
(repeat as needed)

---

# Tester Suggestions

| ID | Area | Suggestion | Reason | Priority | Accepted? |
|---|---|---|---|---|---|
| | | | | | |

This table exists specifically so useful UX ideas are never mis-classified as bugs.

---

# Final Scorecard

```
Functional readiness:        __/10
UX readiness:                __/10
UI readiness:                __/10
Engineering usefulness:      __/10
Performance:                 __/10
Discoverability:             __/10
Professional readiness:      __/10

Overall:                     __/10

Would you use this professionally?   YES / NO / WITH CHANGES

What must change before professional use?
____________________________________
```

---

# Release Readiness Checklist

```
[ ] No P0 issues
[ ] No unresolved P1 issues
[ ] PR-014 WebView lifetime verified (Section N)
[ ] Save/reopen verified (Section F/P)
[ ] Multi-document behavior verified (Section B)
[ ] Trace verified (Section H)
[ ] DMM verified (Section I)
[ ] Search verified (Section K)
[ ] Export verified (Section L)
[ ] Error handling reviewed (Section O)
[ ] First-time-user test performed (Section S)
[ ] Real installer workflow performed (Section T)
[ ] Tester suggestions reviewed
[ ] Screenshots/evidence collected
[ ] Known limitations documented

Final recommendation:  READY / READY WITH KNOWN ISSUES / NOT READY
```

---

# Test Evidence

Capture a screenshot when: a bug occurs; the UI is confusing; visual rendering is wrong; an error occurs; an unexpected state appears; or a suggestion depends on visual context. You do **not** need a screenshot for every PASS.

---

# Test Philosophy

The tester is **not** trying to prove the developer's implementation is correct. The tester is trying to determine whether the **product** behaves correctly for a **human**.

- If the application technically works, but a reasonable user cannot figure out how to use it — that is a valid UX finding.
- If an operation is technically correct, but its result is confusing — that is a valid UX finding.
- If a feature is discoverable only because a developer explained it — that is a valid discoverability finding.
- If something works but could clearly be better — record it as a suggestion.

**Do not suppress negative feedback.**

---

# Document Review Checklist (for whoever maintains this test)

Before considering this test document complete/current, confirm:
- [ ] A technically competent person who did not write Diagram Studio could execute this test using only this document.
- [ ] They could tell exactly what they're supposed to do at each step.
- [ ] They could distinguish a bug from a suggestion.
- [ ] They could record an unexpected behavior without knowing implementation details.
- [ ] A developer could reproduce an issue from the recorded information alone.
- [ ] Two different testers' results could meaningfully be compared.

If any answer is "no," improve this document rather than the test execution.
