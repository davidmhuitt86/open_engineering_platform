WP-STUDIO-025
Knowledge Studio Application Layer

Repository

projects/platform/oep_studio

Documentation

Save as:

projects/platform/oep_studio/docs/tasks/WP-STUDIO-025 Knowledge Studio Application Layer.md

=====================================================
OBJECTIVE
=====================================================

Introduce a proper application layer for Knowledge Studio.

During WP-STUDIO-023 it was discovered that Knowledge Studio has no
ambient application/service layer comparable to:

• Diagram Studio's EngineeringProjectNotifier

• Engineering Acquisition Studio's AcquisitionRuntimeNotifier

As a result, Knowledge Studio could not expose executable Platform
commands.

This work package corrects that architectural inconsistency.

The goal is NOT to redesign Knowledge Studio.

The goal is to establish a proper state owner that becomes the
single execution surface for Knowledge Studio.

=====================================================
BACKGROUND
=====================================================

Current Platform Architecture

✓ Studio Registry

✓ Capability Metadata

✓ Command Framework

✓ Command Palette

Knowledge Studio is currently the only major Studio without an
application controller/runtime layer.

This work package brings it into architectural parity with the other
Studios.

=====================================================
IMPLEMENTATION
=====================================================

Review Knowledge Studio.

Identify existing UI actions.

Determine where state currently lives.

Design a single KnowledgeStudioController
(or similarly appropriate application-layer object consistent with the
existing architecture).

The controller should own application operations rather than widgets.

Widgets should delegate behavior to the controller.

=====================================================
PHASE 1
ARCHITECTURE REVIEW
=====================================================

Document:

Current Knowledge Studio architecture.

Current state ownership.

Current action flow.

Current limitations.

=====================================================
PHASE 2
APPLICATION LAYER
=====================================================

Create a centralized application controller.

Responsibilities include:

• creating knowledge objects

• editing knowledge objects

• deleting knowledge objects

• searching knowledge

• loading knowledge

Only move functionality that already exists.

Do NOT invent new engineering features.

=====================================================
PHASE 3
UI REFACTOR
=====================================================

Update the Knowledge Studio UI to delegate
operations through the application layer.

Behavior should remain unchanged.

=====================================================
PHASE 4
COMMAND FRAMEWORK INTEGRATION
=====================================================

Register Knowledge Studio commands
using the Platform Command Framework.

Only commands backed by real implementations
should be registered.

=====================================================
PHASE 5
VALIDATION
=====================================================

Verify:

• behavior unchanged

• commands execute correctly

• Platform Command Palette now discovers
Knowledge Studio commands

• no duplicated business logic

=====================================================
OUT OF SCOPE
=====================================================

Do NOT redesign Knowledge Studio UI.

Do NOT redesign the data model.

Do NOT add AI features.

Do NOT add workflows.

Do NOT redesign Platform services.

Do NOT implement new engineering functionality.

=====================================================
DELIVERABLES
=====================================================

Provide:

1. Knowledge Studio architecture review

2. Application-layer design

3. Controller implementation

4. UI integration

5. Command Framework integration

6. Validation results

7. Documentation

8. Recommendations for future Knowledge Studio work

=====================================================
IMPORTANT
=====================================================

This is an architectural refactor.

Behavior should remain unchanged.

Maintain complete backwards compatibility.

Do not invent features.

Do not begin another work package without authorization.
