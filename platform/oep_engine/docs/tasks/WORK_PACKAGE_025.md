# WORK PACKAGE 025

# Unified Engineering Workspace

Status: Approved

Version: 1.0

Repositories

projects/platform/oep_foundation (READ ONLY)

projects/platform/oep_engine

projects/platform/oep_studio

---

# Objective

Transform OEP Studio from a collection of independent workspaces into a unified engineering environment.

Knowledge Studio and Diagram Studio shall become two synchronized views of the same Engineering Project.

Navigation, evidence, AI, search, property inspection, validation, and repository interactions shall operate seamlessly across both workspaces.

No new engineering editing features.

No new repository features.

No Marketplace implementation.

No Simulation.

This work package is entirely about workflow integration.

---

# Architectural Principles

The ownership boundaries established in previous work packages remain permanent.

Foundation owns:

- Repository
- Knowledge
- Evidence
- Provenance

Engineering Engine owns:

- Engineering Graph
- Diagram Layout
- ViewState
- Commands
- Search
- Validation
- Navigation

Studio owns:

- Workspace orchestration
- User interaction
- Window management
- Workflow
- Docking
- Property Inspector
- Workspace persistence

No ownership boundaries shall change.

---

# ENGINE-TASK-000118

## Engineering Project

Introduce the concept of an Engineering Project.

An Engineering Project becomes the parent object for:

- Knowledge
- Diagrams
- Engineering Graphs
- Evidence
- AI Sessions
- Validation Results
- Future Simulation Sessions

Projects coordinate existing systems.

Projects do not duplicate repository functionality.

---

# ENGINE-TASK-000119

## Workspace Synchronization

Implement synchronization between Knowledge Studio and Diagram Studio.

Support:

- Shared active project
- Shared repository
- Shared navigation context
- Shared active object
- Shared selection where applicable
- Shared recent history

Changing workspaces shall preserve context.

---

# ENGINE-TASK-000120

## Unified Navigation

Implement platform-wide navigation.

Support:

- Navigate to Knowledge Object
- Navigate to Diagram Element
- Navigate to Evidence
- Navigate to Relationship
- Navigate to Validation Result
- Navigate to Search Result

Navigation shall automatically activate the appropriate workspace.

---

# ENGINE-TASK-000121

## Shared Search

Merge existing search capabilities into a unified search experience.

Search shall include:

- Knowledge Objects
- Engineering Graph
- Components
- Symbols
- Relationships
- Evidence
- Annotations
- Layers

Search results shall identify:

- Object Type
- Owning Workspace
- Repository Location

---

# ENGINE-TASK-000122

## Shared Property Inspector

Complete integration of the Property Inspector.

Selecting an object anywhere in OEP shall display the correct inspector automatically.

Support:

- Knowledge Objects
- Diagram Objects
- Evidence
- Relationships
- Components
- Layers
- Annotations

The Property Inspector remains Studio-owned.

---

# ENGINE-TASK-000123

## Evidence Integration

Allow Engineering Graph objects to navigate directly to supporting evidence.

Support:

- Images
- PDFs
- OCR Results
- Notes
- Specifications

Evidence ownership remains in Foundation.

---

# ENGINE-TASK-000124

## AI Workspace Integration

Complete AI workflow integration.

AI shall receive unified project context including:

- Knowledge
- Engineering Graph
- Selected object
- Related evidence
- Active diagram
- Validation results

Reuse the existing AI provider architecture.

Do not introduce new providers.

---

# ENGINE-TASK-000125

## Validation Integration

Expose Engineering Engine validation through Studio.

Support:

- Live validation panel
- Click-to-navigate
- Highlight affected objects
- Suggested fixes
- AI explanation entry point

Validation logic remains Engine-owned.

---

# ENGINE-TASK-000126

## Project Explorer

Replace workspace-specific explorers with a unified Project Explorer.

Display:

Engineering Project

├── Knowledge

├── Diagrams

├── Evidence

├── Components

├── Validation

├── AI Sessions

└── Future Simulation

Project Explorer becomes the primary navigation surface for OEP.

---

# ENGINE-TASK-000127

## Unified Workflow

Users shall be able to perform workflows such as:

Select component

↓

Open related knowledge

↓

Open related evidence

↓

Edit diagram

↓

Run validation

↓

Ask AI

↓

Return to diagram

without manually managing workspace state.

---

# Documentation

Create:

docs/ENGINEERING_PROJECT.md

docs/WORKSPACE_SYNCHRONIZATION.md

docs/UNIFIED_SEARCH.md

docs/PROJECT_EXPLORER.md

docs/WORKFLOW_ARCHITECTURE.md

Update:

README.md

IMPLEMENTATION_STATUS.md

ARCHITECTURE_DECISIONS.md

Document:

- Engineering Project model
- Workspace synchronization
- Navigation architecture
- Unified workflow philosophy
- Project Explorer architecture

---

# Verification

Run:

oep_engine

- flutter analyze
- flutter test
- flutter build windows

oep_studio

- flutter analyze
- flutter test
- flutter build windows

Manual verification:

- Create project
- Add knowledge
- Create diagram
- Navigate between workspaces
- Shared search
- Shared Property Inspector
- Evidence navigation
- AI context
- Validation navigation
- Project Explorer
- Workspace persistence

---

# Definition of Done

Complete when:

Knowledge Studio and Diagram Studio behave as one integrated engineering environment.

Project Explorer is operational.

Shared search is operational.

Navigation automatically activates the correct workspace.

Property Inspector is fully unified.

Evidence integration is complete.

AI receives unified engineering context.

Validation integrates naturally into Studio workflows.

All tests pass.

Windows builds succeed.

Stop and await formal architectural review.