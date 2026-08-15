# SDD-029

# Engineering Extension Manifest

Status: Frozen

Version: 1.0

---

# Purpose

Defines how Engineering Engine extensions register with the platform.

Extensions add capability.

Extensions never modify Core.

---

# Extension Manifest

Every extension defines:

Identifier

Name

Version

Author

Description

Dependencies

Minimum Engine Version

License

---

# Optional Registrations

Extensions may register:

Symbol Libraries

Validators

Simulation Engines

Importers

Exporters

Renderers

AI Prompt Packs

Templates

Training Assets

---

# Categories

Automotive

Industrial

Marine

Rail

Aviation

Hydraulic

Pneumatic

Electrical

General

---

# Dependencies

Extensions may depend upon:

Core

Other Extensions

Marketplace Packages

---

# Versioning

Semantic Versioning.

Major

Minor

Patch

---

# Compatibility

Extensions declare:

Minimum Engine Version

Maximum Tested Version

---

# Security

Extensions execute through public Engineering Engine interfaces only.

No direct Foundation access.

No direct Studio access.

---

# Distribution

Extensions may originate from:

Marketplace

Enterprise

Developer

Local

---

# Architecture Rules

Extensions never modify Core.

Extensions register through Engine.

Extensions remain independently installable.

Core shall function without any extension.