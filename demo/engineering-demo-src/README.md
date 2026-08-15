# Engineering Demo Package

A minimal, real `.oep` package demonstrating the OEP Package Format (PKG-001) and Package Manifest (PKG-002) end to end, built with the `oep-package` CLI (`@oep-exchange/package-cli`).

- **Package ID:** `com.oep.demo.engineering-showcase`
- **Publisher:** OEP Demo Publisher (`demo-publisher`)
- **Version:** 1.0.0

## Contents

| Path | Purpose |
| --- | --- |
| `manifest/package.json` | The PKG-002 manifest — package identity, publisher, classification, and (empty, since none exist yet) license/dependency/signature blocks. |
| `package.info` | Human-readable package summary (PKG-001 §6 "Package Metadata"). |
| `fragment/objects/` | Two sample Engineering Objects — a GL1200 ignition wiring harness `Component` and the `Diagram` documenting it. |
| `fragment/relationships/` | One sample Relationship (`Documents`) connecting the two objects above. |
| `assets/images/cover.svg` | The Marketplace cover image. |
| `assets/documents/getting-started.md` | Sample documentation. |
| `licenses/LICENSE.md` | This package's license text. |
| `signatures/` | Empty — this package is unsigned (no signing tool exists in this codebase yet). |

See `assets/documents/getting-started.md` for how this package was built.
