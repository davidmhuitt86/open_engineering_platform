# OEP Home UX Specification

**Status:** Proposed
**Storage:** `docs/architecture/ux/OEP_HOME_UX_SPEC.md` (corrected AP-UX-002 C6 — this line previously named a hyphenated path that does not exist on disk)

## 1. Purpose

Define Home as the global OEP landing surface.

Home is not a directory of backend services and is not a mandatory dashboard.

## 2. Home Responsibilities

Home answers:

```text
What was I working on?
What can I open?
Which Studio should I use?
Does anything require attention?
```

## 3. Continue Working

The highest-priority region should surface active/recent work.

Example:

```text
CONTINUE WORK

Honda TRX300 Service Manual
Engineering Acquisition
Extracting Engineering Knowledge

[ Open → ]
```

The user should be able to resume without navigating through the Studio hierarchy.

## 4. Recent Work

Recent work may include:
- acquisitions
- diagrams
- knowledge projects
- repositories
- other meaningful work objects

Each entry should identify both the work object and its Studio.

## 5. Available Studios

Home should expose Studios as intentional destinations.

Example:

```text
Diagram Studio
Engineering Acquisition
Knowledge Studio
Engineering Exchange
Engineering Intelligence
Instruments
```

Internal capabilities such as Objects, Relationships, Graph, Validation, and Packages do not belong here.

## 6. System Status

A concise status region may expose important platform state.

It should not become a technical monitoring dashboard.

Prefer:

```text
Engineering Engine     Ready
Repository             Ready
Knowledge Runtime      Ready
Engineering Exchange   Not Connected
```

over a large collection of implementation diagnostics.

## 7. Continue Working Priority

If active work exists, Continue Working should visually outrank Studio discovery.

The user should be able to resume work in one action.

## 8. Empty State

If there is no recent work:

```text
WELCOME TO OEP

Choose a Studio to begin engineering work.

[ Diagram Studio ]
[ Engineering Acquisition ]
[ Knowledge Studio ]
```

Avoid empty-state panels that imply the system is broken.

## 9. Home and Open Tabs

Home does not close open Studio or workspace tabs.

Returning Home is navigation only.

## 10. Global Search

If global search is provided, it should be accessible from the shell without turning Search into another implementation-oriented Studio.

Search results should route the user directly into the relevant Studio/workspace context.
