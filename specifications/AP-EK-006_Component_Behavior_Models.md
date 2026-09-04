# AP-EK-006
# Component Behavior Models
## Deterministic Engineering Component Modeling Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 — Reference Compiler Boundary; AP-EK-003 — Quantity + Unit Engine; AP-EK-004 — Deterministic Equation Engine; AP-EK-005 — Electrical Law Library  
**Primary consumers:** OEP Engineering Analysis / Knowledge Runtime

---

## 1. Purpose

Define how OEP represents the engineering behavior of physical components without conflating:

```text
Engineering Object identity
Electrical topology
Engineering laws
Component behavior
Simulation behavior
Diagram presentation
```

A component model describes how a particular class of engineering component behaves within an analysis context.

The model may provide:

- parameters;
- terminals;
- equations;
- operating conditions;
- constraints;
- assumptions;
- applicability;
- state variables;
- provenance.

The model does not replace the Engineering Object Model.

---

## 2. Architectural Position

```text
Engineering Object
       |
       v
Component Type / Model Reference
       |
       v
Component Behavior Model
       |
       +---- Parameters
       +---- Terminals
       +---- Equations
       +---- Constraints
       +---- Applicability
       |
       v
Engineering Analysis
       |
       v
Deterministic Equation Engine
       |
       v
AnalysisResult
```

The component model is a knowledge/runtime abstraction.

It is not a Diagram Studio widget.

---

## 3. Identity Boundary

The existing Engineering Object Model remains the identity authority.

A component instance may therefore have:

```text
objectId
objectType = Component
```

The behavior model is referenced by the component instance.

Conceptually:

```text
Component Object
  objectId = ...
  componentModelId = resistor
```

The model identity and the component instance identity are distinct.

---

## 4. Component Model Contract

Conceptual:

```text
ComponentModel
  modelId
  name
  category
  terminals[]
  parameters[]
  states[]
  equations[]
  constraints[]
  assumptions[]
  applicability
  provenance
  version
```

Additional metadata may include:

```text
description
symbols
manufacturerData
referenceIdentifiers
modelFamily
```

Those additions must not compromise the deterministic runtime contract.

---

## 5. Component Instance vs Component Model

A critical distinction:

```text
Component Model
  "Resistor"
```

describes behavior shared by a class.

```text
Component Instance
  R1 = 10 Ω
```

represents one engineering object using that model.

The instance supplies values for model parameters.

---

## 6. Terminals

Electrical components interact with a circuit through terminals.

Conceptual:

```text
Terminal
  terminalId
  name
  domain
  polarity
```

Example:

```text
Resistor
  terminal A
  terminal B
```

A terminal is an analysis connection point.

The physical symbol rendered in Diagram Studio is a separate presentation concern.

---

## 7. Terminal Identity

Terminal identifiers must be stable within a component model.

Example:

```text
resistor.terminal_a
resistor.terminal_b
```

An instance maps its model terminals to actual topology nodes.

```text
R1
  A -> node_1
  B -> node_2
```

This mapping is essential for topology extraction.

---

## 8. Terminal Domains

The initial electrical domain should support at least:

```text
electrical
```

Future domains may include:

```text
mechanical
thermal
fluid
hydraulic
pneumatic
control
signal
```

The component-model architecture should not hard-code electrical assumptions into the generic component abstraction.

---

## 9. Parameters

A component parameter is a typed engineering quantity or structured value.

Example:

```text
Resistor
  resistance = 10 Ω
```

Parameters must have:

```text
parameterId
name
type
unit/dimension where applicable
required/optional
default where authoritative
constraints
provenance
```

Defaults are authoritative data only when explicitly supplied by the knowledge source.

---

## 10. Parameter Validation

Parameter validation occurs before analysis.

Examples:

```text
resistance = 10 Ω
  valid

resistance = 10 V
  invalid

resistance = -5 Ω
  depends on model applicability
```

The model must explicitly determine whether a parameter domain permits negative, zero, or bounded values.

The runtime must not invent those restrictions.

---

## 11. Resistor Model

Initial canonical resistor model:

```text
modelId:
  electrical.resistor
```

Parameters:

```text
R : resistance
```

Terminals:

```text
A
B
```

Primary relationship:

```text
V = I × R
```

The model establishes that the resistor uses an ohmic relationship under its declared applicability conditions.

---

## 12. Resistor Instance

Example:

```text
R1
  model = electrical.resistor
  resistance = 10 Ω
```

If the topology establishes:

```text
12 V across R1
```

the analysis may evaluate:

```text
I = V / R
I = 12 V / 10 Ω
I = 1.2 A
```

The result originates from:

```text
resistor model
+
Ohm's Law
+
Quantity Engine
+
Equation Engine
```

not from Diagram Studio.

---

## 13. Voltage Source Model

Initial conceptual model:

```text
modelId:
  electrical.voltage_source
```

Parameters:

```text
nominalVoltage
```

Terminals:

```text
positive
negative
```

The model establishes an imposed voltage relationship according to its applicability and source behavior.

Ideal-source behavior may be the first implementation.

Non-ideal source resistance belongs to a more advanced model.

---

## 14. Current Source Model

Conceptual:

```text
modelId:
  electrical.current_source
```

Parameters:

```text
nominalCurrent
```

Terminals:

```text
positive
negative
```

The model establishes an imposed current relationship.

Direction/sign convention must be explicit.

---

## 15. Ground / Reference Model

Ground/reference is not simply another resistor-like component.

Conceptually:

```text
modelId:
  electrical.reference_node
```

It establishes the reference potential for a circuit analysis.

The analysis graph should treat reference identity as a topology/model property.

Ground symbols in Diagram Studio remain presentation.

---

## 16. Switch Model

Initial switch model:

```text
modelId:
  electrical.switch
```

State:

```text
OPEN
CLOSED
```

Idealized behavior:

```text
OPEN
  no conductive path

CLOSED
  conductive path
```

The exact resistance/conductance semantics should be explicit in the compiled model.

The switch state is analysis input/state, not diagram styling.

---

## 17. Fuse Model

A fuse should be modeled as a component with both behavior and constraints.

Parameters may include:

```text
ratedCurrent
resistance
```

State may include:

```text
INTACT
OPEN
```

The initial model may remain idealized.

The important architecture is:

```text
Fuse behavior
+
Fuse rating constraint
```

rather than embedding all protection logic inside the electrical law library.

---

## 18. Load Model

A generic load model may be required for divider and circuit analysis.

The first implementation should avoid making "load" a universal behavioral equation.

Instead, a load should reference an explicit model such as:

```text
resistive_load
constant_current_load
constant_power_load
```

where authoritative definitions exist.

---

## 19. Diode Model

A diode is intentionally outside the first simple-resistor vertical slice.

The component-model architecture must nevertheless support nonlinear devices.

Conceptually:

```text
electrical.diode
```

may contain:

```text
forwardVoltage
current
temperature
reverseLimits
```

The actual diode equations and operating-region behavior should be introduced only when authoritative models are available.

The runtime must not fabricate semiconductor equations.

---

## 20. Capacitor Model

Conceptual:

```text
electrical.capacitor
```

Parameter:

```text
capacitance
```

Potential relationship:

```text
I = C × dV/dt
```

This introduces time-domain analysis.

The component-model contract must therefore support equations whose applicability requires a time-domain analysis capability.

The initial AP-EK-007 circuit solver may remain steady-state DC.

---

## 21. Inductor Model

Conceptual:

```text
electrical.inductor
```

Parameter:

```text
inductance
```

Potential relationship:

```text
V = L × dI/dt
```

Again, dynamic analysis is outside the first vertical slice.

The model architecture must not require the first runtime to implement differential-equation solving.

---

## 22. Component State

Some components have state.

Examples:

```text
switch: OPEN/CLOSED
fuse: INTACT/OPEN
relay: DEENERGIZED/ENERGIZED
capacitor: stored voltage
inductor: stored current
```

State must be separate from static model parameters.

Conceptually:

```text
ComponentInstance
  parameters
  state
```

---

## 23. State Authority

Component state may originate from:

```text
analysis initialization
simulation
measurement
user input
stored engineering data
```

The authoritative source must be explicit.

The component model defines what states are valid.

It does not decide where the current state came from.

---

## 24. Simulation Boundary

Simulation and analysis are related but distinct.

```text
Component Model
      |
      +---- Analysis equations
      |
      +---- Simulation behavior
```

A simulation implementation may use the same authoritative component model while maintaining its own dynamic state.

Simulation must not mutate authoritative component definitions.

---

## 25. Component Constraints

Component constraints may include:

```text
minimumVoltage
maximumVoltage
minimumCurrent
maximumCurrent
powerRating
temperatureRange
```

Only constraints supported by authoritative data should be populated.

Constraints belong to the constraint subsystem and are evaluated by AP-EK-008.

---

## 26. Component Applicability

A component model may specify:

```text
operatingMode
domain
temperatureRange
frequencyRange
stateRequirements
parameterRequirements
```

Example:

```text
Ideal switch closed
```

is a different analysis state from:

```text
Ideal switch open
```

Applicability must be explicit.

---

## 27. Model Composition

A component model may depend on multiple laws.

Example:

```text
Resistor
  |
  +-- Ohm's Law
  +-- Power relationship
  +-- current rating constraint
  +-- power rating constraint
```

The component model references these capabilities rather than copying their definitions.

This prevents duplicated engineering knowledge.

---

## 28. Model Inheritance

The runtime may eventually support model specialization.

Example:

```text
resistor
   |
   +-- automotive_resistor
   |
   +-- precision_resistor
```

Inheritance is deferred until a concrete requirement exists.

The first implementation should prefer explicit model composition over deep inheritance trees.

---

## 29. Model Selection

Engineering Analysis resolves:

```text
Engineering Object
      |
      v
Component Model
      |
      v
Applicable model/equations
```

Selection must be deterministic.

Potential evidence includes:

```text
object type
modelId
component metadata
parameters
operating state
analysis domain
```

AI suggestions do not constitute authoritative model selection.

---

## 30. Topology Interaction

The component model exposes terminals.

Engineering Analysis maps those terminals into the electrical graph.

Example:

```text
R1.A -> Node 1
R1.B -> Node 2
```

The component model does not traverse the entire graph.

This preserves the boundary:

```text
Component Model = local behavior
Engineering Analysis = network behavior
```

---

## 31. Relationship Interaction

Existing OEP Relationships remain authoritative for object relationships.

Electrical connectivity is a domain-specific graph interpretation.

The runtime must not create a second competing universal relationship identity system merely for components.

Where electrical topology requires specialized edge/terminal semantics, those semantics must remain linked to the underlying Engineering Object/Relationship identity.

---

## 32. Component Model Registry

Conceptual API:

```text
ComponentModelRegistry
  getModel(modelId)
  listModels(domain)
  validateInstance(instance)
  resolveTerminal(modelId, terminalId)
```

The registry is immutable during an analysis session.

Changes require a new compiled runtime version.

---

## 33. Model Validation

Validation should occur in stages:

```text
1. model identity
2. parameter structure
3. parameter units
4. parameter domains
5. terminal definitions
6. equation references
7. constraint references
8. applicability
9. provenance
```

A model failing validation must not be activated.

---

## 34. Provenance

Every component model requires provenance.

Conceptually:

```text
modelId
modelVersion
knowledgeVersion
sourceObjectId
sourceReference
```

Instance-specific parameter values may have separate provenance.

Example:

```text
R1 resistance = 10 Ω
source = schematic/design input

Resistor model
source = authoritative reference
```

These must not be conflated.

---

## 35. Model Package

The compiled runtime package should contain:

```text
component models
parameter schemas
terminal definitions
equation references
constraint references
applicability rules
provenance
versions
```

The package is immutable once activated.

---

## 36. First Component Package

The initial runtime should prioritize:

```text
electrical.resistor
electrical.voltage_source
electrical.current_source
electrical.reference_node
electrical.switch
```

Additional models:

```text
fuse
generic_resistive_load
```

may follow immediately if required by the first circuit-analysis scenarios.

Nonlinear/dynamic models are explicitly deferred.

---

## 37. First Vertical Slice

Required circuit:

```text
12 V voltage source
10 Ω resistor
reference node
```

Topology:

```text
Source +
   |
   v
  R1
   |
   v
Reference
```

Expected:

```text
V_R1 = 12 V
I_R1 = 1.2 A
P_R1 = 14.4 W
```

The result should identify:

```text
source model
resistor model
selected law
equations
topology
input parameters
calculated values
provenance
```

---

## 38. Switch Scenario

Circuit:

```text
12 V source
switch
10 Ω resistor
reference
```

When:

```text
switch = CLOSED
```

the resistor participates in the conductive network.

When:

```text
switch = OPEN
```

the idealized circuit path is interrupted.

The analysis must not report the closed-state current for the open-state topology.

---

## 39. Invalid Component Example

If a resistor instance declares:

```text
resistance = 10 V
```

model validation fails because:

```text
V != Ω
```

The system must report a structured parameter/unit error.

---

## 40. Model Failure Modes

At minimum:

```text
UNKNOWN_COMPONENT_MODEL
INVALID_MODEL
INVALID_PARAMETER
INVALID_PARAMETER_UNIT
INVALID_TERMINAL
INVALID_STATE
MISSING_REQUIRED_PARAMETER
MODEL_NOT_APPLICABLE
UNKNOWN_EQUATION_REFERENCE
UNKNOWN_CONSTRAINT_REFERENCE
MISSING_PROVENANCE
```

---

## 41. AI Boundary

AI may:

```text
explain component behavior
suggest a candidate model
help identify terminology
generate documentation
```

AI may not:

```text
invent component parameters
invent operating limits
invent equations
override model applicability
override parameter validation
alter authoritative model definitions
```

Any AI-generated model remains non-authoritative until processed through the knowledge-authoring pipeline.

---

## 42. Testing

### Model registry

- known models resolve;
- unknown models fail;
- versions are stable.

### Parameter validation

- correct units accepted;
- incorrect units rejected;
- required values enforced.

### Terminal validation

- valid terminal mappings accepted;
- unknown terminals rejected;
- duplicate invalid mappings rejected.

### Behavioral tests

Resistor:

```text
12 V / 10 Ω = 1.2 A
```

Voltage source:

```text
source voltage = declared voltage
```

Switch:

```text
OPEN -> no conductive path
CLOSED -> conductive path
```

### Provenance

Model and instance data must retain independent provenance.

### Determinism

Identical model package, parameters, states, topology, and runtime version must produce equivalent analysis inputs/results.

---

## 43. Definition of Done

AP-EK-006 is complete when:

1. component model contract exists;
2. model/instance identity separation is defined;
3. terminal abstraction exists;
4. parameter contract exists;
5. state contract exists;
6. applicability is represented;
7. model-to-equation references work;
8. model-to-constraint references work;
9. provenance is preserved;
10. component registry is versioned;
11. resistor model works end-to-end;
12. voltage source model works;
13. reference node model works;
14. switch model works at minimum ideal level;
15. first vertical slice can resolve component behavior without DS-specific logic;
16. nonlinear/dynamic models have an explicit extension path without requiring them in the first implementation.

---

## 44. Follow-On

```text
AP-EK-007  Circuit Analysis / Topology Solver
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/Diagram Studio Analysis API
AP-EK-011  Dynamic / Nonlinear Analysis Extension
```

---

## Architectural Non-Negotiables

1. Engineering Object identity remains authoritative.
2. Component model identity is distinct from component instance identity.
3. Component models describe local behavior.
4. Engineering Analysis owns network/topology reasoning.
5. Laws remain separate from component models.
6. Constraints remain separate from equations.
7. Simulation state remains separate from authoritative model definitions.
8. Parameters carry explicit engineering meaning and units.
9. Unknown behavior must not be invented.
10. AI cannot become authoritative for component behavior.
11. Component models are compiled into the Knowledge Runtime.
12. Runtime model registries are versioned and immutable during analysis.
13. Diagram Studio renders/presents components; it does not define their engineering behavior.
14. Nonlinear and dynamic behavior must have an extension path without contaminating the initial DC analysis core.
15. Existing OEP object/relationship architecture is reused rather than replaced.
