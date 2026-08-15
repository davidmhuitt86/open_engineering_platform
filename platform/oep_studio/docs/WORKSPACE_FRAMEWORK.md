# SDD-004

# Workspace Framework

Version: 1.0

Status: Draft

---

# Purpose

The Workspace Framework defines how engineering content is presented within OEP Studio.

Every future Studio shall operate inside the Workspace Framework.

The Workspace provides consistency across all engineering disciplines while allowing each Studio to expose specialized tools.

---

# Workspace Layout

The application window consists of five major regions.

* Top Toolbar
* Navigation Rail
* Primary Workspace
* Property Inspector
* Status Bar

Future specifications may introduce additional dockable panels.

---

# Primary Workspace

The Primary Workspace is the central engineering surface.

Only one workspace is active at a time.

Examples include:

* Dashboard
* Repository Browser
* Object Explorer
* Relationship Explorer
* Search Results
* Graph View
* Diagram Editor
* Documentation Editor

---

# Workspace Lifecycle

Each workspace supports:

* Open
* Activate
* Deactivate
* Close
* Refresh

Workspaces shall preserve user state whenever practical.

---

# Workspace Communication

Workspaces shall communicate through Studio Services.

Workspaces shall never communicate directly with one another.

---

# Foundation Integration

Workspaces request engineering operations through the Foundation Bridge.

No workspace shall access Foundation directly.

---

# Engineering Principle

The Workspace is the engineer's desktop.

Every Studio shall feel like another tool operating within the same environment.
