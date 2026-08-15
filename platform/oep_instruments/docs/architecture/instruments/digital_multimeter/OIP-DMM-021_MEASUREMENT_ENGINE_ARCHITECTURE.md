# OEP Digital Multimeter Measurement Engine Architecture

**Document ID:** OIP-DMM-021  
**Status:** Draft  
**Repository:** oep_instruments

---

# 1. Purpose

This document defines the Measurement Engine Architecture used by the OEP Digital Multimeter.

The Measurement Engine provides the common runtime responsible for requesting, validating, processing, formatting, and presenting engineering measurements. Individual measurement modes (Voltage, Current, Resistance, etc.) extend this architecture rather than implementing their own independent measurement pipelines.

---

# 2. Scope

This architecture applies to every measurement mode supported by the Digital Multimeter and every supported client platform.

It governs common behavior only. Mode-specific behavior is defined in the corresponding measurement specifications.

---

# 3. Design Objectives

The Measurement Engine shall:

- Provide deterministic measurement behavior.
- Remain independent of measurement type.
- Support simulated and physical measurement sources.
- Integrate with Engineering Sessions.
- Support recording and playback.
- Be extensible without architectural redesign.

---

# 4. Responsibilities

The Measurement Engine is responsible for:

- Measurement requests
- Measurement state management
- Probe validation
- Measurement formatting
- Unit selection
- Auto/Manual range management
- Measurement quality
- Recording integration
- Playback integration
- Error handling

Engineering calculations remain the responsibility of the Host.

---

# 5. Measurement Lifecycle

Every measurement follows the same lifecycle:

Requested

↓

Validated

↓

Acquired

↓

Processed

↓

Quality Evaluated

↓

Formatted

↓

Displayed

↓

Recorded (optional)

↓

Published

Each stage shall complete in order.

---

# 6. Measurement State Machine

Supported states:

- Idle
- Initializing
- Waiting
- Measuring
- Stable
- Hold
- Recording
- Playback
- Error

Only one primary state may exist at a time.

---

# 7. Auto Range Framework

Auto Range shall:

- Select the most appropriate engineering range.
- Prevent oscillation between adjacent ranges.
- Preserve display stability.
- Remain measurement-mode independent.

---

# 8. Manual Range Framework

Manual Range shall:

- Lock the selected range.
- Ignore automatic changes.
- Preserve the selected range until released by the operator.

---

# 9. Measurement Quality

Every measurement shall include quality metadata.

Examples:

- Stable
- Updating
- Simulated
- Estimated
- Invalid
- Unavailable

Quality metadata shall never alter the engineering value.

---

# 10. Formatting

The Measurement Engine formats values before presentation.

Formatting includes:

- Engineering prefixes
- Units
- Decimal precision
- Sign handling
- Over-range indication
- Under-range indication

Formatting shall be presentation-only.

---

# 11. Integration

The Measurement Engine integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

---

# 12. Error Handling

Examples:

- Invalid probe configuration
- Unsupported measurement mode
- Host disconnected
- Measurement unavailable
- Session unavailable

Errors shall transition the engine into a recoverable state whenever possible.

---

# 13. Acceptance Criteria

- Common behavior shared across all measurement modes.
- Deterministic state transitions.
- Consistent formatting.
- Platform-independent behavior.
- Complete Engineering Session integration.
- Extensible architecture.

---

End of Document
