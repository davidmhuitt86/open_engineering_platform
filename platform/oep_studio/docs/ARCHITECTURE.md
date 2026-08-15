# SDD-001

# OEP Studio Architecture

Version: 1.0

Status: Draft

---

## Purpose

OEP Studio provides the graphical user interface for the Open Engineering Platform.

Studio shall contain no engineering business logic.

All engineering operations shall execute through OEP Foundation.

---

## Architecture

```text
Flutter UI

↓

Studio Services

↓

Foundation Runtime

↓

Foundation Services

↓

Repository
```

---

## Responsibilities

Studio owns:

* User Interface
* Navigation
* Windows
* Dialogs
* Themes
* Layout
* User Preferences

Foundation owns:

* Repository
* Runtime
* Search
* Validation
* Graph
* Packages
* Import
* Export

---

## Engineering Principle

Studio is a presentation layer.

Foundation is the engineering engine.

Studio shall never duplicate Foundation functionality.
