# OEP Studio Architecture — Taxonomy & Constitution Reconciliation
## (AP-OEP-STUDIO-ARCHITECTURE-001)

**Status: PROPOSED — PENDING RATIFICATION.** This document does not
overrule any existing ratified constitution. Where it conflicts with
`platform/oep_foundation/CLAUDE.md` or
`platform/oep_studio/docs/PLATFORM_ARCHITECTURE.md`, that conflict is
recorded explicitly (§11) and left for constitutional review, not
silently resolved here.

---

## 1. Purpose

To establish one place that states, with evidence, what "Studio" means
in this codebase today, which Studios actually exist, which are only
named in documentation, and how those two sets relate — because no
single existing document currently does this, and three different
documents currently name three different, mutually inconsistent Studio
lists (§4).

## 2. Studio definition

No existing ratified document defines "Studio" with a single, precise
sentence. The closest working definitions found:

- `oep_foundation/CLAUDE.md`: "Studios are workflow applications. Studios
  are **not** industries. Studios represent professional activities."
- `oep_foundation/PROJECT_MEMORY.md`: "Studios represent professional
  workflows. Studios do not represent industries."
- `platform/oep_studio/docs/PLATFORM_ARCHITECTURE.md`: frames Studios as
  the layer between "Shared Platform Services" and "Engineering
  Repositories" in a `Users → Platform Shell → Studio Framework →
  Shared Platform Services → Engineering Studios → Engineering
  Repositories → Engineering Data` stack — i.e., architecturally, a
  Studio is a consumer application layer over shared platform services,
  not itself a data layer.
- In code (`studio_registry.dart`), a Studio is operationally: an entry
  in `StudioRegistry.defaultRegistry` — a `StudioDestination` enum value
  paired with a `pageBuilder`, reachable from the persistent Navigation
  Rail, optionally with a `settingsProvider`, `searchProvider`, and a
  list of `CapabilityDescriptor`s.

**Working definition adopted by this document** (synthesizing the
above, not inventing new language): *A Studio is a registered, top-level,
Navigation-Rail-reachable workspace representing one professional
engineering activity, implemented as a `StudioDescriptor` in
`StudioRegistry`.* This is a description of what the code already does,
not a new rule.

## 3. Studio taxonomy — as actually implemented (Phase 1)

Source of truth: `platform/oep_studio/lib/core/routing/studio_destination.dart`
+ `studio_registry.dart`. 17 `StudioDestination` values, each a
Navigation-Rail entry:

| Destination | Route | Label (exact) | Status | Web-Surface-backed? | Native? | Documented role? |
|---|---|---|---|---|---|---|
| `dashboard` | `/` | Dashboard | Production | No | Yes | Platform home, not a "Studio" per its own code comment |
| `projectExplorer` | `/project` | Project Explorer | Production | No | Yes | Core platform page |
| `knowledge` | `/knowledge` | **Knowledge Studio** | Production | No | Yes | Yes — audited in AP-OEP-INTERACTION-MODEL-002 |
| `diagram` | `/diagram` | **Diagram Studio** | Production | **Yes** — `WebSurfacesHostPage(autoOpenLegacyV2: true)` | No (native renderer retired, BRIDGE-010) | Yes — extensively documented (`DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`) |
| `acquisition` | `/acquisition` | **Engineering Acquisition** (label does *not* contain the word "Studio") | Production | No | Yes | Yes — audited in AP-OEP-INTERACTION-MODEL-002 |
| `repository` | `/repository` | Repository | Production | No | Yes | Core platform page |
| `objects` | `/objects` | Objects | Production | No | Yes | Core platform page |
| `relationships` | `/relationships` | Relationships | Production | No | Yes | Core platform page |
| `search` | `/search` | Search | Production | No | Yes | Core platform page |
| `graph` | `/graph` | Graph | Production | No | Yes | Core platform page |
| `validation` | `/validation` | Validation | Production | No | Yes | Core platform page |
| `packages` | `/packages` | Packages | Production | No | Yes | Core platform page |
| `engineeringIntelligence` | `/engineering-intelligence` | Engineering Intelligence | Production | No | Yes | Maps to the Engine's 8-layer stack |
| `exchange` | `/exchange` | Engineering Exchange | Production | No | Yes | Marketplace-style Studio |
| `copilot` | `/copilot` | AI Engineering Copilot | Production | No | Yes | Core platform page |
| `diagramClassic` | `/diagram-classic` | Engineering Workbench (Perspectives) | Production, **deliberately excluded from Nav Rail** | No | Yes | Retained only to host the Engineering and Instruments Perspectives (comment in `studio_destination.dart`) |
| `settings` | `/settings` | Settings | Production | No | Yes | Core platform page |

**Explicitly NOT registered as a `StudioDestination` today**: `Web
Surfaces` as a standalone destination. §6 documents this in detail —
it is a real, drifted finding, not an assumption.

**Explicitly NOT present anywhere in code**: Installation Studio,
Repairers Studio, Maintainers Studio, Engineers Studio, Service Studio,
Maintenance Studio, Inspection Studio, Operations Studio, Training
Studio, Administration Studio, Engineering Studio (as a distinct
destination — `Engineering Intelligence` and `Engineering Workbench`
are the only "Engineering"-named destinations that exist, and neither
is named "Engineering Studio").

## 4. Studio taxonomy — as named in architecture documents (Phase 2)

Three separate, non-identical lists exist in ratified or near-ratified
documents, none of which matches §3's actual registry:

**List 1 — `platform/oep_foundation/CLAUDE.md`** (Engineering Development
Constitution, "Version 1.0," Authority: Divad Technology Group) and its
near-duplicate in `platform/oep_foundation/PROJECT_MEMORY.md`:

> "Current Studio family: Installation Studio, Service Studio,
> Maintenance Studio, Engineering Studio, Inspection Studio, Operations
> Studio, Training Studio, Administration Studio."

`PROJECT_MEMORY.md` additionally states: "The first commercial
implementation of OEP is Installation Studio. Installation Studio
targets independent installation professionals" — i.e., this list is
presented as the *product roadmap*, not as a description of what
exists in `oep_studio` today.

**List 2 — `platform/oep_studio/docs/PLATFORM_ARCHITECTURE.md`**
("Document Status: Ratified," Version 1.0.0, Scope: Entire Platform):

> "Examples include: Engineering Acquisition, Engineering Knowledge,
> Engineering Review, Engineering Publishing, Engineering Exchange,
> Installation Studio, Repair Studio, Diagnostics Studio."

This document separately names speculative future Studios (its own
wording, not adopted here): "Simulation Studio, CAD Studio, PCB Studio,
Robotics Studio, Manufacturing Studio, AI Engineering Studio, Compliance
Studio."

**List 3 — actual code (§3)**: Dashboard, Project Explorer, Knowledge
Studio, Diagram Studio, Engineering Acquisition, Repository, Objects,
Relationships, Search, Graph, Validation, Packages, Engineering
Intelligence, Engineering Exchange, AI Engineering Copilot, Engineering
Workbench (Perspectives), Settings.

**No two of these three lists agree.** List 1 and List 2 share zero
exact names (List 2's "Installation Studio" matches List 1's wording,
but List 2 additionally has "Repair Studio"/"Diagnostics Studio" where
List 1 has "Service Studio"/"Maintenance Studio"/"Inspection Studio" —
not obviously the same taxonomy, just adjacent vocabulary). List 3
shares only "Knowledge"/"Acquisition"/"Exchange"-flavored names with
List 2, in different exact wording ("Engineering Knowledge" vs.
"Knowledge Studio"; "Engineering Acquisition" is actually an exact match
to List 3's real label). List 3 shares nothing with List 1.

**`OEP_INTERACTION_MODEL.md` already flagged part of this** (its own
§13, conflict "C1") as an open, unresolved documentation-vs-
implementation gap — this document confirms C1, extends it to a
three-way (not two-way) mismatch by locating List 2, and does not
resolve it either (§14).

## 5. Historical naming reconciliation (Phase 5)

Evidence-based, not assumed:

- **"Engineering Studio" (List 1)** — no code, no other document, ever
  implements or references a destination by this exact name. The
  closest code concepts are `Engineering Intelligence` (a real,
  registered destination with 8 capabilities mapping to the Engine's
  layer stack) and `Engineering Workbench` (the retained multi-
  Perspective shell). Neither is a renaming of "Engineering Studio" —
  no document states one became the other. **Classification: separate
  concept, or List 1's item is a still-unbuilt future Studio distinct
  from either.**
- **"Installer's Studio" / "Installation Studio" (Lists 1 and 2, same
  wording in both)** — the only Studio name that appears, worded
  identically, in *two* of the three lists. `PROJECT_MEMORY.md`
  explicitly calls it "the first commercial implementation of OEP." No
  code implements it. **Classification: PLANNED — the one name with the
  strongest cross-document consensus, despite zero implementation.**
  This document deliberately does not use "Installer's Studio" (a
  phrasing that appeared only inside the prior AP-OEP-INTERACTION-
  MODEL-001 task prompt, not in any actual repository document) — no
  evidence found for that exact wording anywhere in the repo.
- **"Repairers Studio" / "Repair Studio"** — List 2 has "Repair Studio"
  (no "-ers"). List 1 has neither "Repairers" nor "Repair" — it has
  "Service Studio." No document uses "Repairers Studio" verbatim.
  **Classification: List 2's "Repair Studio" and List 1's "Service
  Studio" are plausibly the same underlying concept under different
  names (documentation drift between the two lists), not confirmed
  identical, not confirmed separate — genuinely ambiguous (§11, class
  D).**
- **"Maintainers Studio" / "Maintenance Studio"** — List 1 has
  "Maintenance Studio." List 2 has neither this nor "Maintainers
  Studio." **Classification: List-1-only concept, PLANNED, not
  cross-referenced elsewhere.**
- **"Engineers Studio"** — appears in none of the three lists verbatim.
  **Classification: not evidenced anywhere in the repository as a named
  concept** (it was named in the prior AP-OEP-INTERACTION-MODEL-001
  task prompt as an example, not sourced from repo documentation — this
  document does not treat it as a real planned Studio absent that
  evidence).
- **"Knowledge Studio"** — List 2 uses "Engineering Knowledge" (no
  "Studio" suffix); code uses "Knowledge Studio" exactly. **Classification:
  RENAMED or simply List 2 using a shorter/different label for the same
  implemented concept — the underlying capability (source ingestion,
  candidate review, evidence linking) matches List 2's "Engineering
  Knowledge" description closely enough that this is very likely the
  same concept under two names, not two concepts. Confidence: high, but
  not textually proven by an explicit rename note anywhere.**
- **"Acquisition Studio"** — this exact phrase (with "Studio") appears
  in the prior AP-OEP-INTERACTION-MODEL-002 task prompt and this
  session's own prior audit findings, but the actual registered label is
  **"Engineering Acquisition"** (no "Studio" suffix, confirmed directly
  from `studio_destination.dart` line 29) — matching List 2's
  "Engineering Acquisition" exactly. **Classification: "Acquisition
  Studio" is informal/conversational shorthand this session (and
  presumably others) have used for what the code and List 2 both
  actually call "Engineering Acquisition." Not a renaming — the code
  was never called "Acquisition Studio."** This document flags the
  informal usage so future documents use the exact registered label.
- **"Diagram Studio"** — see §7, a dedicated phase.
- **"Web Surfaces"** — see §6, a dedicated phase.

## 6. Web Surface classification (Phase 6)

**Classification: B — a presentation technology**, with one qualifying
nuance evidenced by a real drift finding (below), confirming and
extending `OEP_INTERACTION_MODEL.md` §15.10's prior conclusion.

Evidence:

1. `WebSurface`/`WebSurfaceTabsController`/`WebSurfaceView` define *how
   content is hosted* (a Chromium webview kept alive in an
   `IndexedStack`, with a structural trust boundary,
   `bridgeAuthorized` as a derived, non-settable property) — nothing
   about selection, inspection, modes, or verification. Those are
   supplied entirely by whatever is loaded inside the surface.
2. Diagram Studio is the only Studio that is Web-Surface-backed today
   (`/diagram` → `WebSurfacesHostPage(autoOpenLegacyV2: true)`).
   Knowledge Studio and Engineering Acquisition are native Flutter with
   no Web Surface involvement, yet (per AP-OEP-INTERACTION-MODEL-002)
   both independently converge on the same selection/inspection
   primitives V2 uses — direct evidence that the interaction grammar is
   independent of Web Surface as a presentation mechanism.
3. **Real drift finding, new to this audit**: `OEP_STUDIO_WEB_SURFACE_
   ARCHITECTURE.md` (§27 of that document) states a
   `StudioDestination.webSurfaces` entry (`'Web Surfaces'`,
   `/web-surfaces`) **was added** as its own top-level Nav-Rail Studio,
   "the same mechanism every other top-level Studio... already uses."
   Direct code inspection of the current
   `platform/oep_studio/lib/core/routing/studio_destination.dart`
   confirms **no such entry exists today** — the enum has 17 values
   (§3), none named `webSurfaces`, and a repo-wide grep for
   `/web-surfaces`/`webSurfaces` outside that one doc and
   `web_surfaces_host_page.dart` itself returns nothing. The same
   document, in a different section (its own §22, written earlier),
   separately states whether `WebSurfacesHostPage` should become a
   registered `StudioDestination` "is a product decision this document
   does not make" — i.e., the document is internally inconsistent
   across its own sections, most likely reflecting different points in
   the feature's history (added, then apparently later removed or
   never actually merged, when `/diagram` became the auto-open host in
   AP-DIAGRAM-V2-BRIDGE-002) without a final correction note.
   **Classification of this specific drift: B — implementation is
   correct (Web Surfaces is reachable only via `/diagram` today, not as
   its own Nav Rail entry), documentation is stale on this one point.**
   This document does not correct `OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md`
   directly (out of this task's scope — only documentation *may* be
   modified, and correcting a different ratified document's internal
   history is a separate, more invasive edit than this task's minimum);
   it is recorded here as an open item (§18).
4. **Conclusion, confirming and sharpening prior work**: Web Surface is
   a presentation technology (classification B), *capable of backing a
   Studio* (as it does for Diagram Studio today) but not itself a
   Studio, and not currently independently registered as one — meaning
   the honest current answer to "is Web Surfaces a Studio" is simply
   **no, not today, and the one document that once said otherwise is
   itself out of date.**

## 7. Diagram Studio status (Phase 7)

**The name "Diagram Studio" remains architecturally correct.** No
existing architecture requires renaming it. Reasoning:

- The Studio/presentation-technology distinction this document adopts
  (§2, §6) is exactly what makes this non-contradictory: "Diagram
  Studio" names the *workspace/professional-activity* (authoring and
  understanding wiring diagrams), while Legacy V2 (via a Web Surface) is
  merely its current *presentation technology*. The architecture chain
  the task itself states —
  `Diagram Studio → Web Surface Host → Legacy V2 → Bridge →
  DiagramStudioController → OEP Engine` — is precisely a Studio (first
  box) implemented through a presentation technology (middle boxes)
  over the Engine (last box), matching §12's proposed model exactly.
- This is not a new argument invented for this document — it is the
  same reasoning `DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md` used
  throughout the BRIDGE series (native renderer retired, "Legacy V2 is
  now the sole production Diagram Studio surface" — the *Studio* name
  never changed even as its presentation technology did, twice: native
  Flutter renderer → Web-Surface-hosted Legacy V2).
- No document anywhere proposes renaming Diagram Studio to something
  V2-flavored ("Wiring Studio," "V2 Studio," etc.) — the destination
  label, route (`/diagram`), and every architecture doc consistently
  keep the name stable across the presentation-technology change.

**No rename is warranted or performed.**

## 8. Knowledge & Acquisition status (Phase 8)

Both are **full OEP Studios** by this document's working definition
(§2) — each is a registered `StudioDestination`, reachable from the
persistent Navigation Rail, with its own `pageBuilder`,
`settingsProvider`, `searchProvider`, and declared `CapabilityDescriptor`s
in `studio_registry.dart`. Neither is a subsystem, a temporary
implementation, or merely a workspace-within-a-Studio.

- **Knowledge Studio**: label exactly "Knowledge Studio" in code,
  matching its own name. Substantially audited in AP-OEP-INTERACTION-
  MODEL-002 — a real, tested implementation (81 passing tests touching
  its services), not a stub.
- **Engineering Acquisition**: label exactly "Engineering Acquisition"
  in code — **not** "Acquisition Studio" (§5). Equally real and tested
  (also part of the 81 passing tests in AP-OEP-INTERACTION-MODEL-002).
  This document recommends future documentation use the exact
  registered label "Engineering Acquisition," reserving "Acquisition
  Studio" only as informal shorthand where the exact label isn't
  load-bearing.

Neither Studio's capability list nor implementation was found anywhere
described as "temporary" or "experimental" in code comments — both are
production-facing per the same registry mechanism every other Studio
uses.

## 9. Five Primitive Rule relationship (Phase 9)

**Studio boundaries represent workflows/professional activities, not
Engine domains — this document does not alter the Five Primitive Rule
and confirms Studios were never meant to map 1:1 onto it.**

- The Five Primitive Rule (Engineering Object, Relationship, Operation,
  Event, Capability) is Engine-layer vocabulary — it describes what data
  *is*, not who works with it or how.
- Every Studio audited so far (Diagram, Knowledge, Engineering
  Acquisition, per AP-OEP-INTERACTION-MODEL-002) operates over the same
  underlying primitives to different degrees and at different points in
  their lifecycle — Diagram Studio edits committed Engineering
  Objects/Relationships directly; Knowledge Studio operates on
  *pre*-primitive candidate records that only become primitives at
  Commit time; Engineering Acquisition's pipeline records are not
  primitives at all yet (a confirmed, disclosed gap, not a violation —
  AP-OEP-INTERACTION-MODEL-002 §15.8).
- This is direct evidence that **Studio = workflow/lifecycle-phase over
  the primitives, not Studio = primitive-domain**. A future architecture
  that tried to define "the Diagram Studio's domain is Relationships" or
  "the Knowledge Studio's domain is Objects" would be a category error —
  every Studio touches multiple primitive types, and the same primitive
  type (Engineering Object) is touched by multiple Studios at different
  lifecycle stages (candidate → committed → related → acquired-and-not-
  yet-promoted).
- **Recommendation for future Studio architecture** (not a new rule
  self-ratified here, offered as evidence-based guidance): define new
  Studios by professional workflow (matching List 1/List 2's actual
  intent — "Installation," "Repair," etc. are workflows, not primitive
  types) and let each Studio's UI decide, independently, which
  primitives and which lifecycle stage (pre-primitive/candidate,
  committed, or external/not-yet-bridged) it needs to expose — exactly
  as Diagram/Knowledge/Acquisition already do differently from each
  other.

## 10. Four-Division Company Architecture relationship (Phase 10)

**Finding: no "Four Division Company Architecture" document — or any
document using the terms "Platform Division," "Engineering Intelligence
Division," "Engineering Exchange Division," or "Engineering Services
Division" — exists anywhere in this repository.** A repo-wide,
case-insensitive search for all of these terms, plus the bare word
"division" across every `.md` file, returned zero organizational
matches (only unrelated electrical/arithmetic "division" usages in
simulation docs).

**This document cannot check the Studio taxonomy against the
Four-Division architecture because that architecture is not present in
this codebase.** If it exists, it is external to this repository (a
separate business/strategy document, a conversation record, or simply
not yet written down anywhere the repository can see). This is recorded
as an open item (§18), not resolved or fabricated.

The closest existing structure, `PLATFORM_ARCHITECTURE.md`'s layered
stack (`Users → Platform Shell → Studio Framework → Shared Platform
Services → Engineering Studios → Engineering Repositories → Engineering
Data`), is a **layering**, not a **division** structure — it describes
one path top-to-bottom through the whole platform, not four parallel
organizational units each owning a subset of Studios. No evidence was
found that Studios are, or were ever intended to be, partitioned across
organizational divisions in this codebase.

## 11. Documentation drift classification (Phase 11)

| Discrepancy | Classification |
|---|---|
| List 1 (`CLAUDE.md`/`PROJECT_MEMORY.md`) vs. actual code | **A — documentation (product roadmap) is "correct" as a stated future intent; implementation has not reached it yet, and was never trying to.** List 1 reads as a genuine future-product list, not a description of current `oep_studio` state — `PROJECT_MEMORY.md`'s own "first commercial implementation" framing confirms this is roadmap, not current-state documentation. |
| List 2 (`PLATFORM_ARCHITECTURE.md`) vs. actual code | **C — both represent different lifecycle states.** List 2 mixes real, implemented Studios (Engineering Acquisition — exact label match) with clearly-labeled "Examples include" speculative ones (Repair Studio, Diagnostics Studio) and an explicit "future Studios" list (Simulation, CAD, PCB, etc.) in the same document — it was written to illustrate the *category*, not to assert current-state fact, so its mismatch with code is by the document's own design, not an error. |
| List 1 vs. List 2 | **D — genuine architectural ambiguity.** Neither document references the other; both claim (or appear to claim) some authority over "the Studio family," and their lists do not obviously map onto each other term-for-term (§5). This is the one discrepancy this document cannot resolve with evidence alone — it needs a human/constitutional decision about which list (if either) is authoritative going forward. |
| `OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md`'s internal `webSurfaces`-destination claim vs. current code | **B — implementation is correct; documentation is stale** (§6, item 3) — the clearest, most concrete drift found in this whole audit, because it's a single document contradicting itself across two of its own sections, not just disagreeing with code. |
| "Acquisition Studio" (informal usage, including in this session's own prior task prompts/reports) vs. "Engineering Acquisition" (actual label) | **E — historical/informal terminology only.** Not a documentation defect anywhere in the repo itself (no repo document ever calls it "Acquisition Studio") — purely a naming looseness in conversational/task-prompt usage, now flagged so future documents use the exact label. |
| "Knowledge Studio" (code) vs. "Engineering Knowledge" (List 2) | **E — historical/informal terminology, high-confidence same concept**, not formally proven identical by an explicit rename record (§5). |

## 12. Proposed authoritative taxonomy (Phase 12)

Evidence supports a clear, minimal model — the four-way distinction the
task itself sketched, adopted here because the evidence (§2, §6, §7, §9)
independently converges on exactly this shape, not because it was
handed down:

- **STUDIO** — a user-facing engineering workspace representing one
  professional activity/workflow, registered as a `StudioDestination` +
  `StudioDescriptor`, reachable from the persistent Navigation Rail.
  Examples: Diagram Studio, Knowledge Studio, Engineering Acquisition.
- **STUDIO IMPLEMENTATION** — the actual registered `pageBuilder`
  widget/controller/provider set backing one Studio. Example: Diagram
  Studio's implementation is `WebSurfacesHostPage(autoOpenLegacyV2:
  true)` today; it was a native `DiagramStudioPage` before BRIDGE-010 —
  same Studio, different implementation, proving the Studio/
  implementation split is load-bearing, not decorative (§7).
- **PRESENTATION TECHNOLOGY** — the rendering mechanism a Studio
  implementation is built on: native Flutter widgets (most Studios
  today), or a Web Surface hosting external content (Legacy V2, for
  Diagram Studio). Confirmed independent of Studio identity (§6) and of
  interaction grammar (§9's cross-Studio convergence, and AP-OEP-
  INTERACTION-MODEL-002's finding that native and Web-Surface-backed
  Studios share the same selection/inspection primitives).
- **WORKSPACE** — the persistent interaction context a Studio operates
  within once entered: a document (Diagram Studio), a session
  (Knowledge Studio), or a looser multi-pointer context (Engineering
  Acquisition's endpoint × job × selection) — per AP-OEP-INTERACTION-
  MODEL-002 §15.4's "Context" row, already confirmed to vary
  legitimately by Studio.

This is not adopted automatically or self-ratified as constitutional
fact (§14) — it is recorded here as the model the evidence supports,
pending formal review.

## 13. Naming rules (recommended, not self-ratified)

1. A Studio's registered label in `studio_destination.dart` is its one
   authoritative name. Documentation and conversation should use that
   exact label ("Engineering Acquisition," not "Acquisition Studio";
   "Knowledge Studio," matching exactly).
2. A Studio's name does not change when its presentation technology
   changes (§7) — renaming should only happen for an explicit, ratified
   product/branding reason, never as a side effect of an implementation
   migration.
3. Documents describing *future/planned* Studios (List 1, List 2's
   speculative entries) should be explicitly labeled as such (roadmap,
   example, or conceptual) rather than presented in the same list
   structure as currently-implemented Studios, to prevent exactly the
   ambiguity found in §4/§11.
4. Where two documents name what might be the same underlying Studio
   concept under different words (§5's "Repair Studio"/"Service
   Studio," "Engineering Knowledge"/"Knowledge Studio"), a future
   document proposing or implementing that Studio should explicitly
   state which prior name(s) it supersedes, if any — this document
   found no such explicit statement anywhere for any of the three
   ambiguous pairs in §5.

## 14. Architectural boundaries

- This document is Studio-taxonomy scope only. It makes no claim about
  Engine architecture, Foundation architecture, or Legacy V2 — those
  remain governed entirely by their own respective constitutions/specs.
- This document does not create, rename, merge, split, or implement any
  Studio. Its only actionable content is naming/classification guidance
  (§13) and the reconciliation record itself (§4, §11).
- This document is subordinate to `oep_foundation/CLAUDE.md` and
  `OEP_ENGINEERING_CONSTITUTION.md` wherever a genuine conflict exists
  and is not itself empowered to resolve that conflict (§11, List 1 vs.
  List 2) — that requires human/constitutional review, explicitly
  flagged in §18, not decided here.

## 15. Open decisions

1. **List 1 vs. List 2** (§11, class D) — which product-roadmap Studio
   list, if either, is authoritative going forward? Not resolvable from
   repository evidence alone.
2. **`OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md`'s internal `webSurfaces`
   destination inconsistency** (§6, item 3) — should that document be
   corrected to reflect that Web Surfaces is not currently an
   independent Nav Rail entry, or should the `StudioDestination.
   webSurfaces` entry actually be (re-)added to match what that document
   describes? This document takes no position — it only records that the
   two currently disagree.
3. **Four-Division Company Architecture** (§10) — does not exist in this
   repository. If it exists elsewhere, it should be added to the
   repository (or referenced from it) so future Studio-taxonomy work can
   actually check against it, as this task was asked to do.
4. **"Repair Studio"/"Service Studio" and "Maintenance Studio"/
   "Maintainers Studio"** (§5) — genuinely ambiguous whether these are
   the same planned concept under different names or distinct concepts;
   no repository evidence resolves this.

---

**Ratification note**: per this task's Phase 14 instruction, this
document is marked **PROPOSED — PENDING RATIFICATION** in its entirety.
No section of it should be read as amending `oep_foundation/CLAUDE.md`,
`OEP_ENGINEERING_CONSTITUTION.md`, or any other existing ratified
constitution.
