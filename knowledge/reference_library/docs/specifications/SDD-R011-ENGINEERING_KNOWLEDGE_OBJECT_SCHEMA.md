# SDD-R011

# Engineering Knowledge Object Schema

**Document ID:** SDD-R011

**Repository:** oep_reference

**Status:** Draft 1.0

**Classification:** Architecture

**Owner:** Divad Technology Group, LLC.

---

# 1. Purpose

This specification defines the canonical schema for every Engineering Knowledge Object (EKO) within the Open Engineering Platform.

It establishes the required structure, organization, and relationships that all Engineering Knowledge Objects shall implement regardless of engineering discipline.

This specification is the contractual interface between:

- Engineering Reference Authoring
- Reference Compiler
- Reference Runtime
- Engineering Engine
- Engineering Behavior Engine
- Artificial Intelligence
- Engineering Discovery
- Validation
- Simulation
- Marketplace Packages

---

# 2. Philosophy

An Engineering Knowledge Object is not a file.

An Engineering Knowledge Object is a structured collection of engineering knowledge organized into independent Engineering Knowledge Facets.

The file layout is an implementation detail.

The Engineering Knowledge Facets define the architecture.

---

# 3. Design Principles

Every Engineering Knowledge Object shall be:

- Self-identifying
- Independently versioned
- Relationship-aware
- Behavior-aware
- Deterministic
- Traceable
- Extensible
- Offline-capable

---

# 4. Engineering Knowledge Facets

Every Engineering Knowledge Object consists of one or more Engineering Knowledge Facets.

The initial facet model is:

```
Identity

Classification

Properties

Relationships

Behaviors

Validation

Education

Simulation

Visualization

Assets

Authority

Evidence

Provenance

History
```

Future facets may be added without redesigning existing Engineering Knowledge Objects.

---

# 5. Identity Facet

Purpose

Uniquely identifies the Engineering Knowledge Object.

Contains:

- Object ID
- Object Type
- Display Name
- Short Name
- Version
- Lifecycle State
- Package ID
- UUID

Identity is immutable.

---

# 6. Classification Facet

Contains:

- Domain
- Discipline
- Family
- Category
- Subcategory
- Roles
- Capabilities
- Technology
- Industry
- Tags

Classification shall reference canonical classification objects where applicable.

---

# 7. Property Facet

Defines engineering properties.

Every property shall possess:

- Property ID
- Display Name
- Primitive Data Type
- Unit Reference
- Value
- Default Value
- Constraints
- Visibility
- Required Status

Property IDs are permanent.

Display names may change.

Units shall reference Unit Engineering Knowledge Objects.

---

# 8. Relationship Facet

Relationships shall reference canonical Relationship Types.

Relationships shall contain:

- Relationship ID
- Relationship Type
- Target Object
- Cardinality
- Lifecycle
- Confidence
- Notes

Relationships are first-class Engineering Knowledge.

---

# 9. Behavior Facet

Engineering Behaviors define executable engineering knowledge.

Behaviors are categorized as:

- Solver
- Calculator
- Validator
- Converter
- Analyzer
- Optimizer
- Recommender
- Explainer
- Simulator

Every behavior contains:

- Behavior ID
- Behavior Type
- Inputs
- Outputs
- Constraints
- Dependencies
- Execution Metadata

Behavior descriptions are documentation.

Executable behavior is independent of documentation.

---

# 10. Validation Facet

Defines deterministic engineering validation.

Validation rules shall be structured objects.

Human-readable validation text shall not be authoritative.

Validation supports:

- Design Validation
- Simulation Validation
- Input Validation
- Property Validation
- Relationship Validation

---

# 11. Education Facet

Contains educational material.

Examples:

- Description
- Engineering Notes
- Common Mistakes
- Design Considerations
- Worked Examples
- Learning Paths
- References

Educational content shall never alter engineering behavior.

---

# 12. Simulation Facet

Defines simulation metadata.

Examples:

- Supported Solvers
- Runtime Requirements
- Simulation Models
- Initial Conditions
- Dynamic States
- State Variables

Simulation metadata does not execute simulation.

---

# 13. Visualization Facet

Defines presentation metadata.

Examples:

- Preferred Symbols
- Color Hints
- Rendering Rules
- Default Labels
- Connection Styles
- Display Groups

Visualization never changes engineering meaning.

---

# 14. Asset Facet

References external assets.

Examples:

- SVG
- PNG
- STEP
- GLB
- PDF
- Images
- Example Diagrams
- Videos

Assets are referenced.

Assets are not Engineering Knowledge.

---

# 15. Authority Facet

Defines the engineering authority supporting the object.

Authority includes:

- Physical Law
- International Standard
- Government Standard
- Manufacturer Specification
- Internal Engineering Authority

Authority identifies where engineering truth originates.

Authority is not ownership.

---

# 16. Evidence Facet

Evidence supports engineering facts.

Evidence references:

- Standards
- Datasheets
- Service Manuals
- Application Notes
- Test Results
- Calculations

Evidence supports engineering claims.

Evidence is independently versioned.

---

# 17. Provenance Facet

Records engineering history.

Contains:

- Author
- Reviewer
- Organization
- Review Date
- Approval Date
- Digital Signature
- Revision Notes

Provenance is permanent.

---

# 18. History Facet

Records object evolution.

Includes:

- Previous Versions
- Superseded Objects
- Migration Notes
- Deprecation History
- Lifecycle Events

History shall never be destroyed.

---

# 19. Facet Independence

Every facet shall remain independently evolvable.

Applications shall consume only the facets required for their operation.

Examples:

Diagram Studio:

- Identity
- Properties
- Visualization
- Relationships

Simulation:

- Behaviors
- Validation
- Properties
- Relationships

AI:

- Education
- Behaviors
- Authority
- Evidence
- Relationships

No application shall require every facet.

---

# 20. Schema Evolution

Future revisions may:

- Add new facets
- Extend existing facets
- Introduce optional fields

Future revisions shall not invalidate previously published Engineering Knowledge Objects without formal migration.

---

# 21. Architectural Rules

1. Every Engineering Knowledge Object consists of Engineering Knowledge Facets.

2. Facets are the architectural unit.

3. Files are implementation details.

4. Property IDs are permanent.

5. Units reference Unit Engineering Knowledge Objects.

6. Relationships reference canonical Relationship Types.

7. Behaviors are executable engineering knowledge.

8. Authority identifies engineering truth.

9. Evidence supports engineering facts.

10. Provenance records engineering history.

11. Visualization shall never alter engineering meaning.

12. Educational content shall never alter engineering behavior.

13. Engineering Knowledge Objects remain deterministic.

14. All Engineering Knowledge Objects shall conform to this schema.

---

# 22. Future Work

SDD-R012 — Engineering Authority & Evidence Model

---

# 23. Ratification

This specification defines the canonical Engineering Knowledge Object Schema for the Open Engineering Platform.

All Engineering Knowledge Objects shall conform to this specification unless superseded through formal architectural revision.