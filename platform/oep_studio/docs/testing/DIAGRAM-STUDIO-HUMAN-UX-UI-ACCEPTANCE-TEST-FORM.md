# Diagram Studio — Human UX/UI Acceptance Test (Fillable Form)

**PRODUCT-READINESS-015** — practical execution copy. For full instructions, definitions, and the complete issue template, see the master specification: [DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md](DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md).

Mark each step **PASS / FAIL / BLOCKED / N/A**. Use the quick-capture issue line under any step where something is worth flagging, and expand it into a full issue entry (below) before ending the session.

---

## Tester Information

```
Tester:                 Date:
Build:                  Commit:
Operating System:       Display resolution:
Input device:           Test environment:
Diagram/document used:
Experience level:  New user / Technician / Installer / Engineer / Developer / Other
```

## Quick Reference

**Result:** PASS = worked as expected · FAIL = did not · BLOCKED = couldn't be completed (defect/prerequisite/crash/env) · N/A = doesn't apply

**Classification:** BUG · UX · UI · USABILITY · PERFORMANCE · DATA/PERSISTENCE · NAVIGATION · ACCESSIBILITY · VISUAL · ENGINEERING LOGIC · DOCUMENTATION · FEATURE REQUEST · SUGGESTION

**Severity:** P0 Blocker · P1 Critical · P2 Major · P3 Minor · P4 Cosmetic/Enhancement · SUGGESTION (no severity)

---

## Section A — Application Startup

| # | Step | Result | Notes |
|---|---|---|---|
| A-001 | Launch Diagram Studio (startup time / initial screen / branding / clarity of next action) | | |
| A-002 | Launch with no Diagram open (is it clear what to do, where past work is, what the app can do?) | | |
| A-003 | Close and relaunch (crashes / stale state / unexpected reopen / UI corruption) | | |

Issue: __________________________________________

## Section B — Workspace / Tabs

| # | Step | Result | Notes |
|---|---|---|---|
| B-001 | Open a Diagram | | |
| B-002 | Open a second Diagram | | |
| B-003 | Switch between tabs | | |
| B-004 | Return to original Diagram | | |
| B-005 | Each Diagram retains visual/selection/edit/panel/WebView/document state | | |
| B-006 | Open/close additional Studio surfaces | | |
| B-007 | Close a Diagram tab | | |
| B-008 | Reopen a Diagram | | |

Issue: __________________________________________

## Section C — Primary Diagram Interaction (TRX300)

| # | Step | Result | Notes |
|---|---|---|---|
| C-001 | Pan | | |
| C-002 | Zoom in | | |
| C-003 | Zoom out | | |
| C-004 | Fit/center | | |
| C-005 | Select a module | | |
| C-006 | Select a wire | | |
| C-007 | Click empty space | | |
| C-008 | Move a module | | |
| C-009 | Move several modules | | |
| C-010 | Result predictable each time? | | |
| C-011 | Selected object visually obvious? | | |
| C-012 | Obvious how to deselect? | | |

Issue: __________________________________________

## Section D — Adding / Editing Engineering Objects

| # | Step | Result | Notes |
|---|---|---|---|
| D-001 | Open ADD | | |
| D-002 | Categories make sense to a first-timer? | | |
| D-003 | Add a module | | |
| D-004 | Move the module | | |
| D-005 | Edit its properties | | |
| D-006 | Change its label (if supported) | | |
| D-007 | Delete/remove it (if supported) | | |
| D-008 | Undo (if supported) | | |
| D-009 | Repeat the workflow | | |

**Primary WebView lifecycle before section: _____   after section: _____   (must match)**

Issue: __________________________________________

## Section E — Wire Creation / Routing

| # | Step | Result | Notes |
|---|---|---|---|
| E-001 | Create a wire | | |
| E-002 | Connect two valid terminals | | |
| E-003 | Attempt an invalid connection | | |
| E-004 | Select a wire | | |
| E-005 | Move/edit the wire | | |
| E-006 | Adjust its route | | |
| E-007 | Reset its route | | |
| E-008 | Move a connected module | | |
| E-009 | Save immediately after | | |
| E-010 | Close/reopen the document | | |
| E-011 | Route preserved? | | |

Issue: __________________________________________

## Section F — File / Document Lifecycle

| # | Step | Result | Notes |
|---|---|---|---|
| F-001 | Make a change | | |
| F-002 | Immediately save | | |
| F-003 | Close | | |
| F-004 | Reopen | | |
| F-005 | Change persisted? | | |
| F-006 | Modify a wire route | | |
| F-007 | Immediately save | | |
| F-008 | Reopen | | |
| F-009 | Route persisted? | | |
| F-010 | Modify without saving | | |
| F-011 | Unsaved state clearly communicated? | | |

Issue: __________________________________________

## Section G — Toolbar UX

For each control, note: expected meaning / label clear? / icon clear? / behaves as expected? / dropdown clear? / grouped logically? / gives feedback? / outcome clear?

| Control | Result | Notes |
|---|---|---|
| FILE | | |
| SELECT | | |
| WIRE | | |
| ADD | | |
| VIEW | | |
| SEARCH | | |
| TRACE | | |
| MEASURE | | |
| ANALYZE | | |
| EXPORT | | |
| INSPECT | | |

Issue: __________________________________________

## Section H — Trace

| # | Step | Result | Notes |
|---|---|---|---|
| H-001 | Select a component | | |
| H-002 | Open Trace | | |
| H-003 | Physical Trace | | |
| H-004 | Conducting Trace | | |
| H-005 | Current Flow Trace | | |
| H-006 | Inspect path results | | |
| H-007 | Click a path step | | |
| H-008 | Diagram highlighting observed | | |
| H-009 | Fit the circuit | | |
| H-010 | Change key/switch state | | |
| H-011 | Repeat trace | | |
| H-012 | Result makes engineering sense? | | |
| H-013 | Source/return/branches/blocked/flow/diagnostics clear? | | |

Issue: __________________________________________

## Section I — DMM / Measurement

| # | Step | Result | Notes |
|---|---|---|---|
| I-001 | Open DMM | | |
| I-002 | Initial state | | |
| I-003 | Select mode | | |
| I-004 | Select probe points | | |
| I-005 | Measure powered circuit | | |
| I-006 | Measure unpowered circuit | | |
| I-007 | Measure continuity | | |
| I-008 | Measure resistance | | |
| I-009 | Measure diode (if applicable) | | |
| I-010 | Change key state | | |
| I-011 | Repeat measurement | | |
| I-012 | OL behavior | | |
| I-013 | Fault behavior | | |
| I-014 | Unsupported behavior | | |
| I-015 | Feels like a real instrument? | | |

Issue: __________________________________________

## Section J — Analysis

| # | Step | Result | Notes |
|---|---|---|---|
| J-001 | Open Analysis | | |
| J-002 | Panel understandable? | | |
| J-003 | Run analysis | | |
| J-004 | Interpret results | | |
| J-005 | Change circuit state | | |
| J-006 | Re-run analysis | | |
| J-007 | Stale results clearly communicated? | | |

Issue: __________________________________________

## Section K — Search

| # | Step | Result | Notes |
|---|---|---|---|
| K-001 | Search (module/component/terminal/wire/relationship/partial/exact/nonexistent) | | |
| K-002 | Select result | | |
| K-003 | Navigate to result | | |
| K-004 | Diagram visibly identifies result? | | |
| K-005 | Clear search | | |
| K-006 | Search again | | |

Issue: __________________________________________

## Section L — Export

| Format | Export OK | Opens OK | Visual fidelity | Routing/labels/symbols OK | Notes |
|---|---|---|---|---|---|
| SVG | | | | | |
| PNG | | | | | |
| PDF | | | | | |
| Other | | | | | |

Issue: __________________________________________

## Section M — Inspect / Property UX

| Object type | Info shown makes sense? | Terminology clear? | Notes |
|---|---|---|---|
| Module | | | |
| Terminal | | | |
| Wire | | | |
| Splice | | | |
| Relationship | | | |
| Other | | | |

Issue: __________________________________________

## Section N — Panel Lifecycle / PR-014 (WebView Lifetime)

```
Primary WebView lifecycle at start of section: ____________
```

| # | Operation | Lifecycle ID after | Changed? |
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
| N-017 | Switch workspace tab | | |
| N-018 | Return to original Diagram | | |

```
Primary lifecycle remained stable across all steps:  YES / NO
(if NO — file a full BUG issue now: previous ID, new ID, exact operation, timestamp, screenshot)
```

## Section O — Error Handling

| Attempted invalid action | App response (prevented/explained/feedback/silent/crash/confusing) | Result | Notes |
|---|---|---|---|---|
| Invalid wire connection | | | |
| Action with no selection | | | |
| Unsupported measurement | | | |
| Nonsense search | | | |
| Close with unsaved work | | | |
| Other invalid operation | | | |

Issue: __________________________________________

## Section P — Persistence / Data Integrity

Session: Open TRX300 → add module → move module → add/edit wire → change route → change labels/properties → save → close → reopen → verify.

| Item verified after reopen | Result | Notes |
|---|---|---|
| Diagram geometry | | |
| Module positions | | |
| Wire routes | | |
| Relationships | | |
| Labels | | |
| Other persisted state | | |

Issue: __________________________________________

## Section Q — Performance

Rate: Fast / Acceptable / Slow / Unusable

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

## Section R — Visual / UI Consistency

| Area | OK? | Notes |
|---|---|---|
| Typography | | |
| Spacing/alignment | | |
| Icons | | |
| Button states | | |
| Dropdowns | | |
| Panels | | |
| Borders | | |
| Selected states | | |
| Disabled states | | |
| Error states | | |
| Empty states | | |
| Dark theme consistency | | |
| Visual hierarchy | | |

Issue: __________________________________________

## Section S — First-Time User Test

Objective given to tester (verbatim, no further explanation): *"Open the TRX300 diagram and investigate how the headlight circuit works."*

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

## Section T — Real Installer Workflow

Scenario: determine how a circuit behaves and verify correct wiring (15-step workflow — see master spec Section T for the full list). Record confusion points below.

```
Confusion points / friction observed:
```

## Section U — Full Real-World Session (30–60 min)

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

## Tester Observation Log

```
Time:               Test:               Observation:
```
(repeat as needed)

---

## Tester Suggestions

| ID | Area | Suggestion | Reason | Priority | Accepted? |
|---|---|---|---|---|---|

---

## Issue Entries (full form — expand every quick-capture line above into one of these)

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
(repeat as needed)

---

## Final Scorecard

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
```

## Release Readiness Checklist

```
[ ] No P0 issues
[ ] No unresolved P1 issues
[ ] PR-014 WebView lifetime verified (Section N)
[ ] Save/reopen verified
[ ] Multi-document behavior verified
[ ] Trace verified
[ ] DMM verified
[ ] Search verified
[ ] Export verified
[ ] Error handling reviewed
[ ] First-time-user test performed
[ ] Real installer workflow performed
[ ] Tester suggestions reviewed
[ ] Screenshots/evidence collected
[ ] Known limitations documented

Final recommendation:  READY / READY WITH KNOWN ISSUES / NOT READY
```
