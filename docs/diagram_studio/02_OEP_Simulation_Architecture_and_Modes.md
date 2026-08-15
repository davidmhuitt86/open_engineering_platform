# OEP Simulation Architecture --- Diagnostic & Engineering Simulation Modes

**Status:** Proposed architectural/UI baseline\
**Scope:** Simulation capabilities invoked from Diagram Studio

## 1. Purpose

OEP requires two distinct simulation concepts.

### Mode 1 --- Diagnostic Simulation

The diagram becomes an interactive diagnostic test bench.

Primary question:

> **What is wrong, where should I test, and what should I expect to
> measure?**

### Mode 2 --- Engineering/System Simulation

The diagram/system model becomes a dynamic engineering simulation.

Primary question:

> **How does this system behave under defined conditions over time?**

These modes may share underlying engineering models and instrumentation
infrastructure, but they have different workflows and outputs.

# 2. Diagnostic Simulation

## 2.1 Purpose

Diagnostic Simulation is intended for:

-   Troubleshooting.
-   Technician training.
-   Electrical diagnostics.
-   Fault isolation.
-   Test-point identification.
-   Measurement training.
-   Diagnostic procedure development.
-   Reproducing field symptoms.

The diagram represents the system being diagnosed.

## 2.2 Operating State

The user establishes the system's operating state.

For a vehicle this may include:

``` text
Ignition: OFF / ACC / RUN / START
Engine: OFF / RUNNING
Switches: ON / OFF
Relays: Energized / De-energized
Loads: Normal / Faulted
```

For other systems, the state model adapts to the actual engineering
objects.

Examples:

``` text
SPST: ON / OFF
SPDT: A / B
DPST: OPEN / CLOSED
Momentary: PRESSED / RELEASED
```

State behavior must derive from the actual engineering model.

## 2.3 Virtual Instruments

Diagnostic Simulation includes virtual diagnostic instruments.

The primary instrument is the virtual DMM.

Potential measurement modes:

-   DC voltage.
-   AC voltage where applicable.
-   Resistance.
-   Continuity.
-   Current.
-   Voltage drop.
-   Potential relative to ground.
-   Potential between arbitrary nodes.

Measurements must be calculated from the simulated engineering state.
The interface must not display arbitrary instructional values.

## 2.4 Test Points

The engineer can place probes or select measurement points directly on
the diagram.

Example:

``` text
Probe A → Connector Pin 4
Probe B → Ground
```

The system calculates the result from the current state and highlights
the active test point.

## 2.5 Fault Injection

Diagnostic Simulation supports controlled scenario faults.

Initial fault categories may include:

-   Open circuit.
-   Short to ground.
-   Short to power.
-   Excessive resistance.
-   Open load.
-   Shorted load.
-   Failed switch.
-   Failed relay.
-   Failed fuse.
-   Poor ground.
-   Intermittent connection.

The supported list must ultimately correspond to actual
engineering-model capabilities.

Injected faults are scenario state, not permanent source-diagram
mutations unless explicitly committed.

## 2.6 Observed Symptoms

The user can enter the symptoms actually being experienced.

Example:

``` text
Observed:
Fuel pump does not operate.

Measurements:
Fuse: 12.5 V both sides
Relay coil: 12.4 V
Relay output: 0 V
Pump connector: 0 V
Ground: Good
```

The user can request diagnostic analysis from those observations.

## 2.7 Diagnostic Reasoning

Diagnostic reasoning should use:

-   Engineering topology.
-   Component behavior.
-   Operating state.
-   Injected faults.
-   User symptoms.
-   Actual measurements.
-   Validation results.
-   Engineering knowledge.
-   Diagnostic relationships.

It should not simply produce generic troubleshooting prose.

## 2.8 Diagnostic Output

A result may look like:

``` text
LIKELY FAULT

Fuel-pump relay is not closing.

WHY

The relay coil has the expected control condition,
but the switched output remains at 0 V.

NEXT TEST

Measure relay control-side ground.

TEST POINT

Relay pin 85

EXPECTED

< 0.2 V to ground

[ SHOW TEST POINT ]
```

The recommended test point should be selectable and highlighted on the
diagram.

## 2.9 Traceability

Diagnostic conclusions should eventually expose:

-   Evidence used.
-   Measurements used.
-   Expected measurement.
-   Actual measurement.
-   Engineering relationship used.
-   Candidate faults considered.
-   Reason for the recommended conclusion.
-   Next recommended test.

The engineer should be able to understand why the system reached its
conclusion.

# 3. Engineering/System Simulation

## 3.1 Purpose

Engineering/System Simulation is intended for:

-   Dynamic system analysis.
-   Electrical behavior over time.
-   Transient analysis.
-   Switching behavior.
-   Component models.
-   Control-system behavior.
-   Sensor behavior.
-   PWM.
-   Relay timing.
-   Motor/load behavior.
-   Fault propagation.
-   System-level engineering studies.

It is not primarily a troubleshooting assistant.

## 3.2 Controls

A simulation workspace may eventually provide:

``` text
RUN
PAUSE
STEP
RESET

TIME
0.000 s

SCENARIO
Normal Operation
```

Controls must correspond to capabilities actually implemented by the
simulation engine.

## 3.3 Dynamic Measurements

Engineering Simulation may expose:

-   Voltage versus time.
-   Current versus time.
-   State transitions.
-   Component states.
-   Signal values.
-   System events.
-   Derived engineering quantities.

# 4. Relationship Between the Two Modes

Both modes may operate on the same engineering diagram/model while
answering different questions.

``` text
                         OPEN DIAGRAM
                              |
                           SIMULATE
                              |
                 +------------+------------+
                 |                         |
                 v                         v
        DIAGNOSTIC SIMULATION      ENGINEERING SIMULATION
                 |                         |
        "What is wrong?"          "How does it behave?"
                 |                         |
        Operating states          Dynamic system model
        DMM measurements          Time-domain behavior
        Fault injection           System events
        Symptoms                  Component models
        Test points               Transients
        Guided diagnosis          Engineering analysis
```

# 5. Source Diagram Integrity

Simulation should not silently modify the authoritative diagram.

Conceptually:

``` text
AUTHORITATIVE DIAGRAM
        |
        +-- Simulation Scenario
        |      +-- Operating State
        |      +-- Measurements
        |      +-- Faults
        |      +-- Parameters
        |
        +-- Diagnostic Session
               +-- Symptoms
               +-- Tests
               +-- Results
               +-- Conclusions
```

A scenario/session may eventually be persisted separately when the
underlying platform supports it.

The source engineering knowledge remains authoritative.

# 6. Training Use

Diagnostic Simulation is naturally suited to training.

A training scenario can define:

-   Known system.
-   Starting operating state.
-   Hidden fault(s).
-   Expected measurements.
-   Available test points.
-   Diagnostic objective.
-   Evaluation criteria.

The trainee can troubleshoot the system using the same workflow as a
real technician.

Evaluation may consider:

-   Test selection.
-   Measurement technique.
-   Diagnostic sequence.
-   Correct fault identification.
-   Unnecessary tests.
-   Final conclusion.

Training remains an extension of Diagnostic Simulation rather than a
separate simulation architecture.

# 7. AI Relationship

AI is not the simulation engine.

The simulation engine determines actual state, measurements, and events.

AI may:

-   Explain measurements.
-   Explain engineering relationships.
-   Summarize evidence.
-   Suggest diagnostic tests.
-   Explain why a test is useful.
-   Answer questions about the active system.
-   Help interpret engineering knowledge.

AI must not invent simulation results.

``` text
Simulation Engine
       |
       +-- State
       +-- Measurements
       +-- Events
              |
              v
       Diagnostic / AI Layer
              |
              v
       Human-readable explanation
```

# 8. Knowledge Relationship

Engineering Knowledge is an input to diagnostic reasoning, not a
substitute for simulation.

``` text
Diagram
   +
Operating State
   +
Measured Values
   +
Component Behavior
   +
Engineering Knowledge
   |
   v
Diagnostic Reasoning
   |
   v
Recommended Test
```

Knowledge may be opened as a contextual panel while simulation remains
active.

# 9. Architectural Boundary

Diagram Studio orchestrates the user workflow.

The Engineering Engine and future simulation services provide
engineering behavior.

The Studio shell must not contain electrical simulation algorithms.

The governing principle remains:

> **The Studio orchestrates. The Engineering Engine executes.**

The existing engine work previously deferred the actual simulation
engine; this document defines the intended behavior and UI architecture
without assuming the complete simulator already exists.

# 10. UI Principle

Simulation should appear because a diagram is open.

Preferred workflow:

``` text
START
  |
DIAGRAM STUDIO
  |
OPEN / CREATE / ACQUIRE DIAGRAM
  |
DIAGRAM WORKSPACE
  |
SIMULATE
  |
SELECT MODE
  +-- Diagnostic
  +-- Engineering/System
```

This keeps simulation contextual and prevents a generic Simulation
Studio from unnecessarily competing with Diagram Studio.

# 11. Definition of Done

The two-mode architecture is successful when:

1.  Diagnostic and Engineering Simulation are clearly distinct.
2.  Both operate against an actual engineering diagram/model.
3.  Diagnostic Simulation supports explicit operating states.
4.  Diagnostic Simulation supports real measurements.
5.  Diagnostic Simulation supports controlled fault injection.
6.  Diagnostic Simulation accepts observed symptoms.
7.  Diagnostic reasoning is grounded in actual engineering state and
    knowledge.
8.  Recommended tests identify locations on the diagram.
9.  Engineering Simulation provides a separate dynamic-system workflow.
10. Simulation does not silently modify the authoritative diagram.
11. AI assists but does not fabricate simulation results.
12. Knowledge can be opened contextually while simulation remains
    active.
13. Simulation is invoked from Diagram Studio rather than unnecessarily
    exposed as a competing primary Studio.
