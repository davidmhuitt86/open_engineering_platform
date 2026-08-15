# SDD-018

# Engineering Knowledge Lifecycle and Provenance

Version: 1.0

Status: Draft

---

# Purpose

Engineering knowledge is never static.

As products evolve, engineering knowledge evolves with them.

This document defines how Engineering Knowledge is created, reviewed, revised, superseded, archived, and traced throughout its lifetime.

The repository shall preserve engineering history rather than overwrite it.

---

# Core Philosophy

Engineering knowledge is a living asset.

Every Engineering Object possesses a lifecycle.

Every change shall remain traceable.

Nothing of engineering significance is ever silently lost.

---

# Knowledge States

Every Engineering Object exists in one of the following lifecycle states.

Draft

↓

Curated

↓

Verified

↓

Approved

↓

Published

↓

Superseded

↓

Archived

The lifecycle state is independent of the object type.

---

# Draft

Created during an active Knowledge Curation Session.

Not yet committed.

Visible only within the session.

---

# Curated

Accepted by an engineer.

Committed to the repository.

May still require technical verification.

---

# Verified

Confirmed against trusted engineering evidence.

Verification may include:

* Physical inspection
* Measurement
* Manufacturer documentation
* Engineering review
* Laboratory testing

Verification records become part of repository history.

---

# Approved

Accepted as trusted engineering knowledge.

May be referenced by any repository object.

---

# Published

Available for general engineering use.

Published knowledge is considered repository truth.

---

# Superseded

New engineering knowledge replaces an existing object.

The original object remains preserved.

Relationships shall indicate:

Supersedes

Superseded By

Reason

Effective Date

---

# Archived

Engineering knowledge no longer actively applies.

Archive does not imply deletion.

Archived knowledge remains searchable.

---

# Provenance

Every Engineering Object shall permanently record:

Original Source

Knowledge Curation Session

Reviewer

Review Date

Approval Date

Supporting Evidence

Confidence

Revision History

Repository Version

No provenance information shall be discarded.

Evidence Objects participate in provenance.

Every Engineering Object shall be traceable to one or more Evidence Objects.

Evidence Objects preserve the engineer's interpretation of source material.

Original source documents remain immutable.

---

# Revision History

Objects are revised.

They are not replaced.

Each revision records:

Revision Number

Author

Date

Reason

Evidence

Affected Relationships

The repository shall always answer:

"What changed?"

---

# Engineering Decisions

Repository decisions shall themselves become knowledge.

Examples:

Merged Duplicate

Rejected Proposal

Specification Corrected

Component Renamed

Procedure Updated

Every decision records:

Who

When

Why

Evidence

---

# Evidence Chain

Every Engineering Object shall maintain an evidence chain.

Example:

Timing Cover Torque

↓

Factory Service Manual

↓

Page 216

↓

Image 7

↓

Knowledge Curation Session 184

↓

Verified by Measurement

↓

Approved

↓

Referenced by Procedure

The evidence chain shall be viewable from Studio.

---

# Trust Levels

Repository knowledge shall expose trust levels.

Examples:

Manufacturer Verified

Engineer Verified

Community Verified

AI Suggested

Imported

Experimental

Trust is descriptive.

It never replaces engineering judgment.

---

# Conflict Resolution

Conflicting engineering knowledge shall coexist.

Example:

Factory Specification

↓

80 ft-lb

Aftermarket Bulletin

↓

82 ft-lb

The repository records both.

Relationships describe:

Conflicts With

Supersedes

Alternative

Applies To

The engineer decides which knowledge applies.

---

# Knowledge Evolution

Repositories are expected to improve over time.

Metrics may include:

Average Confidence

Verification Coverage

Duplicate Rate

Unverified Objects

Evidence Coverage

Relationship Density

These metrics describe repository maturity.

---

# Long-Term Goal

An engineer shall be able to inspect any Engineering Object and understand not only what is known, but:

* Why it is believed
* Where it originated
* Who reviewed it
* How it changed
* What evidence supports it
* What conflicting knowledge exists
* When it became repository truth

Engineering knowledge shall be explainable, auditable, and continuously improvable.
