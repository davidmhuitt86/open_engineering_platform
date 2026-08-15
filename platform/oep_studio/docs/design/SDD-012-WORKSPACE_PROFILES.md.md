# SDD-012

# Workspace Profiles

Version: 1.0

Status: Draft

---

# Purpose

Workspace Profiles define how OEP Studio presents itself to different users and workflows.

Profiles change the user experience only.

They do not change Foundation functionality, repository contents, permissions, or engineering capabilities.

Every profile operates on the same Foundation Runtime.

---

# Design Philosophy

OEP shall adapt to the engineer.

The engineer shall not be required to adapt to OEP.

Profiles simplify or expand the interface while preserving a consistent engineering model.

---

# Initial Profiles

Version 1 defines three built-in profiles.

* Guided
* Engineering
* Developer

Future versions may introduce additional profiles.

---

# Guided Profile

Purpose:

Provide a streamlined environment focused on completing engineering tasks.

Target users include:

* Students
* Technicians
* Occasional users
* Training environments

The Guided profile emphasizes workflows over engineering internals.

Visible workspaces:

* Dashboard
* Repository
* Wiring (when installed)
* Documentation
* Procedures
* Search
* Settings

Hidden by default:

* Relationship Explorer
* Graph
* Validation
* Package Manager
* Registry
* Diagnostics
* Developer Tools

The user shall never lose access to repository functionality.

Only interface complexity is reduced.

---

# Engineering Profile

Purpose:

Provide the complete engineering environment.

This is the default profile for first-time installations.

Visible workspaces:

* Dashboard
* Repository
* Objects
* Relationships
* Search
* Graph
* Validation
* Packages
* Settings

Future engineering workspaces shall appear automatically when installed.

---

# Developer Profile

Purpose:

Expose platform internals and development tools.

Target users include:

* Plugin developers
* Foundation developers
* SDK developers
* Advanced users

Additional workspaces may include:

* Diagnostics
* Runtime Monitor
* API Explorer
* Registry
* Package Development
* Performance Monitor
* Plugin Manager

Developer Profile shall expose additional diagnostic information while maintaining the same Foundation behavior.

---

# First Launch Experience

On first launch Studio shall present a profile selection screen.

Example:

Welcome to OEP Studio

How would you like to work?

○ Guided

○ Engineering (Recommended)

○ Developer

The selected profile becomes the default workspace profile.

Users may change profiles at any time.

---

# Profile Switching

Profiles shall be switchable without restarting Studio.

Changing profiles updates:

* Navigation
* Visible workspaces
* Toolbars
* Panels
* Menu items

Current repository state shall remain unchanged.

---

# Persistence

Studio shall remember:

* Last selected profile
* Workspace layout
* Panel visibility

These preferences shall be stored independently of the repository.

---

# Future Expansion

Future versions shall support user-defined profiles.

Users may:

* Create profiles
* Rename profiles
* Export profiles
* Import profiles
* Share profiles

A custom profile shall inherit from one of the built-in profiles.

---

# Security

Profiles are not security boundaries.

They provide interface customization only.

All authorization remains the responsibility of future authentication and permission systems.

---

# Engineering Principle

Every engineer works differently.

Workspace Profiles allow OEP Studio to present the same engineering platform through interfaces optimized for different workflows without fragmenting the underlying architecture.
