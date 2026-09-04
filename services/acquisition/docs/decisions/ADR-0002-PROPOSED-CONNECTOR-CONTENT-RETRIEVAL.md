# ADR-0002 (Proposed)

# Connector Content Retrieval Capability

Status: Proposed -- blocking WORK_PACKAGE-006, pending ratification in `oep_architecture`

Date: 2026-07-17

Authored by: Claude (Sonnet 5), during WORK_PACKAGE-006 implementation

---

# Context

WORK_PACKAGE-006 ("Engineering Downloader") requires:

> The downloader shall obtain engineering content exclusively through the
> Source Connector Framework.
>
> No connector-specific logic shall exist inside the downloader.

and, in its Validation Rules:

> Connector shall exist.
>
> Connector shall be healthy.

This presumes the Source Connector Framework (WORK_PACKAGE-005) already
exposes a way to retrieve engineering content through `IConnector`.

It does not. `IConnector` (`include/oep/acquisition/connectors/connector.hpp`)
was implemented per WORK_PACKAGE-005's own explicit constraint --
"No implementation shall perform actual network communication" -- and its
Connector Interface section named exactly five capabilities: Connect,
Disconnect, Health Check, Get Capabilities, Validate Configuration. None
of these retrieve content. There is no `fetch`, `download`, `read`, or
similar method anywhere on the interface.

This is not an unspecified implementation detail (like Job Priority's
value range in WORK_PACKAGE-003, or how many steps `execute()` advances
in WORK_PACKAGE-004) -- it is a capability WORK_PACKAGE-006 requires that
the already-ratified, already-implemented `IConnector` contract has no
method for. Implementing WORK_PACKAGE-006 as written requires extending
that contract.

---

# Why This Needs an ADR, Not an Implementation Decision

Per `ARCHITECTURE_AMENDMENT_POLICY.md`, this is an **Architectural Gap**
("Implementation reveals a capability that cannot be implemented using
the approved architecture... A required subsystem has no architectural
owner").

Extending `IConnector` is a decision with consequences beyond this work
package: every future connector type (HTTP, FTP, browser automation --
none of which exist yet; WORK_PACKAGE-005 shipped only `StubConnector`)
will need to implement whatever shape this method takes. Choosing that
shape unilaterally during WORK_PACKAGE-006 -- synchronous vs. streaming,
whether it writes to a destination path or returns an in-memory buffer,
how progress reporting integrates, what error taxonomy it uses, whether
cancellation is cooperative -- would be inventing architecture rather
than filling a gap, which `ARCHITECTURE_AMENDMENT_POLICY.md` and this
work package's own governing instructions direct against.

Per the user's explicit instruction for this work package ("If
implementation exposes an architectural ambiguity: Stop implementation.
Document the issue. Recommend an ADR if appropriate. Do not invent
architecture."), implementation of WORK_PACKAGE-006 has been paused
pending this ADR's ratification in `oep_architecture`. No Downloader
code (model, repository, service, REST API, migration, or tests) has
been written.

---

# Proposed Decision (for `oep_architecture` to ratify)

Extend `IConnector` with a content-retrieval capability, for example:

```cpp
struct FetchRequest {
  std::string source_uri;
  std::filesystem::path destination_path;
};

struct FetchResult {
  std::filesystem::path stored_path;
  std::string mime_type;
  std::uint64_t file_size_bytes;
};

using ProgressCallback = std::function<void(std::uint64_t bytes_transferred, std::uint64_t total_bytes)>;

class IConnector {
  // ... existing methods unchanged ...

  [[nodiscard]] virtual FetchResult fetch(const FetchRequest& request,
                                           const ProgressCallback& on_progress) = 0;
};
```

This is offered as a starting point for discussion, not a final design --
open questions the ratifying ADR should resolve include:

- Synchronous (blocking the calling thread) vs. an async/future-based
  return, given WORK_PACKAGE-006 also excludes "Background scheduling"
  and "Parallel downloads" from its own scope.
- Whether cancellation is cooperative (the callback returns a
  stop-signal) or requires a separate `cancel()`-style method.
- Error reporting: exceptions vs. a `std::expected`/result type, and
  whether `capability::kDownloadFiles` should be a precondition the
  Registry or Downloader checks before calling `fetch` at all.
- Whether `StubConnector` should gain a fake/deterministic `fetch`
  implementation (writing a small canned file) so downloader tests can
  run without a real connector type existing yet, mirroring how
  `StubConnector`'s `health_check` is already configurable via
  `ConnectorConfig::settings`.

---

# Consequences of Not Deciding

WORK_PACKAGE-006 cannot proceed until this is resolved. Everything else
in its dependency chain (WORK_PACKAGE-001 through 005) remains complete,
committed, and unaffected.

---

# Related Documents

- `oep_acquisition/docs/tasks/WORK_PACKAGE_006.md`
- `oep_acquisition/include/oep/acquisition/connectors/connector.hpp`
- `oep_architecture/development/guides/ARCHITECTURE_AMENDMENT_POLICY.md`
- `oep_architecture/development/ADRs/ADR-0007-PLATFORM_API_STRATEGY.md` (the
  prior instance of this same pattern, for WORK_PACKAGE-001)

---

End of Document
