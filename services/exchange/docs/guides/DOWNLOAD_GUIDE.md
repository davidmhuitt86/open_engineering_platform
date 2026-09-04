# Download Guide

How to download a published package artifact from the Engineering Exchange (TASK-EXC-0007). This covers retrieving the raw `.oep` archive a prior upload (`docs/guides/UPLOAD_GUIDE.md`) attached to a Package — it does not cover authentication, licensing/entitlements, or installation, all of which are explicitly out of scope for this task (WP-EXC-007.md §2).

## Downloading

Two endpoints, following the flow "receive request → validate package → locate artifact → record download → return package artifact" (WP-EXC-007.md §5):

| Endpoint                                                | Downloads                                |
| ------------------------------------------------------- | ---------------------------------------- |
| `GET /api/v1/packages/{id}/download`                    | The Package's current (latest) version.  |
| `GET /api/v1/packages/{id}/versions/{version}/download` | One specific version, by version string. |

```sh
curl -o package.oep http://localhost:3000/api/v1/packages/<package-id>/download
curl -o package.oep http://localhost:3000/api/v1/packages/<package-id>/versions/1.0.0/download
```

A successful download returns `200` with the raw `.oep` archive as the response body (`Content-Type` matches the stored artifact's mime type, `application/vnd.oep.package` by default) plus metadata headers:

| Header                | Meaning                                                |
| --------------------- | ------------------------------------------------------ |
| `Content-Disposition` | `attachment; filename="<original file name>"`          |
| `Content-Length`      | Artifact size in bytes.                                |
| `X-Checksum-Sha256`   | The artifact's SHA-256 hash.                           |
| `X-Package-Id`        | The Package's `packageId` (reverse-domain identifier). |
| `X-Package-Version`   | The version actually delivered.                        |

## Validation

Before returning an artifact, each request is checked (WP-EXC-007.md §6):

1. **Package exists** — `404` if the id is unknown.
2. **Requested version exists** — for the version-specific endpoint, `404` if that version was never uploaded; the latest-version endpoint instead `404`s if the Package has no version yet.
3. **Artifact exists** — `404` if the resolved version has no stored file (should not happen for a version created via the Upload Pipeline, but guarded against regardless).
4. **Package status permits download** — a `suspended` Package returns `403`; `draft`, `published`, and `deprecated` Packages may still be downloaded (deprecation is a signal to prefer a newer version, not a block).

## Download recording

Every successful download is recorded (WP-EXC-007.md §8) in the `downloads` table (built in TASK-EXC-0002): the Package version delivered, a timestamp, and client information (IP address and `User-Agent`) when available. This is the same table `EXC-002`'s Publisher Analytics and `EXC-004`'s package listing "Download Count" already anticipate — an append-only event log, never edited or soft-deleted, only ever aggregated.

## Errors

Same shared envelope as every other Exchange endpoint:

```json
{ "error": { "code": "...", "message": "...", "details": { ... } } }
```

| Situation                               | HTTP status | `error.code`       |
| --------------------------------------- | ----------- | ------------------ |
| Malformed package id or missing version | 400         | `VALIDATION_ERROR` |
| Package suspended                       | 403         | `FORBIDDEN`        |
| Package, version, or artifact not found | 404         | `NOT_FOUND`        |

The full request/response schema (aside from the binary body) is also available live at `/documentation`.
