# AP-EK-007
# Circuit Analysis / Topology Solver
## Deterministic Electrical Graph-to-Circuit Analysis Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-006  
**Primary consumers:** OEP Engineering Analysis Runtime  
**Presentation consumer:** Diagram Studio

---

## 1. Purpose

Define the deterministic circuit-analysis subsystem that transforms an OEP Engineering Graph into an analyzable electrical circuit model.

This increment establishes the boundary between:

```text
Engineering Graph
      |
      v
Electrical Topology
      |
      v
Circuit Model
      |
      v
Law / Equation / Component Resolution
      |
      v
Deterministic Analysis
      |
      v
AnalysisResult
```

The subsystem must determine:

- electrical nodes;
- component terminal connections;
- branches;
- reference nodes;
- circuit connectivity;
- applicable analysis models;
- solvable circuit equations;
- deterministic electrical quantities;
- topology diagnostics.

---

## 2. Architectural Principle

Diagram geometry is not circuit topology.

The solver operates on engineering connectivity, not:

```text
pixel coordinates
wire appearance
SVG paths
widget positions
visual proximity
```

A visually connected wire is meaningful only when the authoritative Engineering Graph represents the corresponding electrical relationship.

---

## 3. Source of Truth

The analysis pipeline begins with authoritative OEP engineering state:

```text
DiagramDocument
      |
      v
Engineering Graph
      |
      v
Electrical Topology Extraction
```

Diagram Studio remains a presentation/editing surface.

It must not independently calculate circuit results.

---

## 4. Analysis Boundary

The Circuit Analysis subsystem owns:

```text
topology extraction
node construction
branch construction
terminal mapping
connectivity validation
reference-node resolution
circuit-model construction
equation assembly
solver orchestration
analysis diagnostics
```

It does not own:

```text
repository persistence
diagram rendering
Flutter widgets
WebView implementation
marketplace behavior
knowledge acquisition
reference compilation
```

---

## 5. Required Input

The solver requires, at minimum:

```text
Engineering Objects
Engineering Relationships
Component Models
Component Parameters
Component States
Electrical Law Registry
Equation Registry
Unit Registry
Analysis Context
```

The analysis context may include:

```text
operating state
requested analysis type
reference node
precision policy
known inputs
boundary conditions
```

---

## 6. Electrical Topology

The solver constructs a normalized electrical topology:

```text
Circuit
  nodes[]
  branches[]
  components[]
  terminals[]
  referenceNode
```

The topology must be deterministic.

Equivalent input graphs must produce equivalent normalized topology.

---

## 7. Terminal Mapping

Every electrical component instance exposes model terminals.

Example:

```text
R1.A
R1.B
```

The topology extractor resolves each terminal to a circuit node.

Example:

```text
R1.A -> Node 1
R1.B -> Node 0
```

Terminal identity comes from the Component Model.

Connectivity comes from Engineering Relationships.

---

## 8. Node Construction

A circuit node represents an electrically common set of terminals.

Conceptually:

```text
Node
  nodeId
  terminalRefs[]
  referenceFlag
```

Two terminals belong to the same node only when the authoritative graph establishes electrical connectivity according to the electrical relationship semantics.

Spatial overlap is insufficient.

---

## 9. Node Identity

Normalized node identity must be deterministic.

Node IDs must not depend on:

```text
widget creation order
memory address
screen position
random UUID generation
```

A stable canonical ordering or deterministic content-derived identity should be used.

The final identity mechanism must preserve traceability back to the source terminals/relationships.

---

## 10. Reference Node

A circuit requires a reference potential for absolute node-voltage reporting.

The topology may contain:

```text
one explicit reference node
```

or, where the analysis contract permits, a reference may be selected from explicit analysis context.

The solver must not silently choose an arbitrary reference when the analysis requires one and none is defined.

Status:

```text
REFERENCE_REQUIRED
```

should be returned when appropriate.

---

## 11. Ground Semantics

A graphical ground symbol is a presentation object unless it is connected to an authoritative reference-node model.

Therefore:

```text
ground-looking symbol
```

does not automatically mean:

```text
electrical reference
```

The engineering graph determines the actual semantics.

---

## 12. Branch Construction

A branch represents an electrical path between two nodes through one or more modeled elements.

For the initial solver, the preferred normalized representation is:

```text
Branch
  branchId
  fromNode
  toNode
  componentRefs[]
  terminalRefs[]
```

The exact branch aggregation strategy must preserve enough information to calculate component-level quantities.

---

## 13. Component-Level Traceability

Even when multiple elements form a topological branch, analysis results must remain traceable to individual components.

Example:

```text
R1
R2
```

may participate in one series path, but results must still expose:

```text
R1 current
R1 voltage
R2 current
R2 voltage
```

when calculable.

---

## 14. Connectivity Validation

Before solving, the topology must be validated.

At minimum:

```text
floating terminal
unconnected component
invalid terminal mapping
unknown component model
invalid relationship
multiple conflicting references
isolated subcircuit
```

must produce explicit diagnostics.

The solver must not invent missing connections.

---

## 15. Circuit Classification

The first implementation should classify circuits into useful deterministic categories.

At minimum:

```text
OPEN
SHORT
CONNECTED
DISCONNECTED
UNSOLVABLE
```

Future classification may include:

```text
PURE_SERIES
PURE_PARALLEL
SERIES_PARALLEL
BRIDGE
GENERAL_LINEAR
NONLINEAR
DYNAMIC
```

Classification is an aid to selecting analysis strategies; it is not itself the electrical solution.

---

## 16. Analysis Modes

The initial circuit solver should support:

```text
DC steady-state linear analysis
```

This covers:

```text
resistors
ideal voltage sources
ideal current sources
switches
reference nodes
```

The architecture must provide extension points for:

```text
AC analysis
transient analysis
nonlinear DC
frequency-domain analysis
dynamic systems
```

These are explicitly deferred.

---

## 17. Topology-Dependent Law Selection

The solver may identify candidate laws based on topology.

Examples:

```text
single resistor
  -> Ohm's Law

series resistors
  -> Series Resistance + Ohm's Law

parallel resistors
  -> Parallel Resistance + KCL

closed loop
  -> KVL
```

The solver provides the context.

The Law Library determines authoritative relationships.

The Equation Engine executes them.

---

## 18. General Linear Circuit Strategy

The architecture should not depend exclusively on special-case formulas.

For general linear circuits, the preferred foundation is a deterministic nodal-analysis approach.

Conceptually:

```text
1. Identify reference node
2. Assign node variables
3. Identify component constitutive relationships
4. Apply KCL
5. Incorporate source constraints
6. Assemble linear system
7. Solve system
8. Recover branch/component quantities
9. Validate constraints
10. Produce derivation/provenance
```

This allows simple circuits and more complex linear networks to share one computational foundation.

---

## 19. Nodal Analysis

For each non-reference node:

```text
Σ I_branch = 0
```

For a resistor between nodes `a` and `b`:

```text
I_ab = (V_a - V_b) / R
```

The Equation Engine evaluates the relationship.

Engineering Analysis supplies:

```text
node assignments
branch direction
component parameters
```

---

## 20. Voltage Sources

Ideal voltage sources require an explicit voltage constraint.

Example:

```text
V_a - V_b = 12 V
```

The solver must not model an ideal voltage source as an arbitrary large conductance.

That would introduce an approximation into the authoritative analysis.

The implementation may use an appropriate exact linear-system formulation such as modified nodal analysis.

---

## 21. Current Sources

An ideal current source contributes a known current term according to its declared direction.

The sign convention must be deterministic.

Example:

```text
+2 A into Node A
```

must be represented consistently throughout KCL assembly.

---

## 22. Resistors

For resistor:

```text
R = 10 Ω
```

between nodes:

```text
A
B
```

the branch current is:

```text
I_AtoB = (V_A - V_B) / 10 Ω
```

This relationship derives from the resistor model and Ohm's Law.

---

## 23. Switches

For an ideal switch:

```text
OPEN
```

the conductive branch is absent for the relevant analysis state.

For:

```text
CLOSED
```

the branch becomes conductive according to the switch model.

State must come from the authoritative component state/input context.

---

## 24. Series Detection

A series relationship can be recognized when components share an intermediate node that:

```text
connects exactly the relevant branch terminals
```

and does not have additional electrically significant branches.

The solver may use series reduction as an optimization.

It must preserve equivalent component-level results.

---

## 25. Parallel Detection

Parallel elements share the same two electrical nodes.

For:

```text
R1
R2
```

if both connect:

```text
Node A
Node B
```

they are parallel under the circuit model.

Parallel reduction may be used as an optimization, but the normalized model must retain original components for result reconstruction.

---

## 26. Voltage Divider Detection

The solver may recognize:

```text
Vin -> R1 -> R2 -> reference
```

as a voltage-divider topology.

The unloaded divider equation may be used only when:

```text
no load alters the output node
```

If a load exists:

```text
Vin -> R1 -> output -> R2 -> reference
                  |
                 RL
                  |
               reference
```

the unloaded divider equation must not be selected.

The general linear solver should handle the loaded case.

---

## 27. Current Divider Detection

A current-divider topology may be recognized when branch elements share the same two nodes.

The solver must verify that the required topology conditions are satisfied before using the specialized divider equations.

---

## 28. Short Circuits

A zero-impedance path requires explicit handling.

The solver must not blindly evaluate:

```text
I = V / 0 Ω
```

Instead, it must classify the topology/model and determine whether the circuit is:

```text
valid ideal short
inconsistent source condition
underdetermined
```

according to the authoritative models and solver rules.

---

## 29. Open Circuits

An open path must not be treated as a finite resistance unless the model explicitly defines such behavior.

For an ideal open branch:

```text
I = 0 A
```

may be inferred only when supported by the component model and circuit topology.

---

## 30. Floating Nodes

A node with no valid reference path may still be mathematically solvable in some formulations, but absolute voltage may be undefined.

The solver must distinguish:

```text
floating but solvable relative network
```

from:

```text
invalid/underdetermined circuit
```

and report the appropriate status.

---

## 31. Singular Systems

A linear system may be singular because of:

```text
floating network
redundant constraints
conflicting ideal sources
invalid topology
insufficient boundary conditions
```

The solver must return a structured diagnostic rather than an arbitrary numerical solution.

---

## 32. Inconsistent Systems

Example:

```text
ideal 12 V source
ideal 5 V source
same two nodes
same polarity
```

may create an inconsistent ideal model.

The solver must identify the contradiction when the assembled system proves inconsistent.

It must not silently choose one source.

---

## 33. Underdetermined Systems

If multiple solutions exist because insufficient information is supplied, the solver must report:

```text
UNDERDETERMINED
```

rather than selecting one arbitrarily.

This is a core engineering trust requirement.

---

## 34. Numerical Solver

The initial implementation requires a deterministic linear-system solver suitable for small and medium engineering circuits.

The algorithm must define:

```text
matrix construction
pivoting strategy
singularity detection
tolerance policy
solution validation
```

The selected implementation must produce reproducible results under the same numeric/runtime policy.

---

## 35. Solver Tolerance

Tolerance must be explicit.

It may be used for:

```text
zero detection
KCL residual
KVL residual
matrix singularity
constraint comparisons
```

Tolerance must not be silently changed by individual component models.

The analysis result should retain the relevant numerical policy/version.

---

## 36. Result Reconstruction

After solving node variables, the solver reconstructs:

```text
node voltages
branch currents
component voltage
component current
component power
```

where the relevant component model/equations support those quantities.

Example:

```text
V_R1 = V_A - V_B
I_R1 = V_R1 / R
P_R1 = V_R1 × I_R1
```

---

## 37. Power Balance

For DC circuits, the solver should provide an optional power-balance validation.

Conceptually:

```text
Σ P_sources + Σ P_loads = 0
```

within the configured numerical tolerance.

A nonzero residual may indicate:

```text
solver error
model error
topology error
numerical issue
```

and should be exposed diagnostically.

---

## 38. Analysis Pipeline

The canonical pipeline is:

```text
DiagramDocument
      |
      v
Engineering Graph
      |
      v
Electrical Topology Extraction
      |
      v
Topology Validation
      |
      v
Component Model Resolution
      |
      v
Reference Resolution
      |
      v
Circuit Classification
      |
      v
Law / Equation Selection
      |
      v
Circuit Equation Assembly
      |
      v
Deterministic Solve
      |
      v
Result Reconstruction
      |
      v
Constraint Evaluation
      |
      v
Provenance / Derivation
      |
      v
AnalysisResult
```

---

## 39. AnalysisResult

The circuit solver should produce a structured result containing conceptually:

```text
AnalysisResult
  analysisId
  status
  circuitIdentity
  runtimeVersion
  topology
  nodeResults
  componentResults
  branchResults
  equationResults
  diagnostics
  derivation
  provenance
  constraintResults
```

The final canonical result contract is established by AP-EK-009.

---

## 40. Component Result

Conceptual:

```text
ComponentAnalysisResult
  componentObjectId
  modelId
  terminalVoltages[]
  currents[]
  powers[]
  states[]
  constraints[]
```

Only quantities actually supported/calculable should be populated.

---

## 41. Node Result

Conceptual:

```text
NodeAnalysisResult
  nodeId
  voltage
  reference
  connectedTerminals[]
```

The reference node should report:

```text
0 V
```

according to the selected analysis reference convention.

---

## 42. Branch Result

Conceptual:

```text
BranchAnalysisResult
  branchId
  fromNode
  toNode
  current
  voltage
  componentRefs[]
```

Current direction must be explicit.

A negative calculated current is valid information and should not be converted into an absolute value.

---

## 43. Sign Conventions

The solver must establish globally consistent conventions.

Initial recommendation:

```text
Branch current:
  positive from fromNode -> toNode

Voltage:
  V = V_fromNode - V_toNode
```

Component models must map their terminal polarity into this convention.

---

## 44. Deterministic Topology Normalization

Equivalent graph inputs should normalize to the same logical topology regardless of:

```text
object ordering
relationship insertion order
diagram coordinates
wire route geometry
UI tab
rendering implementation
```

This is critical for reproducible analysis.

---

## 45. Diagram Studio Boundary

Diagram Studio may request:

```text
analyze current diagram
```

but the analysis implementation remains in Engine/runtime.

DS receives:

```text
AnalysisResult
```

and presents:

```text
node values
component values
warnings
violations
derivation
provenance
```

DS must not reimplement:

```text
KCL
KVL
Ohm's Law
matrix solving
component behavior
```

---

## 46. Simulation Boundary

Simulation and circuit analysis may share component models but have different execution semantics.

```text
Analysis
  deterministic solution for defined conditions

Simulation
  state evolution over time/interaction
```

The analysis solver must not read transient simulation state unless explicitly supplied as analysis input.

---

## 47. First Vertical Slice

Circuit:

```text
12 V ideal source
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

Solver result:

```text
V_R1 = 12 V
I_R1 = 1.2 A
P_R1 = 14.4 W
```

Expected power balance:

```text
P_source = -14.4 W
P_R1     = +14.4 W

ΣP = 0 W
```

---

## 48. Second Vertical Slice

Circuit:

```text
12 V source
R1 = 10 Ω
R2 = 20 Ω
reference
```

Series reduction:

```text
Rtotal = 30 Ω
```

Current:

```text
I = 12 V / 30 Ω
I = 0.4 A
```

Voltage drops:

```text
V_R1 = 4 V
V_R2 = 8 V
```

KVL:

```text
12 V - 4 V - 8 V = 0 V
```

---

## 49. Third Vertical Slice

Circuit:

```text
12 V source
R1 = 10 Ω
R2 = 20 Ω
parallel
```

Expected equivalent resistance:

```text
Rtotal = 6.666... Ω
```

Expected source current:

```text
I_total = 12 V / 6.666... Ω
        = 1.8 A
```

Branch currents:

```text
I1 = 1.2 A
I2 = 0.6 A
```

KCL:

```text
1.2 A + 0.6 A - 1.8 A = 0 A
```

---

## 50. Fourth Vertical Slice — Loaded Divider

Circuit:

```text
Vin
 |
R1
 |
 +---- Vout
 |      |
R2     RL
 |      |
 +------+
 |
Reference
```

The solver must treat:

```text
R2 || RL
```

as the effective lower branch.

It must not apply the unloaded two-resistor divider formula directly.

This validates the boundary between specialized law selection and general topology analysis.

---

## 51. Fifth Vertical Slice — Switch

Circuit:

```text
12 V source
switch
10 Ω resistor
reference
```

State:

```text
CLOSED
```

must produce:

```text
I = 1.2 A
```

State:

```text
OPEN
```

must produce the model-defined open-circuit result.

The analysis must reflect the current component state.

---

## 52. Diagnostics

The solver should provide structured diagnostics such as:

```text
NO_REFERENCE_NODE
FLOATING_NODE
UNCONNECTED_TERMINAL
UNKNOWN_COMPONENT_MODEL
INVALID_PARAMETER
INVALID_TOPOLOGY
SINGULAR_SYSTEM
INCONSISTENT_SYSTEM
UNDERDETERMINED_SYSTEM
UNSUPPORTED_COMPONENT
UNSUPPORTED_ANALYSIS_MODE
INVALID_SOURCE_CONFIGURATION
```

Diagnostics should identify affected object/node/relationship IDs where possible.

---

## 53. Unsupported Models

If a circuit contains a component model outside the current solver capability:

```text
electrical.diode
```

for example, the solver should return:

```text
UNSUPPORTED_COMPONENT_MODEL
```

or an appropriate analysis status.

It must not substitute an invented resistor or linear approximation unless an authoritative approximation model explicitly exists.

---

## 54. Analysis Context

Analysis should accept explicit context:

```text
analysisMode
referenceNode
knownInputs
operatingState
numericPolicy
requestedOutputs
```

The context is part of reproducibility.

---

## 55. Caching

Analysis results may be cached.

A cache key must account for:

```text
diagram/graph identity
graph version
component model versions
law/equation versions
knowledge runtime version
analysis context
numeric policy
```

A cache hit must return the same observable result and provenance as a fresh calculation.

---

## 56. Security / Trust

The solver executes only validated compiled models and equations.

It must not execute:

```text
arbitrary code
raw scripts embedded in engineering documents
LLM-generated executable expressions
untrusted UI callbacks
```

Compiled knowledge is data interpreted by deterministic runtime components.

---

## 57. Testing

### Topology

- terminal-to-node mapping;
- deterministic node identity;
- series detection;
- parallel detection;
- reference resolution;
- open/closed switch topology;
- disconnected networks.

### Solver

- single resistor;
- series resistors;
- parallel resistors;
- voltage divider;
- loaded divider;
- ideal voltage source;
- ideal current source;
- KCL;
- KVL.

### Failure

- no reference;
- floating network;
- singular system;
- inconsistent sources;
- underdetermined network;
- unsupported model;
- invalid parameter.

### Reproducibility

Identical:

```text
graph
knowledge runtime
models
inputs
analysis context
numeric policy
```

must produce equivalent serialized results.

### Conservation

KCL and KVL residuals must remain within explicit tolerance.

Power balance must pass for supported DC circuits.

---

## 58. Definition of Done

AP-EK-007 is complete when:

1. electrical topology extraction exists;
2. terminal-to-node mapping works;
3. deterministic node normalization exists;
4. reference-node handling exists;
5. topology validation exists;
6. component models resolve;
7. law/equation selection context exists;
8. deterministic linear circuit solving exists;
9. ideal voltage/current sources are supported;
10. resistor networks are supported;
11. switches are supported at the initial model level;
12. node/branch/component results are reconstructed;
13. KCL/KVL residuals can be validated;
14. power balance can be validated;
15. singular/inconsistent/underdetermined systems are explicit;
16. unsupported models fail safely;
17. provenance and runtime versions are retained;
18. first five vertical slices pass;
19. Diagram Studio consumes results rather than implementing circuit mathematics.

---

## 59. Follow-On

```text
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/Diagram Studio Analysis API
AP-EK-011  Dynamic / Nonlinear Analysis Extension
AP-EK-012  Electrical Analysis Validation Suite
```

---

## Architectural Non-Negotiables

1. Engineering Graph connectivity is the source of circuit topology.
2. Diagram geometry is never electrical truth.
3. Component models provide local behavior.
4. Engineering Analysis provides network behavior.
5. Laws remain authoritative knowledge.
6. Equations remain deterministic executable representations.
7. The solver must not invent missing components, connections, equations, or values.
8. General linear analysis must have a principled matrix-based foundation rather than only special-case formulas.
9. Ideal sources must be modeled explicitly, not approximated by arbitrary conductances.
10. Singular, inconsistent, and underdetermined systems are explicit engineering states.
11. Sign conventions are global and deterministic.
12. Component-level traceability is preserved after topology reduction.
13. KCL/KVL and power balance are validation mechanisms, not presentation features.
14. AI cannot override or replace deterministic circuit solving.
15. Diagram Studio receives analysis results and does not perform authoritative engineering calculations.
16. Simulation state is separate from analysis state.
17. Runtime knowledge/model/equation versions are part of reproducibility.
18. The architecture must extend to nonlinear and dynamic analysis without rewriting the foundational graph/model boundaries.
