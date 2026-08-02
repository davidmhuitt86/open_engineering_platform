# OEP Menu System Architecture

Document ID:
OIP-MENU-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the menu architecture for the OEP Instruments platform.

Menus organize engineering functionality that is not required during continuous operation.

Menus shall remain predictable, concise, and consistent throughout every instrument.

---

# 2. Philosophy

Menus are organizational tools.

They are not workspaces.

Frequently used engineering operations belong on instrument controls or toolbars.

Menus expose configuration, maintenance, and infrequently used functionality.

---

# 3. Objectives

The menu architecture shall be:

Consistent

Minimal

Predictable

Context Aware

Responsive

Accessible

Platform Independent

---

# 4. Menu Hierarchy

The platform supports:

Application Menu

Workspace Menu

Instrument Menu

Context Menu

Overflow Menu

Recent Items Menu

Developer Menu (Internal Builds Only)

Future menu types

---

# 5. Application Menu

The Application Menu contains global platform functionality.

Examples:

Home

Hosts

Sessions

Instrument Library

Settings

Updates

Help

About

Exit

Application menus shall remain identical across every instrument.

---

# 6. Workspace Menu

Workspace menus contain operations relevant to the active workspace.

Examples:

Export

Import

History

Bookmarks

Diagnostics

Reports

Workspace Layout

Workspace menus shall never expose engineering calculations.

---

# 7. Instrument Menu

Instrument menus contain operations unique to an instrument.

Examples:

Calibration

Measurement Preferences

Display Configuration

Audio Settings

Probe Configuration

Recording Options

Instrument Information

Firmware Information

---

# 8. Context Menu

Context menus appear only when an object is selected.

Examples:

Measurement

Bookmark

Probe

Engineering Object

History Entry

Timeline Event

Context menus shall contain only actions applicable to the selected object.

---

# 9. Overflow Menu

Overflow menus contain secondary functions.

Examples:

Advanced Settings

Maintenance

Export

Diagnostics

Debug Information

Developer Options (Internal Builds)

Frequently used commands shall never reside exclusively in the overflow menu.

---

# 10. Recent Items Menu

Maintain quick access to:

Recent Sessions

Recent Hosts

Recent Projects

Recent Instruments

Recent Measurements

Recent Reports

Recent items shall be ordered chronologically.

---

# 11. Menu Organization

Menus shall group commands logically.

Typical grouping:

Session

Measurement

Display

Configuration

Reports

Maintenance

Help

Grouping shall remain consistent throughout the platform.

---

# 12. Command Presentation

Each menu command shall provide:

Label

Optional Icon

Optional Shortcut

Enabled State

Disabled State

Busy State

Optional Description

Labels shall use standard engineering terminology.

---

# 13. Command States

Commands may exist in:

Available

Unavailable

Busy

Disabled

Checked

Unchecked

Expanded

Collapsed

State changes shall be immediately visible.

---

# 14. Submenus

Submenus shall be used sparingly.

Maximum recommended nesting depth:

Three levels

Deep navigation structures are prohibited.

---

# 15. Searchable Menus

Menus containing large collections shall support search.

Examples:

Sessions

Projects

Reports

Bookmarks

Hosts

Search shall filter without changing menu organization.

---

# 16. Keyboard Support

Menus shall support:

Keyboard Navigation

Accelerator Keys

Shortcuts

Escape

Arrow Navigation

Enter

Platform-specific shortcuts may exist while preserving consistent behavior.

---

# 17. Touch Support

Menus shall support:

Touch

Stylus

External Mouse

Trackpad

Large touch targets shall be maintained.

---

# 18. Accessibility

Menus shall support:

Screen Readers

Large Text

High Contrast

Keyboard Navigation

Voice Access

Accessible Focus Indicators

All menu functionality shall remain accessible.

---

# 19. Platform Consistency

Menu organization shall remain consistent across:

Android

Windows

Linux

Future iOS

Dedicated Hardware

Platform conventions shall not alter engineering workflow.

---

# 20. Future Expansion

Future instruments may introduce additional menu groups.

Existing menu organization shall remain stable.

New menu groups shall integrate without restructuring existing menus.

---

# 21. Performance

Menus shall:

Open immediately

Remain responsive

Avoid unnecessary animations

Preserve focus

Never interrupt engineering measurements

---

# 22. User Experience

The engineer shall always know:

Where a command is located

Why it appears

When it is available

What it affects

Menu organization shall minimize cognitive effort.

---

# 23. Core Principles

1.

Menus organize engineering functionality.

2.

Frequently used operations belong on controls, not menus.

3.

Menu organization remains consistent across the platform.

4.

Context determines available commands.

5.

Deep menu hierarchies are prohibited.

6.

Professional engineering workflow is the design reference.

7.

Menus support engineering rather than replace it.

8.

Every menu belongs to one unified OEP interaction architecture.

---

End of Document