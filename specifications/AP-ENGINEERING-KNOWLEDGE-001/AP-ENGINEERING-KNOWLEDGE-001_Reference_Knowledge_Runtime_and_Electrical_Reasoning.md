# AP-ENGINEERING-KNOWLEDGE-001
# Reference Knowledge Runtime & Electrical Reasoning
## Architecture and Implementation Specification

**Status:** Proposed — Architecture Phase  
**Scope:** OEP Knowledge Runtime + deterministic electrical analysis foundation  
**Primary consumer:** Diagram Studio  
**Authoritative reference source:** `oep_reference_library`  
**Acquisition source:** `oep_acqusition`  
**AI role:** explanatory/assistive only; never authoritative for engineering computation

---

## 1. Purpose

Establish the architecture required for OEP to ingest authoritative engineering reference material, compile it into structured runtime knowledge, and allow Diagram Studio to analyze an engineering circuit using:

1. authoritative reference knowledge,
2. structured engineering models,
3. deterministic equations and units,
4. explicit circuit topology,
5. component/state parameters,
6. traceable provenance.

The objective is not to turn Diagram Studio into a textbook reader or an LLM-powered calculator. The objective is to make engineering knowledge executable and traceable.

## 2. Architectural Principle

OEP SHALL NOT derive engineering truth from language alone.

Engineering conclusions SHALL be grounded in deterministic models and evidence.

AI MAY explain results, identify potentially relevant laws, propose hypotheses, guide analysis, translate terminology, and improve wording. AI SHALL NOT be the authoritative substrate for numerical calculations, unit conversion, circuit equations, topology resolution, component-state determination, or engineering constraint evaluation.

## 3. Existing Architecture Boundaries

`oep_engine` owns the engineering graph, layout, routing, validation, simulation, measurement, commands, and persistence operations. `oep_reference_library` remains the authoritative deterministic reference-library/compiler domain. `oep_acqusition` remains the acquisition/trust layer. `oep_exchange` remains the distribution/licensing boundary.

This phase does NOT move reference-library responsibilities into Studio and does NOT create a second reference repository.

## 4. Target Architecture

```text
                    AUTHORITATIVE SOURCES
                           |
             +-------------+-------------+
             |                           |
      oep_acqusition              authored/reference data
             |                           |
             +-------------+-------------+
                           |
                           v
                 oep_reference_library
                           |
                    canonical knowledge
                           |
                           v
                  KNOWLEDGE COMPILER
                           |
             +-------------+-------------+
             |                           |
      semantic metadata             executable forms
             |                           |
             +-------------+-------------+
                           |
                           v
                 OEP KNOWLEDGE RUNTIME
                           |
             +-------------+-------------+
             |             |             |
           Laws         Models       Constraints
             |             |             |
             +-------------+-------------+
                           |
                           v
                ENGINEERING ANALYSIS
                           ^
                           |
                 Engineering Graph
                           |
                           v
                    Diagram Studio
```

## 5. Knowledge Domains

### 5.1 Declarative Knowledge

Describes what an engineering entity is: resistor, capacitor, inductor, diode, transistor, relay, switch, fuse, battery, motor, connector, ground, conductor.

### 5.2 Mathematical Knowledge

Defines equations and mathematical relationships such as Ohm's Law, Kirchhoff's Current Law, Kirchhoff's Voltage Law, electrical power, voltage/current dividers, capacitor and inductor relationships, and time constants.

### 5.3 Behavioral Knowledge

Describes how an entity behaves under conditions. Example: a relay coil being energized changes its contact state.

### 5.4 Constraint Knowledge

Describes conditions that must hold or warnings that may apply: voltage/current/power ratings, resistance limits, polarity, temperature limits, and operating-state restrictions.

### 5.5 Provenance Knowledge

Every authoritative engineering fact used in an analysis SHALL be traceable to its source.

## 6. Canonical Runtime Objects

Exact implementation names may be adjusted to conform to the existing canonical EKO schema.

### EngineeringLaw

```text
EngineeringLaw
  id
  name
  domain
  description
  equations[]
  variables[]
  applicability[]
  constraints[]
  evidence[]
```

### Equation

```text
Equation
  id
  expression
  variables[]
  units[]
  domains[]
  constraints[]
```

The equation must be machine-evaluable without invoking an LLM.

### Engineering Quantity

```text
Quantity
  value
  unit
```

Examples: `12.6 V`, `4.2 A`, `10 Ω`, `14.4 W`.

### ComponentModel

```text
ComponentModel
  type
  properties[]
  behaviors[]
  equations[]
  constraints[]
  terminals[]
  states[]
  evidence[]
```

### AnalysisResult

```text
AnalysisResult
  analysisId
  subject
  inputs[]
  equationsUsed[]
  derivedValues[]
  constraintsEvaluated[]
  conclusions[]
  evidence[]
  warnings[]
```

## 7. Electrical Analysis Pipeline

```text
DiagramDocument
      |
      v
EngineeringGraph
      |
      v
Topology extraction
      |
      v
Electrical model resolution
      |
      v
Applicable-law resolution
      |
      v
Equation selection
      |
      v
Deterministic calculation
      |
      v
Constraint evaluation
      |
      v
Provenance assembly
      |
      v
AnalysisResult
      |
      v
Diagram Studio
```

## 8. First Electrical Capability Set

Initial deterministic support:

### Laws
- Ohm's Law
- Kirchhoff's Current Law
- Kirchhoff's Voltage Law

### Power
- `P = V * I`
- `P = I² * R`
- `P = V² / R`

### Basic network relationships
- series resistance
- parallel resistance
- voltage divider
- current divider

Reactive relationships are deferred until the DC foundation is validated.

## 9. Example

Given:

```text
Battery = 12.0 V
R1 = 10 Ω
R1 connected between battery positive and ground
```

The system resolves:

```text
V = 12.0 V
R = 10 Ω

I = V / R
I = 1.2 A

P = V * I
P = 14.4 W
```

The result retains the equations and inputs used. It must be reproducible without AI.

## 10. Topology vs Knowledge

The Engineering Graph and Knowledge Runtime are separate systems.

The Engineering Graph answers:

> What exists in this circuit?

The Knowledge Runtime answers:

> What is known about these entities and what laws govern them?

The Analysis Engine combines them.

## 11. "Why?" Reasoning

The analysis system shall retain a derivation chain. For example:

```text
Why is W17 approximately 12.6 V?

1. W17 is connected to B1 positive.
2. B1 is modeled at 12.6 V.
3. F3 is closed.
4. No modeled series voltage drop exists between B1 and W17.
5. Therefore W17 = approximately 12.6 V.
```

The UI presents a human-readable explanation from this deterministic derivation chain. AI may improve wording but must not invent missing derivation steps.

## 12. Fault Analysis

Fault analysis extends the same deterministic framework. Conclusions must distinguish:

```text
CALCULATED FACT
MODEL ASSUMPTION
REFERENCE CONSTRAINT
ENGINEERING INFERENCE
HYPOTHESIS
```

## 13. Provenance

Every result must be able to answer:

```text
Where did this value come from?
Which law produced it?
Which component model was used?
Which source supports the model?
Which assumptions were made?
```

No analysis result should become an opaque number.

## 14. Reference Library Boundary

`oep_reference_library` remains authoritative. The runtime SHALL NOT become a competing authoring system.

```text
Reference
   |
   v
Acquisition / validation
   |
   v
Canonical reference knowledge
   |
   v
Compilation
   |
   v
Runtime package
   |
   v
Analysis
```

Runtime data may be optimized for lookup and calculation, but must retain identity and provenance back to canonical knowledge.

## 15. Knowledge Compilation

The compiler should eventually produce deterministic runtime packages containing:

```text
manifest
knowledge entities
laws
equations
units
component models
constraints
indexes
provenance
schema/version information
integrity information
```

The package should be deterministic, versioned, integrity-verifiable, offline-capable, portable, and independently testable. Reuse existing OEP package/repository conventions rather than inventing a second package system.

## 16. Versioning

Knowledge must be versioned independently from Diagram Studio. An analysis should record:

```text
knowledgeRuntimeVersion
knowledgeEntityVersions[]
analysisEngineVersion
documentVersion
```

This allows historical analyses to remain explainable.

## 17. Domain Profiles

The architecture remains domain-neutral. Electrical engineering is the first implementation domain. Automotive electrical systems can later be represented as a domain profile rather than contaminating the core mathematical engine.

```text
Electrical Engineering
        |
        +-- Automotive Electrical
              +-- 12 V systems
              +-- 24 V systems
              +-- charging
              +-- starting
              +-- lighting
              +-- relay logic
              +-- sensors
              +-- actuators
              +-- vehicle networks
```

## 18. Diagram Studio Integration

DS receives analysis through an Engine-facing service/API.

```text
DS Controller
      |
      v
Engineering Analysis API
      |
      v
Analysis Engine
      |
      +---- Engineering Graph
      +---- Knowledge Runtime
      |
      v
AnalysisResult
```

DS must not implement Ohm's Law, maintain a second circuit model, directly query raw reference files, calculate electrical values in widgets, or become the knowledge database.

## 19. DS Analysis Surfaces

After backend validation, DS can expose:

- Analysis Panel — voltage, current, resistance, power, applicable laws, warnings, constraints.
- Derivation Panel — deterministic "why" chain.
- Knowledge Panel — applicable theory.
- Evidence Panel — canonical source identity.

## 20. AI Integration Boundary

AI consumes structured analysis context:

```text
AnalysisResult
      |
      v
Explanation Context
      |
      v
AI Assistant
```

AI may answer questions such as "Explain why the relay does not energize" using topology, states, calculated values, constraints, derivation, and evidence supplied by OEP.

## 21. Implementation Sequence

### AP-EK-001 — Knowledge Contract
Define runtime entity interfaces, equation representation, quantity/unit representation, provenance, and versioning.

### AP-EK-002 — Reference Compiler Boundary
Define `reference_library -> runtime package` without changing reference-library authority.

### AP-EK-003 — Unit and Quantity Engine
Implement unit normalization, dimensional compatibility, conversions, and precision rules.

### AP-EK-004 — Equation Engine
Implement variable binding, equation evaluation, validation, deterministic results, and derivation graph.

### AP-EK-005 — Electrical Laws
Implement Ohm's Law, KCL, KVL, and power equations.

### AP-EK-006 — Electrical Component Models
Implement resistor, voltage source, current source, switch, fuse, and diode as the initial set.

### AP-EK-007 — Circuit Analysis
Resolve nodes, branches, series/parallel relationships, operating states, and applicable equations.

### AP-EK-008 — Constraints
Implement voltage, current, power, polarity, and operating constraints.

### AP-EK-009 — Provenance and Derivation
Make every calculated conclusion explainable.

### AP-EK-010 — Engine/DS API
Expose immutable analysis results.

### AP-EK-011 — DS Analysis Surface
Build UI only after deterministic backend validation.

### AP-EK-012 — Automotive Electrical Profile
Extend the validated electrical foundation into automotive-specific models.

## 22. Testing Strategy

The first acceptance tests must be deterministic.

```text
12 V / 10 Ω = 1.2 A
12 V * 1.2 A = 14.4 W
```

Network, KCL, KVL, provenance, unit-compatibility, missing-parameter, unsupported-model, and invalid-state tests must all be included.

## 23. Initial Scope Limitations

Do NOT initially attempt full SPICE replacement, arbitrary nonlinear device solving, electromagnetic field simulation, thermal FEA, universal fault diagnosis, automatic interpretation of arbitrary textbooks, LLM-generated engineering truth, or autonomous design approval.

The first goal is a small, complete, deterministic electrical reasoning vertical slice.

## 24. First Vertical Slice

```text
12 V Source
     |
    R1
   10 Ω
     |
    GND
```

The system must:

1. identify topology,
2. resolve the voltage source,
3. resolve the resistor,
4. select Ohm's Law,
5. calculate current,
6. calculate power,
7. validate resistor power rating,
8. produce a derivation chain,
9. attach provenance,
10. expose the result to DS,
11. explain the result without requiring AI.

Only after this passes should the system expand to switches, relays, fuses, diodes, and automotive circuits.

## 25. Architectural Non-Negotiables

1. `oep_reference_library` remains authoritative.
2. `oep_acqusition` remains the acquisition/trust boundary.
3. Knowledge runtime does not become a second authoring database.
4. Diagram Studio does not own engineering truth.
5. Deterministic calculations are performed by code, not LLM inference.
6. Units are explicit.
7. Provenance is mandatory.
8. Derived values retain their derivation.
9. Assumptions are explicit.
10. Facts, calculations, constraints, inferences, and hypotheses are distinguishable.
11. Domain-specific knowledge is isolated through domain profiles.
12. The first implementation is a small complete vertical slice.
13. No broad Engine rewrite is authorized merely to support this phase.
14. Any required Engine change must be justified against the existing architecture and implemented as the smallest additive extension.
15. DS presentation remains downstream of authoritative Engine/analysis state.

## 26. Definition of Done

A real OEP diagram can be passed into a deterministic analysis pipeline and DS can show:

```text
WHAT EXISTS
    +
WHAT IS HAPPENING
    +
WHY IT IS HAPPENING
    +
HOW IT WAS CALCULATED
    +
WHICH ENGINEERING LAW SUPPORTS IT
    +
WHERE THE KNOWLEDGE CAME FROM
```

At that point Diagram Studio has crossed the boundary from a diagram editor/simulator toward an engineering reasoning environment without sacrificing OEP's existing authority boundaries.
