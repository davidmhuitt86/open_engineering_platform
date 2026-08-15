# SDD-008

# Repository Explorer

Version: 1.0

Status: Draft

---

# Purpose

The Repository Explorer provides the primary navigation of engineering content contained within an OEP Repository.

It serves a role similar to Solution Explorer in an IDE.

---

# Layout

The Repository Explorer shall appear as a collapsible panel.

The panel displays the repository hierarchy.

Example:

Repository

├── Components

├── Diagrams

├── Documents

├── Procedures

├── Images

├── Relationships

└── Packages

---

# Selection

Selecting an item updates the active Workspace.

Only one repository item is active at a time.

---

# Context Menu

Repository Explorer shall support:

* Open
* Rename
* Delete
* Properties
* Copy ID

Additional commands may be introduced later.

---

# Search

The Repository Explorer includes an incremental filter.

Filtering affects only visible items.

Repository data remains unchanged.

---

# Engineering Principle

The Repository Explorer provides structural navigation.

It is not a search engine.
