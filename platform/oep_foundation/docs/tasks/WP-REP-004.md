# WP-REP-004
# Foundation Repository Runtime
# Vertical Slice 4 – Trust & Signing

**Repository:**
oep_foundation

**Status:**
Planned

**Priority:**
Critical

---

# 1. Objective

Implement the Repository Trust & Signing subsystem.

This work package establishes the Foundation Repository as the authority responsible for verifying the authenticity and integrity of installed engineering packages.

Every installed package shall pass through the Repository Trust pipeline before installation is permitted.

---

# 2. Scope

Included

- Package hashing
- Signature verification
- Trust Store
- Public key management
- Trust evaluation
- Installation verification
- Runtime APIs
- Public C API
- CLI support
- Studio verification

Excluded

- Dependency resolution
- Update
- Uninstall
- Merge
- Networking
- Certificate authorities
- Online revocation

---

# 3. Trust Architecture

Implement the Repository Trust subsystem.

Responsibilities:

- Verify package integrity.
- Verify package signatures.
- Evaluate publisher trust.
- Produce Repository Trust Results.
- Prevent installation of invalid packages.

Trust decisions shall occur before Repository Transactions begin.

---

# 4. Trust Store

Implement a persistent Trust Store.

Maintain:

- Trusted publishers
- Trusted public keys
- Key fingerprints
- Key creation date
- Key expiration (when present)
- Trust status
- Revocation status (local only)

The Trust Store shall be independent of the Repository Registry.

---

# 5. Package Verification

Verify:

- SHA-256 digest
- BLAKE3 digest (when present)
- Ed25519 signature
- Manifest integrity
- Repository Fragment integrity

Packages failing verification shall not be installed.

---

# 6. Trust Evaluation

Produce one of the following results:

- Trusted
- Verified
- Untrusted
- Unknown Publisher
- Invalid Signature
- Corrupted Package
- Unsupported Signature
- Verification Failed

Repository Runtime shall expose the reason for every failure.

---

# 7. Runtime Integration

Modify Package Installer:

Verify Package

↓

Evaluate Trust

↓

Begin Transaction

↓

Install

↓

Commit

Trust verification shall occur before any Repository mutation.

---

# 8. Runtime API

Extend Foundation Runtime.

Implement:

- VerifyPackage()
- VerifySignature()
- EvaluateTrust()
- ImportTrustedKey()
- RemoveTrustedKey()
- ListTrustedKeys()

Maintain backward compatibility.

---

# 9. Public C API

Expose Trust functionality.

Preserve ABI compatibility.

---

# 10. CLI

Implement:

oep trust import

oep trust remove

oep trust list

oep package verify

oep package trust

Display:

Publisher

Signature

Fingerprint

Verification Result

Trust Status

---

# 11. Studio Verification

Expose Trust information through the Foundation Bridge.

Verify Studio can retrieve:

- Trust status
- Publisher
- Signature information
- Verification results

No new Studio UI is required.

---

# 12. Testing

Implement:

- Valid signature tests
- Invalid signature tests
- Corrupted package tests
- Unknown publisher tests
- Trust Store tests
- CLI tests
- Runtime API tests

Validate using:

engineering-demo.oep

Generate both signed and intentionally invalid test packages.

---

# 13. Documentation

Update:

Repository Runtime Guide

Trust Guide

CLI Guide

Foundation API Guide

Package Specification

Create:

Repository Trust Architecture

Trust Store Guide

Signing Guide

---

# 14. Deliverables

Repository Trust subsystem

Trust Store

Package verification

Runtime APIs

CLI support

Studio verification

Documentation

Validation report

---

# 15. Exit Criteria

✓ Trust Store implemented

✓ Package verification operational

✓ Signature verification operational

✓ Installation blocked for invalid packages

✓ Runtime APIs completed

✓ CLI commands completed

✓ Documentation completed

✓ All tests pass