# AP-EK-014
# Engineering Explanation / Teaching Layer
## Deterministic Engineering Results → Human-Understandable Reasoning

**Status:** Architecture Phase — Implementation Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-001 through AP-EK-013  
**Primary objective:** Define the OEP explanation and teaching boundary that converts authoritative engineering analysis into understandable, traceable instruction without becoming an authority for engineering truth.

---

## 1. Purpose

AP-EK-014 defines the layer between deterministic Engineering Analysis and the human engineer, installer, technician, student, or instructor.

Its purpose is to answer questions such as:

```text
What happened?
Why did it happen?
How was it calculated?
Which engineering law applies?
Which inputs mattered?
Which constraint failed?
What evidence supports the result?
What should the engineer inspect next?
What concept should a student learn from this result?
```

The layer explains engineering truth.

It does not create engineering truth.

---

## 2. Fundamental Authority Rule

The authoritative chain remains:

```text
Authoritative Knowledge
        ↓
Knowledge Runtime
        ↓
Engineering Analysis
        ↓
AnalysisResult
        ↓
Explanation / Teaching Layer
```

Never:

```text
AI / Explanation
        ↓
Engineering Truth
```

The explanation layer is downstream of deterministic engineering computation.

---

## 3. Core Separation

Three concepts must remain distinct:

```text
CALCULATION
    What the system mathematically determined.

EXPLANATION
    How the system communicates that determination.

TEACHING
    How the system uses the determination to build understanding.
```

A calculation may exist without an explanation.

An explanation may exist without being a lesson.

A lesson must remain grounded in authoritative results and knowledge.

---

## 4. Responsibilities

The Explanation / Teaching Layer owns:

```text
result interpretation
derivation narration
engineering terminology
step explanation
causal explanation
constraint explanation
diagnostic guidance
concept linking
difficulty adaptation
teaching sequences
question generation
answer evaluation where deterministic criteria exist
explanation provenance
```

It does not own:

```text
circuit solving
unit conversion
law selection as engineering authority
topology extraction
component physical models
authoritative reference facts
source acquisition
knowledge authoring
diagram geometry
```

---

## 5. Inputs

The primary input is:

```text
AnalysisResult
```

Additional inputs may include:

```text
AnalysisRequest
KnowledgeRuntimeContext
ProvenanceGraph
DerivationGraph
ConstraintResults
EngineeringObject metadata
user-selected component
user-selected node
user-selected equation
teaching context
```

---

## 6. Output

Conceptual:

```text
EngineeringExplanation
```

containing:

```text
explanationId
analysisId
resultReference
audience
purpose
sections[]
evidence[]
derivationReferences[]
knowledgeReferences[]
warnings[]
confidence
```

The explanation must reference the underlying engineering result rather than duplicating it as an independent truth source.

---

## 7. Explanation Identity

Every generated explanation should be traceable to:

```text
analysisId
analysisResultVersion
knowledgePackageId
knowledgePackageVersion
runtimeVersion
```

This allows an explanation to be regenerated when the underlying engineering result changes.

---

## 8. Explanation Types

Initial types:

```text
SUMMARY
DERIVATION
CONCEPT
DIAGNOSTIC
CONSTRAINT
COMPONENT
TOPOLOGY
PROCEDURE
TEACHING
```

Future types may include:

```text
DESIGN_REVIEW
COMPARISON
FAILURE_ANALYSIS
TROUBLESHOOTING
EXAM_REVIEW
```

---

## 9. Summary Explanation

A summary communicates the result without unnecessary derivation.

Example:

```text
The 12 V source drives 1.2 A through the 10 Ω resistor.
The resistor dissipates 14.4 W.
```

The numbers originate from AnalysisResult.

The explanation layer must not independently recalculate them.

---

## 10. Derivation Explanation

A derivation exposes the reasoning chain.

Example:

```text
Known:
V = 12 V
R = 10 Ω

Applicable law:
Ohm's Law

Equation:
I = V / R

Substitution:
I = 12 V / 10 Ω

Result:
I = 1.2 A
```

Each step references the authoritative derivation/equation identity.

---

## 11. Causal Explanation

The system should distinguish mathematical dependency from physical causation.

For example:

```text
12 V
   ↓
across resistor
   ↓
10 Ω resistance
   ↓
1.2 A current
```

The explanation should only assert causal relationships supported by the component model and analysis.

It must not infer unsupported physical mechanisms.

---

## 12. Constraint Explanation

A violated constraint should produce an explanation such as:

```text
Constraint:
Resistor power rating ≤ 10 W

Calculated:
14.4 W

Status:
VIOLATED
```

The explanation may state:

```text
The calculated power exceeds the specified rating.
```

It must not silently invent an additional physical consequence.

---

## 13. Diagnostic Explanation

Diagnostics should be evidence-driven.

Example:

```text
Observed:
Expected current = 1.2 A
Measured current = 0.0 A

Possible causes supported by the model:
- open switch
- open conductor
- missing source connection
```

The system must distinguish:

```text
DETERMINED
SUPPORTED POSSIBILITY
UNSUPPORTED HYPOTHESIS
```

A diagnostic explanation must never present a possibility as a confirmed fault.

---

## 14. Evidence Classification

Explanation content should carry an evidence class:

```text
REFERENCE_FACT
DESIGN_INPUT
MEASUREMENT
CALCULATED_VALUE
ENGINEERING_INFERENCE
HYPOTHESIS
```

These classifications derive from AP-EK-001 and AP-EK-009.

---

## 15. Confidence

Confidence must not become a substitute for evidence.

For deterministic results:

```text
calculated value = deterministic
```

For inference:

```text
inference strength = evidence-dependent
```

For hypotheses:

```text
hypothesis = explicitly uncertain
```

Avoid generic percentages such as:

```text
87% likely
```

unless a formally defined probabilistic model exists.

---

## 16. AI Boundary

AI may be used to:

```text
rephrase
summarize
translate
adapt vocabulary
generate examples
generate questions
organize explanations
produce conversational teaching
```

AI must not be allowed to:

```text
invent calculated values
modify AnalysisResult
alter equation semantics
alter provenance
declare constraints satisfied
invent component behavior
override deterministic diagnostics
replace missing reference knowledge
silently introduce assumptions
```

---

## 17. AI-Assisted Explanation Contract

If AI generates text, the generation request should contain structured evidence rather than unrestricted engineering context.

Conceptual:

```text
ExplanationContext
  analysisResult
  selectedEvidence
  derivation
  allowedKnowledgeRefs
  audience
  purpose
  constraints
```

The AI produces:

```text
ExplanationDraft
```

which can be validated against its source references.

---

## 18. Explanation Validation

A generated explanation should be checked for:

```text
referenced result exists
referenced equation exists
referenced law exists
referenced component exists
referenced constraint exists
no unsupported numeric claim
no contradiction with AnalysisResult
no fabricated provenance
```

The first implementation may use structured templates rather than an LLM.

---

## 19. Deterministic Templates

Initial explanations should use deterministic templates.

Example:

```text
Given:
{sourceVoltage}

Resistance:
{resistance}

Using:
{equationName}

Current:
{current}
```

This establishes a trustworthy baseline before generative explanation is introduced.

---

## 20. Explanation Graph

An explanation can be represented as a graph:

```text
Result
  ↓
Derivation Step
  ↓
Equation
  ↓
Law
  ↓
Knowledge Source
```

For a component:

```text
Result
  ↓
Component
  ↓
Component Model
  ↓
Constraint
```

This enables clickable engineering provenance.

---

## 21. Concept Graph

Teaching requires a second graph:

```text
Concept
  ├── prerequisite
  ├── related
  ├── example
  ├── equation
  ├── component
  └── misconception
```

This is not a replacement for the Engineering Knowledge Graph.

It is a pedagogical view over authoritative knowledge.

---

## 22. Engineering Concept

Conceptual:

```text
EngineeringConcept
  conceptId
  name
  definition
  prerequisites[]
  knowledgeRefs[]
  equations[]
  examples[]
  misconceptions[]
  difficulty
```

The canonical engineering facts remain in authoritative knowledge.

Pedagogical metadata may reference them.

---

## 23. Teaching Objective

Conceptual:

```text
TeachingObjective
  objectiveId
  conceptRefs[]
  expectedCapabilities[]
  difficulty
  prerequisites[]
```

Examples:

```text
identify-voltage-current-resistance
apply-ohms-law
interpret-power-dissipation
trace-series-current
identify-open-circuit
```

---

## 24. Lesson

Conceptual:

```text
Lesson
  lessonId
  objectiveRefs[]
  prerequisiteRefs[]
  sequence[]
  assessments[]
```

A lesson should be reproducible from versioned knowledge and teaching content.

---

## 25. Teaching Step Types

Initial:

```text
EXPLAIN
SHOW
ASK
PREDICT
CALCULATE
TRACE
COMPARE
DIAGNOSE
VERIFY
REFLECT
```

---

## 26. Interactive Teaching

The system should eventually allow:

```text
"Predict the current before calculating it."
```

Then:

```text
student answer
      ↓
deterministic evaluation
      ↓
feedback
      ↓
explanation
```

Where exact deterministic evaluation is possible, it should be preferred.

---

## 27. Assessment Boundary

Assessment can evaluate:

```text
numeric answer
unit
sign
selected equation
selected component
topology interpretation
constraint interpretation
```

Assessment must not alter authoritative engineering data.

---

## 28. Worked Example

First canonical teaching example:

```text
Source = 12 V
Resistor = 10 Ω
```

Student is asked:

```text
What current should flow?
```

Expected reasoning:

```text
I = V / R
I = 12 / 10
I = 1.2 A
```

Then:

```text
P = V × I
P = 12 × 1.2
P = 14.4 W
```

Every value references the AnalysisResult.

---

## 29. Misconception Model

The teaching layer may maintain known misconceptions.

Example:

```text
Misconception:
"Voltage is consumed by a resistor."

Correction:
The resistor has a voltage drop while electrical energy is transferred to another form.
```

Such statements must be grounded in authoritative knowledge where engineering correctness is asserted.

---

## 30. Diagnostic Teaching

A failed analysis can become a lesson.

Example:

```text
Constraint violated:
resistor power rating

Teaching objective:
understand power dissipation

Prompt:
Why is the resistor operating outside its specified limit?
```

The educational system uses the actual engineering result rather than constructing an artificial example.

---

## 31. Adaptive Difficulty

Difficulty can vary by:

```text
number of components
number of equations
required inference
measurement uncertainty
topology complexity
unknown count
diagnostic ambiguity
```

Difficulty metadata is pedagogical, not engineering truth.

---

## 32. Audience Profiles

Initial profiles:

```text
NOVICE
STUDENT
APPRENTICE
TECHNICIAN
ENGINEER
INSTRUCTOR
```

The same result may be explained differently for each audience.

The underlying result remains identical.

---

## 33. Vocabulary Adaptation

For a novice:

```text
"Voltage is the electrical potential difference between two points."
```

For an engineer:

```text
"ΔV across the component terminal pair is 12 V."
```

Terminology adaptation must not change semantics.

---

## 34. Unit Presentation

The teaching layer may choose presentation units.

Example:

```text
1.2 A
```

versus:

```text
1200 mA
```

The underlying Quantity remains authoritative.

Presentation conversion must use the Quantity/Unit Engine.

---

## 35. Explanation of Unknowns

If analysis returns:

```text
UNKNOWN
```

the explanation must say why.

Possible reasons:

```text
missing parameter
insufficient topology
unsupported model
measurement unavailable
constraint applicability unresolved
```

Never fill an unknown with an invented value.

---

## 36. Explanation of Failure

For an invalid circuit:

```text
Analysis failed.

Reason:
No valid reference node was identified.
```

The explanation should expose the diagnostic generated by the analysis system.

It must not disguise a failure as an approximate result.

---

## 37. Explanation of Assumptions

Every nontrivial assumption should be visible.

Example:

```text
Assumption:
Ideal DC source

Reason:
Required by selected component model.
```

Assumptions should be linked to AP-EK-009 provenance.

---

## 38. Measurement Comparison

Measured and calculated values must remain distinct:

```text
Calculated:
1.20 A

Measured:
1.15 A
```

The explanation may compute:

```text
difference = 0.05 A
```

using deterministic analysis.

It must not silently declare the measurement correct or incorrect without an applicable tolerance/constraint.

---

## 39. Troubleshooting

Future troubleshooting should follow:

```text
Observation
   ↓
Known facts
   ↓
Analysis
   ↓
Constraint failures
   ↓
Supported candidate causes
   ↓
Recommended verification
   ↓
New measurement
   ↓
Updated analysis
```

This creates an evidence-driven diagnostic loop.

---

## 40. Verification Recommendations

A recommendation should reference the reason it was generated.

Example:

```text
Recommendation:
Verify continuity across the switch.

Reason:
The current path requires the switch to be closed.
```

Recommendations must be traceable to topology/model/constraint evidence.

---

## 41. Procedure Integration

A future procedure may reference:

```text
EngineeringObject
Component
AnalysisResult
Constraint
Measurement
VerificationStep
```

The teaching layer may explain a procedure but must not silently modify it.

---

## 42. Diagram Studio Integration

DS owns presentation:

```text
explanation panel
derivation view
highlighted components
equation display
constraint display
diagnostic overlay
teaching interaction
```

The Explanation Layer owns the semantic content.

DS does not calculate explanation values.

---

## 43. Visual Traceability

An explanation may identify:

```text
source node
target node
component
wire
terminal
constraint
```

DS may highlight these entities.

The explanation layer supplies semantic references; DS maps them to visual objects.

---

## 44. Explain This Component

A future DS action:

```text
Explain Component
```

should resolve:

```text
Engineering Object
Component Model
current AnalysisResult
applicable constraints
relevant equations
```

Then produce a component-focused explanation.

---

## 45. Explain This Wire

A wire explanation may show:

```text
source terminal
target terminal
electrical node
current
voltage
connected components
relevant constraints
```

If current or voltage cannot be determined, the explanation must state that.

---

## 46. Explain Why

A generic:

```text
Why?
```

interaction should resolve the nearest available reasoning chain:

```text
result
→ derivation
→ equation
→ law
→ model
→ input/provenance
```

This becomes a core OEP interaction pattern.

---

## 47. Explain Why Not

For an invalid or unexpected result:

```text
Why is this not working?
```

the system should prioritize:

```text
violated constraints
analysis diagnostics
missing information
unsupported models
topology discontinuities
measurement discrepancies
```

rather than generic troubleshooting guesses.

---

## 48. Teaching From Real Engineering

A central OEP capability should be:

```text
engineering work
      ↓
analysis
      ↓
explanation
      ↓
learning opportunity
```

The same engineering object can therefore serve:

```text
work
training
assessment
documentation
troubleshooting
```

without creating separate incompatible representations.

---

## 49. Explanation Persistence

Explanations should generally be reproducible rather than authoritative document state.

Persist:

```text
explanation request
source analysis identity
knowledge identity
teaching context
```

rather than treating generated prose as the engineering source of truth.

A user may explicitly save an explanation as an Engineering Object if desired.

---

## 50. Versioning

An explanation depends on:

```text
knowledge version
analysis version
teaching content version
explanation engine version
```

A changed analysis invalidates dependent explanations.

---

## 51. Caching

Explanation results may be cached using:

```text
analysisId
analysisVersion
explanationType
audience
purpose
teachingContextVersion
explanationEngineVersion
```

Caches are derived data.

---

## 52. Determinism

For deterministic templates:

```text
same inputs
same knowledge
same analysis
same template version
→ same explanation
```

Generative AI may produce variable wording, but semantic claims must remain constrained by structured source evidence.

---

## 53. Semantic Validation of Generated Text

Future AI-generated explanations should produce structured claims in parallel with prose.

Conceptual:

```text
ExplanationClaim
  claimId
  statement
  evidenceRefs[]
  claimType
```

Example:

```text
Claim:
"The resistor dissipates 14.4 W."

Evidence:
AnalysisResult.power[R1]
```

Unsupported claims can then be rejected.

---

## 54. Claim Types

Initial:

```text
NUMERIC_RESULT
REFERENCE_FACT
EQUATION_APPLICATION
CONSTRAINT_STATUS
TOPOLOGY_FACT
MODEL_FACT
ASSUMPTION
INFERENCE
HYPOTHESIS
RECOMMENDATION
```

---

## 55. Explanation Guardrails

The system should reject or flag generated text that:

```text
introduces unsupported numeric values
contradicts analysis
claims an unknown is known
claims a hypothesis is a fact
removes required assumptions
changes units incorrectly
misattributes provenance
references nonexistent objects
```

---

## 56. Translation

Translation may be performed on explanation text.

Engineering identifiers must remain stable:

```text
equationId
lawId
objectId
constraintId
unitId
```

Translated terminology must preserve technical meaning.

---

## 57. Accessibility

Teaching/explanation presentation should eventually support:

```text
plain language
technical language
screen-reader structure
equation descriptions
unit expansion
step-by-step narration
```

Accessibility changes presentation, not engineering semantics.

---

## 58. Instructor Mode

An instructor may see:

```text
objective
prerequisites
expected reasoning
common misconceptions
analysis result
answer
evidence
```

A student may see:

```text
problem
hints
result feedback
derivation
learning objective
```

Both reference the same authoritative knowledge.

---

## 59. Hint System

Hints should progressively reveal information.

Example:

```text
Hint 1:
Identify the known voltage and resistance.

Hint 2:
Which law relates voltage, current, and resistance?

Hint 3:
Solve Ohm's Law for current.
```

Hints should not reveal the final answer prematurely unless configured to do so.

---

## 60. Explanation Depth

Initial levels:

```text
LEVEL 1 — RESULT
LEVEL 2 — WHY
LEVEL 3 — DERIVATION
LEVEL 4 — ENGINEERING THEORY
LEVEL 5 — TEACHING / PRACTICE
```

This allows the user to control cognitive depth.

---

## 61. Knowledge Navigation

Every explanation element should support navigation where possible:

```text
equation → equation definition
law → law definition
component → model
constraint → constraint definition
source → provenance
```

This creates an integrated engineering knowledge experience.

---

## 62. First Implementation

Do not begin with a general AI tutor.

Implement:

```text
AnalysisResult
      ↓
deterministic explanation templates
      ↓
DS explanation panel
```

First supported outputs:

```text
result summary
equation derivation
constraint explanation
component explanation
provenance explanation
```

---

## 63. First Teaching Slice

Use the canonical circuit:

```text
12 V source
10 Ω resistor
reference node
```

Teaching sequence:

```text
1. Identify voltage.
2. Identify resistance.
3. Select Ohm's Law.
4. Solve for current.
5. Calculate power.
6. Compare power against rating.
7. Explain the result.
```

---

## 64. First Diagnostic Slice

Circuit:

```text
12 V source
10 Ω resistor
open switch
```

Expected teaching/diagnostic flow:

```text
Observation:
current = 0 A

Topology:
current path is open

Analysis:
no current through the open branch

Teaching:
an open switch prevents the modeled current path from conducting
```

The exact result must come from the analysis/model layer.

---

## 65. API Boundary

Conceptual:

```text
ExplanationService
  explainAnalysis(request)
  explainResult(resultId)
  explainComponent(componentId)
  explainConstraint(constraintId)
  explainDerivation(derivationId)
  teach(objectiveId, context)
```

The service consumes Engine-owned semantic results.

---

## 66. Analysis-to-Explanation Contract

Minimum:

```text
AnalysisResult
AnalysisRequest
KnowledgeRuntimeContext
ProvenanceGraph
DerivationGraph
```

must be sufficient to reconstruct the explanation without reading raw reference documents.

---

## 67. Explanation-to-DS Contract

DS should receive structured content:

```text
sections
claims
evidenceRefs
visualRefs
equationRefs
componentRefs
constraintRefs
actions
```

This allows DS to render rich engineering explanations without owning their semantics.

---

## 68. Future Knowledge Compiler Integration

Teaching metadata may eventually be compiled alongside authoritative knowledge.

However:

```text
engineering truth
```

and:

```text
pedagogical metadata
```

must remain distinguishable.

A teaching package may reference engineering package identities.

---

## 69. Exchange Integration

Engineering Exchange may distribute:

```text
knowledge packages
teaching packages
worked examples
procedures
courses
```

Licensing applies to the distributed content.

Runtime verification remains separate from Exchange commerce.

---

## 70. Academic Alliance

The architecture supports academic use without creating a separate engineering model.

An institution can distribute:

```text
course content
teaching objectives
lessons
assessments
```

that reference the same OEP Engineering Knowledge Runtime.

This preserves continuity between:

```text
classroom
laboratory
field work
professional engineering
```

---

## 71. Testing

### Explanation correctness

- values match AnalysisResult;
- units match Quantity;
- equation references resolve;
- law references resolve;
- constraint status matches;
- provenance references resolve.

### Teaching correctness

- objective references resolve;
- prerequisites resolve;
- expected answer matches deterministic evaluator;
- hints do not contradict authoritative results.

### AI safety

- unsupported claim detection;
- numeric contradiction detection;
- provenance fabrication detection;
- unknown-to-known hallucination detection.

---

## 72. Definition of Done

AP-EK-014 is complete when:

1. ExplanationService boundary is defined;
2. EngineeringExplanation contract exists;
3. explanation identity is tied to analysis identity;
4. deterministic templates are implemented;
5. derivation explanation is supported;
6. constraint explanation is supported;
7. component explanation is supported;
8. provenance navigation is supported;
9. evidence classifications are preserved;
10. assumptions are exposed;
11. unknowns remain unknown;
12. unsupported claims are rejected or flagged;
13. DS can render structured explanations;
14. first teaching slice works against the canonical electrical circuit;
15. diagnostic teaching can consume analysis results;
16. no explanation code calculates authoritative engineering values;
17. AI, if introduced, remains downstream and constrained;
18. AP-EK-012 validation covers explanation boundary contracts.

---

## 73. Architectural Non-Negotiables

1. Explanation is downstream of Engineering Analysis.
2. Teaching is downstream of authoritative engineering knowledge.
3. AI is assistive, not authoritative.
4. AnalysisResult cannot be modified by explanation.
5. Explanation cannot modify engineering provenance.
6. Unknown values remain unknown.
7. Hypotheses remain hypotheses.
8. Calculated values originate in deterministic analysis.
9. Engineering claims must have evidence.
10. Pedagogical metadata must not become engineering truth.
11. DS renders explanations but does not author their semantics.
12. Generated prose is not the engineering source of truth.
13. Deterministic templates precede general AI tutoring.
14. Every explanation remains traceable to its analysis and knowledge versions.
15. Real engineering work can become a teaching artifact without creating a second engineering representation.
16. The system must never hide uncertainty behind fluent language.
17. Explanation depth is adjustable without changing the underlying result.
18. Technical vocabulary may adapt, but semantics may not.
19. Exchange may distribute explanations/teaching content, but runtime remains the execution boundary.
20. The ultimate purpose is not merely to answer engineering questions; it is to make the engineering reasoning itself inspectable, teachable, and reusable.
