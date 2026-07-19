# EXC-005
# Package Entitlements & Licensing Specification

**Specification ID:** EXC-005

**Title:** Package Entitlements & Licensing Specification

**Status:** Draft 1.0

**Authority:** Open Engineering Platform Specification

**Depends On:**

- EXC-001 Open Engineering Exchange Architecture
- EXC-002 Publisher Model
- EXC-003 Publication Workflow
- EXC-004 Engineering Discovery & Search
- PKG-001 through PKG-008

---

# 1. Purpose

This specification defines how the Engineering Exchange determines whether a user or organization is entitled to acquire, install, update, and use engineering packages.

The licensing system governs rights.

The commerce system governs payment.

These responsibilities are intentionally separated.

---

# 2. Design Goals

The entitlement system shall be:

- Publisher controlled
- Platform independent
- Offline capable
- Enterprise ready
- Auditable
- Extensible

Entitlements describe permissions.

They do not describe payment methods.

---

# 3. Entitlement Model

An entitlement grants specific rights to a package.

Examples include:

Download

Install

Activate

Update

Use

Transfer

Offline Use

Enterprise Deployment

Educational Access

Support

Every entitlement has a defined scope.

---

# 4. License Models

The Exchange supports multiple licensing models.

Examples:

Open Source

Free

Commercial

Academic

Student

Enterprise

Government

OEM

Subscription

Trial

Evaluation

Custom

Future models may be introduced without changing package specifications.

---

# 5. Entitlement Scope

Entitlements may apply to:

Individual User

Organization

Department

Enterprise

Educational Institution

Government Agency

Hardware Device

Named Project

The scope is defined by the Publisher.

---

# 6. License Duration

Licenses may be:

Perpetual

Subscription

Time Limited

Evaluation

Academic Term

Project Duration

Hardware Lifetime

Future duration models may be added.

---

# 7. Offline Rights

Publishers may grant offline usage rights.

Examples:

Unlimited Offline

30-Day Validation

90-Day Validation

Enterprise Offline

Permanent Offline

Offline rights are part of the entitlement.

---

# 8. Academic Licensing

The Exchange supports academic programs.

Examples:

Student Licenses

Faculty Licenses

Institution Licenses

Research Licenses

Laboratory Licenses

Educational licenses may include reduced pricing, expanded offline rights, or institution-managed deployments.

---

# 9. OEM Licensing

Publishers may bundle packages with:

Vehicles

Equipment

Controllers

Diagnostic Tools

Engineering Instruments

Hardware activation methods are defined separately.

---

# 10. Enterprise Licensing

Enterprise entitlements may include:

Organization-wide deployment

Department licenses

Floating licenses

Named-user licenses

Private Exchange distribution

Offline repositories

Enterprise policy enforcement

---

# 11. Package Updates

An entitlement may include:

Major Updates

Minor Updates

Security Updates

Long-Term Support

Extended Support

Update rights are independent of installation rights.

---

# 12. License Transfer

Publishers may allow:

No Transfer

One-Time Transfer

Unlimited Transfer

Organization Transfer

Asset Transfer

Transfer policies are publisher-defined.

---

# 13. Entitlement Verification

Verification may occur:

At acquisition

At installation

At activation

During updates

During periodic validation

Offline verification shall be supported when permitted by the entitlement.

---

# 14. Repository Behavior

A package already installed in a repository shall not become unusable solely because communication with the Exchange is unavailable.

Repository functionality shall respect the granted entitlement and offline rights.

---

# 15. Privacy

Entitlement validation shall minimize the collection of personal information.

The Exchange shall collect only the information necessary to administer licenses and fulfill publisher requirements.

---

# 16. Audit

The Exchange records:

Entitlement Creation

Activation

Renewal

Transfer

Expiration

Revocation

Enterprise Assignment

Audit records shall be retained according to platform policy.

---

# 17. Future Extensions

Future specifications may introduce:

Usage-based licensing

Consumption credits

Floating engineering seats

Hardware trust modules

Regional licensing

Government procurement programs

Marketplace subscriptions

without changing the entitlement model.

---

# 18. Conformance

An implementation claiming compliance with EXC-005 shall:

- Support multiple licensing models.
- Separate entitlements from commerce.
- Preserve entitlement history.
- Support offline rights where granted.
- Support organization-based licensing.
- Maintain auditable entitlement records.