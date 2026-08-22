# OEP Interaction Model (AP-OEP-INTERACTION-MODEL-001)

**Status:** Proposed architectural specification — not yet ratified.
**Scope:** Studio-layer (`platform/oep_studio`) interaction/UX architecture
only. Does not modify, and is subordinate to, `platform/oep_foundation/
CLAUDE.md` (the platform constitution), the Engineering Knowledge Engine
Constitution, and `platform/oep_studio/docs/OEP_ENGINEERING_CONSTITUTION.md`.
**Relationship to prior art:** builds on, and does not duplicate,
`platform/oep_engine/docs/EKE_INTERACTION_MODEL.md` (the Engine-side
behavioral audit of the Legacy V2 reference) and the Web Surface
architecture doc (`OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md`). Cites both
rather than restating them.

---

## 1. V2 behavioral interaction model

Fully documented by direct source audit of `reference/legacy_wiring_sim_v2/
eke-wiring-sim/js/`. Full findings folded into this document rather than
duplicated verbatim a second time — see the companion audit notes; the
essential grammar:

- **One canvas, one always-visible sidebar** (tabbed Inspector/Meter), one
  topbar. No competing surfaces except modals and a minimap.
- **Single, kind-independent selection** — exactly one wire *or* one
  module selected at a time, never both, never multiple. Selecting
  re-purposes the *same* sidebar region rather than opening a new panel.
- **Selection → sidebar becomes context.** Nothing about the sidebar's
  structure changes; its *content* swaps to match what's selected
  (module info vs. wire info vs. empty-state prompt).
- **Property editing is modal, not inline.** The sidebar is read-only
  display + button launcher; actual field editing happens in one of two
  full-form modals (Module Editor, Wire Properties).
- **Three mutually exclusive, explicit interaction modes** (`editMode`/
  Layout, `wireMode`/Wire, `routeEditMode`/Route) that each unlock a
  different gesture set and suppress the others. Selection-driven
  inspection only functions in the implicit fourth "normal" mode.
- **Discovery is layered, not hidden**: toolbar buttons (primary) →
  contextual sidebar action buttons (secondary, appear only once
  something is selected) → right-click context menu (tertiary) →
  documented keyboard shortcuts (`?` overlay). Nothing is exclusively
  keyboard-only.
- **Escape is a cascade**, not a single global "close everything" — it
  backs out exactly one layer (lead-placement → route-edit → wire-mode →
  open modal → search → module panel → wire selection) per press.
- **Verification is reachable directly from a selected relationship** —
  selecting a wire is sufficient context to read a live/simulated
  measurement for it in the Meter panel; no separate navigation step.
- **Undo is architecturally sketched but functionally absent** in V2
  itself (`editor/undo-redo.js` defines a complete, correct
  `UndoRedoStack`/Command-pattern class that is never instantiated —
  confirmed independently by `EKE_INTERACTION_MODEL.md`'s own audit).
  This matters for OEP: **OEP must not import V2's undo (non-)behavior**
  — it already has a real, working command/undo stack in the Engine, and
  the bridge already routes every V2-originated mutation through it
  (`DiagramStudioController` + `EditingSession` commands, confirmed
  working end-to-end in AP-DIAGRAM-V2-BRIDGE-008/011). V2's own missing
  undo is a gap in the *reference implementation*, not a pattern to
  standardize on.
- **Search is flat, cross-type, and jump-to-select** — one search box
  matches both modules and wires by substring, results pan/select on
  click. No faceted filtering, no per-type search scoping.
- **Save/load in V2 itself is a delta-only file download/upload** — this
  is explicitly **not** the model OEP uses; OEP's bridge already
  intercepts and replaces V2's native save with the real, path-based
  `DiagramStudioController.saveDocument`/`saveDocumentAs`, and that
  substitution — not V2's own save mechanism — is what should inform any
  common "document lifecycle" primitive.

## 2. V2 visual-vs-behavioral separation

| Behavioral (candidate for OEP-wide adoption) | Visual (V2-specific, not to be cloned) |
|---|---|
| Contextual sidebar (selection re-purposes one region) | Exact sidebar width, exact SVG multimeter face |
| Single-selection, kind-independent | Exact selection glow color/opacity values |
| Explicit, mutually exclusive interaction modes | Exact mode-badge text/positioning |
| Modal for structured multi-field editing, sidebar for read + launch | Exact modal `.modal-box` styling |
| Layered discoverability (toolbar → contextual buttons → context menu → shortcut overlay) | Exact icon glyphs, exact button labels ("⚡ Wire") |
| Escape-as-cascade | — (behavior has no meaningful "visual" counterpart) |
| Object-selected → relationship-list → relationship-selected → verify | Exact wire-color-to-hex mapping (`CAT_CLR`) |
| Flat cross-type search, jump-to-select | Exact result-row layout |
| Zoom-to-cursor, Fit View, minimap-click-to-pan | Exact minimap chrome |
| Click-click relationship creation (not drag-to-wire) | Exact terminal-dot hover treatment |

The line is genuinely clean here: everything in the left column is a
*rule about what happens*, independent of pixels; everything in the
right column is *how it happens to look* in one specific reference app
built for one specific domain (automotive wiring). §21 of the OEP
visual-integration work (`DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`
§21) already established the principle "integrate OEP's visual
language, preserve V2's functional workflow" for the *chrome around*
V2; this document extends the same behavioral/visual split to the rest
of OEP, without proposing V2's CSS become an OEP design system.

## 3. Common OEP interaction primitives (Phase 2 classification)

| # | Primitive | Classification | Why |
|---|---|---|---|
| 1 | Workspace | **COMMON** | Every Studio needs exactly one dominant surface plus a persistent chrome frame — already true of Diagram Studio (canvas) and Knowledge Studio alike. |
| 2 | Context | **COMMON** | "What am I currently looking at / working on" is a universal Studio question; the *mechanism* (selection, active tab, active document) varies. |
| 3 | Object selection | **COMMON** | `SelectionService.current` already exists Engine-side, already models this as a single `SelectionState` — this is not new work, just adoption at the UI layer. |
| 4 | Object inspection | **COMMON** | Every Studio's core loop starts with "look at one thing closely." |
| 5 | Property editing | **ADAPTABLE (common grammar, Studio-specific fields)** | The *pattern* (structured form, sidebar-launched or modal) generalizes; the actual property schema is entity/domain-specific and cannot be generic. |
| 6 | Relationship inspection | **COMMON** | Directly maps to the Five Primitive Rule's `Relationship` primitive — this is not Diagram-Studio-specific, it's platform-fundamental. |
| 7 | Relationship editing | **ENGINE-BACKED BUT UI-SPECIFIC** | The Engine already has generic relationship commands (`UpdateRelationshipPropertiesCommand`, `ReconnectRelationshipCommand`); what the *editing surface* looks like per Studio is not generic. |
| 8 | Explicit interaction modes | **ADAPTABLE** | Valuable where direct manipulation genuinely conflicts with inspection (drag-to-move vs. click-to-select) — true for Diagram Studio, not obviously true for a document-centric Studio like Knowledge Studio. Not universal, but not Studio-exclusive either — see §6. |
| 9 | Contextual action surface | **COMMON** | "Once I've selected something, show me what I can do to it" is domain-agnostic. |
| 10 | Sidebar/property surface | **ADAPTABLE** | The *concept* (a persistent region that becomes contextual on selection) generalizes; whether it's a left dock, right dock, or bottom panel is legitimately Studio-specific (already true today — Diagram Studio's docked panels are a `Column` on one side; a future Studio could differ). |
| 11 | Search/filter | **COMMON** | Every Studio operates on a graph of Engineering Objects/Relationships; a flat cross-type search over "things in the current document/context" generalizes cleanly, exactly as V2's does. |
| 12 | Modal detail/editor | **OPTIONAL** | Appropriate for structured multi-field edits (V2's Module/Wire Properties). Not every property change needs a modal — a single-field rename does not. This should remain a tool the Studio reaches for, not a mandated pattern. |
| 13 | Tabbed workspace | **ADAPTABLE** | Web Surfaces already proves this pattern works for independently-alive multi-document contexts; not every Studio needs multiple simultaneous tabs (a single-document Studio doesn't gain anything from forcing a tab strip). |
| 14 | Persistent working context | **COMMON** | Directly the Web Surface architecture's existing principle (`IndexedStack`, state preserved across tab switches) — already generalized once; extending it conceptually to "a Studio is a persistent workspace around a document" (Phase 7) is not new invention. |
| 15 | Direct manipulation | **ADAPTABLE** | Essential where the domain is inherently spatial (wiring diagrams, layout). Less obviously essential for a Studio whose domain is fundamentally list/graph-based (e.g., a validation dashboard) — forcing drag gestures there would be manufactured, not organic. |
| 16 | Verification/instrumentation | **COMMON, ENGINE-BACKED** | The Five Primitive Rule's `Event`/`Capability` primitives plus the Engine's existing simulation/measurement/validation subsystems already generalize this — see Phase 8. |
| 17 | Undo/redo | **COMMON, ENGINE-BACKED, NOT UI-SPECIFIC** | Already solved once, correctly, at the Engine layer (`EditingSession` command stack) and already proven to work end-to-end through a UI as different as V2's webview (BRIDGE-008/011). Every Studio should route through this, never invent its own. |
| 18 | Save/document lifecycle | **COMMON, ENGINE-BACKED** | `DiagramStudioController.saveDocument`/`saveDocumentAs` is already the model; V2's own client-side-file-download save was explicitly *not* adopted (§1) — this row is evidence *against* blindly importing V2 behavior, not for it. |

## 4. Sidebar/context model (Phase 4)

The V2 principle:

```
SELECT OBJECT
    ↓
SIDEBAR BECOMES CONTEXT FOR OBJECT
    ↓
INSPECT
    ↓
EDIT
    ↓
INSPECT RELATIONSHIPS
    ↓
PERFORM CONTEXTUAL ACTION
    ↓
VERIFY
```

**Is it valid as an OEP-wide principle?** Yes, as a *behavioral* pattern
(§2's left column) — it does not depend on wiring-diagram specifics.
Object → Relationship → Operation/Event is exactly the shape the Five
Primitive Rule already implies (Phase 6).

**Which Studios could use it directly, as currently understood:**
- **Diagram Studio** — already uses it, via V2 itself.
- **Knowledge Studio** — plausible fit: source documents/candidates are
  the "object," evidence links are the "relationship," review/approval
  is the "contextual action," but this was **not verified against
  Knowledge Studio's actual current UI code in this study** (out of
  scope for this pass — flagged as NOT YET PROVEN, not asserted).
- **Engineering Intelligence** — its own capability list (Explorer,
  Knowledge Graph Explorer, Query Console, Validation/Analysis/
  Reasoning Dashboards) suggests a dashboard-of-dashboards shape, not a
  single-object-context shape; the sidebar-context principle may apply
  *within* one of its sub-panels (e.g. Knowledge Graph Explorer) but not
  as the Studio's top-level organizing pattern. **NOT YET PROVEN.**

**What must vary between Studios:** the *content* of "inspect,"
"relationships," and "contextual action" is entirely domain-specific and
cannot be generic — this document does not attempt to define a universal
property-schema or action-list. What can be common is the *shape*
(select → context → inspect → act → verify), not the payload.

**This study does not build a universal sidebar component.** Per the
task's explicit limit, and because the payload varies too much for a
single generic widget to be honest — a shared *pattern document* (this
one) is the correct level of abstraction for now, not shared code.

## 5. Modes vs. command palette (Phase 5)

V2 has no global command palette at all — every action is either
toolbar-visible, sidebar-contextual, or mode-gated. OEP's own prior
native Diagram Studio (`diagram_studio_page.dart`, now retired) *did*
have `CallbackShortcuts` bindings surfaced through both toolbar buttons
and shortcuts (`DIAGRAM_STUDIO_CONSTITUTION.md`-adjacent
`architecture/diagram_studio/INTERACTION_MODEL.md`, now stale but still
evidence of prior OEP-native intent) — so this is a real, evidence-based
tension, not a hypothetical.

**Recommended rule**, synthesizing both:

- **Contextual actions** (the wire's Edit/Trace/Route/Delete in V2, or
  a node's rotate/mirror in the retired native Studio) belong on the
  contextual action surface tied to the current selection — never in a
  global palette. A user should never have to remember a shortcut for
  "delete the thing I'm currently looking at."
- **Mode-specific actions** (route-segment nudge, wire-terminal click)
  are only meaningful while a mode is active and should be discoverable
  via the mode's own status affordance (V2's `#wep` status bar is a good
  model: "Click a source terminal") — not a palette entry, since a
  palette entry implies the action is always available, which it isn't.
- **Global application commands** (Undo/Redo, Save, Find/Search, Fit
  View, toggle a dock panel) are legitimately palette/shortcut territory
  — these are context-independent by definition, which is exactly what a
  command palette is good at surfacing.
- **Document commands** (Save As, Reload, switch document/tab) belong
  with global commands, not contextual ones — they act on the whole
  workspace, not the current selection.
- **Destructive actions** (delete object, delete relationship) should
  always be contextual (tied to what's selected) **and** confirmed
  (V2's native `confirm()` dialogs, however unstyled, are the right
  instinct) — never available from a global palette where "what am I
  about to delete" isn't visually obvious at the moment of invocation.

**Conclusion: OEP should generally prefer CONTEXT + MODE + SIDEBAR for
anything that acts on a specific object or relationship, and reserve a
global command surface for genuinely context-independent commands.**
This is not a rejection of command palettes — it's a scoping rule for
when one is the right tool.

## 6. Object/relationship-first-class model (Phase 6)

The Five Primitive Rule (`platform/oep_foundation/CLAUDE.md`, verbatim):

> "The platform is permanently based upon five primitive concepts. —
> Engineering Object — Relationship — Operation — Event — Capability.
> Everything in OEP must ultimately be expressible through these
> primitives."

V2's actual interaction grammar maps onto this cleanly and *without
forcing*:

```
Engineering Object      (V2: a module)
    ↓ Select
Select                  (V2: selMod / selWire)
    ↓ Inspect
Inspect                 (V2: sidebar Inspector pane)
    ↓ Relationships
Relationships           (V2: a module's wire list; a wire's endpoints)
    ↓ Operations
Operations              (V2: Edit / Route / Delete — contextual actions)
    ↓ Events / Verification
Events / Verification   (V2: Meter panel reading, Trace circuit)
```

This is not a coincidence requiring reinterpretation — V2's `selM`/
`selW` selection already *is* Engineering-Object/Relationship selection
in miniature, and the Meter/Trace step already *is* an
Event/Capability-flavored verification step, just without those exact
platform names attached. **This alignment is genuine, not
retrofitted**, which is the strongest evidence in this study that
Object → Select → Inspect → Relationships → Operations → Events is a
sound candidate for the common UI interaction grammar (§10). This phase
does not alter the Five Primitive Rule itself — it only observes that a
proven UI happens to already trace its shape.

## 7. Document/workspace model (Phase 7)

V2 treats "the active diagram" as one single, always-loaded document —
no internal multi-document concept, no internal tabs (its sidebar tabs
are panel tabs, not document tabs — confirmed by direct source read,
§1 item 13 of the underlying audit). OEP's Web Surface architecture,
by contrast, already generalizes multi-document/multi-context far
beyond what V2 itself needed: independently-alive tabs (`IndexedStack`,
state preserved across switches), a structural trust boundary per tab
(`bridgeAuthorized` as a derived, non-settable property), and an
explicit, already-ratified decision **not** to fold Web Surface tabs
into `DiagramTabsController`'s single-shared-`EditingSession` model,
because they are genuinely different kinds of "document."

**Proposed principle:** *A Studio is a persistent workspace around an
authoritative engineering document/context, not merely a collection of
screens.* This is not a new invention — it is already exactly how the
Web Surface architecture works today, and this document proposes
generalizing the *wording* of that already-proven pattern to Studios
broadly, not proposing new mechanism.

**Where it applies:** any Studio whose primary job is "work on one (or
several concurrently open) authoritative engineering document(s)" —
Diagram Studio, and by extension any future document-centric Studio.

**Where it does not apply cleanly:** dashboard/exploration-shaped
Studios (Engineering Intelligence's Explorer/Query Console/dashboards)
are not naturally "a document" — they're views over the whole
Repository, not an editable authoritative artifact. Forcing a "tab per
document" framing onto a query console would be artificial. This is a
real boundary, not an oversight — see §11's matrix.

## 8. Verification as a first-class workflow (Phase 8)

V2's Inspect → Modify → Verify loop (select wire → edit properties →
read multimeter) is the single clearest transferable behavioral pattern
in the entire study, precisely *because* OEP Engine already has
substantially more capability behind "Verify" than V2's static
per-key-position lookup table:

- `MeasurementEngine`/`ProbePoint` (component- and, per BRIDGE-011 §20.7,
  potentially terminal-precise measurement)
- `VerificationEngine` (relationship/port-referenced checks, already
  consuming the `metadata['sourcePort']`/`['targetPort']` convention
  established in BRIDGE-011)
- `StateConditionResolver`/`InputStateDefinition.topologyEffects`
  (discrete-state-driven topology blocking — the generalized form of
  V2's key-position-driven readings)
- `ValidationEngine`/`AnalysisEngine`/`ReasoningEngine` (the Engineering
  Knowledge Engine's own 8-layer stack, per its constitution)

**Proposed principle:** INSPECT → MODIFY → VERIFY should be a standard
engineering workflow shape across OEP, not specific to Diagram Studio's
electrical domain:

- **Installation**: inspect an installation step's requirements → modify
  its state (mark complete, attach evidence) → verify against
  dependency/requirement relationships (already an Engine-native concept
  — relationships as `RequiresRelationship`/`MinRelationshipCount` per
  the Engine constitution's `RuleEvaluator` vocabulary).
- **Repair/diagnostics**: inspect a fault → modify (record a test
  result) → verify against diagnostic-dependency relationships and
  evidence links — structurally identical to V2's Trace-circuit
  workflow, different domain vocabulary.
- **Maintenance**: inspect a component's due/overdue state → modify
  (log service performed) → verify against maintenance-interval rules.
- **Engineering**: inspect an Engineering Object → modify its
  properties/relationships → verify via `ValidationEngine`.
- **Simulation/Instruments**: this is V2's own domain, already proven.

**This is a UI/workflow-shape recommendation, not an implementation.**
The backend capability already exists for every one of these domains at
the Engine layer (the `RuleEvaluator` primitives are explicitly generic,
per the Engine constitution's "No Hardcoded Engineering Rules"
principle) — what's missing, if anything, is Studio-side UI exposing
that existing capability through the same three-step shape, not new
Engine work. No Engine change is proposed or required by this phase.

## 9. Visual model vs. behavioral model (Phase 9)

Already addressed in full in §2. Restated as the governing rule for this
whole document: **every principle proposed below is a behavioral claim.
None of them requires, implies, or should be read as a mandate to reuse
V2's CSS, iconography, colors, or exact widget dimensions anywhere else
in OEP.** The BRIDGE-011/OEP-UI-001 chrome work already demonstrated the
correct pattern in miniature: OEP's own `StudioColors`/`StudioTheme`
supply the visuals; V2 (and, by extension, this document's proposed
grammar) supplies the behavior.

## 10. Proposed OEP interaction grammar (Phase 10)

1. **Enter a workspace** — via the persistent Navigation Rail /
   `StudioRegistry`, unchanged from today.
2. **Establish context** — open or activate a document/tab (Web Surface
   pattern) or select a top-level scope (e.g. a Repository view) — the
   mechanism is Studio-specific, the *requirement that context be
   explicit and visible* is common.
3. **Find an engineering object** — flat, cross-type search over the
   current context (§3 row 11), mirroring V2's `doSearch`.
4. **Select it** — single, explicit selection (§3 row 3); multi-select
   is an enhancement some Studios may need (Diagram Studio's native
   renderer already had it) but is not part of the common baseline V2
   demonstrates.
5. **Inspect it** — the contextual sidebar/property-surface shows its
   properties, read-first (§4).
6. **Inspect its relationships** — the same contextual surface exposes
   what it's connected to, list-form, each entry itself
   navigable/selectable (V2's wire-list-in-module-inspector).
7. **Modify it** — via a structured editor (inline field, or a modal for
   multi-field structured data — §3 row 12), always through the Engine's
   command stack, never a local-only mutation.
8. **Change modes** — only where direct manipulation and inspection
   genuinely conflict (§6); mode entry/exit is always explicit
   (button/shortcut), never implicit, and Escape always cascades back
   out one layer rather than resetting everything at once.
9. **Perform contextual operations** — surfaced only once something
   relevant is selected, never listed as always-available (§5).
10. **Verify the result** — Inspect → Modify → Verify (§8), reachable
    directly from the modified object/relationship's own context, no
    extra navigation required.
11. **Undo** — always the Engine's real command stack (§1, §3 row 17) —
    never a Studio-local or webview-local undo mechanism.
12. **Save** — always the Engine-backed document lifecycle
    (`saveDocument`/`saveDocumentAs`), never a client-only
    export/download, regardless of what a bridged external tool's own
    native save mechanism looks like.
13. **Move to another object** — via relationship navigation (click a
    related item to re-select it, V2's proven pattern) or via search
    again — both are already "select," not a new primitive.
14. **Move to another workspace/document** — via the tab system (Web
    Surface pattern) where the Studio is multi-document; via the
    Navigation Rail where it is not.
15. **Maintain multiple contexts simultaneously** — via independently-
    alive tabs (`IndexedStack`, proven), only where the Studio's domain
    genuinely benefits from it (§7) — not mandated everywhere.

## 11. Common vs. Studio-specific architecture matrix (Phase 11)

Diagram Studio is the only Studio with a fully verified current
interaction pattern in this codebase (via the Web Surface/V2 bridge).
Installation/Repairers/Maintainers/Engineers Studios, as named in this
task, **are not currently registered or implemented** in
`studio_registry.dart` — they exist only as an aspirational "Studio
family" named in `oep_foundation/CLAUDE.md`'s constitution, which does
not match the actually-implemented Studio set (Knowledge, Diagram,
Acquisition, Engineering Intelligence, Exchange, Copilot — see §13
conflict C1). The columns below for those four Studios are therefore
**projections from the constitution's stated intent and the Five
Primitive Rule, not verified UI audits** — marked accordingly.

| Capability | Common OEP Pattern | Diagram Studio (verified) | Installation Studio (projected) | Repairers Studio (projected) | Maintainers Studio (projected) | Engineers Studio (projected) | Instruments (partially verified) |
|---|---|---|---|---|---|---|---|
| Object selection | COMMON | Module/wire click-select | Step/product/component select | Fault/component/test select | Component select | Engineering Object select | Probe/measurement-point select |
| Contextual sidebar | ADAPTABLE | V2's Inspector pane | Plausible: step details | Plausible: fault details | Plausible: component status | Plausible: object properties | Meter panel is exactly this today |
| Relationship inspection | COMMON | Wire list per module | Dependency/requirement list | Diagnostic-dependency/evidence list | Maintenance-interval relationships | Engineering relationships | Wire/circuit membership |
| Explicit modes | ADAPTABLE | Layout/Wire/Route | Unlikely to need — installation is largely sequential, not spatial | Unlikely — diagnostics is largely sequential | Unlikely | Possible if a spatial/graph editor exists | Lead-placement mode is exactly this today |
| Modal structured editing | OPTIONAL | Module/Wire Properties modals | Plausible for multi-field install records | Plausible for test-result entry | Plausible for service-log entry | Plausible for property editing | Plausible for calibration data |
| Verification workflow | COMMON, ENGINE-BACKED | Multimeter/Trace | Requirement/dependency check | Diagnostic trace (structurally identical to V2's Trace) | Interval-compliance check | `ValidationEngine` | Live measurement (already real) |
| Tabbed multi-document | ADAPTABLE | Web Surface tabs | Plausible if multiple installs open concurrently | Plausible if multiple diagnostic sessions open | Less likely — usually one active job | Plausible | Not applicable — instruments are per-session, not per-document |
| Undo/redo | COMMON, ENGINE-BACKED | Engine command stack (proven via bridge) | Should be Engine command stack | Should be Engine command stack | Should be Engine command stack | Should be Engine command stack | N/A — measurement is read-only |
| Save/document lifecycle | COMMON, ENGINE-BACKED | `DiagramStudioController` | Should be equivalent controller pattern | Should be equivalent | Should be equivalent | Should be equivalent | N/A |
| Search | COMMON | Not yet in Web Surface host chrome itself (V2 has its own internal search) | Plausible | Plausible | Plausible | Plausible | Plausible (find a probe point) |

**This table is deliberately conservative about the four unimplemented
Studios** — it states what the grammar in §10 would predict, not what
has been verified, per the task's own instruction not to assume all
Studios should look identical and not to fabricate parity.

## 12. Architectural recommendation (Phase 12)

**Yes, OEP should adopt this document as a formal architectural
specification**, with the following scope discipline:

- **Purpose**: define the *behavioral* interaction grammar common across
  OEP Studios, so each new Studio starts from a proven shape rather than
  reinventing selection/inspection/verification from nothing — without
  mandating a shared visual system or shared widget library.
- **Scope**: Studio-layer UI/UX architecture only (`platform/oep_studio`).
  Does not touch Engine, Foundation, or Legacy V2.
- **Principles**: §10's 15-step grammar, §5's contextual-vs-global
  command rule, §8's Inspect→Modify→Verify workflow shape.
- **Common primitives**: §3's COMMON and ENGINE-BACKED rows.
- **Studio extension points**: §3's ADAPTABLE/OPTIONAL rows — sidebar
  position, whether tabs are needed, whether explicit modes are needed,
  whether a modal or inline editor is used for a given field.
- **Contextual interaction rules**: §5.
- **Mode rules**: §6's observation that modes are justified only where
  direct manipulation and inspection genuinely conflict — not a default.
- **Relationship rules**: §6 — Relationship is a first-class primitive
  with its own inspection step, never buried inside object properties.
- **Verification rules**: §8.
- **Document/workspace rules**: §7.
- **Global command rules**: §5.
- **Visual-system relationship**: §9 — this document governs behavior
  only; `StudioColors`/`StudioTheme` (already established, per
  `DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md` §21) governs visuals, and
  the two are deliberately independent.

**This document is that specification** (created at
`platform/oep_studio/docs/OEP_INTERACTION_MODEL.md`, confirmed via
directory search that no prior document of this name existed — the two
adjacent, differently-scoped documents found,
`platform/oep_engine/docs/EKE_INTERACTION_MODEL.md` and
`platform/oep_studio/docs/architecture/diagram_studio/
INTERACTION_MODEL.md`, are cited, not duplicated or overwritten).

No universal UI framework/shared widget library is proposed — the study
did not demonstrate one is required; §3/§11 show the right level of
reuse today is a shared *document*, not shared *code*.

## 13. Relationship to existing OEP architecture and constitutions (Phase 13)

**Alignment:**

- **Five Primitive Rule** — direct, non-forced alignment demonstrated in
  §6. This document does not alter the Rule.
- **Engineering Knowledge Engine Constitution** — this document's
  Verify/Undo/Save rules (§8, §3 rows 16-18) explicitly route through
  existing Engine capability rather than proposing new Engine surface
  area, consistent with the constitution's "No Persistence Above
  Foundation" and "Never bypass the Engineering Intelligence Platform"
  principles.
- **`EKE_INTERACTION_MODEL.md`** — this document's §1 explicitly confirms
  and builds on that doc's finding that V2's *implementation mechanism*
  (global mutable variables, no reactive store) is **not** being
  migrated, while its *interaction shape* (single selection, mode
  exclusivity, escape cascade) is worth generalizing — same conclusion,
  now extended platform-wide instead of Engine-scoped.
- **Web Surface Architecture** — §7 explicitly generalizes, rather than
  contradicts, its persistent-workspace/tab-lifetime model.
- **OEP Engineering Constitution (`oep_studio`)** — Article III (Single
  Responsibility) and Article XI (Interoperability, "communicate through
  published contracts") are respected: this document does not propose
  merging Studio-specific UI responsibilities, only a shared behavioral
  vocabulary.

**Conflicts / open decisions (documented, not silently resolved):**

- **C1 — Studio family mismatch.** `oep_foundation/CLAUDE.md`'s
  constitution names a "Current Studio family" (Installation, Service,
  Maintenance, Engineering, Inspection, Operations, Training,
  Administration Studios) that does not match what is actually
  registered in `studio_registry.dart` today (Knowledge, Diagram,
  Acquisition, Engineering Intelligence, Exchange, Copilot, plus core
  platform pages — no Installation/Repairers/Maintainers/Engineers
  Studio exists as code). This is a pre-existing documentation-vs-
  implementation gap, not created by this study, but it means §11's
  matrix columns for those four Studios are necessarily projections.
  **This document does not resolve C1** — it is a constitution-level
  question outside this task's scope (this task must not rewrite that
  document) and is flagged here for separate architectural review.
- **C2 — stale Studio-specific interaction doc.**
  `platform/oep_studio/docs/architecture/diagram_studio/
  INTERACTION_MODEL.md` documents `diagram_studio_page.dart`/
  `graph_view_panel.dart`, both deleted in AP-DIAGRAM-V2-BRIDGE-010. It
  is not rewritten by this task (out of scope — "do not rewrite those
  documents" applies to constitutions, and this doc is adjacent
  Diagram-Studio-specific prior art, not one of the named constitutions,
  but it is left untouched here regardless, since correcting it is not
  this task's scope). **Flagged for a follow-up documentation task**:
  either mark it explicitly superseded by
  `DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`, or delete it now that
  the code it describes no longer exists.
- **C3 — Web Surface Studio-status still open.** The Web Surface
  architecture doc's own §22 leaves unresolved whether
  `WebSurfacesHostPage` should be a true top-level Studio sibling to
  Diagram Studio or embedded elsewhere. This document's §7/§11 assume
  today's actual routing (`/diagram` → `WebSurfacesHostPage`) without
  taking a position on that open question — it is out of scope here.

**No STOP CONDITION was triggered**: V2's interaction model does not
conflict with the Five Primitive Rule (§6 shows direct alignment); no
existing *ratified* Studio-wide interaction model contradicts this
proposal (the one adjacent doc that could compete, C2, describes
retired code and was never platform-wide in scope); this document does
not force unlike Studio workflows into one UI (§11's ADAPTABLE/
STUDIO-SPECIFIC classifications explicitly preserve difference); and
every rule proposed routes through existing Engine capability (§3 rows
16-18, §8) rather than requiring Engine changes.

## 14. Final deliverable index

1. V2 behavioral interaction model — §1.
2. V2 visual-vs-behavioral separation — §2, §9.
3. Common OEP interaction primitives — §3.
4. Common vs. Studio-specific matrix — §11.
5. Sidebar/context model — §4.
6. Mode model — §6 (modes), §5 (mode-specific actions).
7. Object/relationship interaction model — §6.
8. Workspace/document model — §7.
9. Verification workflow model — §8.
10. Proposed OEP interaction grammar — §10.
11. Recommended OEP-wide principles — §12.
12. Recommended Studio extension points — §12 ("Studio extension
    points"), §3 ADAPTABLE/OPTIONAL rows.
13. Command-palette disposition — §5.
14. Relationship to Five Primitive Rule — §6, §13.
15. Relationship to existing OEP architecture — §13.
16. Conflicts/open decisions — §13 (C1, C2, C3).
17. Recommended specification/documentation — this document itself
    (§12).
18. Whether an OEP Interaction Model should become a formal
    architectural document — **yes**, per §12, pending ratification
    review (this document is proposed, not self-ratifying).
19. Recommended next implementation phase — **none proposed as
    mandatory**; if pursued, the lowest-risk next step would be a
    Studio-by-Studio interaction audit of Knowledge Studio and
    Acquisition Studio (the two most UI-mature Studios besides Diagram
    Studio) against §3/§10, to convert §11's "projected" columns into
    verified ones before any further architectural commitment — not a
    universal-component build, and not a new Studio implementation.

---

## 15. Verification audit (AP-OEP-INTERACTION-MODEL-002)

**Status of this section: evidence recorded, findings applied as status
tags below. Sections 3/10/11 above are left textually unchanged — this
section does not silently rewrite them; it records what direct code
audit of Knowledge Studio and Acquisition Studio actually found, and
narrows this document's claims accordingly.**

### 15.1 Method

Full source audits of `platform/oep_studio/lib/knowledge/` (7-panel
`KnowledgeStudioPage`, `FoundationRuntimeNotifier`/`FoundationServiceState`,
40+ models) and `platform/oep_studio/lib/acquisition/`
(`AcquisitionStudioPage`, `AcquisitionRuntimeNotifier`,
`AcquisitionSelectionNotifier`, EAM pipeline models), plus the platform
Command Framework (`core/commands/command_registry.dart`,
`app/widgets/command_palette_dialog.dart`). 81 existing tests
(`test/acquisition/*`, `test/knowledge_*_test.dart`) re-run — **81/81
passed**, confirming the audited behavior matches tested behavior, not
just doc-comment claims.

### 15.2 Knowledge Studio — headline finding

Knowledge Studio's **true native pattern is QUEUE-REVIEW +
BATCH-COMMIT, not a single-object SELECT→INSPECT→RELATE→MODIFY→VERIFY
loop.** SELECT and INSPECT map directly (single, mutually-exclusive
selection across 9+ object types, funneled into one shared, display-only
`PropertyInspectorPanel`, exactly matching Section 3/4 above). RELATE
and MODIFY are real but **dialog-mediated, not in-place/direct-
manipulation** (`LinkEvidenceDialog`, `KnowledgeCandidateFormDialog`) —
the opposite texture from a canvas-drag relate/modify gesture. VERIFY is
real but is a **continuously-visible property of every candidate**
(status, validation result, AI confidence, evidence-link count shown
simultaneously in list rows), not a terminal step a user invokes after
modifying one object — the one true user-invoked terminal verification
gate is a **session-wide, batched Commit**, which involves no object
selection at all. The one genuine direct-manipulation surface (drag to
draw an Evidence Region on a PDF) sits outside the Select→Inspect loop
entirely — it is a creation gesture, not a manipulation of a selected
object.

### 15.3 Acquisition Studio — headline finding

Acquisition Studio's **true native pattern is a linear, forward-only
pipeline/state-machine** (Source → Job → Download → Verify → Extract
Metadata → Publish [immutable]), run either via a guided Wizard
(`AcquisitionWizardController.run()`, fully automatic) or via per-row
forward-only action buttons. It **does not fit the proposed grammar**:
SELECT and (display-only) INSPECT exist, but selecting an object's
purpose is to view it or advance its pipeline stage — never to modify
it. **MODIFY of an existing object is NOT PRESENT anywhere in this
Studio** — the only editing is record *creation* via modal dialog;
`VaultEntryRecord` is explicitly immutable by design once published.
RELATE is essentially absent (flat foreign-key-to-name lookups only, no
relationship browser, no click-through between pipeline stages of
different jobs). VERIFY is real and genuinely load-bearing (SHA-256
integrity check, hard-gating each pipeline stage) but is a **fixed-
position pipeline gate**, always in the same place in the sequence, not
a flexible action invoked on an arbitrary selected/related object. Undo
is confirmed **NOT PRESENT and not meaningful** — job state only moves
forward, vault entries are immutable, and the code does not pretend
otherwise. Save/document lifecycle is **NOT PRESENT** in the Engine-
backed sense — there is no local "unsaved" state at all; every mutating
action commits immediately to the EAM REST backend, closer to a
database/queue client than a document editor. Critically: **the bridge
from an acquired artifact back into an Engineering Object usable
elsewhere in OEP does not exist yet** — the code discloses this
candidly (wizard log: "Knowledge Extraction: not yet available
(Knowledge Engine not built)") rather than fabricating it.

### 15.4 Three-Studio comparison matrix

| Capability | Diagram Studio / V2 | Knowledge Studio | Acquisition Studio |
|---|---|---|---|
| Workspace | COMMON (canvas) | COMMON (7-panel fixed layout) | COMMON (3 dashboards + drill-down) |
| Context | Document (V2 diagram) | Session (`KnowledgeSession`) | Job/source/artifact triple, no single context |
| Object | Module/wire | Candidate/source/region/entity (heterogeneous) | Source/Job/Artifact (pipeline record) |
| Relationship | First-class (wire) | Evidence links + relationship candidates (dialog-mediated) | NOT PRESENT as first-class — FK-to-name only |
| Selection | COMMON, single | COMMON, single, mutually exclusive across many kinds | COMMON, single, mutually exclusive across 3 kinds |
| Inspection | COMMON (sidebar) | COMMON (shared `PropertyInspectorPanel`, display-only) | COMMON (same shared panel, display-only) |
| Contextual sidebar | COMMON | COMMON | ADAPTABLE — closer to a job-drilldown log viewer than a property sidebar |
| Property editing | Modal (V2) | Modal only, never inline (confirms row 5's ADAPTABLE call) | Modal, creation only — no edit-existing path at all |
| Modal editing | OPTIONAL, used | OPTIONAL, used heavily | OPTIONAL, used only for creation |
| Modes | ADAPTABLE, real (V2) | NOT PRESENT — confirmed mode-free | NOT PRESENT — confirmed mode-free |
| Search | COMMON (V2 internal) | COMMON (global + local list filter) | ADAPTABLE — global search present, no local filter/search in-panel |
| Direct manipulation | ADAPTABLE, central (V2 canvas) | STUDIO-SPECIFIC — one narrow surface (evidence-region drawing), not general | NOT PRESENT — zero drag/drop anywhere |
| Verification | COMMON, ENGINE-BACKED | COMMON, ENGINE-BACKED, continuous not terminal | COMMON, ENGINE-BACKED, fixed pipeline gate not flexible |
| Undo/redo | COMMON, ENGINE-BACKED, proven via bridge | NOT PRESENT | NOT PRESENT, and not a meaningful concept for this domain |
| Document lifecycle | COMMON, ENGINE-BACKED (`saveDocument`) | ADAPTABLE — autosave-on-mutation + separate one-shot transactional Commit | NOT PRESENT in the document sense — REST-backed, always-synced, no local dirty state |
| Tabs | ADAPTABLE (Web Surface) | NOT PRESENT (one in-panel tab strip only, Candidates/Relationships) | NOT PRESENT |
| Global commands | Command Palette (platform-wide) | Command Palette | Command Palette |
| Contextual commands | Sidebar action buttons (V2) | Row-level Accept/Reject/Edit/Delete buttons | Row-level Acquire/Verify/Extract/Publish buttons |
| Destructive actions | Confirm dialog (V2 `confirm()`) | Confirm dialog pattern (commit confirmation states "cannot be undone") | No delete path found; Cancel is a forward state transition, not a delete |

### 15.5 15-step grammar verification (Section 10 tested against real Studios)

| Step | Diagram Studio / V2 | Knowledge Studio | Acquisition Studio |
|---|---|---|---|
| 1. Enter workspace | DIRECT | DIRECT | DIRECT |
| 2. Establish context | DIRECT (open/create document) | DIRECT (create/open session) | STUDIO-SPECIFIC (no single context — endpoint x selected job x selected object) |
| 3. Find an object | DIRECT (V2 search) | DIRECT (global + local filter) | ADAPTABLE (global search only, no in-panel filter) |
| 4. Select it | DIRECT | DIRECT | DIRECT |
| 5. Inspect it | DIRECT | DIRECT | DIRECT (display-only, same shared panel) |
| 6. Inspect relationships | DIRECT | ADAPTABLE (dialog-mediated, two distinct relationship kinds) | STUDIO-SPECIFIC (FK-name lookup only, no relationship browser) |
| 7. Modify it | DIRECT (modal) | ADAPTABLE (modal only, never inline) | NOT PRESENT for existing objects — creation only |
| 8. Change mode | DIRECT (V2 modes) | NOT PRESENT (confirmed mode-free) | NOT PRESENT (confirmed mode-free) |
| 9. Contextual operations | DIRECT | DIRECT (row-level Accept/Reject/etc.) | DIRECT (row-level pipeline-stage buttons) |
| 10. Verify | DIRECT (terminal, per-object) | ADAPTABLE (continuous, not terminal) | ADAPTABLE (fixed-position pipeline gate, not flexible) |
| 11. Undo | DIRECT (Engine command stack) | NOT PRESENT | NOT PRESENT — not meaningful for this domain |
| 12. Save | DIRECT (Engine-backed) | ADAPTABLE (autosave + separate batched commit) | NOT PRESENT — always-synced REST state, no save concept |
| 13. Move to another object | DIRECT (relationship navigation) | ADAPTABLE (candidate list, evidence-link click-through) | STUDIO-SPECIFIC (Job to Source name only, no reverse or lateral navigation) |
| 14. Move to another workspace/document | DIRECT (Web Surface tabs) | N/A — single fixed page, no sub-navigation | N/A — single fixed page, Wizard is a separate full route |
| 15. Maintain multiple contexts | DIRECT (Web Surface `IndexedStack`) | NOT PRESENT (one active session at a time) | NOT PRESENT (one selection surface, though multiple jobs run concurrently server-side) |

### 15.6 Genuine contradictions (Phase 6 test — not merely differences)

Applying the task's own bar ("a contradiction means the proposed common
rule would actively make the existing workflow worse or impossible," not
"looks different"):

- **No genuine contradiction found for MODIFY.** Acquisition Studio has
  no in-place edit of an existing object, but this is not the proposed
  grammar breaking the Studio — a mandatory inline-edit rule was never
  proposed (property editing was already classified ADAPTABLE in
  Section 3, correctly anticipating this). Not a contradiction; a
  confirmation that the ADAPTABLE classification was the right call.
- **No genuine contradiction found for MODES.** Both real Studios are
  mode-free, and Section 3's modes row already classified modes as
  ADAPTABLE, not COMMON — the model never claimed every Studio needs
  modes. Not a contradiction; further confirmation.
- **No genuine contradiction found for UNDO.** Acquisition Studio has no
  undo because forward-only job state and immutable vault entries make
  undo semantically meaningless, not merely unimplemented. Section 3's
  undo/redo claim was "every Studio should route through the Engine's
  command stack, never invent its own" — Acquisition Studio does not
  violate this (it has no local mutable state to have a command stack
  over in the first place). Not a contradiction; a domain boundary the
  original document did not anticipate but does not conflict with.
- **A genuine tension, not quite a contradiction, exists for VERIFY.**
  Section 8's Inspect→Modify→Verify shape implies Verify is a step a
  user reaches by first selecting and modifying an object. In both real
  Studios, verification is either continuous (Knowledge) or a fixed
  pipeline position independent of any particular selection
  (Acquisition) — never "verify the thing I just modified." **This
  narrows Section 8's claim**: Verify is confirmed as a common,
  Engine-backed concept, but "Inspect→Modify→Verify" as a strict
  three-step sequence tied to one object's selection state does **not**
  generalize; it is now understood as **Diagram-Studio/V2-specific
  sequencing** of a more general, always-true principle ("verification
  is a first-class, Engine-backed concern," which does hold everywhere).
- **A genuine tension exists for RELATE-by-direct-manipulation.**
  Section 4 and step 6 of Section 10 implicitly carry V2's texture
  (click a related item to navigate to it, drag to create a
  relationship). Real Studios relate objects through dialogs or flat
  lookups, never direct manipulation. This does not make relationship-
  inspection itself wrong (it holds in all three Studios) but it
  retracts any implicit claim that relating objects should be a
  *direct-manipulation* gesture platform-wide — that was never
  explicitly claimed in Section 3 (relationship inspection was already
  COMMON; relationship editing was already correctly marked
  ENGINE-BACKED BUT UI-SPECIFIC) but is worth stating explicitly now
  that it's tested.

**No STOP-CONDITION-grade contradiction exists.** Nothing found would
make an existing Studio's workflow worse or impossible if this document
were adopted, because the document's COMMON claims (selection,
inspection, relationship-as-a-concept, verification-as-a-concept,
Engine-backed undo/save) all independently held across all three
Studios, and everything that varies (modes, direct manipulation, exact
verify sequencing, exact relate mechanism) was already correctly scoped
as ADAPTABLE/OPTIONAL/STUDIO-SPECIFIC rather than COMMON.

### 15.7 What actually generalizes (Phase 7 reclassification)

**A. Strongly validated OEP-wide principles** (held, unforced, across
all three real Studios):
- Single, mutually-exclusive object selection.
- A shared, display-only, selection-driven inspection surface — literally
  the *same* `PropertyInspectorPanel` class across Diagram/Knowledge/
  Acquisition, not just an analogous pattern.
- Relationship is a meaningful, inspectable concept everywhere, even
  where the UI for it is thin.
- Engine-backed verification as a standing concern, not a Studio
  invention — **downgraded from "terminal step in a fixed sequence" to
  "a property that must be surfaced, whose exact timing is
  Studio-specific."**
- Command Palette scoped to global/document-level commands, contextual
  actions kept off it — confirmed by `command_registry.dart`'s own doc
  comments explicitly deferring contextual/scoped commands as
  out-of-scope for the framework today.
- Search as a cross-object, jump-to-select capability — present in some
  form in all three, though local-filter maturity varies.

**B. Valid but adaptable by Studio** (real, but the mechanism differs
enough that no shared component should be assumed):
- Property editing surface (modal vs. inline vs. absent), now with three
  data points instead of zero.
- Save/document lifecycle mechanism (Engine document / session-autosave
  plus batch-commit / always-synced REST), now confirmed to have three
  genuinely different shapes, not one shape with cosmetic variation.
- Contextual action surface content (row-level buttons vs. sidebar
  action buttons vs. pipeline-stage buttons) — same underlying rule,
  different surfaces.
- Whether "the current context" is a single document, a session, or a
  multi-pointer tuple — all three are real, none should be forced onto
  the others.

**C. Diagram-Studio/V2-specific** (do not generalize; the audit narrows
these from the original proposal):
- Explicit, mutually-exclusive interaction modes — already correctly
  scoped ADAPTABLE, now confirmed genuinely V2/Diagram-only among the
  three real Studios.
- Direct manipulation as a general-purpose object-editing gesture —
  confirmed present only narrowly, and only for object *creation*, in
  the other two Studios.
- Strict "Inspect→Modify→Verify" as a three-step sequence gated by one
  object's selection — retained as valid V2/Diagram-Studio behavior, no
  longer claimed as the universal shape; see 15.6.
- Relate-by-direct-manipulation (dragging to connect) — confirmed
  V2-specific; other Studios relate via dialog or flat lookup.

**D. Not yet sufficiently evidenced** (unchanged from the original
document — this audit did not touch these):
- Everything in Section 11's original matrix concerning Installation/
  Repairers/Maintainers/Engineers Studios remains NOT YET PROVEN — those
  Studios still do not exist as code (confirmed still true; no new
  registry entries were found during this audit).
- Whether Undo/Redo should ever be retrofitted into Knowledge/
  Acquisition Studio — genuinely open; this audit found it absent and
  arguably unneeded (Acquisition) or acceptable-as-is given autosave
  (Knowledge), not that it's missing and should be added.

### 15.8 Five Primitive Rule alignment (Phase 8 re-test)

- **Fits directly**: Knowledge Studio's `KnowledgeCandidate` to
  `EngineeringEntity`/eventual Engineering Object,
  `RelationshipCandidate` to Relationship, and its Commit step producing
  real repository objects, is a textbook direct instance of the
  Object/Relationship primitives — arguably a *cleaner* fit than V2's
  module/wire mapping, since Knowledge Studio's candidates are
  explicitly pre-primitives awaiting promotion.
- **Requires adaptation**: Acquisition Studio's pipeline records
  (`OfficialSource`, `AcquisitionJob`, `VerificationRecord`,
  `VaultEntryRecord`) are **not currently Engineering Objects at all**
  — confirmed by `AcquisitionSelection`'s own doc comment: "come from
  EAM's REST API and have no Foundation representation at all." They
  could in principle be expressed as Objects/Events (an `AcquisitionJob`
  as an Operation, a completed download as an Event) but are not today.
  This is exactly the gap the task's own Phase 3 asked about, and the
  honest answer is: **that bridge does not exist yet** — Wizard steps
  7-8 are inert UI shells waiting on a "Knowledge Engine" the code
  itself says is not built.
- **Does not apply**: nothing found in either Studio actively conflicts
  with the Five Primitive Rule — Acquisition Studio's gap is an
  *absence* of primitive-expression (not-yet-implemented), not a
  *violation* of it (no code models something as a sixth primitive type
  or bypasses the primitives with ad hoc data).
- **No conflict with the Five Primitive Rule was found in either
  Studio.** The Rule is not altered by this audit.

### 15.9 Command-palette findings (Phase 9)

`command_registry.dart`'s own doc comments explicitly and repeatedly
defer contextual/scoped command support as "out of scope for this Work
Package" — i.e., the Command Framework's own authors already
independently arrived at the same contextual-vs-global split this
document proposes in Section 5, **before** this document existed.
`command_palette_dialog.dart`'s doc comment confirms the palette "never
registers a command, never holds its own copy of command/capability
metadata, and never calls a Studio method directly" — it is a pure
global/document-level command surface, consistent with Section 5's rule.
**Section 5's rule holds, unmodified, confirmed independently by the
existing Command Framework's own design intent.**

### 15.10 Web Surface findings (Phase 10)

Evidence from this and prior audits (BRIDGE-011, OEP-UI-001) supports:
**Web Surface = presentation technology, not a Studio interaction
model.** The Web Surface architecture (`WebSurface`/
`WebSurfaceTabsController`/`WebSurfaceView`) defines *how content is
hosted* (a webview, kept alive in an `IndexedStack`, with a structural
trust boundary) — it says nothing about selection, inspection,
relationships, modes, or verification; those are supplied entirely by
whatever is inside the surface (V2, in Diagram Studio's case). Knowledge
and Acquisition Studios, by contrast, are native Flutter Studios with no
Web Surface involvement at all, yet both independently converge on the
same selection/inspection primitives V2 uses — which is evidence *for*
this document's core claim (a common interaction grammar exists
independent of presentation technology) and *against* conflating "Web
Surface" with "the interaction model." The open question flagged in the
original document's Section 13 (C3 — whether `WebSurfacesHostPage`
should be a true top-level Studio) remains genuinely open and is not
resolved by this finding either way; this audit did not touch Web
Surface architecture code.

### 15.11 Conclusion

**OEP_INTERACTION_MODEL.md remains the correct formal interaction
architecture reference for OEP**, with its scope narrowed rather than
expanded by this audit: the COMMON claims in Section 3 held up under
direct testing against two real, structurally different Studios (a
review-queue-into-batch-commit pipeline and a job-orchestration
dashboard), neither of which resembles Diagram Studio/V2's canvas shape
— that is meaningfully stronger evidence than the original document had
(which was tested only against V2 itself). The one substantive
correction is Section 15.6/15.7's narrowing of "Inspect→Modify→Verify"
from a mandatory three-step per-object sequence to "verification is a
common, Engine-backed concern whose exact sequencing is Studio-
specific" — this document does not silently rewrite Section 8's
original wording, but Section 15 should now be read as the authoritative
refinement of that claim.
