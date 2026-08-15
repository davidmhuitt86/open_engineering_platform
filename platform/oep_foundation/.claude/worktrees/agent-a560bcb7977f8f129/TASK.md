# TASK
# TASK.md
## Open Engineering Platform (OEP)

Task ID: 000034 (WP-REP-004)

Status: Complete — awaiting user review/approval

---

# Current Task

Implement WP-REP-004 — Foundation Repository Runtime, Vertical Slice 4: the **Repository Trust & Signing Subsystem**, implementing PKG-005 (Package Trust & Digital Signature): offline Ed25519 signature verification, a per-repository Trust Store of locally trusted publisher certificates, and package trust verification integrated into the installation pipeline — running strictly before any Repository Transaction begins.

---

# Context

WP-REP-001 installed unsigned packages by design; WP-REP-002 added the Repository Registry; WP-REP-003 made installation atomic via the Repository Transaction Engine. WP-REP-004 closes the trust gap both explicitly documented: every package is now cryptographically verified before it can touch the repository. PKG-001 through PKG-006, OEP-ARCH-002, CLAUDE.md, and PROJECT_MEMORY/STATUS were read before implementation.

**Design decisions:**

- **Hand-rolled Ed25519 verification** (`platform/installer/ed25519.hpp/.cpp`), per this codebase's established no-third-party-dependency convention (hand-rolled SHA-256/JSON parser/UUID generation already exist). Verify-only, deliberately: Foundation never signs anything and holds no private key. Built on a new hand-rolled SHA-512 (`sha512.hpp/.cpp`, distinct from the existing SHA-256 used for package hashing — Ed25519/RFC 8032 requires SHA-512). Both were validated against their respective NIST/RFC published test vectors before anything was built on top of them.
- **Signing lives in `oep_exchange`**, not Foundation: `@oep-exchange/signing` was implemented for real (previously a TASK-EXC-0001 scaffold) using Node's built-in `node:crypto` — no new npm dependency either. The two Ed25519 implementations (C++ verifier, Node signer) are genuinely independent, cross-checked by installing a real signed archive end-to-end, not just unit-testing against shared fixtures.
- **Trust verification runs before any Repository Transaction begins** — the user's explicit, load-bearing requirement. `install_package` calls `verify_package_trust` immediately after confirming the package isn't already installed, strictly before `open_transaction_internal`. A trust-rejected install opens no transaction and writes no journal record — proven by a dedicated test.
- **Backward compatibility preserved by pure C API addition, not modification**: `oep_package_install_result_t` and `oep_package_details_t` (WP-REP-002) were left byte-for-byte unchanged; trust status is queried through a new function (`oep_package_get_trust_status`) and a new struct, following the same "never modify an existing struct" convention WP-REP-002/003 established. `OEP_API_VERSION` 7 → 8, `OEP_ABI_VERSION` unchanged at 1. Unsigned packages still install by default (`TrustStore` policy `require_signatures` defaults to `false`), preserving WP-REP-001–003's behavior exactly.

---

# Objectives

## Objective 1 — Repository Trust & Signing subsystem
Hand-rolled SHA-512 and Ed25519 verification (RFC 8032), tested against NIST/RFC vectors. `verify_package_trust` (`package_verifier.hpp/.cpp`) implements PKG-005 §11's pipeline: structure → content hashes (every archive entry outside `signatures/`, per §9/§10 — nothing in the payload exempt) → certificate → signature → `TrustState` (`Trusted`/`Unsigned`/`UnknownPublisher`/`ExpiredCertificate`/`RevokedCertificate`/`InvalidSignature`/`Tampered`).

## Objective 2 — Trust Store
`TrustStore` (`trust_store.hpp/.cpp`): locally trusted publisher certificates persisted under `<repository>/settings/trust/` (one JSON file per publisher, plus a policy file), entirely offline (PKG-005 §3) — no certificate authority, no online revocation feed. `add_certificate`/`get_certificate`/`list_certificates`/`revoke_certificate` (kept, marked revoked, per §12/§13's retained-history model) plus `get_policy`/`set_policy`.

## Objective 3 — Installation pipeline integration
`FoundationRuntime::install_package` verifies trust before opening any transaction. Rejection states abort the install with nothing extracted and nothing journaled. On success, `RepositoryRegistryEntry` gains `trust_status`/`trust_fingerprint`, and `RuntimeInstallResult` gains `trust_status`.

## Objective 4 — Foundation Runtime
Six new pass-through methods (`trust_add_certificate`/`trust_get_certificate`/`trust_list_certificates`/`trust_revoke_certificate`/`trust_get_policy`/`trust_set_policy`) plus a `trust_store()` accessor. These are local writes to `settings/trust/`, not Repository Transactions.

## Objective 5 — Public C API
`oep_trust_add_certificate`/`_get_certificate`/`_list_certificates`(+release)/`_revoke_certificate`/`_get_policy`/`_set_policy`, `oep_package_get_trust_status`, `oep_trust_state_to_string`, with new `oep_trust_state_t`/`oep_publisher_certificate_t`/`oep_certificate_list_t`/`oep_package_trust_status_t`. `OEP_API_VERSION` 8.

## Objective 6 — CLI
New `oep trust trust|list|revoke|policy` command. `oep package info` now shows Trust Status and fingerprint. `oep package install`'s stale "not transactional" note (already obsolete since WP-REP-003) removed.

## Objective 7 — Studio compatibility
Foundation Bridge FFI bindings for all seven new functions (`PublisherCertificate`/`PackageTrustStatus`/`TrustState` Dart models, seven `FoundationBridge` methods); `flutter analyze`/`flutter test` verified.

---

# Explicitly Out of Scope

Dependency resolution, update, uninstall, merge, networking, online trust services — per the user's exclusion list. Also explicitly deferred, named rather than silently absent: certificate authority chains and enterprise trust policies (PKG-005 §14), multiple signatures per package (§15), repository-wide re-audit/revalidation of already-installed packages (§16), and repair transactions for corrupted packages (§17) — all require capabilities (update, networking, or the merge engine) this Work Package excludes.

---

# Verification Record

**Build:** WSL Ubuntu CMake 3.28.3 / g++ 13.3.0 (no Windows-native C++ toolchain on this host — same environmental limitation as Tasks 000031–000033; MSVC not independently re-verified). Full build succeeded with no errors.

**A real, pre-existing bug was found and fixed in shared JSON infrastructure**: `platform/repository/json_value.cpp`'s `serialize()` never actually wrote `Bool`/`Number` values (a silent no-op, present since the JSON module was first written, undiscovered because nothing had ever serialized a boolean before `TrustStore`'s `revoked` field). Fixed (`as_bool()`/`as_number()` accessors added, `write_value` writes `true`/`false`/the numeric literal); caught immediately by the new `oep_trust_store_tests`' first run, before anything was built on top of it.

**A real bug was found and fixed in `@oep-exchange/signing`** (`oep_exchange`, not `oep_foundation`): its file-sort used `String.prototype.localeCompare`, which orders certain paths (e.g. `"LICENSE.md"` vs. `"licenses/LICENSE.md"`) differently than C++'s `std::string::operator<` — the exact order Foundation's verifier reconstructs its content-hash payload with. A genuinely signed `engineering-demo.oep` installed as `InvalidSignature` until this was found (during end-to-end validation, not unit testing) and fixed to sort byte-wise; a regression test now pins the correct order.

**Regression suite:** 38/38 CTest suites pass, including new `oep_sha512_tests`, `oep_ed25519_tests` (RFC 8032 §7.1 vectors plus tamper/malleability rejection cases), `oep_trust_store_tests`, `oep_package_verifier_tests` (trusted/unsigned/unknown-publisher/revoked/tampered/extra-entry/bad-signature/unsupported-algorithm), `oep_trust_integration_tests` (Runtime-level, including the "no transaction opened on trust rejection" proof), and `oep_trust_command_tests`; extended `oep_api_tests`.

**Signing package (`oep_exchange`):** `@oep-exchange/signing` — 12/12 vitest cases pass, including the byte-wise-ordering regression test above.

**End-to-end CLI validation:** a real Ed25519 key pair was generated (`oep-package keygen`), `engineering-demo.oep`'s source tree was actually signed (`oep-package sign`) and rebuilt (Stored compression, as prior work packages require), then installed against a fresh `oep init` repository: (1) install rejected as `UnknownPublisher` before the publisher was trusted, with an empty transaction journal proving trust ran first; (2) `oep trust trust` + reinstall succeeded, `oep package info` showing `Trust Status: Trusted` with the correct fingerprint, and exactly one Committed transaction; (3) a second repository with the publisher trusted-then-revoked rejected the same install as `RevokedCertificate`. All steps passed.

**Studio:** `flutter analyze` — 0 new issues (2 pre-existing unrelated lints); `flutter test` — all 460 tests passed (2 pre-existing skips).

---

# After Completion

Stop and await formal review/approval of WP-REP-004 before beginning WP-REP-005, per the user's explicit instruction.
