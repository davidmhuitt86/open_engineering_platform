# CLI

Status: Foundation (v0.1.0)

Purpose: The `oep` executable — the primary developer interface for Foundation, per OEP-SPEC-012-CLI_COMMAND_FRAMEWORK. Every command that touches a repository goes through `FoundationRuntime`; the CLI never constructs Repository/Search/Validation/Package services directly.

## Architecture

- `include/oep/cli/` — public command interfaces (`Command`, `CommandRegistry`)
- `src/commands/` — individual command implementations
- `src/generator/` — Foundation Generator (repository scaffolding used by `init`)
- `src/foundation_version.hpp` — the single `kFoundationVersion` constant shared by `version`, the generator, and every Runtime-backed command
- `src/main.cpp` — thin entry point: registers commands and dispatches

Command logic is built as a static library, `oep_cli_core` (see `CMakeLists.txt`), which the `oep` executable links against. This lets `tests/cli` unit-test commands directly, without spawning the built executable as a subprocess.

## Commands

- `oep --help` / `oep -h` — display available commands (Name/Syntax/Description for each)
- `oep version` — display the CLI version
- `oep init <repository-name>` — generate a Standard Repository per OEP-SPEC-002-FOUNDATION_REPOSITORY
- `oep open <repository>` — open a repository through the Foundation Runtime
- `oep validate [repository]` — run Repository Validation and report health
- `oep packages [repository]` — list discovered packages and their state
- `oep status [repository]` — show Runtime state, current repository, repository ID, and loaded package count
- `oep object create|list|show|delete` — create, list, show, and delete Engineering Objects (`--repository <path>` optional, defaults to the current working directory)
- `oep relationship create|list|show|delete` — create, list, show, and delete Relationships (`--repository <path>` optional, defaults to the current working directory)
- `oep search [objects|relationships] <query>` — search Engineering Objects and/or Relationships, with `--type`/`--author`/`--tag` filters applied after the Search Engine runs
- `oep graph neighbors|traverse|path` — explore Engineering Objects through their Relationships (BFS/DFS traversal, path existence)
- `oep export <output-file>` — export the repository to a single deterministic archive (`--include-packages` optional)
- `oep import <archive-file>` — reconstruct a repository from an archive (`--destination`/`--overwrite` optional)
- `oep template create|list|instantiate` — capture, list, and instantiate reusable Repository Templates (`--templates-dir` optional, defaults to the current working directory)
- `oep batch create|delete|validate <input-file>` — execute or validate a batch of object/relationship operations from a JSON file (`--repository` optional, defaults to the current working directory)
- `oep package install <archive.oep>` — install a valid `.oep` package into the repository: verify its trust (WP-REP-004; rejected outright if `Tampered`/`InvalidSignature`/`UnknownPublisher`/`ExpiredCertificate`/`RevokedCertificate`), then extract its Repository Fragment, register its Engineering Objects and Relationships, update the Search/Graph indexes, and record the install in the Repository Registry (`--repository` optional, defaults to the current working directory). Atomic since WP-REP-003 — a failed install rolls back completely and nothing is journaled if trust verification itself rejects the package.
- `oep package uninstall <package-id>` — remove an installed package (WP-REP-005): delete every Engineering Object and Relationship it contributed, then remove its Repository Registry record and update the Search/Graph indexes. Atomic — a failed uninstall rolls back completely and the package remains installed. Does not touch the source `.oep` archive.
- `oep package list` — list every package recorded in the Repository Registry (ID, version, title, publisher, runtime state, contribution counts, install time)
- `oep package info <package-id>` — the full Repository Registry record: manifest metadata, publisher, engineering domains, runtime state, installation path, and SHA-256 package hash (WP-REP-002)
- `oep package contents <package-id>` — the Engineering Objects and Relationships the package installed, with their live names/types loaded from the repository
- `oep package verify <package-id>` — verify every recorded contribution still exists and the source archive (if still present) still matches its recorded hash; exits nonzero on a failed verification
- `oep package locate <entity-id>` — which installed package contributed a given Engineering Object or Relationship
- `oep package search <query>` — search installed packages by ID, title, summary, category, version, publisher, engineering domain, or installed-object name
  (all `package` subcommands take `--repository <path>`, defaulting to the current working directory; `install`/`uninstall` are atomic since WP-REP-003/WP-REP-005 — a failure rolls back completely)
- `oep transaction list` — every journaled Repository Transaction (WP-REP-003): id, state (Committed/RolledBack/Failed), description, operation count, open time
- `oep transaction show <transaction-id>` — one journaled transaction in full, including each operation's target and previous/new state
- `oep trust trust <publisher-id> --key <hex> [--name <name>] [--expires <utc>] [--issuer <name>]` — trust a publisher's Ed25519 public key (WP-REP-004); the fingerprint is always computed locally, never taken from input
- `oep trust list` — every certificate in this repository's Trust Store, trusted and revoked alike
- `oep trust revoke <publisher-id>` — revoke a publisher's certificate (the record is kept, marked revoked; does not uninstall anything already installed from that publisher)
- `oep trust policy [show|require|allow-unsigned]` — view or change whether this repository's `oep package install` rejects unsigned packages (default: allowed)

See [platform/runtime/CLI_USAGE.md](../runtime/CLI_USAGE.md) for build instructions, example sessions, and troubleshooting.

New commands are added by implementing `oep::cli::Command` (overriding `usage()` if the command takes arguments) and registering an instance in `main.cpp`. No other part of the CLI needs to change.
