# SDD-R010

# Engineering Knowledge Authoring Format (EKAF)

**Document ID:** SDD-R010

**Repository:** oep_reference

**Status:** Draft 1.0

**Classification:** Architecture

**Owner:** Divad Technology Group, LLC.

---

# 1. Purpose

This specification defines the Engineering Knowledge Authoring Format (EKAF).

EKAF is the canonical source format used by engineers to create, review, and maintain Engineering Knowledge Objects (EKOs).

The authoring format is optimized for:

- Human readability
- Version control
- AI-assisted authoring
- Community contributions
- Automated validation
- Compiler consumption

The Engineering Runtime shall never consume authoring files directly.

---

# 2. Philosophy

Engineering knowledge shall exist in two representations.

Authoring Representation

↓

Compiled Runtime Representation

The authoring format exists for engineers.

The runtime format exists for software.

These are intentionally different.

---

# 3. Design Principles

The authoring format shall be:

• Human readable

• Deterministic

• Version controlled

• Diff friendly

• AI friendly

• Compiler friendly

• Extensible

---

# 4. Repository Layout

The Reference Library repository shall contain:

```
docs/

schemas/

packages/

compiler/

validator/

runtime/

tools/

examples/
```

Engineering Knowledge Objects reside under packages/.

---

# 5. Package Layout

Example

```
packages/

core_components/

core_equations/

core_theory/

core_symbols/

core_units/

core_materials/

core_measurement/
```

Every package remains independently buildable.

---

# 6. Object Layout

Each Engineering Knowledge Object occupies its own directory.

Example

```
resistor/

object.yaml

properties.yaml

relationships.yaml

behaviors.yaml

validation.yaml

education.yaml

assets/

symbol.svg

images/

examples/
```

One object.

One directory.

---

# 7. Source Format

Authoring files shall use YAML.

Reasons:

- easier to read than JSON
- comments supported
- minimal punctuation
- Git friendly
- AI friendly

The compiler converts YAML into runtime objects.

---

# 8. Schemas

Every authoring file shall validate against a schema.

Schemas define:

Required fields

Optional fields

Data types

Constraints

Relationships

Version compatibility

---

# 9. Assets

Assets remain external.

Examples

SVG

PNG

STEP

PDF

Example diagrams

Videos

Objects reference assets.

Assets never duplicate engineering knowledge.

---

# 10. Cross References

Objects reference other objects only by Object ID.

Never by filename.

Example

```
component.passive.resistor

↓

uses_equation

↓

equation.ohms_law
```

Compiler resolves references.

---

# 11. Validation

The validator shall verify:

Unique IDs

Broken references

Duplicate names

Missing relationships

Invalid schemas

Circular dependencies

Unused assets

Behavior consistency

Validation must succeed before compilation.

---

# 12. Compiler

Compiler responsibilities:

Read YAML

Validate

Resolve references

Generate graph

Generate indexes

Generate runtime database

Generate package manifest

Sign package

Create .oerp

Reference Compiler Implementation

The Reference Compiler and Validator are implemented in Python.

This implementation language applies only to the authoring toolchain and imposes no requirements on the runtime. Compiled .oerp packages are language-independent and may be consumed by any conforming runtime implementation.

---

# 13. Review Workflow

Knowledge changes follow:

Author

↓

Validation

↓

Engineering Review

↓

Technical Verification

↓

Approval

↓

Compilation

↓

Publication

---

# 14. Version Control

Every object is independently versioned.

Git manages source history.

The compiler manages package versions.

---

# 15. AI Authoring

AI may assist with:

Initial drafts

Descriptions

Relationship suggestions

Validation fixes

Educational content

AI shall never bypass engineering review.

---

# 16. Community Contributions

Community contributions remain source-based.

Contributors submit:

Engineering Knowledge Objects

Assets

Behaviors

Documentation

Examples

Compiler output shall never be submitted.

---

# 17. Runtime Separation

Runtime shall never:

Read YAML

Modify authoring files

Depend upon source repository layout

The runtime consumes only compiled packages.

---

# 18. Architectural Rules

1. YAML is the canonical authoring format.

2. One Engineering Knowledge Object per directory.

3. Objects reference Object IDs.

4. Assets remain external.

5. Validation precedes compilation.

6. Compiler produces immutable packages.

7. Runtime consumes compiled packages only.

8. Git manages authoring history.

9. Engineering review remains mandatory.

10. Source and runtime remain permanently separated.

---

# 19. Ratification

This specification defines the Engineering Knowledge Authoring Format used throughout the Open Engineering Platform.

All Engineering Knowledge Objects shall be authored according to this specification unless superseded by a formally ratified revision.