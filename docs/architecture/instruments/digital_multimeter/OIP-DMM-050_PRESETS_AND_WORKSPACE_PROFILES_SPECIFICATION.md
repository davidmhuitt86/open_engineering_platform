# OEP Digital Multimeter Presets & Workspace Profiles Specification

**Document ID:** OIP-DMM-050
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Presets and Workspace Profiles architecture for the OEP Digital Multimeter.

The subsystem enables engineers, organizations, and educational institutions to save, restore, share, and standardize complete instrument configurations for specific engineering tasks. Presets improve workflow efficiency while Workspace Profiles provide a comprehensive operating environment that includes instrument configuration, user interface preferences, probe assignments, and Engineering Session defaults.

---

# 2. Scope

This specification applies to:

- Android
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware
- Engineering Sessions
- User Profiles
- Organization Profiles

---

# 3. Design Objectives

The subsystem shall:

- Reduce repetitive instrument configuration.
- Support personal and organizational workflows.
- Preserve deterministic instrument behavior.
- Support profile sharing.
- Remain extensible for future OEP instruments.

---

# 4. Definitions

**Preset**

A Preset stores a specific instrument configuration.

Examples include:

- DC Voltage Diagnostics
- Continuity Testing
- Automotive Charging System
- Sensor Verification

A preset configures the instrument only.

---

**Workspace Profile**

A Workspace Profile defines the complete working environment.

A profile may include:

- Instrument Presets
- Display Theme
- Display Profile
- Probe Configuration
- Accessibility Settings
- Recording Preferences
- Publishing Preferences
- Engineering Session Defaults
- User Interface Layout

Workspace Profiles may contain one or more Presets.

---

# 5. Preset Categories

The architecture shall support:

- Factory Presets
- User Presets
- Organization Presets
- Educational Presets
- Project Presets
- Temporary Session Presets

Each category shall maintain independent ownership and permissions.

---

# 6. Preset Contents

A Preset may contain:

- Measurement Mode
- Auto/Manual Range
- Relative Mode State
- Hold Configuration
- Recording Configuration
- Preferred Probe Assignment
- Display Units
- Measurement Filters
- Audible Settings

Presets shall not contain live engineering measurements.

---

# 7. Workspace Profile Contents

Workspace Profiles may include:

- Active Theme
- Display Layout
- Accessibility Options
- Instrument Presets
- Connected Smart Probes
- Preferred Current Clamp
- Temperature Probe Configuration
- Recording Destination
- Export Preferences
- Publishing Preferences

Profiles shall not include immutable Engineering Session data.

---

# 8. Import & Export

Presets and Workspace Profiles shall support:

- Import
- Export
- Backup
- Restore
- Organization Distribution

Exported profiles shall include schema version information.

---

# 9. Versioning

Every Preset and Workspace Profile shall include:

- Identifier
- Schema Version
- Creator
- Creation Timestamp
- Last Modified Timestamp
- Compatibility Information

Older versions shall be migrated when supported.

---

# 10. Integration

The subsystem integrates with:

- Measurement Engine
- Settings
- Probe Manager
- Engineering Sessions
- Recording & Playback
- Publishing
- Engineering Repository

Loading a Preset shall not interrupt active measurements unless required by the selected configuration.

---

# 11. Acceptance Criteria

- Presets load deterministically.
- Workspace Profiles restore complete operating environments.
- Import/export preserves configuration.
- Version migration is supported.
- Engineering Session integrity is maintained.
- Future OEP instruments can adopt this architecture without redesign.

---

End of Document
