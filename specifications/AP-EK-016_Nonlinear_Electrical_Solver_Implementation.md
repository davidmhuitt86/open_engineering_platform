# AP-EK-016
# Nonlinear Electrical Solver Implementation
## Deterministic Nonlinear DC Analysis, Iteration, Convergence, and Device Models

**Status:** Architecture Phase — Implementation Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-001 through AP-EK-015  
**Primary objective:** Define the first implementable nonlinear electrical analysis solver while preserving the deterministic Engine/Knowledge Runtime boundaries established by the preceding architecture.

---

## 1. Purpose

AP-EK-016 extends the electrical analysis foundation beyond ideal linear components.

The initial linear solver established the ability to analyze networks composed of linear models such as:

```text
resistor
ideal voltage source
ideal current source
reference node
switch
```

Real engineering systems also contain components whose behavior is nonlinear.

Initial examples:

```text
diode
LED
transistor
thermistor
varistor
semiconductor junction
nonlinear load
```

This increment defines the architecture required to solve nonlinear steady-state electrical systems deterministically.

---

## 2. Scope

This specification covers:

```text
nonlinear component equations
piecewise models
system assembly
Newton-style iterative solving
Jacobian construction
initial guesses
convergence
residual evaluation
failure classification
deterministic iteration policy
multiple-solution handling
provenance
constraint integration
AnalysisResult integration
```

It does not yet implement:

```text
transient analysis
AC frequency-domain analysis
thermal coupling
electromagnetic simulation
full semiconductor physics
```

Those remain future extensions.

---

## 3. Architectural Position

The system remains:

```text
DiagramDocument
      ↓
Engineering Graph
      ↓
Topology Extraction
      ↓
Component Model Resolution
      ↓
Nonlinear System Assembly
      ↓
Nonlinear Solver
      ↓
Constraint Evaluation
      ↓
Provenance / Derivation
      ↓
AnalysisResult
      ↓
Explanation / DS
```

The nonlinear solver is part of Engineering Analysis.

It is not part of Diagram Studio.

---

## 4. Authority Boundary

The Knowledge Runtime supplies:

```text
component models
equations
parameters
constraints
units
applicability
provenance
```

The nonlinear solver interprets those definitions.

The solver must not invent component behavior.

---

## 5. Linear vs Nonlinear

A system is linear only when its governing equations satisfy linearity with respect to unknowns.

Example:

```text
I = V / R
```

with constant R is linear.

A nonlinear example:

```text
I = Is × (exp(Vd / (nVt)) - 1)
```

contains an exponential dependency on an unknown voltage.

Such a system requires nonlinear solution methods.

---

## 6. Analysis Mode

Use:

```text
DC_STEADY_STATE_NONLINEAR
```

for the initial implementation.

The analysis mode must be stored in:

```text
AnalysisRequest
AnalysisResult
AnalysisSnapshot
```

as established by AP-EK-010 and AP-EK-015.

---

## 7. Nonlinear System Representation

Normalize the circuit into:

```text
NonlinearAnalysisSystem
  unknowns[]
  equations[]
  parameters[]
  constraints[]
  initialState
  referenceState
  solverPolicy
```

The solver should operate on this normalized system rather than directly on DiagramDocument structures.

---

## 8. Unknowns

Typical unknowns include:

```text
node voltages
branch currents
auxiliary voltage-source currents
device state variables
```

Each unknown requires:

```text
unknownId
name
unit
dimension
initialValue
bounds where applicable
sourceReference
```

Unknown identity must be deterministic.

---

## 9. Equations

Each nonlinear equation must provide:

```text
equationId
residual expression
variables
parameters
units/dimensions
applicability
provenance
```

The solver evaluates residuals.

The equation itself remains authoritative knowledge.

---

## 10. Residual Form

For numerical solving, equations should be normalized to:

```text
F(x) = 0
```

where:

```text
x = vector of unknowns
F = vector of residuals
```

Example:

```text
I - Is × (exp(Vd/(nVt)) - 1) = 0
```

The solver seeks:

```text
F(x) ≈ 0
```

within the declared numerical tolerance.

---

## 11. Dimensional Validation

Before numerical execution:

```text
every equation
every parameter
every constant
every residual
```

must pass Quantity/Unit dimensional validation.

Invalid dimensions are a model/knowledge error, not a numerical convergence problem.

---

## 12. Jacobian

For Newton-style methods, define:

```text
J(x) = ∂F/∂x
```

The Jacobian may be supplied through:

```text
analytic derivatives
automatic differentiation
symbolically compiled derivatives
finite-difference approximation
```

Initial implementation should prefer deterministic analytic/compiled derivatives where available.

---

## 13. Derivative Authority

Derivative expressions are derived from authoritative equation definitions.

They must not change the physical meaning of the equation.

If a derivative is unavailable and finite difference is permitted, the method and step policy must be recorded in provenance.

---

## 14. Solver Abstraction

The existing AP-EK-011 solver abstraction becomes:

```text
NonlinearSolver
  solve(system, policy)
```

Potential implementation:

```text
NewtonSolver
```

Future:

```text
DampedNewtonSolver
TrustRegionSolver
ContinuationSolver
```

The solver implementation remains separate from component models.

---

## 15. Initial Guess

Nonlinear solving requires an initial guess.

The source must be explicit.

Possible sources:

```text
component default
zero-state
previous analysis
linearized solution
user supplied
deterministic heuristic
```

The selected source must be recorded.

---

## 16. Initial Guess Policy

Initial implementation should define a deterministic default hierarchy.

Recommended:

```text
1. explicitly supplied valid initial state
2. valid prior compatible analysis state
3. deterministic model-provided default
4. deterministic zero/nominal initialization
```

The hierarchy must be documented and versioned.

---

## 17. Previous Analysis as Initial Guess

A previous analysis may provide an initial state only when:

```text
same compatible topology
same compatible model identities
same required knowledge semantics
```

Otherwise it must not be silently reused.

---

## 18. Bounds

Some unknowns may have meaningful bounds.

Examples:

```text
diode current >= 0
temperature > 0 K
junction state within model range
```

Bounds are model/constraint metadata.

The solver must distinguish:

```text
mathematical convergence
physical/model validity
```

---

## 19. Convergence

A nonlinear solution requires explicit convergence criteria.

At minimum:

```text
residual norm
step norm
```

should be considered.

Example conceptual condition:

```text
||F(x)|| <= residualTolerance
```

and optionally:

```text
||Δx|| <= stepTolerance
```

---

## 20. Residual Norm

The norm must be deterministic.

Initial implementation should use a defined norm such as:

```text
infinity norm
```

with an explicit scaling policy.

Do not leave norm semantics implementation-dependent.

---

## 21. Variable Scaling

Poorly scaled systems can converge badly.

The solver should support deterministic scaling:

```text
voltage scale
current scale
parameter scale
residual scale
```

The selected scaling policy must be persisted in solver provenance.

---

## 22. Iteration Limit

Every solve requires:

```text
maximumIterations
```

If exceeded:

```text
NONLINEAR_NO_CONVERGENCE
```

must be returned.

Never return the last iterate as a successful engineering result merely because the iteration limit was reached.

---

## 23. Newton Update

Conceptual:

```text
J(xk) Δx = -F(xk)

x(k+1) = xk + Δx
```

The linear system solution must use the deterministic linear solver infrastructure.

---

## 24. Singular Jacobian

If:

```text
J(x)
```

is singular or numerically ill-conditioned beyond declared policy:

```text
SINGULAR_JACOBIAN
```

or an equivalent structured diagnostic must be returned.

The solver must not silently perturb the system to obtain a result.

---

## 25. Damping

Pure Newton iteration can overshoot.

A future or optional deterministic damping policy may use:

```text
x(k+1) = xk + αΔx
```

where:

```text
0 < α <= 1
```

The selection policy must be deterministic.

---

## 26. Line Search

If implemented, line search must be deterministic.

It may minimize a declared merit function such as:

```text
||F(x)||²
```

subject to explicit termination rules.

---

## 27. Multiple Solutions

A nonlinear system may have multiple valid solutions.

The solver must not claim uniqueness unless uniqueness is established by an applicable method/model.

If multiple solutions are discovered:

```text
MULTIPLE_SOLUTIONS
```

may be returned.

---

## 28. Initial-Guess Dependence

If different valid initial guesses converge to different solutions, that fact is engineering evidence.

The analysis result should preserve:

```text
initial guess policy
converged solution
alternative solution evidence where evaluated
```

A single solution must not automatically be labeled globally unique.

---

## 29. Piecewise Models

Many engineering components are piecewise.

Example conceptual diode model:

```text
if Vd < threshold:
    state = OFF

else:
    state = ON
```

The model must explicitly declare:

```text
regions
conditions
equations
state transitions
```

---

## 30. Piecewise Boundary

At a region boundary, the system must define behavior.

Example:

```text
Vd = Vthreshold
```

The model must specify whether:

```text
either region is valid
one region has precedence
a transition state exists
```

The solver must not invent boundary semantics.

---

## 31. Diode Model

The first nonlinear component implementation should be a deliberately bounded diode model.

Possible initial model:

```text
ideal diode
```

or:

```text
piecewise constant-voltage diode
```

The selected model must come from the Knowledge Runtime.

A full Shockley model may follow.

---

## 32. Ideal Diode

Conceptual states:

```text
OFF:
I = 0
Vd <= 0

ON:
Vd = 0
I >= 0
```

The model is a complementarity/piecewise system rather than a simple explicit equation.

This should be treated accordingly.

---

## 33. Piecewise Linear Diode

A practical deterministic first model may use:

```text
OFF:
I = 0

ON:
Vd = Vf + I × Rd
```

with explicit region conditions.

Parameters:

```text
Vf
Rd
```

must be supplied by the component model.

---

## 34. Shockley Diode

A later model may use:

```text
I = Is × (exp(Vd/(nVt)) - 1)
```

Parameters:

```text
Is
n
Vt
```

must be explicit.

Numerical overflow handling must be defined.

---

## 35. Exponential Safety

The solver must not evaluate an exponential blindly.

The model/runtime must define:

```text
valid input range
overflow behavior
underflow behavior
limiting policy
```

Any numerical limiting must be semantically documented.

A hidden clamp is not acceptable.

---

## 36. Temperature

If a diode model depends on temperature:

```text
temperature
```

must be an explicit input or model state.

Do not silently assume:

```text
25 °C
```

unless the model explicitly defines that as its nominal/default parameter.

---

## 37. Component Model Contract

Each nonlinear component model should expose:

```text
residual equations
unknown dependencies
parameter definitions
state definitions
applicability
bounds
derivatives where available
constraints
provenance
```

---

## 38. Network Assembly

For each component:

```text
resolve model
resolve terminals
map terminals to electrical nodes
bind parameters
instantiate equations
instantiate constraints
```

Then add network equations:

```text
KCL
KVL where required
source equations
branch relationships
```

---

## 39. Modified Nodal Analysis

The preferred general network formulation remains:

```text
Modified Nodal Analysis
```

extended with nonlinear device residual equations.

This avoids creating special-case network solvers for every nonlinear component.

---

## 40. Nonlinear MNA

Conceptually:

```text
F(x) =
[
  KCL residuals
  source residuals
  linear branch residuals
  nonlinear device residuals
]
```

Newton iteration evaluates:

```text
F(x)
J(x)
```

until convergence.

---

## 41. Linear Components in Nonlinear Networks

Linear components should continue using their existing models.

A nonlinear network may therefore contain:

```text
resistors
voltage sources
current sources
switches
diodes
```

within one system.

No duplicate linear component implementation should be created for nonlinear analysis.

---

## 42. Switch State

Switches remain explicit engineering states.

A nonlinear analysis may analyze:

```text
switch open
switch closed
```

as separate deterministic configurations.

Do not silently change switch state during nonlinear solving unless a model explicitly defines switching behavior.

---

## 43. Topology Changes

If a component changes topology based on state, the model must expose that behavior explicitly.

The solver should distinguish:

```text
continuous nonlinear state
discrete topology/state transition
```

This establishes groundwork for future hybrid-system analysis.

---

## 44. Convergence Diagnostics

Every nonlinear solve should record:

```text
iterations
initial residual
final residual
final step norm
termination condition
solver policy
scaling policy
initial guess
```

This is required for reproducibility and explanation.

---

## 45. Iteration Trace

An optional diagnostic trace may record:

```text
iteration
residual norm
step norm
damping factor
Jacobian condition indicator
```

The trace is derived evidence.

It is not part of the authoritative circuit model.

---

## 46. Failure Classification

Minimum failure categories:

```text
INVALID_MODEL
INVALID_PARAMETER
INVALID_INITIAL_STATE
DIMENSIONAL_ERROR
SINGULAR_JACOBIAN
NUMERICAL_OVERFLOW
NUMERICAL_UNDERFLOW
NO_CONVERGENCE
MULTIPLE_SOLUTIONS
OUT_OF_MODEL_RANGE
INCONSISTENT_SYSTEM
INSUFFICIENT_DATA
UNSUPPORTED_MODEL
```

---

## 47. No Silent Fallback

If nonlinear solving fails, the system must not silently:

```text
switch to linear mode
drop a component
ignore a constraint
clamp a value
replace a model
change topology
```

Any fallback must be an explicit user/system-selected analysis strategy and must produce a new analysis identity.

---

## 48. Constraint Evaluation

After convergence:

```text
AnalysisResult
      ↓
Constraint Engine
```

must evaluate:

```text
component limits
operating regions
power limits
current limits
voltage limits
model validity
residual constraints
```

A numerically converged solution can still violate engineering constraints.

---

## 49. Model Validity

A solution is not automatically valid merely because:

```text
F(x) ≈ 0
```

The result must also satisfy applicable:

```text
model range
parameter constraints
operating limits
topology conditions
```

---

## 50. Solution Status

Conceptual combined status:

```text
CONVERGED_VALID
CONVERGED_WITH_WARNINGS
CONVERGED_CONSTRAINT_VIOLATION
CONVERGED_OUTSIDE_MODEL_RANGE
NO_CONVERGENCE
INVALID
```

The exact status model should remain compatible with AP-EK-008 and AP-EK-010.

---

## 51. Provenance

The nonlinear result must preserve:

```text
component model IDs
model versions
equation IDs
equation versions
knowledge package identity
runtime identity
solver identity
initial state
solver policy
numeric policy
```

---

## 52. Derivation

The derivation should record:

```text
topology construction
model instantiation
equation assembly
initialization
iteration
convergence
constraint evaluation
```

The iteration trace need not become a human-readable derivation step unless requested.

---

## 53. Determinism

Given identical:

```text
document snapshot
knowledge package
runtime
solver
numeric policy
initial state
```

the solver must produce the same result.

This includes:

```text
iteration order
equation ordering
unknown ordering
matrix assembly ordering
tie-breaking
termination policy
```

---

## 54. Stable Ordering

All deterministic collections must use stable ordering.

Recommended identity ordering:

```text
objectId
nodeId
terminalId
equationId
unknownId
constraintId
```

Do not depend on hash-map iteration order.

---

## 55. Floating-Point Policy

The implementation must document:

```text
floating-point representation
precision
comparison tolerance
overflow policy
underflow policy
NaN handling
infinity handling
```

Numerical equality must never be tested using undocumented exact comparisons.

---

## 56. Reproducibility Across Machines

Bit-for-bit equality may not be guaranteed across every hardware/software environment unless the numerical policy establishes it.

Therefore distinguish:

```text
semantic deterministic equivalence
```

from:

```text
bitwise identical floating-point execution
```

The analysis result should record enough numerical identity to establish the intended reproducibility level.

---

## 57. Result Hashing

AP-EK-015 result hashing must incorporate nonlinear solver identity and policy.

Two results with the same final voltage/current values but different:

```text
solver
model
knowledge version
```

must not automatically receive the same semantic identity.

---

## 58. Cache Compatibility

A nonlinear analysis cache key must include:

```text
documentHash
knowledgeHash
runtimeVersion
solverVersion
analysisMode
numericPolicy
initialGuessPolicy
requestedOutputs
```

A cache hit is valid only when all required semantic inputs match.

---

## 59. Previous Result Reuse

A previous nonlinear result may be reused as:

```text
initial state
```

or:

```text
cached result
```

These are distinct operations.

The system must record which occurred.

---

## 60. Explanation Integration

AP-EK-014 should be able to explain:

```text
why nonlinear solving was required
which component introduced nonlinearity
what initial condition was used
how convergence was achieved
whether constraints were satisfied
```

Example:

```text
The diode's nonlinear current-voltage relationship prevents direct linear solution.
The solver iteratively adjusted node voltage until the network residual fell below tolerance.
```

This statement is generated from structured solver evidence.

---

## 61. Diagnostic Teaching

A failed nonlinear solve can become a teaching event.

Example:

```text
Problem:
The solver did not converge.

Teaching:
What does convergence mean?

Evidence:
Final residual > declared tolerance.
```

The explanation layer should not invent a physical fault merely because the numerical solver failed.

---

## 62. Diagram Studio Integration

DS receives:

```text
AnalysisResult
solver diagnostics
component result data
constraint results
derivation references
```

DS may visualize:

```text
node voltages
branch currents
device operating states
constraint violations
convergence diagnostics
```

DS does not perform nonlinear iteration.

---

## 63. Visual Operating Regions

For piecewise components, DS may show:

```text
OFF
ON
FORWARD
REVERSE
OUT_OF_RANGE
```

These are derived from model state/results.

They are not UI-invented labels.

---

## 64. First Nonlinear Vertical Slice

Use:

```text
12 V source
1 kΩ resistor
diode
ground
```

with an explicitly selected deterministic diode model.

The expected solution must be generated from the model's declared parameters.

Do not hard-code a universal diode voltage such as 0.7 V unless that is the selected model parameter.

---

## 65. First Acceptance Criteria

The nonlinear slice must demonstrate:

```text
model resolution
topology extraction
nonlinear system assembly
initialization
Jacobian generation
iteration
convergence
constraint evaluation
provenance
AnalysisResult
```

---

## 66. Failure Acceptance

At least these cases must be tested:

```text
missing diode parameter
invalid unit
invalid model range
singular Jacobian
iteration limit
numerical overflow
inconsistent system
```

Each must return structured failure information.

---

## 67. Multiple-Solution Acceptance

Construct a test fixture with known multiple solutions if supported by the selected model.

The solver must:

```text
not claim uniqueness without evidence
record initial guess
identify different converged solutions where discovered
```

---

## 68. Convergence Regression Suite

Test:

```text
easy convergence
slow convergence
damped convergence
near-singular system
non-convergence
boundary solution
piecewise transition
```

---

## 69. Performance

The initial implementation should prioritize:

```text
correctness
determinism
diagnostics
provenance
```

over maximum performance.

Optimization follows measured profiling.

---

## 70. Threading

Independent analyses may execute concurrently.

Within one deterministic analysis:

```text
equation assembly
unknown ordering
matrix assembly
iteration
```

must have deterministic semantics.

Parallel implementation must not change the semantic result.

---

## 71. Cancellation

The analysis API may support cancellation.

If cancelled:

```text
status = CANCELLED
```

A partial iterate must not be reported as a valid solution.

Diagnostic iteration history may be retained.

---

## 72. Resource Limits

The solver must support explicit limits:

```text
maximumIterations
maximumEvaluationCount
maximumExecutionTime
maximumMemory
```

A resource limit is a structured analysis termination condition.

---

## 73. Numerical Pathologies

The solver must detect or expose:

```text
NaN
Infinity
overflow
underflow
ill-conditioning
division by near-zero
invalid logarithm
invalid exponential range
```

The model and numeric policy determine appropriate handling.

---

## 74. No Hidden Regularization

The solver must not silently add:

```text
resistance
conductance
leakage
damping
parasitic
```

to make a circuit solvable.

If regularization is supported in the future, it must be:

```text
explicit
versioned
configurable
provenanced
```

and produce a result that clearly identifies the approximation.

---

## 75. Approximation Boundary

Approximate nonlinear models are valid when explicitly defined as models.

Example:

```text
piecewise diode
```

may approximate a physical diode.

That approximation is part of:

```text
ComponentModel
```

not an undocumented solver shortcut.

---

## 76. Model Selection

The system may offer:

```text
Ideal Diode
Piecewise Linear Diode
Shockley Diode
```

as model choices.

The selected model identity/version must enter analysis provenance.

---

## 77. Knowledge Runtime Contract

The nonlinear solver requests:

```text
getComponentModel(modelId)
getEquation(equationId)
getConstraint(constraintId)
getUnit(unitId)
```

It does not directly inspect the reference library.

---

## 78. Persistence Contract

AP-EK-015 must persist:

```text
nonlinear analysis mode
solver identity
initial guess
solver policy
convergence diagnostics
model versions
knowledge package identity
result
constraints
provenance
```

---

## 79. Validation Suite Integration

AP-EK-012 must add nonlinear categories:

```text
NONLINEAR_MODEL
NONLINEAR_SOLVER
CONVERGENCE
NON_CONVERGENCE
PIECEWISE_MODEL
JACOBIAN
NUMERICAL_SAFETY
MULTIPLE_SOLUTION
REPRODUCIBILITY
```

---

## 80. Implementation Sequence

```text
1. define NonlinearAnalysisSystem
2. define Unknown and Residual contracts
3. extend component model contract
4. implement deterministic system assembly
5. implement Jacobian interface
6. integrate existing linear solver
7. implement Newton solver
8. implement residual/step convergence policy
9. implement deterministic initialization
10. implement nonlinear diagnostics
11. implement piecewise model support
12. implement first diode model
13. integrate Constraint Engine
14. integrate Provenance / Derivation
15. integrate AnalysisResult persistence
16. add validation fixtures
17. integrate DS result visualization
```

---

## 81. Recommended Repository Boundary

Conceptual:

```text
platform/
  oep_engine/
    analysis/
      nonlinear/
        nonlinear_system
        nonlinear_solver
        newton_solver
        jacobian
        convergence
        initialization
        diagnostics
```

Component behavior remains under the established model/knowledge boundary.

Exact paths must follow the existing repository taxonomy.

---

## 82. Definition of Done

AP-EK-016 is complete when:

1. nonlinear systems have a normalized representation;
2. unknowns are deterministic;
3. residual equations are structured;
4. dimensional validation occurs before solving;
5. Jacobian generation is defined;
6. deterministic initialization exists;
7. Newton-style solving works;
8. convergence criteria are explicit;
9. iteration limits are enforced;
10. singular Jacobians are detected;
11. numerical failures are structured;
12. piecewise model semantics are supported;
13. at least one nonlinear electrical component model is implemented;
14. linear and nonlinear components coexist in one network;
15. constraints are evaluated after convergence;
16. model validity is checked;
17. provenance records solver/model/version information;
18. derivation records system construction;
19. results persist through AP-EK-015;
20. AP-EK-012 nonlinear validation passes;
21. DS receives structured results without implementing the solver;
22. no silent fallback or hidden regularization exists.

---

## 83. Architectural Non-Negotiables

1. Nonlinear solving belongs to Engineering Analysis.
2. Knowledge Runtime remains the source of component/law/equation semantics.
3. The solver never invents component behavior.
4. Every nonlinear equation is dimensionally validated before execution.
5. Unknown ordering must be deterministic.
6. Equation ordering must be deterministic.
7. Matrix assembly must be deterministic.
8. Initial conditions must be explicit.
9. Convergence criteria must be explicit.
10. Failure to converge is not a valid engineering result.
11. A converged numerical result may still violate engineering constraints.
12. Model validity is separate from numerical convergence.
13. Multiple solutions must not be silently collapsed into a claim of uniqueness.
14. Hidden regularization is prohibited.
15. Hidden clamps are prohibited.
16. Hidden topology changes are prohibited.
17. Solver behavior must be reproducible under the declared numerical policy.
18. Solver identity and policy are part of provenance.
19. DS visualizes nonlinear results but does not solve them.
20. Explanation may explain iteration and convergence but cannot alter the result.
21. Historical nonlinear results remain immutable.
22. A new model/version creates a new semantic analysis identity.
23. Performance optimization must not compromise deterministic semantics.
24. Unsupported nonlinear behavior must fail explicitly.
25. The nonlinear solver extends the linear foundation; it does not replace or fork it.
