# SDD-027

# Engineering Graph Object Model

Status: Frozen

Version: 1.0

---

# Purpose

This document defines the canonical runtime object model for the Engineering Graph.

The Engineering Graph represents engineering knowledge independently of any visual representation.

---

# Philosophy

Engineering knowledge exists independently of diagrams.

Diagrams visualize Engineering Graphs.

Repository objects persist Engineering Knowledge.

Engineering Nodes represent runtime Engineering Objects.

---

# Engineering Graph

An Engineering Graph consists of:

- Engineering Nodes
- Engineering Relationships
- Engineering Groups
- Metadata
- Evidence Links

---

# Engineering Node

Every Engineering Node shall contain:

- id
- category
- displayName
- symbolId
- repositoryObjectId
- metadata
- evidenceLinks
- properties
- ports

Optional:

- extensionData

---

# Engineering Relationship

Every Engineering Relationship shall contain:

- id
- relationshipType
- sourceNode
- targetNode
- repositoryRelationshipId
- metadata
- evidenceLinks

---

# Engineering Group

Groups organize Nodes.

Examples:

- Circuit
- Harness
- Assembly
- Subsystem
- Module

Groups contain references.

Groups never duplicate Nodes.

---

# Ports

Ports define valid connection locations.

Each Port contains:

- id
- name
- direction
- type
- metadata

---

# Evidence Links

Every Node and Relationship may reference evidence.

Evidence remains immutable.

---

# Runtime Metadata

Runtime metadata includes:

- selection
- visibility
- expanded
- highlighted

Runtime metadata shall never be persisted into Foundation.

---

# Repository Mapping

Engineering Nodes reference Foundation Objects.

Engineering Relationships reference Foundation Relationships.

Engineering Graphs never replace Foundation.

---

# Architecture Rules

1. Graph is canonical runtime.
2. Repository is canonical persistence.
3. Runtime metadata is transient.
4. Evidence remains immutable.
5. Nodes never own layout.