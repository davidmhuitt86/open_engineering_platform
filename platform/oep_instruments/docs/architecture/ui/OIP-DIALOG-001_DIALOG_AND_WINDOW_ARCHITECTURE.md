# OEP Dialog & Window Architecture

Document ID:
OIP-DIALOG-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the architecture governing dialogs, windows, overlays, sheets, and transient interface elements throughout the OEP Instruments platform.

Dialogs exist to support engineering workflows.

They shall never interrupt engineering work unnecessarily.

---

# 2. Philosophy

Professional engineering equipment rarely interrupts the operator.

Dialogs shall appear only when additional information or explicit user interaction is required.

Engineering measurements shall remain visible whenever practical.

Dialogs shall support engineering—not become the engineering workspace.

---

# 3. Objectives

Dialogs shall be:

Purpose Driven

Minimal

Predictable

Consistent

Responsive

Non-destructive

Accessible

Platform Independent

---

# 4. Dialog Categories

The platform supports:

Confirmation Dialogs

Configuration Dialogs

Selection Dialogs

Information Dialogs

Engineering Reports

Calibration Dialogs

Session Dialogs

Warning Dialogs

Critical Alert Dialogs

Help Dialogs

Future dialog types

---

# 5. Confirmation Dialogs

Confirmation dialogs shall be reserved for actions that permanently affect user data.

Examples:

Delete Session

Delete History

Factory Reset

Reset Calibration

Remove Host

Exit Without Saving

Routine engineering operations shall never require confirmation.

---

# 6. Configuration Dialogs

Configuration dialogs provide access to:

Instrument Settings

Measurement Options

Display Preferences

Audio

Haptics

Theme

Transport

Session Preferences

Configuration changes shall preview immediately where possible.

---

# 7. Selection Dialogs

Selection dialogs allow engineers to choose:

Hosts

Sessions

Projects

Measurements

Bookmarks

Probe Targets

Engineering Objects

Selection dialogs shall support searching and filtering.

---

# 8. Information Dialogs

Information dialogs display:

Instrument Details

Firmware

Version Information

Licensing

About

Runtime Information

Information dialogs shall be read-only.

---

# 9. Engineering Report Dialogs

Engineering reports may display:

Measurement History

Diagnostics

Validation Results

Recommendations

Fault Reports

Simulation Reports

Reports shall support export without modification.

---

# 10. Calibration Dialogs

Calibration dialogs shall guide users through structured workflows.

Characteristics:

Sequential

Clearly numbered

Recoverable

Interruptible

Progress visible

Calibration shall never occur accidentally.

---

# 11. Session Dialogs

Session dialogs manage:

Create Session

Resume Session

Archive Session

Rename Session

Share Session

Export Session

These dialogs shall preserve current engineering context.

---

# 12. Warning Dialogs

Warnings notify users of recoverable conditions.

Examples:

Probe Missing

Host Disconnected

Measurement Invalid

Simulation Paused

Low Battery

Warnings shall remain concise.

---

# 13. Critical Alert Dialogs

Critical dialogs shall appear only when immediate user attention is required.

Examples:

Session Lost

Authentication Failure

Transport Failure

Corrupted Session

Critical alerts shall clearly indicate required user action.

---

# 14. Window Behavior

Dialogs shall:

Open predictably

Remain centered

Scale appropriately

Dismiss cleanly

Restore focus

Window behavior shall remain consistent across every instrument.

---

# 15. Modal Behavior

Modal dialogs shall be rare.

They shall be used only when user action is required before engineering work may safely continue.

Most dialogs should remain modeless.

---

# 16. Non-Modal Panels

Examples:

Measurement History

Bookmarks

Diagnostics

Engineering Notes

These shall remain accessible while engineering work continues.

---

# 17. Overlay Windows

Temporary overlays include:

Connection Status

Measurement Captured

Recording Started

Bookmark Saved

Overlays shall automatically dismiss.

They shall never obscure primary measurements.

---

# 18. Progress Indicators

Long-running operations shall display progress.

Examples:

Connecting

Importing

Exporting

Synchronization

Recovery

Progress indicators shall remain informative without blocking unnecessarily.

---

# 19. Error Presentation

Errors shall:

Clearly describe the condition

Explain the consequence

Recommend corrective action

Avoid technical jargon where unnecessary

Never obscure engineering measurements longer than required.

---

# 20. Accessibility

Dialogs shall support:

Screen Readers

Keyboard Navigation

Large Text

High Contrast

External Keyboards

Stylus

All dialog functions shall remain fully accessible.

---

# 21. Platform Consistency

Dialog behavior shall remain consistent across:

Android

Windows

Linux

Future iOS

Dedicated Hardware

Users shall not relearn interaction patterns.

---

# 22. Future Expansion

Future instruments may define specialized dialogs.

Specialized dialogs shall inherit this architecture.

No redesign shall be required.

---

# 23. Core Principles

1.

Dialogs support engineering work.

2.

Dialogs never become engineering workspaces.

3.

Modal dialogs remain exceptional.

4.

Engineering measurements remain visible whenever practical.

5.

User interruption is minimized.

6.

Consistency builds confidence.

7.

Professional engineering equipment remains the design reference.

8.

Every dialog belongs to one unified OEP interaction system.

---

End of Document