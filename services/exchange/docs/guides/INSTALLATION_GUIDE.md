# Installation Guide

How an OEP Repository installs a published package from the Engineering Exchange (TASK-EXC-0008). This covers requesting an installation and checking its status — it does not cover authentication, licensing/entitlements, dependency resolution, digital signature verification, or automatic updates, all of which are explicitly out of scope for this task (WP-EXC-008.md §2).

WP-EXC-010 adds the first real caller of this API from a Studio context: OEP Studio's Exchange workspace calls exactly the two endpoints below (no new ones) to install a package into whichever Repository Studio has open, then calls the Repository's own `refreshRepository()` to reflect the change — see `docs/guides/STUDIO_INTEGRATION_GUIDE.md` "Repository Integration."

## What "installation" means here

Installing a package (WP-EXC-008.md §5) is: resolve the requested Package version, download its artifact, hand it to the OEP Repository through the Repository's own public interface, and record the outcome. The Exchange never reaches into the Repository directly — every call to it goes through a `RepositoryClient` abstraction (`packages/installer`), so the Exchange has no dependency on Repository internals (WP-EXC-008.md §7).

**No real OEP Repository exists yet anywhere in the platform.** Until one does, `apps/exchange-api` talks to a `StubRepositoryClient` by default — a deterministic stand-in that reports success. This lets the whole install flow (validation, artifact resolution, status recording, the REST API) work end to end today; swapping in the real `HttpRepositoryClient` later requires no change to this API's behavior or contract.

## Requesting an installation

`POST /api/v1/packages/{id}/install`

```json
{ "version": "1.0.0" }
```

`version` is optional — omit it (or send an empty body) to install the Package's current version. A successful request returns `201` with the resulting Installation, whether the Repository accepted or rejected it:

```json
{
  "id": "c4b1...",
  "packageId": "com.divad.honda.gl1200.electrical",
  "version": "1.0.0",
  "status": "completed",
  "repositoryPackageId": "repo-abc123",
  "errorMessage": null,
  "requestedAt": "2026-07-19T12:00:00.000Z",
  "completedAt": "2026-07-19T12:00:01.000Z"
}
```

`status` is one of:

| Status      | Meaning                                                                                                                                   |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `pending`   | Never observed in a response — every request runs to completion synchronously; a persisted `pending` row would only be visible mid-crash. |
| `completed` | The Repository accepted the package; `repositoryPackageId` is populated.                                                                  |
| `failed`    | The Repository rejected the install (or could not be reached); `errorMessage` explains why.                                               |

A `failed` status is **not** an HTTP error — the Exchange's own request succeeded (Package validated, artifact located, Repository contacted); the Repository's own decision is data in the response body, the same way a completed-but-unsuccessful job execution is reported elsewhere on this platform.

## Checking installation status

`GET /api/v1/installations/{installationId}`

Returns the same shape as the `POST` response — the persisted record of that one installation attempt, for later lookup (e.g. by an operator investigating a report of a failed install).

## Validation

Before contacting the Repository, each request is checked (WP-EXC-008.md §6):

1. **Package exists** — `404` if the id is unknown.
2. **Requested version exists** — `404` for an unknown version string; the current-version installs `404` if the Package has no version yet.
3. **Package status permits installation** — a `suspended` Package returns `403`; `draft`, `published`, and `deprecated` Packages may still be installed.
4. **Artifact exists** — `404` if the resolved version has no stored file (should not happen for a version created via the Upload Pipeline, but guarded against regardless).
5. **Repository response** — validated by `InstallationService`, which records `completed`/`failed` accordingly rather than propagating a raw Repository error.

## Errors

Same shared envelope as every other Exchange endpoint:

```json
{ "error": { "code": "...", "message": "...", "details": { ... } } }
```

| Situation                                             | HTTP status | `error.code`       |
| ----------------------------------------------------- | ----------- | ------------------ |
| Malformed package/installation id, blank version      | 400         | `VALIDATION_ERROR` |
| Package suspended                                     | 403         | `FORBIDDEN`        |
| Package, version, artifact, or installation not found | 404         | `NOT_FOUND`        |

The full request/response schema is also available live at `/documentation`.
