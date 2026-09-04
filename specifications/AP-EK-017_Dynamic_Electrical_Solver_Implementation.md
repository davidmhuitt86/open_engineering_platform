# AP-EK-017
# Dynamic Electrical Solver Implementation
## Deterministic Time-Domain Analysis, State Variables, Integration, Events, and Transient Evidence

**Status:** Architecture Phase — Implementation Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-001 through AP-EK-016  
**Primary objective:** Define the first implementable dynamic electrical analysis architecture for deterministic time-domain simulation while preserving the OEP separation between authoritative knowledge, engineering analysis, persistence, explanation, and Diagram Studio presentation.

---

## 1. Purpose

AP-EK-017 extends OEP electrical analysis from:

```text
steady-state
```

to:

```text
time-domain transient behavior
```

A dynamic circuit cannot generally be represented by one static solution.

Its behavior depends on:

```text
time
state
initial conditions
component dynamics
inputs
events
```

The first implementation therefore establishes a deterministic transient analysis foundation.

---

## 2. Scope

This specification defines:

```text
dynamic component models
state variables
initial conditions
time representation
differential equations
algebraic equations
DAE-ready architecture
numerical integration
timestep policy
adaptive stepping
events
switching
discontinuities
convergence
error control
transient diagnostics
provenance
persistence
DS integration
```

It does not fully implement:

```text
AC frequency-domain analysis
electromagnetic field simulation
distributed transmission lines
thermal multiphysics
fluid dynamics
```

Those remain future domains.

---

## 3. Architectural Position

The dynamic pipeline is:

```text
DiagramDocument
      ↓
Engineering Graph
      ↓
Topology Extraction
      ↓
Component Model Resolution
      ↓
Dynamic System Assembly
      ↓
Initial Condition Resolution
      ↓
Time Integrator
      ↓
Event Detection / State Updates
      ↓
Constraint Evaluation
      ↓
Derivation / Provenance
      ↓
AnalysisResult
      ↓
Explanation / Diagram Studio
```

---

## 4. Steady-State vs Dynamic Analysis

Use separate analysis modes:

```text
DC_STEADY_STATE_LINEAR
DC_STEADY_STATE_NONLINEAR
TRANSIENT
```

A transient analysis may use nonlinear component models.

Therefore:

```text
TRANSIENT
```

is an analysis mode, not a claim that the system is linear.

---

## 5. Dynamic System

Conceptually:

```text
DynamicAnalysisSystem
  states[]
  algebraicUnknowns[]
  differentialEquations[]
  algebraicEquations[]
  parameters[]
  inputs[]
  events[]
  constraints[]
  initialConditions[]
  solverPolicy
```

The architecture should be capable of representing differential-algebraic systems even if the first solver handles only a restricted subset.

---

## 6. State Variable

A state represents information required to determine future system behavior.

Conceptual:

```text
StateVariable
  stateId
  name
  quantity
  unit
  initialValue
  derivativeEquation
  bounds
  sourceReference
```

For a capacitor:

```text
state = capacitor voltage
```

For an inductor:

```text
state = inductor current
```

---

## 7. State Ownership

State belongs to the active analysis execution.

It is not automatically authoritative document state.

For example:

```text
capacitor voltage at t = 2 ms
```

is simulation state, not a permanent modification to the component definition.

---

## 8. Initial Conditions

Every required dynamic state must have an initial condition.

Possible sources:

```text
explicit analysis input
component model default
previous compatible analysis
document-specified initial state
deterministic initialization rule
```

The selected source must be recorded.

---

## 9. Initial Condition Validation

Initial conditions must satisfy applicable model/topology constraints where required.

Invalid initial conditions produce:

```text
INVALID_INITIAL_CONDITION
```

rather than silently being corrected.

---

## 10. Dynamic Equations

Dynamic component models may expose:

```text
dx/dt = f(x, z, u, t)
```

where:

```text
x = state variables
z = algebraic unknowns
u = external inputs
t = time
```

Algebraic equations may be represented as:

```text
g(x, z, u, t) = 0
```

---

## 11. DAE-Ready Architecture

The long-term normalized representation should support:

```text
F(t, x, xdot, z) = 0
```

This permits:

```text
ODE systems
index-reduced DAE systems
circuit MNA formulations
```

The first transient implementation may reduce supported systems to explicit ODE form where possible.

---

## 12. Capacitor Model

Initial dynamic model:

```text
i = C × dv/dt
```

State:

```text
v
```

Derivative:

```text
dv/dt = i/C
```

Parameters:

```text
C
```

must be supplied by the Component Model.

---

## 13. Inductor Model

Initial dynamic model:

```text
v = L × di/dt
```

State:

```text
i
```

Derivative:

```text
di/dt = v/L
```

Parameters:

```text
L
```

must be supplied by the Component Model.

---

## 14. Resistor in Dynamic Systems

A resistor remains algebraic:

```text
v = i × R
```

It introduces no state.

Dynamic networks may therefore contain:

```text
R
C
L
sources
switches
nonlinear devices
```

without requiring separate solver architecture for each combination.

---

## 15. First Transient Vertical Slice

The first canonical dynamic circuit should be an RC charging circuit:

```text
12 V source
switch
1 kΩ resistor
1 µF capacitor
ground
```

with an explicitly defined initial condition:

```text
Vc(0) = 0 V
```

and a source/switch event that establishes the charging condition.

Expected time constant:

```text
τ = R × C
```

The transient solver should calculate the trajectory rather than hard-code the analytical solution.

---

## 16. Source Inputs

Dynamic sources may be time-dependent.

Conceptual:

```text
u(t)
```

Examples:

```text
step
pulse
ramp
piecewise constant
piecewise linear
sampled input
```

The source definition must specify its temporal behavior.

---

## 17. Input Identity

Each dynamic input must have:

```text
inputId
sourceObjectId
parameterization
time domain
units
provenance
```

A time-dependent source is an engineering input, not UI animation.

---

## 18. Time Representation

The solver must define:

```text
startTime
endTime
initialStep
minimumStep
maximumStep
outputStep
```

All quantities must carry explicit time units.

---

## 19. Time Monotonicity

Solver time must advance monotonically:

```text
t(n+1) > t(n)
```

except for internal event localization operations that do not alter committed solution ordering.

Negative or zero committed timestep is invalid.

---

## 20. Fixed-Step Integration

Initial implementation should support a deterministic fixed-step method.

Candidate:

```text
Backward Euler
```

or:

```text
Trapezoidal / implicit midpoint
```

The selected method must be explicit and versioned.

---

## 21. Why Implicit Integration

Circuit dynamics can become stiff.

An implicit method provides a stronger foundation for future:

```text
RC
RL
RLC
semiconductor
power electronics
```

systems than relying exclusively on explicit integration.

---

## 22. Backward Euler

For:

```text
dx/dt = f(x,t)
```

Backward Euler uses:

```text
x(n+1) = x(n) + Δt × f(x(n+1), t(n+1))
```

This may require solving a nonlinear system at each timestep.

The existing AP-EK-016 nonlinear solver can therefore serve as the timestep nonlinear solve infrastructure.

---

## 23. Trapezoidal Integration

Future support may use:

```text
x(n+1) =
x(n) + Δt/2 × [f(x(n),t(n)) + f(x(n+1),t(n+1))]
```

The method identity must be part of analysis provenance.

---

## 24. Integrator Abstraction

Conceptual:

```text
TimeIntegrator
  initialize(system, initialState)
  step(state, time, dt)
  estimateError(...)
  accept(...)
  reject(...)
```

Potential implementations:

```text
BackwardEulerIntegrator
TrapezoidalIntegrator
BDFIntegrator
```

---

## 25. Timestep Controller

Conceptual:

```text
TimeStepController
  proposeStep(...)
  acceptStep(...)
  rejectStep(...)
```

The policy determines:

```text
step growth
step reduction
minimum step
maximum step
error target
```

All rules must be deterministic.

---

## 26. Adaptive Stepping

Adaptive stepping may be introduced after fixed-step correctness is established.

The controller should reduce timestep when:

```text
error too large
rapid state change
event proximity
solver difficulty
```

and increase it when:

```text
solution smooth
error comfortably below tolerance
```

---

## 27. Error Estimation

The solver should distinguish:

```text
local truncation error
nonlinear solver error
algebraic residual
constraint violation
```

These are not interchangeable.

---

## 28. Tolerances

At minimum:

```text
absolute tolerance
relative tolerance
residual tolerance
nonlinear convergence tolerance
```

must be explicit.

---

## 29. Quantity Scaling

State variables may differ dramatically in magnitude.

Example:

```text
voltage ≈ 10 V
current ≈ 1 mA
```

Error control should support quantity-aware scaling.

The selected scaling policy must be recorded.

---

## 30. Event Model

Conceptual:

```text
SimulationEvent
  eventId
  eventType
  trigger
  time/state condition
  priority
  actions
  provenance
```

Initial events:

```text
scheduled time event
threshold crossing
switch transition
source transition
```

---

## 31. Scheduled Events

A scheduled event occurs at a declared time:

```text
t = 1 ms
```

The solver must ensure the event is applied at the correct logical time.

If a timestep crosses an event, the solver must localize the event rather than silently applying it late.

---

## 32. Threshold Events

A threshold event may be:

```text
V(node) = threshold
```

or:

```text
I(branch) = threshold
```

The solver should detect crossings using a deterministic policy.

---

## 33. Event Localization

When an event lies inside:

```text
[t0, t1]
```

the solver may subdivide the step.

The event time must satisfy the configured localization tolerance.

---

## 34. Event Priority

Multiple events at the same logical time require deterministic ordering.

Priority may be based on:

```text
explicit event priority
stable event identity
```

Never rely on container iteration order.

---

## 35. Switching

Switch state transitions may change topology.

The architecture must explicitly distinguish:

```text
continuous state evolution
discrete topology transition
```

A switch event may cause:

```text
open → closed
closed → open
```

with an explicit state transition.

---

## 36. Topology Reassembly

After a topology-changing event:

```text
event
 ↓
new topology
 ↓
reassemble system
 ↓
continue integration
```

The new topology must be validated.

---

## 37. State Continuity

When topology changes, the model must define which states remain continuous.

For example:

```text
capacitor voltage
inductor current
```

may have continuity requirements.

The solver must not arbitrarily reset dynamic state.

---

## 38. Algebraic Reinitialization

After topology changes, algebraic variables may need to be recomputed while preserving valid state variables.

This is a distinct operation from resetting the entire simulation.

---

## 39. Discontinuities

The system must explicitly represent discontinuities in:

```text
input
state
topology
component equation
```

Integration must not silently smooth them.

---

## 40. Initial-Time Events

Events at:

```text
t = startTime
```

must have deterministic ordering relative to initial-condition application.

The policy must be explicit.

---

## 41. Output Sampling

The solver integration timestep and output sampling interval are separate concepts.

Example:

```text
integration:
adaptive

output:
every 10 µs
```

The stored trajectory must distinguish actual solver steps from requested display samples where necessary.

---

## 42. Trajectory

Conceptual:

```text
AnalysisTrajectory
  time[]
  state[]
  algebraicValues[]
  events[]
  constraints[]
```

A trajectory is derived analysis evidence.

It is not document state.

---

## 43. Result Sampling

Persisted analysis may store:

```text
full trajectory
sampled trajectory
key events
final state
```

depending on retention policy.

If downsampling is performed, the method must be recorded.

---

## 44. Full Fidelity

For reproducibility, the original analysis configuration must be preserved even if the UI stores only sampled display data.

The display representation must not become the sole source of transient evidence.

---

## 45. Constraint Evaluation During Simulation

Constraints may be evaluated:

```text
every accepted step
at output points
at events
at final state
```

depending on constraint type.

Safety-critical/operating constraints should not rely solely on sparse output samples.

---

## 46. Constraint Crossing

A constraint may be violated between output samples.

The solver should support event/monitor mechanisms for constraints that require continuous or threshold monitoring.

---

## 47. Example Constraint

Capacitor voltage:

```text
Vmax = 16 V
```

If the trajectory exceeds 16 V:

```text
CONSTRAINT_VIOLATION
```

must be recorded at the relevant simulation time.

---

## 48. Simulation Termination Conditions

A transient analysis may terminate because of:

```text
end time reached
event-triggered stop
constraint-triggered stop
solver failure
minimum timestep reached
resource limit
cancellation
```

Termination reason must be explicit.

---

## 49. Solver Failure

Examples:

```text
NONLINEAR_NO_CONVERGENCE
STEP_SIZE_UNDERFLOW
INVALID_STATE
INVALID_MODEL
SINGULAR_SYSTEM
NUMERICAL_OVERFLOW
EVENT_LOCALIZATION_FAILURE
```

A failed transient solve must not be presented as a complete trajectory.

---

## 50. Step Rejection

When adaptive integration is used, a failed trial step may be rejected without being treated as an engineering failure.

The final analysis result must distinguish:

```text
internal rejected step
```

from:

```text
analysis termination failure
```

---

## 51. Determinism

Given identical:

```text
document snapshot
knowledge package
runtime
solver/integrator
initial state
inputs
numeric policy
event policy
```

the transient analysis must produce semantically identical results.

---

## 52. Deterministic Event Ordering

Event processing must be deterministic.

At equal time:

```text
priority
then stable event identity
```

should define ordering.

---

## 53. Deterministic Adaptive Stepping

Adaptive policies must define:

```text
error estimator
step acceptance threshold
growth factor
reduction factor
min/max step
tie-breaking
```

No implementation-defined heuristics should alter semantic behavior.

---

## 54. Numerical Stability

The solver should monitor:

```text
residual
state magnitude
step size
conditioning
energy/power balance where applicable
```

Warnings should be explicit.

---

## 55. Energy/Power Checks

Electrical transient analysis may use:

```text
instantaneous power
integrated energy
```

as validation quantities.

For a capacitor:

```text
E = 1/2 C V²
```

For an inductor:

```text
E = 1/2 L I²
```

These are knowledge/equation definitions and must not be hard-coded into DS.

---

## 56. Energy Consistency

Where applicable, the analysis may evaluate:

```text
source energy
stored energy
dissipated energy
```

and compare them using explicit residual/constraint definitions.

This is an analysis validation mechanism, not a universal guarantee for every model.

---

## 57. Dynamic Component Model Contract

A dynamic model should expose:

```text
states
derivative equations
algebraic equations
parameters
initial conditions
events
state bounds
applicability
constraints
provenance
```

---

## 58. Nonlinear Dynamic Models

A dynamic component may also be nonlinear.

Example:

```text
diode + capacitance
```

The architecture should permit:

```text
dynamic equations
+
nonlinear residual equations
```

to coexist.

---

## 59. Solver Reuse

AP-EK-016's nonlinear solver should be reusable for:

```text
implicit timestep solves
```

rather than creating a second unrelated nonlinear solver.

---

## 60. Linear Transient Systems

For linear dynamic networks, the system may eventually exploit specialized linear methods.

Such optimization must preserve the same:

```text
AnalysisResult semantics
provenance
determinism
```

as the general solver.

---

## 61. State Initialization From DC

A common workflow is:

```text
DC steady-state
      ↓
initial condition
      ↓
transient analysis
```

This may be supported as an explicit initialization strategy.

The originating DC analysis identity must be recorded.

---

## 62. No Implicit DC Initialization

The solver must not silently run a hidden DC analysis to determine initial state unless explicitly defined by the analysis request/policy.

If automatic DC initialization is enabled:

```text
initializationMode = DC_STEADY_STATE
```

must be visible in provenance.

---

## 63. Previous Transient State

A previous transient endpoint may be used as an initial condition for another run.

This creates lineage:

```text
newAnalysis.reinitializedFrom = previousAnalysis
```

and must preserve the source identity.

---

## 64. Restart

A transient analysis may support restart from:

```text
saved state at t = T
```

The restart snapshot must include:

```text
state variables
algebraic values where required
input state
event state
solver state where required for exact continuation
```

---

## 65. Event State Persistence

If a source/switch has discrete state, persistence must include that state when required for continuation.

Otherwise the restart could produce a different trajectory.

---

## 66. Time-Series Storage

The persistence layer should support efficient storage of:

```text
time
state trajectories
selected node values
branch currents
component states
events
constraint crossings
```

Large transient analyses may be substantially larger than steady-state results.

---

## 67. Data Reduction

Optional reduction methods:

```text
uniform sampling
event-preserving sampling
error-bounded compression
selected-signal storage
```

Any lossy reduction must preserve the original analysis identity and clearly identify the reduced representation.

---

## 68. Analysis Result

Transient AnalysisResult should include:

```text
status
analysis identity
time range
initial conditions
solver identity
integrator identity
trajectory reference
events
constraints
diagnostics
provenance
```

---

## 69. Explanation Integration

AP-EK-014 should be able to answer:

```text
Why did voltage rise?
When did the switch change state?
Why did the timestep shrink?
When was a constraint violated?
What is the circuit time constant?
What state variable is storing energy?
```

Every answer must reference structured analysis evidence.

---

## 70. Teaching Integration

A transient result can support teaching objectives:

```text
understand capacitor state
understand time constant
predict charging behavior
interpret exponential response
understand initial conditions
understand switching events
```

Teaching content remains downstream of the analysis.

---

## 71. Diagram Studio Integration

DS may visualize:

```text
waveforms
cursor measurements
event markers
state values
constraint violations
component operating states
```

DS must not implement integration or event detection.

---

## 72. Interactive Cursor

A waveform cursor may request:

```text
value at time t
```

The analysis service returns the value according to the stored trajectory/interpolation policy.

Interpolation must be explicit.

---

## 73. Interpolation

For sampled results, interpolation may be:

```text
none
linear
model-aware
```

The selected method must be explicit.

DS must not silently interpolate engineering results using arbitrary UI behavior.

---

## 74. Analysis Request Extension

AP-EK-010 should be extended with:

```text
timeRange
initialConditions
inputSelections
integratorPolicy
outputPolicy
eventPolicy
```

while retaining compatibility with steady-state requests.

---

## 75. Persistence Integration

AP-EK-015 must persist:

```text
analysisMode = TRANSIENT
time policy
initial conditions
integrator
timestep policy
event policy
input identity
trajectory identity
termination status
```

---

## 76. Provenance Integration

AP-EK-009 must capture:

```text
dynamic model versions
equation versions
integrator version
solver version
initial condition source
input versions
event definitions
numeric policy
```

---

## 77. Validation Suite Extension

AP-EK-012 should add:

```text
TRANSIENT_MODEL
STATE_INITIALIZATION
INTEGRATOR
TIMESTEP
EVENT
SWITCHING
TRAJECTORY
CONSTRAINT_CROSSING
RESTART
DETERMINISM
ENERGY_CONSISTENCY
```

---

## 78. First RC Acceptance

Circuit:

```text
12 V source
1 kΩ resistor
1 µF capacitor
switch
ground
```

Initial:

```text
Vc(0) = 0 V
```

Run:

```text
TRANSIENT
```

Verify:

```text
time advances monotonically
capacitor state exists
resistor current exists
trajectory is persisted
event is recorded
results are reproducible
```

---

## 79. RC Sanity Check

The expected time constant is:

```text
τ = R × C
  = 1 ms
```

The analysis may use this relationship as a validation/reference calculation.

The transient solver must not substitute the closed-form RC equation for actual integration in the general transient path.

---

## 80. First RL Acceptance

Circuit:

```text
12 V source
10 Ω resistor
100 mH inductor
ground
```

Initial:

```text
IL(0) = 0 A
```

Verify:

```text
inductor current is a state
current evolves over time
energy state is preserved
```

---

## 81. First RLC Acceptance

Circuit:

```text
source
resistor
inductor
capacitor
```

Verify:

```text
multiple dynamic states
coupled equations
trajectory generation
deterministic results
```

---

## 82. First Event Acceptance

Circuit contains:

```text
switch
```

Event:

```text
close at t = 1 ms
```

Expected:

```text
event detected at declared time
topology changes
system reassembled
state continuity respected
trajectory continues
```

---

## 83. Constraint Crossing Acceptance

Define:

```text
Vc <= 10 V
```

Run transient.

Verify that when:

```text
Vc > 10 V
```

the constraint engine records:

```text
VIOLATED
```

with the relevant simulation time.

---

## 84. Restart Acceptance

Run:

```text
0 → 10 ms
```

Save state at:

```text
5 ms
```

Restart from 5 ms.

Verify that the continuation is semantically equivalent to the original trajectory after 5 ms under identical inputs/policies.

---

## 85. Determinism Acceptance

Repeat the same transient analysis twice.

Expected:

```text
same semantic trajectory
same event ordering
same constraint results
same solver/integrator identity
```

---

## 86. Failure Acceptance

Test:

```text
missing capacitance
invalid inductance
invalid initial state
zero/invalid timestep
event localization failure
nonlinear timestep non-convergence
resource limit
```

Every failure must be explicit.

---

## 87. Performance

Initial priorities:

```text
correctness
determinism
stability
diagnostics
provenance
```

Performance optimization follows profiling.

Large transient simulations may later require:

```text
sparse matrices
factorization reuse
adaptive output
parallel evaluation
```

without changing semantic contracts.

---

## 88. Sparse Solver Readiness

The normalized system should not assume dense matrices permanently.

The architecture should permit:

```text
dense linear solver
sparse linear solver
iterative linear solver
```

under the same solver abstraction.

---

## 89. Matrix Reuse

For systems whose Jacobian/topology remains unchanged between steps, factorization reuse may be used as an optimization.

The optimization must not change deterministic semantics.

---

## 90. Cancellation

Long simulations must support cancellation.

Cancellation returns:

```text
CANCELLED
```

and may preserve partial diagnostic state.

Partial trajectory must not be mislabeled as complete.

---

## 91. Resource Limits

Support:

```text
maximum simulation time
maximum steps
maximum evaluations
maximum wall time
maximum memory
```

Termination reason must be persisted.

---

## 92. Security

Transient inputs and imported models must not execute arbitrary code.

Dynamic model behavior is represented by validated knowledge/runtime semantics.

Resource limits must mitigate pathological models and malicious packages.

---

## 93. Implementation Sequence

```text
1. define DynamicAnalysisSystem
2. define StateVariable
3. define InitialCondition
4. define dynamic equation contract
5. extend component model interface
6. implement RC capacitor model
7. implement fixed-step integrator
8. integrate nonlinear timestep solving
9. implement trajectory
10. implement transient constraints
11. implement event model
12. implement switch topology transitions
13. implement RL/RLC models
14. implement adaptive timestep control
15. integrate persistence
16. integrate provenance/derivation
17. integrate AP-EK-012 validation
18. integrate DS waveform presentation
```

---

## 94. Recommended Repository Boundary

Conceptual:

```text
platform/
  oep_engine/
    analysis/
      transient/
        dynamic_system
        state
        integrator
        timestep
        events
        trajectory
        diagnostics
```

Dynamic component models remain under the established Component Model boundary.

No second simulation engine should be created.

---

## 95. Definition of Done

AP-EK-017 is complete when:

1. dynamic systems have a normalized representation;
2. state variables are explicit;
3. initial conditions are explicit;
4. dynamic equations are structured;
5. the architecture supports algebraic equations;
6. at least one deterministic transient integrator works;
7. nonlinear timestep solving can reuse AP-EK-016;
8. trajectories are generated;
9. events are represented;
10. event ordering is deterministic;
11. topology-changing events are supported;
12. state continuity is explicit;
13. transient constraints are evaluated;
14. constraint crossings are detectable where required;
15. solver failures are explicit;
16. transient identity/provenance is persisted;
17. restart semantics are defined;
18. deterministic repeatability is demonstrated;
19. RC/RL/RLC validation slices pass;
20. DS can consume waveform results without implementing the solver;
21. AP-EK-012 transient validation passes.

---

## 96. Architectural Non-Negotiables

1. Dynamic state belongs to an analysis execution, not automatically to the authoritative document.
2. Initial conditions must be explicit.
3. Time must be an explicit Quantity.
4. Dynamic equations must come from authoritative component models/knowledge.
5. The transient solver does not invent component behavior.
6. Steady-state and transient analyses remain distinct modes.
7. Nonlinear transient solving reuses the nonlinear solver foundation.
8. Integration method identity is part of provenance.
9. Timestep policy is part of provenance.
10. Event policy is part of provenance.
11. Event ordering is deterministic.
12. Topology-changing events are explicit.
13. State continuity is model-defined.
14. Failed trial steps are not automatically analysis failures.
15. Failed final solves are not valid results.
16. Sparse/dense solver choice must not change semantic meaning.
17. Hidden damping, smoothing, leakage, or regularization is prohibited.
18. Hidden DC initialization is prohibited unless explicitly requested.
19. Trajectory display data is not the sole authoritative analysis record.
20. DS renders transient results but does not integrate equations.
21. Explanation may interpret trajectories but cannot modify them.
22. Teaching content remains downstream of deterministic analysis.
23. Historical transient analyses are immutable.
24. Restarted analyses receive new identities and preserve lineage.
25. The transient solver extends the existing Engineering Analysis architecture rather than creating a separate simulation authority.
