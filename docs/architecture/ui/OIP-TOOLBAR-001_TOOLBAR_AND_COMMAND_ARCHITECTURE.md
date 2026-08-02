# OEP Toolbar & Command Architecture

Document ID:
OIP-TOOLBAR-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the toolbar architecture for the OEP Instruments platform.

Toolbars provide immediate access to an instrument's most frequently used engineering functions.

Toolbars shall maximize efficiency while minimizing visual clutter.

---

# 2. Philosophy

Professional engineering equipment exposes only the controls required for the current task.

Toolbars shall prioritize engineering workflow over feature visibility.

Every command placed on a toolbar shall justify its presence through frequent operational use.

---

# 3. Objectives

The toolbar architecture shall be:

Consistent

Minimal

Predictable

Task-Oriented

Context Aware

Responsive

Platform Independent

---

# 4. Toolbar Hierarchy

The platform supports:

Application Toolbar

Workspace Toolbar

Instrument Toolbar

Context Toolbar

Selection Toolbar

Playback Toolbar

Floating Tool Palette

Future toolbars

Each toolbar has a clearly defined responsibility.

---

# 5. Application Toolbar

The Application Toolbar contains global commands.

Examples:

Home

Hosts

Sessions

Instrument Switcher

Notifications

Settings

Help

About

Application commands shall remain identical across every instrument.

---

# 6. Workspace Toolbar

Workspace toolbars expose commands related to the active workspace.

Examples:

Measurement

Diagnostics

History

Playback

Calibration

Configuration

Export

Workspace commands shall never alter instrument-specific behavior.

---

# 7. Instrument Toolbar

Each instrument provides its own primary toolbar.

Examples:

Hold

Auto Range

Manual Range

Relative

Min/Max

Peak

Record

Stop

Instrument commands shall remain visible during normal operation.

---

# 8. Context Toolbar

Context toolbars appear only when relevant.

Examples:

Probe Selected

Measurement Selected

History Entry Selected

Bookmark Selected

Engineering Object Selected

Context toolbars shall automatically disappear when no longer applicable.

---

# 9. Selection Toolbar

Selection toolbars expose operations applicable to the current selection.

Examples:

Bookmark

Export

Rename

Annotate

Share

Selection toolbars shall never replace primary engineering controls.

---

# 10. Playback Toolbar

Playback controls include:

Play

Pause

Stop

Step Forward

Step Back

Jump

Timeline

Playback Speed

Playback controls shall remain grouped.

---

# 11. Command Organization

Toolbar commands shall be organized by frequency.

Highest frequency commands shall appear closest to the engineer's natural interaction point.

Rarely used commands shall reside within menus.

---

# 12. Icons

Every toolbar command shall provide:

Icon

Accessible Label

Tooltip

Optional Keyboard Shortcut

Optional Gesture

Icons shall follow the Iconography Architecture.

---

# 13. Labels

Commands shall use concise engineering terminology.

Examples:

HOLD

AUTO

REL

MIN/MAX

REC

PLAY

STOP

Labels shall remain consistent across all instruments.

---

# 14. Overflow

Overflow menus shall contain:

Rarely used commands

Configuration

Advanced options

Maintenance functions

Overflow menus shall never contain frequently used engineering operations.

---

# 15. Command States

Commands may exist in:

Enabled

Disabled

Busy

Active

Inactive

Unavailable

Current state shall always be visually apparent.

---

# 16. Customization

Users may customize:

Toolbar order

Visible commands

Hidden commands

Button size

Label visibility

Icon size

Customization shall not alter engineering behavior.

---

# 17. Responsiveness

Toolbars shall adapt to:

Phone

Tablet

Landscape

Portrait

Foldable Devices

Desktop

Overflow shall preserve functionality.

---

# 18. Accessibility

Support:

Keyboard Navigation

Screen Readers

Large Touch Targets

Stylus

External Mouse

High Contrast

Every toolbar command shall remain accessible.

---

# 19. Platform Consistency

Toolbar behavior shall remain consistent across:

Android

Windows

Linux

Future iOS

Dedicated Hardware

Users shall not relearn toolbar operation.

---

# 20. Future Expansion

Future instruments may introduce additional toolbars.

New toolbars shall inherit this architecture.

No redesign shall be required.

---

# 21. Core Principles

1.

Toolbars expose frequently used engineering commands.

2.

Context determines command visibility.

3.

Rare commands belong in menus.

4.

Icons support engineering terminology.

5.

Customization affects presentation only.

6.

Toolbar layout remains predictable.

7.

Professional engineering workflow is the design reference.

8.

Every toolbar belongs to one unified command architecture.

---

End of Document