# Annotation System

WORK_PACKAGE_023, ENGINE-TASK-000100: "Implement Diagram Layout support
for: Text Labels, Leader Notes, Callouts, Wire Labels, Component Labels,
Free Text, Revision Notes... Annotations belong to Diagram Layout. They
are not Engineering Graph objects."

---

## `DiagramAnnotation`

```dart
enum AnnotationType {
  textLabel, leaderNote, callout, wireLabel, componentLabel, freeText, revisionNote,
}

class DiagramAnnotation {
  final String id;
  final AnnotationType type;
  final String text;
  final Point2D position;
  final double rotation;          // degrees
  final String? anchorNodeId;
  final String? anchorRelationshipId;
  final Map<String, Object?> metadata;
}
```

An annotation is a drafting/documentation mark on a diagram — a
revision note, a torque callout, a wire label — never an engineering
object, relationship, or evidence link. `anchorNodeId`/
`anchorRelationshipId` are soft, plain-id references (for Component/Wire
Labels that track a specific node or relationship): if the anchored
object is deleted, the annotation simply renders unanchored. There is no
foreign-key-style integrity requirement, the same way `EvidenceLink`
references stay soft.

## Where annotations live

`DiagramLayoutState.annotations: Map<String, DiagramAnnotation>` — a
sibling of `positions`, `wireOverrides`, and `layers`. Accessors:
`annotationOf`, `withAnnotation`, `withoutAnnotation`.

## Commands

- `CreateAnnotationCommand(annotation)`
- `DeleteAnnotationCommand(annotationId)` — captures the removed
  annotation for revert.
- `UpdateAnnotationCommand(annotationId, {position?, rotation?, text?})`
  — one patch-style command covers Move, Rotate, and Edit (text), the
  same shape `UpdateNodePropertiesCommand` already uses. Unset fields
  leave that property untouched.

Undo/Redo for all three is automatic — they go through `CommandHistory`
exactly like every other layout mutation.

## Selection, Copy, and Paste

`GraphSelection` gained `annotationIds` (alongside `nodeIds`/
`relationshipIds`/`groupIds`) so annotations participate in the same
selection/clipboard machinery as everything else:

- `SelectionProvider.selectAnnotation`/`toggleAnnotation`.
- `ClipboardEntry` gained `List<DiagramAnnotation> annotations`;
  `ClipboardExtraction.extract` pulls annotations whose id is in
  `selection.annotationIds`.
- `PasteCommand`/`DuplicateSelectionCommand` id-remap and offset-place
  pasted annotations the same way nodes already are — an anchor is only
  remapped if the anchored node/relationship was itself part of the same
  copy; otherwise it's dropped rather than silently pointing outside the
  pasted selection.
- `DeleteManyCommand` gained an `annotationIds` parameter so Cut and
  multi-selection Delete remove annotations too, with full revert
  support.

## Demonstration Host rendering

`AnnotationWidget` renders text in a small bordered box, positioned via
`Positioned` + `Transform.rotate` (engine tracks rotation in degrees;
Flutter wants radians — the conversion is a Demonstration Host concern,
not engine code). Tap selects, drag moves (committing
`UpdateAnnotationCommand` on release, with a live position preview during
the drag itself — the same pattern node dragging already uses),
double-tap opens an inline text-edit dialog.

## Verification

`test/editing/annotation_commands_test.dart`: create/delete (+ revert),
update (all fields + partial patch + revert), `ClipboardExtraction`
pulling selected annotations, `PasteCommand` id-remap/offset/revert, and
`DeleteManyCommand` deleting + restoring annotations.
