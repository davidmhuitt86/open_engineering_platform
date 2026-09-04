# AP-EK-011
# Dynamic / Nonlinear Analysis Extension
## Extension Architecture for Nonlinear Devices, Time-Dependent Systems, and Advanced Engineering Analysis

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-010  
**Primary consumers:** OEP Engineering Analysis Runtime  
**Presentation consumer:** Diagram Studio

---

## 1. Purpose

Define the extension architecture required for OEP to move beyond the initial:

```text
DC steady-state
linear
lumped electrical circuit
```

analysis capability.

The architecture must support future:

```text
nonlinear electrical systems
dynamic/time-domain systems
frequency-domain analysis
stateful components
multi-domain engineering systems
```

without replacing the foundational boundaries established by AP-EK-003 through AP-EK-010.

---

## 2. Architectural Principle

Advanced analysis is an extension of the same deterministic pipeline:

```text
Engineering Graph
      |
      v
Topology / Model Extraction
      |
      v
Applicable Models + Laws
      |
      v
Equation System
      |
      v
Deterministic Solver
      |
      v
Constraints
      |
      v
Derivation + Provenance
      |
      v
AnalysisResult
```

The solver strategy may change.

The authority model must not.

---

## 3. Current vs Future Capability

Initial capability:

```text
DC_STEADY_STATE_LINEAR
```

Future capabilities:

```text
DC_STEADY_STATE_NONLINEAR
TRANSIENT
AC_FREQUENCY_DOMAIN
SMALL_SIGNAL
PARAMETRIC
MULTI_DOMAIN
```

Each mode requires an explicit capability declaration.

Unsupported modes must fail explicitly.

---

## 4. Nonlinear Analysis

A nonlinear component does not necessarily have a constant linear relationship between its variables.

Examples:

```text
diode
transistor
varistor
nonlinear magnetic device
temperature-dependent resistor
```

A nonlinear model may be represented as:

```text
f(x, p) = 0
```

where:

```text
x = unknown state variables
p = parameters / known inputs
```

---

## 5. Nonlinear Equation Contract

The existing Equation Engine remains responsible for structured equations.

Nonlinear solving becomes an orchestration/solver capability.

Conceptually:

```text
Component Models
      |
      v
Nonlinear Equations
      |
      v
Nonlinear System
      |
      v
Deterministic Nonlinear Solver
```

The Equation Engine must not become responsible for global circuit topology.

---

## 6. Nonlinear Solver Strategy

The initial nonlinear architecture should support iterative solution methods.

Candidate methods include:

```text
Newton-Raphson
damped Newton
continuation/homotopy
```

The exact algorithm is an implementation decision.

The runtime must record:

```text
solverAlgorithm
solverVersion
convergencePolicy
iterationLimit
tolerancePolicy
```

in the analysis result when nonlinear solving is used.

---

## 7. Deterministic Iteration

Nonlinear solving must remain reproducible.

Identical:

```text
system
initial conditions
solver algorithm
solver version
tolerances
iteration policy
numeric policy
```

must produce equivalent results.

Iteration order must be deterministic.

---

## 8. Initial Guess

Nonlinear systems require an initial guess.

The source of that guess must be explicit:

```text
DEFAULT_MODEL_GUESS
USER_SUPPLIED
PREVIOUS_ANALYSIS
CONTINUATION_STEP
MEASUREMENT
```

A solver must not silently change the initial guess source between analyses.

---

## 9. Convergence

A nonlinear solution must satisfy explicit convergence criteria.

Examples:

```text
residual norm
state delta
relative error
absolute error
```

The convergence policy must be versioned and included in the analysis dependency snapshot.

---

## 10. Non-Convergence

Failure to converge is not a valid engineering solution.

Result status:

```text
NON_CONVERGED
```

or an equivalent structured status must be returned.

The solver must expose useful diagnostics:

```text
iteration count
final residual
final state delta
failure reason
```

---

## 11. Multiple Solutions

A nonlinear system may have multiple valid solutions.

The runtime must not claim uniqueness unless it can establish it.

The result should identify:

```text
solution status
initial guess
solver path
```

when multiple-solution behavior is relevant.

Future solution-set exploration may be added without changing the core contract.

---

## 12. Discontinuities

Components such as switches, ideal diodes, relays, and protection devices may contain discontinuous behavior.

The model architecture must distinguish:

```text
continuous nonlinear behavior
piecewise behavior
discrete state behavior
```

The first nonlinear implementation should prefer explicit piecewise/state models rather than hiding discontinuities inside arbitrary numerical functions.

---

## 13. Piecewise Models

Example:

```text
Switch:
  OPEN
  CLOSED
```

or an idealized diode:

```text
OFF
ON
```

Each region may have its own equations and applicability conditions.

Conceptually:

```text
Component Model
   |
   +-- Operating Region A
   |      equations
   |
   +-- Operating Region B
          equations
```

Region selection must be deterministic and explainable.

---

## 14. Dynamic Analysis

Dynamic analysis introduces time-dependent state.

Conceptually:

```text
state(t)
```

with equations such as:

```text
I = C × dV/dt
V = L × dI/dt
```

The architecture must support:

```text
state variables
initial conditions
time
time step
integration method
events
```

---

## 15. State Variable Contract

Conceptual:

```text
StateVariable
  stateId
  componentObjectId
  quantity
  initialValue
  bounds
  provenance
```

A state variable is analysis/runtime state.

It is not automatically an Engineering Object.

---

## 16. Initial Conditions

Dynamic analysis requires explicit initial conditions where the model requires them.

Examples:

```text
capacitor voltage at t=0
inductor current at t=0
switch state at t=0
```

If required initial information is missing:

```text
INSUFFICIENT_INITIAL_CONDITIONS
```

must be returned.

The solver must not invent an initial state.

---

## 17. Time Domain

A transient request should define:

```text
startTime
endTime
timeStep / adaptive policy
```

The time representation must carry explicit units.

Example:

```text
0 s
10 ms
```

---

## 18. Integration Methods

The architecture should permit multiple deterministic integration methods.

Potential methods:

```text
Backward Euler
Trapezoidal
Gear/BDF family
```

The first implementation may select one appropriate method.

The selected method must be recorded in the analysis result.

---

## 19. Adaptive Time Stepping

Future dynamic solvers may adjust time step based on error estimates.

Adaptive stepping must remain deterministic.

The policy must define:

```text
minimum step
maximum step
error tolerance
step acceptance/rejection
```

and must record the resulting solver configuration.

---

## 20. Event Handling

Dynamic systems may contain events:

```text
switch opens
switch closes
relay changes state
threshold crossed
simulation boundary reached
```

Events must have explicit conditions.

The solver must not miss a model-defined discrete transition merely because a numerical time step crossed it.

Event semantics require dedicated testing.

---

## 21. Frequency-Domain Analysis

Future AC analysis may operate in the frequency domain.

Conceptually:

```text
phasor voltage
phasor current
complex impedance
```

The Quantity/Unit architecture must eventually support complex-valued engineering quantities.

Complex support is therefore an extension point of AP-EK-003, not a reason to corrupt the initial real-valued quantity contract.

---

## 22. Complex Quantities

A future complex quantity may be:

```text
real component
imaginary component
unit
```

or:

```text
magnitude
phase
unit
```

The canonical internal representation must be chosen before AC implementation.

The representation must preserve mathematical equivalence.

---

## 23. Small-Signal Analysis

Nonlinear devices may later be linearized around an operating point.

Conceptually:

```text
Nonlinear model
      |
      v
Operating point
      |
      v
Local linearization
      |
      v
Small-signal model
      |
      v
Linear solver
```

The operating point and linearization method must be part of provenance.

---

## 24. Operating Point

A nonlinear analysis may first determine:

```text
DC operating point
```

then use that point for:

```text
small-signal
AC
incremental
```

analysis.

The dependency must be explicit.

---

## 25. Solver Abstraction

The architecture should introduce a solver abstraction:

```text
AnalysisSolver
  solve(system, context)
```

with specialized implementations:

```text
LinearSolver
NonlinearSolver
TransientSolver
FrequencyDomainSolver
```

The abstraction should not erase solver-specific diagnostics.

---

## 26. Equation System Abstraction

The solver consumes a normalized system.

Conceptually:

```text
AnalysisSystem
  unknowns[]
  equations[]
  constraints[]
  parameters[]
  initialConditions[]
  events[]
```

The exact fields depend on analysis mode.

This provides a stable boundary between model/equation resolution and numerical solving.

---

## 27. Jacobian

Nonlinear methods such as Newton-Raphson require derivatives/Jacobians.

The architecture should support:

```text
JacobianProvider
```

Possible implementations:

```text
analytic derivatives
automatic differentiation
deterministic numerical differentiation
```

The first nonlinear implementation should prefer the most deterministic and auditable approach compatible with the authoritative model representation.

---

## 28. Derivative Provenance

If derivatives affect a nonlinear solution, the result should identify:

```text
derivative method
derivative version
```

A generated derivative must not become an unexplained black box.

---

## 29. Solver Tolerances

Advanced solvers require explicit tolerance categories.

Examples:

```text
absolute residual tolerance
relative residual tolerance
absolute state tolerance
relative state tolerance
time integration tolerance
event tolerance
```

The complete tolerance policy must be versioned.

---

## 30. Numerical Stability

The runtime should distinguish:

```text
mathematically invalid
numerically unstable
non-convergent
insufficient precision
```

These are different engineering diagnostics.

A solver must not convert numerical instability into a normal successful result.

---

## 31. Conditioning

Linear and nonlinear systems may be poorly conditioned.

Future solver diagnostics should be able to report:

```text
conditioning estimate
pivot issues
scaling issues
near-singularity
```

The first implementation may expose only a subset.

---

## 32. Continuation

Continuation/homotopy may help solve difficult nonlinear systems.

Conceptually:

```text
easy system
   |
   v
intermediate system
   |
   v
target system
```

If used, the continuation path must be deterministic and recorded.

---

## 33. Model Validity

A numerically converged solution is not automatically an engineeringly valid solution.

After solving:

```text
model applicability
parameter ranges
operating regions
constraints
```

must still be evaluated.

Example:

```text
solver converged
but diode model operating region invalid
```

Result:

```text
engineering validity failure
```

rather than unconditional success.

---

## 34. Dynamic Constraint Evaluation

Constraints may apply:

```text
at every time step
at event boundaries
at final state
over an entire trajectory
```

The constraint contract must eventually support temporal scopes.

Examples:

```text
maximum voltage at any time
maximum current
time above threshold
temperature excursion
```

---

## 35. Trajectory Results

Dynamic analysis produces a series of states rather than one scalar state.

Conceptual:

```text
Trajectory
  time[]
  state[]
  outputs[]
  events[]
```

The result should support compact storage and lazy retrieval for large trajectories.

---

## 36. Result Identity

Advanced analysis continues to use AP-EK-010:

```text
analysisId
requestId
document identity/version
runtime identity
knowledge identity
```

Additional solver-specific identity is additive.

---

## 37. Provenance

Advanced results must retain:

```text
model versions
law versions
equation versions
solver algorithm/version
numeric policy
tolerances
initial conditions
analysis context
```

This is mandatory for reproducibility.

---

## 38. Deterministic Randomness

The initial architecture should avoid random algorithms.

If a future solver ever requires randomness:

```text
seed
algorithm
version
```

must become explicit dependencies.

Randomness must never be implicit.

---

## 39. Performance

Advanced analysis may be computationally expensive.

The Engine should support:

```text
asynchronous execution
progress reporting
cancellation
result caching
incremental solving
parallel-safe workloads
```

Parallelization must not alter deterministic result semantics.

---

## 40. Parallelism

Independent calculations may execute concurrently.

However:

```text
unordered floating-point reductions
race-dependent iteration order
non-deterministic event ordering
```

must not alter the authoritative result.

Deterministic reduction/order rules are required.

---

## 41. Unsupported Advanced Components

If a circuit contains:

```text
diode
```

but the active runtime does not include a valid diode model:

```text
UNSUPPORTED_COMPONENT_MODEL
```

must be returned.

The solver must not silently replace it with:

```text
short
open
resistor
```

unless an authoritative approximation model explicitly specifies that behavior.

---

## 42. First Nonlinear Vertical Slice

A future first nonlinear slice should be:

```text
DC source
series resistor
diode
reference
```

The diode model provides authoritative nonlinear behavior.

The nonlinear solver determines the operating point.

The result includes:

```text
diode current
diode voltage
resistor current
resistor voltage
operating region
convergence diagnostics
provenance
```

No diode equation should be invented during implementation.

---

## 43. First Dynamic Vertical Slice

A future first dynamic slice should be:

```text
DC source
resistor
capacitor
reference
```

with:

```text
I = C × dV/dt
```

The solver produces:

```text
V_C(t)
I_C(t)
I_R(t)
```

subject to the authoritative model and integration method.

---

## 44. First AC Vertical Slice

A future first AC slice should be:

```text
AC source
resistor
capacitor
reference
```

with explicit:

```text
frequency
source magnitude
phase
component values
```

Complex quantity support must be implemented before this capability is activated.

---

## 45. Analysis Capability Registry

The runtime should expose:

```text
AnalysisCapabilityRegistry
  supports(mode)
  supportedComponents(mode)
  supportedLaws(mode)
  supportedSolvers(mode)
```

This allows DS or other clients to determine available analysis modes without embedding capability assumptions.

---

## 46. DS Boundary

Diagram Studio receives the same class of immutable:

```text
AnalysisResult
```

for advanced analyses.

DS may render:

```text
operating points
waveforms
frequency responses
solver diagnostics
constraint violations
```

but must not implement numerical solving.

---

## 47. Backward Compatibility

Adding nonlinear/dynamic capabilities must not alter existing:

```text
DC_STEADY_STATE_LINEAR
```

results under identical runtime versions and inputs.

If a numerical algorithm changes, the runtime/solver version must identify the change.

---

## 48. Migration Strategy

No foundational rewrite is required.

The extension sequence should be:

```text
Existing linear topology
        |
        v
General AnalysisSystem
        |
        v
LinearSolver
        |
        +---- NonlinearSolver
        |
        +---- TransientSolver
        |
        +---- FrequencyDomainSolver
```

This preserves the architecture already established.

---

## 49. Testing

### Nonlinear

- convergence;
- non-convergence;
- initial guess;
- multiple-solution behavior;
- piecewise regions;
- residual validation.

### Dynamic

- initial conditions;
- time units;
- integration;
- event handling;
- trajectory output;
- temporal constraints.

### Frequency domain

- complex quantities;
- magnitude/phase;
- impedance;
- deterministic frequency sweep.

### Solver reproducibility

Identical solver configuration and inputs must produce equivalent results.

### Unsupported capability

Unsupported models/modes must fail explicitly.

---

## 50. Definition of Done

AP-EK-011 is complete when:

1. advanced-analysis extension boundary is defined;
2. solver abstraction exists conceptually;
3. linear/nonlinear/dynamic modes are distinct;
4. nonlinear system representation exists;
5. dynamic state representation exists;
6. solver configuration is versioned;
7. convergence semantics are defined;
8. initial-condition semantics are defined;
9. event semantics are defined;
10. complex-quantity extension point is defined;
11. solver-specific provenance is defined;
12. advanced failures are explicit;
13. existing linear analysis remains backward compatible;
14. DS can consume advanced results without implementing advanced mathematics.

This architecture document does not require implementation of nonlinear, dynamic, or AC solving as part of the initial OEP electrical vertical slice.

---

## 51. Follow-On

```text
AP-EK-012  Electrical Analysis Validation Suite
AP-EK-013  Knowledge Runtime Implementation
AP-EK-014  Engineering Explanation / Teaching Layer
AP-EK-015  Analysis Result Persistence
AP-EK-016  Nonlinear Electrical Solver Implementation
AP-EK-017  Dynamic Electrical Solver Implementation
AP-EK-018  Frequency-Domain / Complex Quantity Implementation
```

---

## Architectural Non-Negotiables

1. Advanced analysis extends the existing architecture rather than replacing it.
2. Solver strategy is separate from knowledge authority.
3. Nonlinear convergence is not equivalent to engineering validity.
4. Non-converged systems do not produce valid solutions.
5. Initial conditions are explicit.
6. Solver tolerances are explicit and versioned.
7. Solver algorithms are identifiable.
8. Dynamic state is analysis state, not automatically Engineering Object state.
9. Complex quantities are an explicit extension of the quantity system.
10. Piecewise/discrete behavior is modeled explicitly.
11. Unsupported models are rejected rather than approximated silently.
12. Model applicability remains authoritative after numerical convergence.
13. Provenance includes solver configuration where it affects results.
14. Deterministic ordering is mandatory even when computation is parallelized.
15. AI cannot provide or override nonlinear/dynamic numerical solutions.
16. Diagram Studio remains a consumer/presenter.
17. Existing linear DC behavior must remain stable.
18. Advanced capability activation requires authoritative models and equations.
19. The architecture must permit future multi-domain analysis without hard-coding electrical assumptions into the solver core.
20. Advanced numerical methods are subordinate to the authoritative engineering model.
