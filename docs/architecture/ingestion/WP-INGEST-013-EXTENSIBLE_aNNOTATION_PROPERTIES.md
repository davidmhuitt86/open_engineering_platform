# WP-INGEST-013 — Extensible Annotation Properties

You are implementing **WP-INGEST-013 — Extensible Annotation Properties** in the Open Engineering Platform repository.

## Objective

Extend the existing Extraction Inspector annotation workflow so that a human annotating a region can record **what the region represents and additional attributes about it**, without creating a large hard-coded engineering-diagram form or prematurely defining a wiring-diagram ontology.

The design must establish a generic, structured observation/property mechanism that can later evolve into a domain-specific engineering annotation vocabulary based on real TRX300 annotation experience.

**Do not commit or push.**

---

# 1. READ FIRST — REQUIRED ARCHITECTURE CONTEXT

Before changing code, inspect:

- the current `ExtractionInspectorDialog`
- `EvidenceRegion`
- existing evidence annotation/origin/status models
- `KnowledgeCandidate`
- `KnowledgeCandidateType`
- evidence-link models/services
- `FoundationRuntimeNotifier` annotation methods
- `KnowledgeSessionRecord`
- `KnowledgeSessionStorage`
- `docs/EVIDENCE_MODEL.md`
- relevant WP-INGEST-010/011/012 tests
- existing serialization conventions in the knowledge models

Establish the actual current implementation before modifying it.

Do **not** assume the architecture from this prompt if the repository differs. Preserve existing conventions.

---

# 2. CORE ARCHITECTURAL RULE

Keep this distinction explicit:

> **EvidenceRegion answers WHERE. Annotation/Observation answers WHAT and WHAT IS KNOWN ABOUT IT.**

The current lifecycle is:

```text
Human draws region
        ↓
EvidenceRegion
        ↓
Classification / Observation
        ↓
KnowledgeCandidate + EvidenceLink
        ↓
Engineering Review
        ↓
CommitPlanService
        ↓
Explicit Commit
```

Classification does **not** create an Engineering Object or Repository truth.

Do not bypass that boundary.

---

# 3. DO NOT TURN EVIDENCE REGION INTO A GIANT SCHEMA

Keep `EvidenceRegion` primarily responsible for spatial/evidence information.

Do not add dozens of engineering-specific fields directly to `EvidenceRegion`.

Existing fields such as:

- source
- page
- normalized coordinates
- origin
- annotator
- status
- observation reference

remain appropriate.

Add a structured annotation/observation payload associated with the evidence region using the repository's existing naming and modeling conventions.

---

# 4. GENERIC ANNOTATION MODEL

Introduce an appropriate structured model for human observation.

Conceptually:

```dart
class EvidenceAnnotation {
  String id;
  String? type;
  String? name;
  String? description;
  List<AnnotationProperty> properties;
}
```

and:

```dart
class AnnotationProperty {
  String key;
  String value;
  String? valueType;
  String? unit;
}
```

**These are conceptual requirements, not mandatory class names.**

Use the repository's actual naming conventions.

### Minimum semantics

Each property must support:

- stable machine-readable key
- value
- optional value type
- optional unit

Keep this deliberately small.

Do **not** introduce a complete type system, ontology framework, validation engine, confidence framework, or unit-conversion subsystem.

---

# 5. UNIVERSAL ANNOTATION FIELDS

The Inspector must support:

- **Type**
- **Name**
- **Description / Notes**
- **Properties**
- existing annotator information
- existing annotation status

The current type selector remains.

Do not add engineering-specific universal fields.

---

# 6. DYNAMIC PROPERTY EDITOR

Extend the existing **non-modal annotation panel** from WP-012.

When an annotation is selected, provide an expandable property section conceptually like:

```text
Annotation
────────────────────────────

Type
[ Component          ▼ ]

Name
[ R123                 ]

Description / Notes
[                       ]
[                       ]

Properties
────────────────────────────

Part Number     [ 123-456 ]   ×
Manufacturer    [ Acme    ]   ×

+ Add Property
```

The exact visual implementation should follow the existing Inspector UI.

Requirements:

- add property
- edit property key
- edit property value
- optionally edit value type
- optionally edit unit
- delete property
- multiple properties allowed
- empty property list is valid

Do not create a modal dialog for every property.

---

# 7. PROPERTY TYPES

Support only a small initial set, using existing project conventions where applicable:

- `text`
- `number`
- `boolean`

If adding `quantity + unit` is straightforward within the existing architecture, it may be supported.

Do **not** build:

- expression evaluation
- unit conversion
- engineering validation
- enumerations
- ontology-defined property types
- confidence scoring

Those belong to later work.

---

# 8. STABLE PROPERTY KEYS

Property keys must be machine-stable.

Prefer:

```text
part_number
manufacturer
wire_color
```

over storing only display strings such as:

```text
Part Number
Manufacturer
Wire Color
```

The UI may display human-friendly labels, but persisted identity should be stable.

Do not create a canonical vocabulary for those example keys yet.

The user must be able to create arbitrary keys.

---

# 9. DO NOT DEFINE THE WIRING ONTOLOGY YET

This is critical.

Do **not** implement hard-coded forms such as:

```text
Wire:
  color
  gauge
  from
  to
  circuit

Connector:
  manufacturer
  part number
  pin count

Pin:
  number
  signal
  terminal
```

Those are examples of information that may eventually matter.

We need to annotate real engineering diagrams first and discover the actual vocabulary.

Therefore:

```text
Generic property infrastructure
        ↓
TRX300 annotation exercise
        ↓
Observed vocabulary
        ↓
Canonical engineering annotation schema
        ↓
Future visual extraction system
```

Do not skip directly to the bottom.

---

# 10. CANDIDATE BOUNDARY

Do not blindly duplicate every annotation property into `KnowledgeCandidate`.

Maintain:

```text
EvidenceAnnotation
    = what the engineer observed at this location

KnowledgeCandidate
    = proposed engineering entity derived from that observation
```

Use the existing evidence-link mechanism.

The candidate remains the downstream semantic object.

Classification must continue to use the existing:

- `renameEvidenceRegion`
- `addKnowledgeCandidate`
- `linkEvidence`
- `editKnowledgeCandidate`

paths where applicable.

Do not create a second candidate pipeline.

---

# 11. PERSISTENCE

Properties must survive:

1. annotation creation
2. classification
3. Knowledge Session save
4. Knowledge Session reload
5. reopening the Extraction Inspector

Use the existing Knowledge Session persistence architecture.

Do **not** modify Reference Vault immutable artifacts.

The intended ownership remains:

```text
Reference Vault artifact
        ↓
immutable evidence
        ↓
Knowledge Session
        ↓
EvidenceRegion
        ↓
EvidenceAnnotation
        ↓
Properties
```

---

# 12. BACKWARD COMPATIBILITY

Existing sessions and existing annotations must continue to load.

Missing annotation/property data must resolve safely to an empty/default state.

Do not require a migration merely to load old sessions unless the repository's existing persistence architecture makes that unavoidable.

Existing serialized fields must remain compatible.

---

# 13. EDITING SEMANTICS

When an annotation is edited:

- changing a property must not create another EvidenceRegion;
- changing a property must not create another KnowledgeCandidate;
- reclassification must continue updating the existing candidate;
- deleting an annotation must clean up its annotation data according to existing evidence-region deletion semantics;
- property edits must persist through the same session persistence path.

If the existing annotation model has a stable annotation ID, preserve it.

Do not generate a new identity merely because the user edits a property.

---

# 14. CLASSIFICATION INTERACTION

Preserve WP-INGEST-012 behavior.

For example:

```text
Draw region
    ↓
Human EvidenceRegion
    ↓
Select Type = Component
    ↓
KnowledgeCandidate created/updated
```

Adding:

```text
Part Number = 123-456
Manufacturer = Acme
```

must not alter that lifecycle.

Properties belong to the human observation.

Do not automatically transform arbitrary properties into Repository fields.

---

# 15. TEST REQUIREMENTS

Add focused tests covering at least:

### Model / serialization

**A.** Annotation with no properties serializes/deserializes.

**B.** One property survives round-trip.

**C.** Multiple properties survive round-trip.

**D.** Optional `valueType` and `unit` survive round-trip.

**E.** Existing annotation/session data without the new fields remains loadable.

### Editing

**F.** Add property.

**G.** Edit property key.

**H.** Edit property value.

**I.** Delete property.

**J.** Multiple properties can coexist.

### Persistence

**K.** Create annotation with properties.

**L.** Save Knowledge Session.

**M.** Reload Knowledge Session.

**N.** Properties are unchanged.

### Classification

**O.** Classifying an annotation still creates exactly one linked candidate.

**P.** Reclassifying updates the existing candidate rather than creating another.

**Q.** Editing annotation properties does not duplicate the candidate.

**R.** Annotation properties remain intact through classification/reclassification.

### Boundary protection

**S.** Property editing does not create an Engineering Object.

**T.** Property editing does not create a Repository object.

**U.** Property editing does not invoke commit.

**V.** Reference Vault artifact/content remains untouched.

### WP-012 regression

Ensure the existing relationship eligibility and Evidence/Candidates behavior remain intact.

---

# 16. UI TESTING

The repository currently has limitations around widget testing with the real `pdfrx` viewer.

Do not introduce a new testing framework solely to manufacture a PDF viewer widget test.

Test the property model and editing logic directly where practical.

A successful Windows build plus focused behavioral/model tests is acceptable.

If existing Inspector widget testing infrastructure can test the property panel without introducing unnecessary complexity, use it.

---

# 17. DOCUMENTATION

Update the canonical:

```text
platform/oep_studio/docs/EVIDENCE_MODEL.md
```

Do not create a competing evidence architecture document.

Document:

- EvidenceRegion vs EvidenceAnnotation
- universal annotation fields
- extensible properties
- stable property keys
- classification relationship to KnowledgeCandidate
- persistence ownership
- explicit boundary to Engineering Objects/Repository
- fact that no canonical wiring ontology is established yet

Include the lifecycle:

```text
Evidence Region
      ↓
Human Observation
      ↓
Properties
      ↓
Classification
      ↓
Knowledge Candidate
      ↓
Engineering Review
      ↓
Explicit Commit
```

---

# 18. SCOPE RESTRICTIONS

Do **not** modify:

- UIF/IngestionOrchestrator
- OCR
- entity extraction
- CandidateGenerationService unless an absolutely necessary compatibility change is proven
- Reference Vault
- acquisition pipeline
- Foundation/EKE
- Repository
- CommitPlanService
- RelationshipCandidateFormDialog
- visual extraction AI
- ontology management
- training/dataset systems
- automatic property extraction

Do not modify the existing zoom, rotation, thumbnail, or drag-preview implementation unless the new property UI genuinely requires it.

This WP is about **annotation data and its editing UI**, not extraction technology.

---

# 19. VALIDATION

Run:

1. focused WP-INGEST-013 tests;
2. relevant knowledge/ingestion/acquisition tests;
3. full `flutter test`;
4. `dart analyze .`;
5. `flutter build windows --debug`.

Report:

- exact test counts;
- exact analyzer result;
- exact build result;
- any baseline failures;
- whether any modified-file failures remain;
- git diff/status.

Do not hide unrelated pre-existing failures.

---

# 20. MANUAL VALIDATION

If practical, manually exercise the actual TRX300 workflow:

1. acquire the TRX300 PDF;
2. open **Inspect Extraction**;
3. draw an annotation;
4. assign a type;
5. enter a name;
6. enter notes;
7. add several arbitrary properties;
8. edit a property;
9. delete a property;
10. close/reopen the session;
11. reopen the Inspector;
12. verify the properties remain;
13. classify the annotation;
14. verify the existing Knowledge Candidate behavior remains correct.

Do not claim manual validation if the running application was not actually exercised.

---

# 21. GIT

Do **not** commit.

Do **not** push.

At the end, report:

```text
git status
git diff --stat
git diff --name-only
```

and identify every modified/untracked file.

---

# 22. FINAL REPORT FORMAT

Return a concise but complete implementation report containing:

1. **Disposition**
2. **Files changed**
3. **Annotation model**
4. **Property model**
5. **UI behavior**
6. **Persistence behavior**
7. **Classification/candidate behavior**
8. **Backward compatibility**
9. **Tests**
10. **Full-suite results**
11. **Analyzer**
12. **Windows build**
13. **Manual validation**
14. **Scope audit**
15. **Limitations**
16. **Git status**

Do not claim completion of anything that was not actually tested.

**Most important constraint:** do not invent the wiring-diagram ontology in this work package. Build the generic structured annotation/property mechanism, then use real TRX300 annotations to discover what the eventual domain-specific schema should be.