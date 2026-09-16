> **STATUS: SUPERSEDED — GLOBAL LANDING MODEL**
>
> This draft defined Dashboard as the engineer's automatic Studio landing page. The current OEP UX architecture replaces that global model with **Home** as the OEP landing surface. Studio-specific dashboard/overview views may still be used where they provide genuine workflow value.
>
> Current UX source of truth: `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`
>
# SDD-007

# Dashboard

Version: 1.0

Status: Draft — historical reference only

---

# Purpose

The Dashboard is the engineer's landing page.

It provides quick access to repositories and summarizes repository health.

---

# Initial Widgets

Version 1 shall include:

* Recent Repositories
* Create Repository
* Open Repository
* Repository Status
* Installed Packages
* Foundation Version

---

# Future Widgets

Future versions may include:

* Recent Activity
* AI Suggestions
* Team Notifications
* Registry Updates
* Favorites

---

# User Experience

The Dashboard shall open automatically when Studio starts.

If a repository is already open, the Dashboard shall display repository information.

---

# Engineering Principle

The Dashboard provides immediate awareness of engineering work without overwhelming the user.
