# WP-INGEST-015 — Evidence Geometry (Area and Path Evidence)

`EvidenceRegion` describes a place on a source page where a human or machine
observation was made. This work package separates **where** from **what**.

    Rectangle geometry describes area evidence.
    Polyline geometry describes linear/path evidence.

    Geometry identifies WHERE.
    Annotation identifies WHAT.
    Properties describe observed attributes.
    Human evidence is not engineering truth.

## Model

    EvidenceRegion
      geometry: EvidenceGeometry            WHERE
        RectangleGeometry  x, y, width, height
        PolylineGeometry   points[ (x, y) ... ], strokeWidth
      annotation: EvidenceAnnotation        WHAT (type, name, description, properties)

* Geometry never contains a semantic type. A wire is a polyline geometry whose
  annotation says `type = wire`; it is not a special kind of geometry.
* `EvidenceRegion.x/y/width/height` remain available on every region. For a
  rectangle they are the rectangle; for a polyline they are the path's bounding
  box, so bounds-based consumers (thumbnails, navigation, Evidence Browser,
  Source Viewer) work for both.

## Coordinates

Points use the same normalized page convention as rectangle regions and OCR
boxes: fractions (0..1) of the page, top-left origin, in the source's Extraction
Orientation frame (`DocumentOrientation`, WP-INGEST-014). There is no second
coordinate system. A polyline needs at least two points; NaN/infinite values and
coordinates outside 0..1 are rejected (`KnowledgeValidationException`), and an
invalid path is never converted into a rectangle.

## Stroke width

`strokeWidth` is in PDF points (1/72 in) of the page — a document-space unit
that does not depend on zoom or Flutter logical pixels. The viewer converts it
to pixels with `strokeWidthToCanvasPx(width, canvasWidthPx, pageWidthPt)`, so a
path keeps the same document width at every zoom level. The default is 2.0 pt.

**Stroke width is visualization/evidence geometry, not wire gauge.** A 2.5 pt
stroke says how wide the path is drawn; it says nothing about conductor
diameter or AWG. Gauge, if observed, is an annotation property (`gauge = 18 AWG`).
Automatic width detection is deliberately not implemented; a future
"proposed width + user adjustment" flow can set `strokeWidth` without changing
the model.

## Persistence

Rectangles serialize exactly as before (flat `x/y/width/height`, no `geometry`
key), so existing sessions load unchanged and there is no migration. A polyline
writes its bounding box in the flat keys (older readers degrade to its extent)
plus the authoritative object:

    "geometry": { "type": "polyline", "points": [[0.21,0.43],[0.28,0.43]], "strokeWidth": 2.0 }

Both geometries persist through the one existing path: `EvidenceRegion` →
`KnowledgeSessionRecord` → `KnowledgeSessionStorage`. There is no separate wire
persistence.

## Lifecycle

A path follows the rectangle lifecycle: human draws evidence → `EvidenceRegion`
→ classify (`KnowledgeCandidateType.wire`) → `KnowledgeCandidate` +
`EvidenceLink` → Engineering Review → explicit Commit. `Wire` has no Foundation
object category (like Tool, Material, …), so `CommitPlanService` does not turn
it into an Engineering Object. A drawn path implies **no** topology: not
from/to, connected-to, same-net or continuity. Relationships stay explicit.

## Inspector

An `Area | Path` selector (default Area) sits beside the annotate toggle. In Path
mode each click adds a vertex; **Finish Path** (≥ 2 points) creates one
`EvidenceRegion`, **Cancel Path** discards the unfinished path. A selected path
uses the same annotation panel as areas (type, name, notes, properties) plus a
**Width** field in points, and is saved through the same *Save Changes* action.
Point editing is deferred.

## Deferred

Point editing/moving, automatic width or wire detection, connectivity/net
semantics, and document orientation/OCR preprocessing are out of scope.
