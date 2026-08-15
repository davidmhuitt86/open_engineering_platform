# SDD-027A

# Engineering Graph Object Model Amendment

Status: Proposed

Version: 1.1

Amends:
SDD-027 Engineering Graph Object Model

---

# Purpose

Expand the Engineering Graph object model to support electrical reasoning, provenance, and future simulation without altering the core graph philosophy.

---

# Amendment 1

## Engineering Net

Introduce:

EngineeringNet

Purpose:

Represent electrical continuity independent of physical wiring.

A Net represents one electrically equivalent conductor.

Examples:

Battery Positive

Ignition Feed

Ground

CAN High

CAN Low

---

# Amendment 2

## Net Membership

Engineering Nodes

Ports

Wire Segments

Connectors

Relationships

may participate in one Engineering Net.

Physical topology and electrical topology remain separate concepts.

---

# Amendment 3

## Confidence

Every engineering object may expose:

confidence

Range:

0.0

through

1.0

Confidence represents certainty of engineering knowledge.

Sources include:

Manual Entry

OCR

Artificial Intelligence

Import

Reverse Engineering

Simulation

Knowledge Merge

Unknown

---

# Amendment 4

## Provenance

Every engineering object may expose:

source

method

timestamp

creator

revision

confidence

The graph shall preserve provenance throughout its lifecycle.

---

# Amendment 5

## Rule References

Engineering objects may reference:

Engineering Rules

Validation Rules

Simulation Rules

Drafting Rules

These references do not execute rules.

They establish relationships.

---

# Amendment 6

## Future Compatibility

The object model shall remain compatible with:

Marketplace Packages

Simulation

Distributed Repositories

Collaborative Editing

AI

Digital Twins