# SDD-R001

# Engineering Knowledge Object (EKO) Model

**Document ID:** SDD-R001  
**Repository:** oep_reference  
**Status:** Draft 1.0  
**Classification:** Architecture  
**Owner:** Divad Technology Group, LLC.

---

# 1. Purpose

This document defines the canonical Engineering Knowledge Object (EKO) model used throughout the Open Engineering Platform (OEP).

The Engineering Knowledge Object is the smallest complete unit of engineering knowledge.

Every engineering concept stored within the Engineering Reference Library shall be represented as an Engineering Knowledge Object.

Examples include, but are not limited to:

- Electrical Components
- Engineering Theory
- Equations
- Standards
- Symbols
- Units
- Materials
- Measurement Devices
- Engineering Processes
- Failure Modes
- Simulation Models

This model shall serve as the single source of truth for:

- Engineering Engine
- Diagram Studio
- Knowledge Studio
- Simulation Engine
- AI Services
- Validation
- Manufacturing
- Engineering Exchange

---

# 2. Philosophy

The Engineering Reference Library does not store documents.

It stores engineering knowledge.

Every Engineering Knowledge Object shall represent one engineering concept.

Objects may reference other objects but shall never duplicate engineering knowledge.

The Engineering Graph is formed by relationships between Engineering Knowledge Objects.

---

# 3. Design Principles

Every EKO shall be:

- Atomic
- Reusable
- Searchable
- Versioned
- Traceable
- Computable
- Extensible

An Engineering Knowledge Object shall contain everything necessary for OEP to understand that engineering concept.

---

# 4. Object Types

Every EKO shall belong to exactly one Object Type.

Initial Object Types:

```
Component

Theory

Equation

Symbol

Unit

Material

Connector

Measurement

Tool

Standard

Process

Failure Mode

Simulation Model

Package

Manufacturer

Property Definition

Engineering Method
```

Additional object types may be introduced through future SDD revisions.

---

# 5. Canonical Object Structure

Every Engineering Knowledge Object shall contain the following sections.

```
Identity

Classification

Description

Engineering Properties

Relationships

Behavior

Validation

Search Metadata

AI Context

Education

Simulation

Visualization

Provenance

Version Information
```

No subsystem shall define alternate object structures.

---

# 6. Identity

Every object shall possess a globally unique identifier.

Required fields:

```
Object ID

Canonical Name

Display Name

Object Type

Version

Status
```

Example

```
component.passive.resistor

Resistor

Component

Version 1.0
```

---

# 7. Classification

Every object shall belong to a taxonomy.

Fields

```
Domain

Category

Subcategory

Tags

Keywords

Aliases
```

Example

```
Electrical

Passive Components

Resistors

Fixed

Carbon Film

Metal Film
```

---

# 8. Description

Every Engineering Knowledge Object shall contain engineering documentation.

Fields

```
Short Definition

Detailed Description

Engineering Notes

Typical Applications

Limitations
```

Descriptions shall be authored by OEP.

Descriptions shall not be copied directly from copyrighted reference material.

---

# 9. Engineering Properties

Engineering properties define measurable characteristics.

Examples

Resistor

```
Resistance

Tolerance

Power Rating

Temperature Coefficient

Maximum Voltage

Preferred Series

Noise

Package Styles
```

MOSFET

```
Threshold Voltage

RDS(on)

Maximum Drain Current

Maximum Gate Voltage

Power Dissipation

Body Diode

Gate Charge
```

Properties are typed.

Each property shall include:

```
Name

Value Type

Units

Default

Range

Required

Read Only
```

---

# 10. Relationships

Engineering knowledge exists as a graph.

Objects reference one another.

Relationship examples

```
USES

DEFINED_BY

MEASURED_BY

REPRESENTED_BY

SIMULATED_BY

APPEARS_IN

REQUIRES

RELATED_TO

HAS_UNIT

HAS_PROPERTY

USES_EQUATION

FAILS_AS

DERIVED_FROM
```

Relationships are directional.

Every relationship shall possess its own identifier.

---

# 11. Behavior

Behavior defines what an object can do.

Behavior is independent of visualization.

Examples

Resistor

```
Calculate Current

Calculate Voltage

Calculate Power

Voltage Divider

Series Resistance

Parallel Resistance
```

Equation

```
Forward Solver

Inverse Solver

Unit Conversion

Variable Validation
```

Behavior shall be exposed through capabilities.

---

# 12. Capabilities

Capabilities describe what services may consume an object.

Examples

```
Searchable

Renderable

Simulatable

Validatable

Teachable

Explainable

Manufacturable

Purchasable

Exportable

Printable

AI Explainable
```

Subsystems query capabilities instead of object types.

Example

Simulation asks

```
Supports Simulation?
```

rather than

```
Is Component?
```

This minimizes subsystem coupling.

---

# 13. Validation Rules

Objects may define validation rules.

Examples

```
Resistance > 0

Power Rating > 0

Tolerance <= 20%

Voltage >= 0
```

Validation rules shall be reusable.

Validation shall never be duplicated inside Diagram Studio.

---

# 14. Equations

Equations are Engineering Knowledge Objects.

Components reference equations.

Example

```
Resistor

↓

USES_EQUATION

↓

Ohm's Law
```

No component shall duplicate equations.

---

# 15. Symbols

Symbols are Engineering Knowledge Objects.

Example

```
Resistor

↓

REPRESENTED_BY

↓

IEC Resistor Symbol
```

One symbol may represent many objects.

One object may possess multiple symbols.

---

# 16. Simulation

Simulation metadata shall remain independent.

Fields

```
Simulation Model

Parameters

State Variables

Failure Modes

Default Values

Runtime Properties
```

Simulation engines consume this information.

---

# 17. AI Context

Each object shall expose structured AI information.

Examples

```
Definition

Engineering Explanation

Common Mistakes

Design Considerations

Troubleshooting

Frequently Asked Questions
```

AI explanations shall be grounded in Engineering Knowledge Objects.

---

# 18. Educational Context

Objects may contain educational information.

Examples

```
Examples

Worked Problems

Exercises

References

Learning Path
```

Education remains optional.

---

# 19. Search Metadata

Each object shall define search metadata.

Fields

```
Keywords

Aliases

Abbreviations

Alternate Names

Manufacturer Terms

Standards References
```

Search indexes are generated from these fields.

---

# 20. Visualization

Objects may expose visualization resources.

Examples

```
IEC Symbol

ANSI Symbol

3D Model

Footprint

Icon

Preview Image
```

Visualization remains independent of engineering behavior.

---

# 21. Provenance

Every Engineering Knowledge Object shall be traceable.

Fields

```
Author

Reviewer

Created Date

Revision Date

Sources Consulted

Review Status

Confidence

Content License
```

Objects without provenance shall never become official OEP Reference Library objects.

---

# 22. Versioning

Every object is independently versioned.

Fields

```
Major

Minor

Patch

Revision Notes

Compatibility
```

Packages may contain multiple object versions.

---

# 23. Serialization

Engineering Knowledge Objects shall be authored as structured source files.

Compiled packages shall be generated by the Reference Compiler.

Runtime systems shall consume compiled packages only.

The runtime shall never depend upon editable authoring files.

---

# 24. Extensibility

Future domains shall extend the Engineering Knowledge Object model without modifying existing object definitions.

Examples

Future domains include:

```
Mechanical

Hydraulics

Pneumatics

Civil

Robotics

RF

Embedded Systems

Industrial Automation
```

The object model shall remain domain independent.

---

# 25. Architectural Rules

The following rules are permanent.

1. Everything is an Engineering Knowledge Object.

2. Engineering knowledge shall never be duplicated.

3. Relationships create knowledge.

4. Behavior belongs to objects.

5. Capabilities describe object functionality.

6. AI consumes Engineering Knowledge Objects.

7. Simulation consumes Engineering Knowledge Objects.

8. Diagram Studio consumes Engineering Knowledge Objects.

9. The Engineering Reference Library is the authoritative source of universal engineering knowledge.

10. User repositories extend engineering knowledge but never replace the Engineering Reference Library.

---

# 26. Future Work

This specification shall be expanded by:

SDD-R002 — Engineering Taxonomy

SDD-R003 — Relationship Model

SDD-R004 — Reference Package Format

SDD-R005 — Simulation Integration

SDD-R006 — AI Integration

SDD-R007 — Search Architecture

SDD-R008 — Core Reference Library Inventory

---

# 27. Ratification

This document defines the canonical Engineering Knowledge Object model for the Open Engineering Platform.

All future Engineering Reference Library development shall conform to this specification unless superseded by a formally ratified revision.