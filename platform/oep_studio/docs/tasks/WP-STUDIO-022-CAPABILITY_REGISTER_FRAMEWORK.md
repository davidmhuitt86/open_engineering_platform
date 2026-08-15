# WP-STUDIO-022
## Studio Capability Metadata Framework

**Repository**

projects/platform/oep_studio

**Documentation**

Save As:

projects/platform/oep_studio/docs/tasks/WP-STUDIO-022 Studio Capability Metadata Framework.md

---

# Objective

Extend the Studio Registry created in WP-STUDIO-021 so that each Studio advertises the engineering capabilities it provides.

This work package expands the Studio Registry into the authoritative metadata source for Platform services.

No separate Capability Registry shall be created.

The Studio Registry remains the single source of truth.

---

# Background

WP-STUDIO-021 introduced a centralized Studio Registry responsible for:

- Studio registration
- Navigation
- Routing
- Search provider registration
- Settings provider registration

The next step is to enrich each StudioDescriptor with structured metadata describing the engineering capabilities exposed by that Studio.

This metadata will become the foundation for future Platform services including:

- Command Palette
- Workflow Engine
- AI orchestration
- Capability discovery
- Documentation
- Marketplace integration

---

# Architectural Principles

The Platform discovers Studios.

Studios advertise capabilities.

Platform services consume capability metadata.

No Platform service shall maintain its own list of capabilities.

The Studio Registry remains the authoritative composition root.

---

# Scope

This work package SHALL:

• Extend StudioDescriptor

• Create immutable CapabilityDescriptor objects

• Associate capabilities with their owning Studio

• Provide lookup APIs

• Validate metadata consistency

This work package SHALL NOT:

• Execute capabilities

• Create an Event Bus

• Implement workflows

• Implement plugins

• Implement dynamic loading

• Implement AI orchestration

---

# Architecture

Current

Studio Registry

↓

Studios

Future

Studio Registry

↓

StudioDescriptor

↓

CapabilityDescriptor[]

↓

Platform Services

Future Platform services discover capabilities by querying the Studio Registry.

---

# Deliverables

## Phase 1

Design CapabilityDescriptor.

Minimum fields:

Capability ID

Display Name

Description

Category

Version

Enabled

Visible

Experimental

Keywords

---

## Phase 2

Extend StudioDescriptor.

Each StudioDescriptor owns:

Capabilities

Command metadata (placeholder)

Help metadata (placeholder)

Dependencies (placeholder)

Future extensions

Only Capabilities are implemented.

Remaining fields are structural placeholders.

---

## Phase 3

Register Capabilities

Knowledge Studio

Create Knowledge Object

Edit Knowledge Object

Browse Knowledge

Search Knowledge

Diagram Studio

Create Diagram

Edit Diagram

Validate Diagram

Inspect Diagram

Engineering Acquisition Studio

Import Sources

Acquire Evidence

OCR Documents

Manage Sources

Metadata Extraction

Verification

Artifact Management

Vault Management

---

## Phase 4

Registry Services

Implement:

Lookup Studio

Lookup Capability

Capabilities by Studio

Capabilities by Category

Capability Exists

Enumerate Capabilities

Validation

---

## Phase 5

Validation

Verify:

Every capability belongs to one Studio.

Duplicate IDs rejected.

Deterministic ordering.

No orphan capabilities.

Consistent metadata.

---

# Data Model

StudioDescriptor

├── Identity

├── Route

├── Icon

├── Settings Provider

├── Search Provider

└── Capabilities

CapabilityDescriptor

├── ID

├── Name

├── Description

├── Category

├── Version

├── Enabled

├── Visible

└── Keywords

---

# Out of Scope

Do NOT implement:

Command execution

Event Bus

Workflow Engine

Notifications

Review Pipeline

Plugins

Dynamic discovery

AI execution

Those systems will consume this metadata in later work packages.

---

# Definition of Done

The Platform can answer:

"What capabilities exist?"

"Which Studio owns OCR?"

"What engineering functions does Diagram Studio provide?"

"What acquisition functions are available?"

without hard-coded switch statements or duplicate metadata.

The Studio Registry remains the only source of truth.

---

# Future Consumers

WP-STUDIO-023

Platform Command Framework

Consumes:

Capability metadata

Studio metadata

WP-STUDIO-024

Platform Event Bus

Consumes:

Capability metadata

WP-STUDIO-025

Workflow Engine

Consumes:

Capability metadata

WP-STUDIO-026

AI Orchestration

Consumes:

Capability metadata

No future Platform service should define capability metadata independently.

---

# Success Criteria

✓ Studio Registry remains authoritative.

✓ No duplicate metadata.

✓ Capabilities owned by Studios.

✓ Fully backwards compatible.

✓ Existing Studio behavior unchanged.

✓ Foundation unaffected.

✓ No Platform redesign.

✓ Ready for Platform-wide Command Framework.