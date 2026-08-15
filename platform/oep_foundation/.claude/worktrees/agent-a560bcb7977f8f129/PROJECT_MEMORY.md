# PROJECT_MEMORY
# PROJECT_MEMORY.md
## Open Engineering Platform (OEP)
### Permanent Project Memory

Version: 1.0
Status: Ratified

---

# Purpose

This document is the permanent institutional memory of the Open Engineering Platform.

Its purpose is to record architectural, organizational, and product decisions that have been formally ratified.

This document contains facts.

It does not contain brainstorming, proposals, feature requests, or discussion.

If a decision is not recorded here, it should not be assumed to be permanently accepted.

---

# Governance

This document may only be modified when a decision has been formally ratified.

Historical decisions are never deleted.

If a decision changes, a new decision supersedes the previous one while preserving project history.

---

# Core Mission

The Open Engineering Platform exists to preserve, organize, validate, distribute, and expand engineering knowledge.

Engineering knowledge should remain available long after its original author has retired, changed careers, or passed away.

---

# Product Vision

OEP is an engineering platform.

It is not a single application.

Studios, Packages, Plugins, SDKs, Exchange, and future products are built upon the platform.

---

# Product Family

The current Studio family consists of:

- Installation Studio
- Service Studio
- Maintenance Studio
- Engineering Studio
- Inspection Studio
- Operations Studio
- Training Studio
- Administration Studio

Studios represent professional workflows.

Studios do not represent industries.

---

# Packages

Industries are implemented as Packages.

Examples include:

- Automotive
- Aviation
- Marine
- HVAC
- Industrial Automation
- Medical
- Robotics

Packages provide engineering knowledge.

Studios provide engineering workflows.

---

# Repository Philosophy

The Repository is the foundation of the platform.

Engineering Objects are the source of truth.

Generated files are views of Engineering Objects.

Applications consume Repository data.

Applications do not own engineering information.

---

# Five Primitive Rule

The platform is permanently based upon five primitive concepts.

- Engineering Object
- Relationship
- Operation
- Event
- Capability

Every engineering concept within OEP must ultimately be expressible through these primitives.

---

# Architecture

Architecture Status

FROZEN

Major architectural changes require explicit approval from the Founder and Chief Systems Architect.

---

# Technology Decisions

Runtime

- C++23

User Interface

- Flutter

Public Interface

- C API

SDKs

- Wrap the Public API

Build System

- CMake

Deployment

- Native builds

Supported Platforms

- Windows
- Linux
- Android
- macOS
- iOS

Virtualization is not required.

---

# Repository First

The Repository precedes every Studio.

No Studio shall bypass the Repository.

Every workflow ultimately produces Repository content.

---

# Development Philosophy

Architecture before implementation.

Specifications before code.

Repository before applications.

Working software over unnecessary documentation.

Complete vertical slices before horizontal expansion.

---

# Documentation Hierarchy

CLAUDE.md

Defines how contributors work.

PROJECT_MEMORY.md

Defines what has already been decided.

Standards

Define engineering policy.

Specifications

Define architecture.

Sprint Documents

Define current implementation work.

---

# AI Development Philosophy

Artificial Intelligence is used as an engineering accelerator.

AI shall assist implementation.

AI shall not redefine platform architecture.

AI shall preserve architectural consistency.

---

# Product Direction

The first commercial implementation of OEP is Installation Studio.

Installation Studio targets independent installation professionals.

The first commercial workflow is:

Vehicle Selection

↓

Product Selection

↓

Guided Installation

↓

Interactive Verification

↓

Programming

↓

Functional Testing

↓

Installation Certificate

↓

Repository Save

---

# Current Strategic Direction

The OEP CLI is the first executable produced by the platform.

The CLI is responsible for creating and managing OEP repositories.

The Foundation Generator is implemented inside the CLI.

The generator creates complete OEP repositories from official templates.

Future development begins from generated repositories rather than manually created structures.

---

# Ratified Standards

The following standards currently exist.

OEP Standard 001

Design Language Standard

OEP Standard 002

Repository Engineering Standard

OEP Standard 003

Performance Standard

OEP Standard 004

Documentation Standard

Future standards shall be numbered sequentially.

---

# Reserved Decisions

The following topics are intentionally deferred.

- Exchange licensing
- Authentication providers
- Cloud synchronization
- Marketplace governance
- Enterprise deployment
- Plugin security
- Distributed repositories
- Digital signatures
- Licensing infrastructure

These topics remain open until formally ratified.

---

# Founding Principle

Engineering knowledge is one of humanity's most valuable resources.

OEP exists to ensure that engineering knowledge can be preserved, improved, shared, and reused by future generations rather than being lost with time.