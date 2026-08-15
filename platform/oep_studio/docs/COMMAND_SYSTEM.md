# SDD-010

# Command System

Version: 1.0

Status: Draft

---

# Purpose

The Command System provides a consistent method of executing actions throughout OEP Studio.

Every user action is represented by a command.

---

# Sources

Commands may originate from:

* Toolbar
* Context Menu
* Keyboard Shortcut
* Command Palette

Future versions may introduce scripting.

---

# Behavior

Commands shall be:

* Discoverable
* Repeatable
* Context-aware

Unavailable commands shall be disabled rather than hidden.

---

# Command Palette

Studio shall provide a searchable command palette.

Users shall execute commands without navigating menus.

---

# Keyboard Shortcuts

Every major command shall support keyboard shortcuts.

Shortcut assignments shall be configurable in a future release.

---

# Engineering Principle

Users should think about engineering tasks rather than interface locations.
