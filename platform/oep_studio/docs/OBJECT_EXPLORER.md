# SDD-009

# Object Explorer

Version: 1.0

Status: Draft

---

# Purpose

The Object Explorer displays Engineering Objects within the currently open Repository.

It provides browsing, inspection, and future editing capabilities.

---

# Display

Each object row displays:

* Icon
* Name
* Object Type
* Author
* Version

---

# Sorting

Version 1 supports:

* Name
* Type
* Author

Future versions may introduce custom sorting.

---

# Filtering

Version 1 supports:

* Object Type
* Author
* Tags

Filtering shall never modify repository contents.

---

# Selection

Selecting an object opens the corresponding Workspace.

---

# Engineering Principle

Object Explorer provides efficient discovery of engineering knowledge without exposing repository implementation details.
