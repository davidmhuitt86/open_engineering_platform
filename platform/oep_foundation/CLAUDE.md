# CLAUDE.md
## Open Engineering Platform (OEP)
### Engineering Development Constitution

**Version:** 1.0  
**Status:** Ratified  
**Authority:** Divad Technology Group

---

# Welcome

Welcome to the Open Engineering Platform (OEP).

Before writing a single line of code, understand that you are not contributing to a software application.

You are contributing to an engineering platform intended to preserve, organize, and expand engineering knowledge for generations to come.

Every implementation decision should strengthen that mission.

If a proposed implementation conflicts with this document, this document takes precedence unless explicitly amended by the Founder and Chief Systems Architect.

---

# Mission

The Open Engineering Platform exists to provide an open, extensible engineering ecosystem where engineering knowledge can be created, organized, preserved, validated, shared, and continuously improved.

Applications are temporary.

Engineering knowledge is permanent.

OEP exists to protect that knowledge.

---

# Vision

OEP is designed to become the universal platform upon which engineering workflows are built.

Studios, plugins, packages, repositories, and future technologies all exist because of OEP.

Nothing should be designed around a single industry.

Everything should be designed around engineering.

---

# Core Philosophy

## OEP Comes First

Every Studio is a client of OEP.

Never implement functionality inside a Studio that belongs in OEP.

If multiple Studios would benefit from a feature, that feature belongs in the Platform.

---

## Repository First

The Repository is the product.

Applications simply interact with it.

Everything ultimately exists inside a Repository.

Never design features that bypass the Repository.

---

## Engineering Objects

Engineering Objects are the single source of truth.

Files, diagrams, reports, certificates, documentation, and visualizations are generated representations of Engineering Objects.

Never duplicate engineering data simply because multiple views require it.

---

## Five Primitive Rule

The platform is permanently based upon five primitive concepts.

- Engineering Object
- Relationship
- Operation
- Event
- Capability

Everything in OEP must ultimately be expressible through these primitives.

No additional primitive types shall be introduced without explicit architectural approval.

---

## Studios

Studios are workflow applications.

Studios are **not** industries.

Studios represent professional activities.

Current Studio family:

- Installation Studio
- Service Studio
- Maintenance Studio
- Engineering Studio
- Inspection Studio
- Operations Studio
- Training Studio
- Administration Studio

Industries are delivered as packages.

---

## Packages

Packages extend the platform.

Examples include:

- Automotive
- Marine
- Aviation
- HVAC
- Industrial Automation
- Medical
- Robotics

Packages contain engineering knowledge.

Studios provide workflows for using that knowledge.

---

# Architecture Freeze

The following architectural decisions are frozen.

Do not redesign them.

Do not replace them.

Do not propose alternatives during implementation.

If a conflict arises, implement within these constraints and document the issue for review.

Frozen decisions include:

- Repository-first architecture
- Engineering Objects as the source of truth
- Studios organized by workflow
- Industries implemented as packages
- Public SDK only
- Open standards
- Commercial implementations
- Flutter user interface
- C++ runtime
- Public C API
- Cross-platform support
- Offline-first architecture

---

# Technology Stack

## Runtime

**Language**

C++23

**Responsibilities**

- Runtime
- Repository
- Filesystem
- Search
- Transactions
- Validation
- Synchronization

---

## User Interface

**Framework**

Flutter

**Responsibilities**

- Rendering
- Navigation
- Docking
- Panels
- Dialogs
- Themes
- User interaction

---

## Build System

CMake

---

## Public Interface

Public C API

Every SDK wraps the C API.

Applications consume SDKs.

No Studio shall communicate directly with Runtime internals.

---

# Layer Responsibilities

Operating System

↓

Filesystem

↓

Repository

↓

Runtime

↓

Public API

↓

SDK

↓

Flutter

↓

Studios

Each layer communicates only with adjacent layers.

No shortcuts.

---

# Development Philosophy

Build vertically.

Complete thin slices.

Avoid partially implementing many unrelated systems.

Every Sprint should leave the project more usable than before.

Every development session should produce a measurable improvement.

---

# UI Development — Live Hot Reload Requirement

UI development is an interactive visual process. When working on Flutter/OEP UI, the actual running OEP application must remain available for continuous visual inspection while implementation is in progress.

Before substantial UI changes begin, establish a dedicated Windows development window running the actual OEP Flutter application with hot reload enabled.

The hot-reload application window must remain open while Claude is performing UI implementation. Do not close the running application after an edit merely to rebuild it from scratch. Use hot reload continuously for iterative UI changes and only restart the application when technically necessary.

The required iteration loop is:

```text
EDIT UI CODE
    ↓
HOT RELOAD
    ↓
OBSERVE ACTUAL OEP WINDOW
    ↓
COMPARE AGAINST APPROVED DESIGN
    ↓
ADJUST
    ↓
HOT RELOAD AGAIN
```

Claude must use the running application as a visual feedback mechanism rather than relying only on source inspection or build success.

During UI work, inspect the live application for layout geometry, panel proportions, spacing, typography, colors, surfaces, active states, navigation behavior, clipping, overflow, embedded engineering surfaces, and overall visual hierarchy.

If the hot-reload application is not already running when a UI task begins, establish the appropriate Windows Flutter hot-reload session before proceeding with visual implementation whenever the local development environment permits it.

For UI work, a successful build alone is not sufficient evidence of completion. The actual running application must be inspected, and the final screen must also be validated at the required 1920×1080 Windows desktop target.

---

# Placeholder Philosophy

Working placeholders are encouraged.

A clickable placeholder is better than an undocumented feature.

However:

- Placeholders must accurately represent the final architecture.
- Temporary implementations must never violate architectural boundaries.

---

# Design Philosophy

Professional.

Minimal.

Information dense.

Predictable.

Fast.

Consistent.

The interface should resemble professional engineering software rather than consumer applications.

Navigation should become muscle memory.

---

# Coding Philosophy

Code should be:

- Simple
- Readable
- Maintainable
- Extensible

Avoid clever implementations.

Favor clarity over novelty.

Every implementation should be understandable by another engineer years later.

---

# Dependencies

Every dependency increases long-term maintenance cost.

Before introducing any dependency ask:

- Does the platform genuinely benefit?
- Can the same result be achieved using existing platform capabilities?
- Would this dependency still be appropriate ten years from now?

If the answer is uncertain, do not introduce the dependency.

---

# AI Responsibilities

AI assists implementation.

AI does not redefine architecture.

AI does not introduce major technologies without approval.

AI should:

- Read repository documentation
- Understand project status
- Implement only the requested task
- Preserve architectural boundaries
- Leave extension points
- Keep the project compiling
- Document important implementation decisions

---

# Development Workflow

1. Read CLAUDE.md
2. Read PROJECT_MEMORY.md
3. Read PROJECT_STATUS.md
4. Read CURRENT_SPRINT.md
5. Read TASK.md
6. Inspect existing implementation
7. For UI work, establish and keep the Windows Flutter hot-reload application window open
8. Implement only the requested work
9. Use hot reload continuously while iterating on UI
10. Run tests where applicable
11. Leave the project cleaner than it was found

---

# Things Never To Do

Never redesign the platform.

Never rename major architectural concepts.

Never move core folders without approval.

Never bypass the SDK.

Never create hidden APIs.

Never introduce unnecessary frameworks.

Never duplicate Engineering Object data.

Never implement future features that were not requested.

Never break a working build to begin another feature.

---

# Required Standards

Every implementation must comply with the current ratified OEP Standards.

At minimum:

- DESIGN_SYSTEM.md
- REPOSITORY_STANDARD.md
- PERFORMANCE_STANDARD.md
- DOCUMENTATION_STANDARD.md

These standards are considered part of the project constitution.

---

# Definition of Done

A task is complete only when:

- The project builds successfully.
- Acceptance criteria are satisfied.
- Architecture remains intact.
- Documentation is updated when required.
- Extension points exist.
- No unnecessary TODOs remain.
- The repository is cleaner than before the work began.

For UI work, completion additionally requires inspection of the actual running application through the hot-reload workflow and final visual validation at the required desktop target.

---

# The Standard

Every line of code should move OEP closer to becoming the definitive platform for preserving, organizing, validating, and applying engineering knowledge.

If a decision improves long-term maintainability, scalability, clarity, or usability, it is likely the correct decision.

When in doubt, choose the solution that best preserves the architecture and serves future engineers.

Remember:

**We are not building software.**

**We are building the infrastructure that engineering knowledge will stand upon.**