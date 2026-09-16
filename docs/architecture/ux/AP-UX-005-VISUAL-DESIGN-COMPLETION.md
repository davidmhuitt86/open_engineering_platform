# AP-UX-005 — OEP UX Visual Design & Render Completion

## 1. Status

**Status:** Active target UX architecture — visual design completion pass. This document does not authorize, describe, or record any Flutter/Dart/C++/SQL implementation change.

## 2. Baseline

`9868197` (post `AP-UX-004-TARGET-UX-ARCHITECTURE-COMPLETION.md`). Verified via `git rev-parse HEAD` at the start of this work package; matched exactly. `git status --short` at that point showed only the same pre-existing unrelated working-tree material tracked since WP-CTRL-002, plus the user's own in-progress render curation (several `docs/architecture/ux/renders/*.png` deletions/additions) — none of it touched by this work package.

## 3. Mission

Turn the completed target UX architecture (AP-UX-004) into a visually demonstrated, implementation-ready design reference: complete the individual shell-region renders, produce the primary missing artifact (Diagram Studio operating inside the full target shell), add dedicated Context Navigation and Inspector references, assess EAM and Home, expose responsive layout pressure without inventing a collapse rule, and bring the render index and Studio-naming documentation into agreement with AP-UX-002's actual decisions.

## 4. Target Design Authority

`AP-UX-004-TARGET-UX-ARCHITECTURE-COMPLETION.md` (immediate authority), `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`, `OEP-UX-ARCHITECTURE.md`, `design-system/OEP-DESIGN-TOKENS.md`, `design-system/OEP-SHELL-COMPONENTS.md`, `design-system/OEP-UI-RULES.md`, `OEP_UX_RENDER_REFERENCE_INDEX.md`, `README.md`, plus Studio-specific specifications as needed (`eam/EAM-ACQUISITION-WORKSPACE-SPEC.md`, `OEP_HOME_UX_SPEC.md`, `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`, `DS-GOLDEN-WORKSPACE-SPEC.md`).

## 5. AP-UX-004 Correction — Instruments

AP-UX-004 used "Tools" in its Studio Inventory (§9), Completion Inventory (§6 row 21), Maturity Assessment (§13), Design Completion Matrix (§19), Next Render Work (§21), and AAR (§24), and additionally stated the naming direction backwards ("Instruments→Tools rename"). This was already wrong at the time AP-UX-004 was written: AP-UX-002 §2A had established `oep.studio.instruments` (`#D95C5C`) as the canonical token and explicitly noted "Tools" was the old, pre-reconciliation draft name used in second-generation documents (AP-UX-002 §2A note, referencing `OEP-UX-ARCHITECTURE.md` §2/C7). This is a documentation inconsistency, not a new architectural decision, and does not reopen C1 or C6.

**Correction applied directly to `AP-UX-004-TARGET-UX-ARCHITECTURE-COMPLETION.md`** in this work package (not merely recorded here): every "Tools" reference naming the Studio was changed to "Instruments," the backwards naming-direction language was corrected to "Tools→Instruments," and two related stale-render references (`oep-home/home.png`, `eam/EAM.png` — both removed from disk during the user's render curation, and `eam/EAM.png` was never actually CANONICAL, only ever HISTORICAL/SUPERSEDED per the render index) were corrected in place rather than left silently wrong.

**The target Studio inventory, confirmed unchanged in substance:**

```text
Home
Diagram Studio
EAM
Knowledge Studio
Engineering Exchange
Instruments
Settings
```

Engineering Intelligence is not included (AP-UX-004 §5, unchanged, not reopened here).

## 6. Render Inventory Before AP-UX-005

At baseline `9868197`, the render corpus (after the user's own curation, which removed `oep-home/home.png`, `oep-shell/oep.png`, and `eam/EAM.png`) consisted only of the "Section 1,2,3, 7,8" wireframe folder: `App Header with OEP Logo.png` (CANONICAL, isolated), `Start With this Exact Wireframe and its Pixel Measurments.png` (CANONICAL, geometry authority), `Status bar use option 2.png` / `studio tab bar use option 3.png` / `toolbar 7 use option 3.png` (each a 5-or-6-option comparison sheet with one option design-owner-selected, not isolated single-purpose assets), and `workspace context tab bar.png` (EXPERIMENTAL, 6 Studio rows, one — EAM — flagged placeholder). No render existed for Diagram Studio operating inside the target shell, nor for Context Navigation or Inspector in isolation.

## 7. Interim Shell Artifacts

Produced in the first pass of this work package, per explicit direction to complete the Header/Studio Bar/Workspace Bar/Toolbar/Status Bar regions before the primary composite:

- **Application Header:** no new asset — `App Header with OEP Logo.png` accepted as-is, already a clean isolated canonical render.
- **`renders/oep-shell/global-studio-bar.svg`** (1920×56) — isolated from `studio tab bar use option 3.png`'s "DUAL-TONE ANGLED" option, with the "Tools"→"Instruments" label correction applied (the only visual change from the reference).
- **`renders/oep-shell/workspace-bar.svg`** (1920×42) — isolated from `workspace context tab bar.png`'s Diagram Studio row (the reference's own non-placeholder row).
- **`renders/oep-shell/toolbar.svg`** (1920×60) — isolated from `toolbar 7 use option 3.png`'s "GROUPED SECTIONS" option.
- **`renders/oep-shell/status-bar.svg`** (1920×36) — isolated from `Status bar use option 2.png`'s "COMPACT (LOW PROFILE)" option.

Format note: no HTML/CSS/render-generation pipeline exists anywhere in the repository, so these were hand-authored as SVG — token-exact (colors and geometry are literal numeric values matched against `OEP-DESIGN-TOKENS.md`, not visual approximations), viewable directly in any browser, and require no build step or new dependency. This is documented here as the render source/provenance per this work package's own instructions.

## 8. Full OEP Shell

**`renders/diagram-studio/oep-diagram-studio-shell.svg`** (1920×1080) — the primary AP-UX-005 deliverable. Fully self-contained: the Application Header is the accepted canonical PNG embedded losslessly as a base64 data URI (pixels unchanged from the source file); the Studio Bar, Workspace Bar, Toolbar, and Status Bar are the accepted §7 assets inlined verbatim at native size; Context Navigation and Inspector are authored at this composite's exact column widths (280px and 640px respectively, see §9/§10/§11); the Engineering Surface is new content built for this composite. No external file references — verified to render correctly as a standalone document (confirmed visually via the in-app browser: header, Studio Bar, Workspace Bar, Context Nav, Engineering Surface, Toolbar, Status Bar, and Inspector all display correctly together and at the correct relative positions).

Region layout (unchanged geometry, per `AP-UX-004` §7 / `OEP-DESIGN-TOKENS.md` §3):

```text
Header 58 / Studio Bar 56 / Workspace Bar 42
Context Nav 280 (variable) / Engineering Surface 1000 (variable) / Inspector 640 (variable)
Toolbar 60 / Status Bar 36
```

280/1000/640 sums to 1920 and matches the proportions of the pixel-measurement wireframe (which used 240/1040/640); 280 was chosen within the documented "variable" range to keep the isolated Context Navigation content legible without altering any fixed token.

## 9. Diagram Studio Integration

The Engineering Surface region of the composite shows a Diagram Studio wiring scenario consistent with `DS-GOLDEN-WORKSPACE-SPEC.md`: Honda TRX300 ignition-system wiring (Battery → Ignition Switch → Ignition Coil → CDI Unit / Spark Plugs, Frame Ground), colored wire conventions (power/ground/signal), a selected object (Ignition Coil, matching the Context Navigation and Inspector scenario for cross-region consistency), selection handles on the associated wire, and viewport/navigation affordances (zoom control, minimap) in the corner. The surface is explicitly labeled "Engine-owned rendering" to preserve the OEP Studio → Diagram Studio → Engineering Workspace → Engine-owned rendering ownership chain (AP-UX-005 §11) — this is a design mockup demonstrating intended visual density and does not imply Flutter owns the engineering model or rendering semantics. No new diagram semantics were invented; content is drawn from the same TRX300/ignition scenario already used in the corpus's own EAM examples.

## 10. Context Navigation

**`renders/oep-shell/context-navigation.svg`** (360×1080 standalone; also inlined into the composite at 280×828). Demonstrates the required concept chain: **Active Workspace** (TRX300 - Main, Diagram Studio) → **Engineering Context** (a structural tree: Wiring Harness → Engine Compartment → Ignition System → Ignition Coil/Spark Plugs/CDI Unit, plus sibling Charging System / Lighting Circuit / Frame & Chassis Ground) → **Contextual View** (Overview active; Objects, Relationships, Graph, Validation — with a pending-count badge, Evidence, History available). Uses only established terminology from `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md` and `OEP-SHELL-COMPONENTS.md` §5. No Studio-identity color is used in this region — only `oep.accent` for the active selection, consistent with Context Navigation being workspace-scoped, not Studio-scoped.

## 11. Inspector

**`renders/oep-shell/inspector.svg`** (360×1080 standalone; also inlined into the composite at 640×828). Demonstrates the required chain: **Selected engineering object** (Ignition Coil, Electrical Component, "In Diagram" status) → **Inspector** → **object/context information** (Source document, Page, Confidence, Status, Terminal Count — all fields already established by the EAM/Diagram Studio corpus, none invented) → **related engineering information** (relationship rows: "provides high voltage to Spark Plug," "receives 12V from Ignition Switch," "mounted to Frame," mirroring the EAM Inspector pattern already established in the corpus) → **contextual actions** (Locate in Diagram, View Evidence). `oep.accent` only, no Studio-identity color, consistent with `OEP-SHELL-COMPONENTS.md` §8.

## 12. EAM

No new EAM shell-integration render was produced in this pass. `eam/EAM.png` (the only prior EAM render) was already classified HISTORICAL/SUPERSEDED before this work package (Dashboard-as-landing pattern, incomplete Studio Bar) and was separately removed from disk during the user's render curation — it would not have been reused regardless. EAM's canonical workflow/workspace/interaction documentation (`eam/EAM-ACQUISITION-WORKSPACE-SPEC.md`, `eam/EAM-INTERACTION-STATE-SPEC.md`) remains complete and is not altered by this work package. A shell-integrated EAM render (matching the pattern this work package established for Diagram Studio: OEP Shell → EAM Studio → EAM Workspace → Acquisition workflow → Contextual workflow state) is recorded as unbuilt — the same category of gap Diagram Studio had before this work package, now closed only for Diagram Studio. The four Studio Bar/Workspace Bar/Toolbar/Status Bar region assets from §7 are Studio-agnostic and directly reusable for a future EAM composite without rework.

## 13. Home

No new Home render was produced in this pass. `oep-home/home.png` (the only prior Home render) was removed from disk during the user's render curation before this work package began; it is not restored. `OEP_HOME_UX_SPEC.md` remains complete and unaltered. A shell-integrated Home render (Header/Studio Bar/Workspace Bar/Home surface/Status Bar — Home has no Workspace Bar tab of its own per `EAM_INTERACTION_STATE_SPEC.md`'s "Returning Home" rule, so the Workspace Bar would show as empty/inactive rather than absent) is recorded as unbuilt, in the same category as EAM above.

## 14. Responsive Visual References

Two schematic references were produced — deliberately schematic (region boundaries and dimensions only, in the style of "Start With this Exact Wireframe and its Pixel Measurments.png"), not full-fidelity content renders, because no collapse/reflow behavior exists yet to render faithfully at reduced width:

- **`renders/responsive/1600x900-layout-pressure.svg`** — holds Context Nav (280px) and Inspector (640px) at their 1920px reference widths; Engineering Surface compresses from 1000px to 680px (32% narrower). Manageable, but toolbar-group and status-bar-item overflow behavior is not yet specified.
- **`renders/responsive/1280x800-layout-pressure.svg`** — same method; Engineering Surface compresses to 360px (64% narrower than reference) — explicitly called out as unworkable for an engineering canvas.

Both renders carry an explicit "DESIGN-OWNER DECISION REQUIRED" banner rather than inventing a collapse, overlay, dock, temporary-panel, or minimum-width rule for Context Navigation or Inspector, per this work package's own instruction not to silently decide.

## 15. Design-System Visual QA

Every new render in §7–§11 and §8 was authored directly from `OEP-DESIGN-TOKENS.md` hex/pixel values (not sampled or approximated from screenshots), so token agreement is by construction rather than after-the-fact inspection. Explicit verification:

- Region heights: Header 58px (unchanged PNG, not re-measured pixel-by-pixel but unaltered), Studio Bar 56px, Workspace Bar 42px, Toolbar 60px, Status Bar 36px — all literal in the SVG `height`/`viewBox` attributes.
- Colors: `oep.bg #0B0F14`, `oep.surface.1 #111720`, `oep.surface.2 #151D27`, `oep.border #2A3542`, `oep.text.primary #E7EDF4`, `oep.text.secondary #9AA8B7`, `oep.accent #2F81F7`, `oep.success #39B56B`, `oep.warning #D9A441` all used as literal hex values matching `OEP-DESIGN-TOKENS.md` §2 exactly.
- Studio identity colors (§2A): `oep.studio.diagram #2F81F7`, `oep.studio.eam #2FB584`, `oep.studio.knowledge #D9A441`, `oep.studio.exchange #8A5CF6`, `oep.studio.instruments #D95C5C`, `oep.studio.settings #667585`, `oep.studio.home #9AA8B7` all used exactly, confined to the Studio Bar and Workspace Bar only.
- No prohibited drift (`OEP-DESIGN-TOKENS.md` §7): no purple/pink AI gradients, no glassmorphism, no oversized rounded cards, no giant empty hero areas, no browser-chrome imitation, no new accent colors outside the closed §2A set.

## 16. Accent-System Visual QA

Verified per render: Studio Bar and Workspace Bar tabs use their parent Studio's identity color (Diagram Studio blue throughout, since that is the active-Studio scenario used everywhere in this pass); Toolbar, Context Navigation, Inspector, and Status Bar use `oep.accent` (`#2F81F7`) only for active/selected states and never a Studio-identity color, confirmed by direct inspection of every fill/stroke value used outside the Studio Bar/Workspace Bar groups. Semantic status colors (`oep.success`, `oep.warning`) are used only for state meaning (Ready dot, Validation pending-count badge, In-Diagram status chip), never decoratively.

## 17. Canonical Render Classification

Applied to `OEP_UX_RENDER_REFERENCE_INDEX.md` in this work package (full table, not just filenames — see that document for Name/Purpose/Resolution/Status/Authority/Related specification/Demonstrates per render):

- **CANONICAL:** `App Header with OEP Logo.png`, `Start With this Exact Wireframe...png`, the three option-comparison sheets (source status), `oep-shell/global-studio-bar.svg`, `oep-shell/workspace-bar.svg`, `oep-shell/toolbar.svg`, `oep-shell/status-bar.svg`, `oep-shell/context-navigation.svg`, `oep-shell/inspector.svg`, `diagram-studio/oep-diagram-studio-shell.svg`.
- **EXPERIMENTAL:** `workspace context tab bar.png` (styling pattern only, EAM row content not authoritative — unchanged from AP-UX-002), the two `responsive/*.svg` schematics (schematic only, explicitly not full-fidelity, carry a DESIGN-OWNER DECISION REQUIRED banner).
- **Removed from disk during user curation (recorded, not restored):** `oep-home/home.png`, `oep-shell/oep.png`, `eam/EAM.png`.

No render was marked CANONICAL without being checked against the design system in §15/§16 first.

## 18. Visual Design Completion Matrix

| Area | Artifact | Resolution | Demonstrates | Status |
|---|---|---:|---|---|
| Header | `App Header with OEP Logo.png` | 2078×105 | Header content/geometry | CANONICAL |
| Studio Bar | `oep-shell/global-studio-bar.svg` | 1920×56 | 7-entry inventory, active/inactive, per-Studio color | CANONICAL |
| Workspace Bar | `oep-shell/workspace-bar.svg` | 1920×42 | Studio-color inheritance, open-work tabs | CANONICAL |
| Context Navigation | `oep-shell/context-navigation.svg` | 360×1080 | Workspace → Context → View chain | CANONICAL |
| Toolbar | `oep-shell/toolbar.svg` | 1920×60 | Grouped monochrome actions, global accent | CANONICAL |
| Diagram Surface | inline in shell composite | 1000×828 (in composite) | Wiring diagram, selection, viewport controls | CANONICAL |
| Inspector | `oep-shell/inspector.svg` | 360×1080 | Selected object → info → related → actions | CANONICAL |
| Status Bar | `oep-shell/status-bar.svg` | 1920×36 | Compact status/context fields | CANONICAL |
| Full Diagram Studio Shell | `diagram-studio/oep-diagram-studio-shell.svg` | 1920×1080 | All 8 regions operating together | CANONICAL |
| EAM | none (existing docs only) | — | Workflow/workspace text specs remain canonical; no shell-integration render | GAP (recorded, §12) |
| Home | none (existing docs only) | — | Landing-surface text spec remains canonical; no shell-integration render | GAP (recorded, §13) |
| 1600×900 | `responsive/1600x900-layout-pressure.svg` | 1600×900 | Engineering Surface compression to 680px | EXPERIMENTAL (schematic) |
| 1280×800 | `responsive/1280x800-layout-pressure.svg` | 1280×800 | Engineering Surface compression to 360px (unworkable) | EXPERIMENTAL (schematic) |

## 19. Remaining Visual Decisions

1. **Context Navigation / Inspector responsive behavior** (collapse, overlay, dock, temporary panel, or minimum width) below the 1920px reference — DESIGN-OWNER DECISION REQUIRED, evidenced concretely by §14's two schematics. Carried from AP-UX-004 §20 item 1, now with visual evidence attached.
2. **Studio-accent scope** — whether Studio-identity colors extend beyond Studio Bar/Workspace Bar into Studio-owned content — carried unresolved from AP-UX-002 §2A / AP-UX-004 §20 item 2; no new visual evidence in this pass required deciding it, so it remains open.
3. **Toolbar/Status Bar overflow behavior** at reduced width (which groups/items get priority, which get an overflow menu) — newly surfaced by §14's schematics; not previously identified as an open question by any prior AP. Not decided here.

## 20. Implementation Readiness

Diagram Studio is now the most implementation-ready Studio in the corpus: full shell composite exists, Context Navigation and Inspector are demonstrated in the exact scenario used by the composite, and the design-to-code contract template (`AP-UX-004` §17) applies directly. `WP-UI-DS-001-PROMPT.md` remains unmodified and still classified REQUIRES REVISION (`AP-UX-003`) — this work package produced the render that classification was waiting on, but re-verifying and revising that prompt itself is implementation-adjacent work explicitly out of scope here (§15 of this work package: "Implementation remains prohibited... Do not execute WP-UI-DS-001"). EAM, Home, Knowledge Studio, Engineering Exchange, Instruments, and Settings all remain not ready for implementation planning — the first two lack a shell-integration render (§12/§13), the last four lack any design at all (`AP-UX-004` §13).

## 21. Verification

```text
git diff --check     -> clean (no whitespace errors)
git status --short   -> only intended new files + pre-existing unrelated material
git diff --stat      -> reviewed before commit
git rev-parse HEAD   -> 9868197 confirmed as baseline before this work package's commit
```

Confirmed:
- All four §7 interim SVGs preserved unchanged in substance (only the studio-bar file went through in-session visual iteration before being accepted; workspace-bar/toolbar/status-bar were not touched after creation).
- User render curation (deletions of `oep-home/home.png`, `oep-shell/oep.png`, `eam/EAM.png`, and the 10 dated exploration PNGs / superseded option sheets from AP-UX-001) untouched — not restored, not further modified.
- No Dart/Flutter/C++/SQL/test/configuration file changed.
- No file under `platform/oep_studio/` changed.
- `WP-UI-DS-001-PROMPT.md` not executed, not modified.
- Target shell geometry (58/56/42/60/36, 240–360/variable/360–640) consistent across `AP-UX-004`, the render index, and every new render.
- Studio inventory consistent (7 entries, Instruments not Tools) across `AP-UX-004` (corrected), this document, and `global-studio-bar.svg`.
- Engineering Intelligence absent from every Studio Bar render produced in this pass.
- Render index (`OEP_UX_RENDER_REFERENCE_INDEX.md`) updated with full Name/Purpose/Resolution/Status/Authority/Related-specification/Demonstrates columns, not just a filename list.
- Remaining design decisions (§19) stated explicitly, not silently resolved.

## 22. AAR

**Recovered:** nothing new — no additional pre-existing design material was found in this pass.

**Completed:** isolated canonical renders for Application Header (accepted as-is), Global Studio Bar, Workspace Bar, Toolbar, and Status Bar; the primary missing artifact — a self-contained, fully-verified 1920×1080 OEP + Diagram Studio full shell composite; dedicated Context Navigation and Inspector references; two responsive layout-pressure schematics that expose real pressure without inventing a collapse rule; a corrected AP-UX-004 (Tools→Instruments, plus two stale/incorrect render-status claims); a fully rebuilt render reference index.

**Already authoritative, unchanged:** every text specification in the corpus (`OEP-UX-ARCHITECTURE.md`, all design-system docs, all Studio-specific specs) — this work package added visual artifacts and one documentation correction, it did not revise behavioral specification content.

**Unresolved (explicit):** Context Navigation/Inspector responsive collapse behavior; Studio-accent scope beyond Studio Bar/Workspace Bar; Toolbar/Status Bar overflow behavior at reduced width. None invented.

**Needs a render still:** EAM shell-integration composite; Home shell-integration composite; any render at all for Knowledge Studio, Engineering Exchange, Instruments, Settings (blocked on those Studios having no design yet, not a rendering gap).

**Needs design-owner input:** the three items in §19, and the full workflow/workspace/interaction design for the four undesigned Studios before any render for them would be meaningful.

**Ready for implementation planning:** Diagram Studio only, and even there, `WP-UI-DS-001-PROMPT.md` itself still needs a (separate, implementation-adjacent) revision pass before execution — not performed here.
