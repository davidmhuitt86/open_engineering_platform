# Upload Guide

How to upload a `.oep` package archive to the Engineering Exchange (TASK-EXC-0005). This is how packages actually get their versions and files registered — `POST /api/v1/packages` (see `docs/guides/PACKAGE_CATALOG_GUIDE.md`) only creates the catalog _record_; uploading is what attaches a real, downloadable version to it.

## What happens when you upload

`POST /api/v1/packages/upload` runs the full pipeline (WP-EXC-005.md §5):

1. **Receive** the uploaded `.oep` file plus your Publisher id (and, optionally, a Category id).
2. **Validate** the request (file present, identifiers well-formed).
3. **Store** the raw archive (content-addressable, by its SHA-256 hash).
4. **Parse the manifest** — `manifest/package.json` is read out of the archive and validated against PKG-002's required fields.
5. **Extract metadata** — title, description, category, engineering domains, keywords, capabilities, license, dependencies, and build/repository statistics are all read from the manifest.
6. **Register the package** — if this is the first upload for this `packageId`, a new Package catalog entry is created; otherwise the existing one is reused.
7. **Register the version** — a new `PackageVersion` (and its `PackageFile`) is created, and the Package's "current version" is updated to point at it.
8. **Return the upload result.**

Digital signature verification and dependency resolution are **not** performed by this task (WP-EXC-005.md §2) — a manifest's `signatures` block is read but not checked.

## Making the request

`POST /api/v1/packages/upload` is a `multipart/form-data` request with:

| Field         | Required | Description                                               |
| ------------- | -------- | --------------------------------------------------------- |
| `file`        | yes      | The `.oep` package archive (a ZIP container, PKG-001 §5). |
| `publisherId` | yes      | The id of the Publisher performing the upload.            |
| `categoryId`  | no       | An existing Category id to file the package under.        |

```sh
curl -X POST http://localhost:3000/api/v1/packages/upload \
  -F "publisherId=<your-publisher-id>" \
  -F "file=@honda-gl1200-electrical-1.0.0.oep;type=application/vnd.oep.package"
```

A successful upload returns `201`:

```json
{
  "packageId": "3f1b2c4d-...",
  "packageVersionId": "9a7e0c11-...",
  "packageFileId": "5d2f88aa-...",
  "version": "1.0.0",
  "fileName": "honda-gl1200-electrical-1.0.0.oep",
  "sizeBytes": 48213,
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "uploadedAt": "2026-07-19T12:00:00.000Z"
}
```

## Package identity and namespace ownership

- The manifest's `packageId` (PKG-001/PKG-002's reverse-domain identifier) must fall under the uploading Publisher's namespace — e.g. a Publisher with namespace `com.divad` may only upload packages whose `packageId` is `com.divad` or starts with `com.divad.` (EXC-002 §5: "Package IDs shall reside within Publisher namespaces").
- If a `packageId` is already registered under a _different_ Publisher, the upload is rejected — package ownership doesn't transfer through re-upload.
- Uploading a new version of a `packageId` you already own simply adds the new version; it does not change the Package's existing `displayName`/`description`/`categoryId` — use `PUT /api/v1/packages/{id}` for that.
- Uploading the same `version` string twice for the same package is rejected.

## Errors

Same shared envelope as every other Exchange endpoint:

```json
{ "error": { "code": "...", "message": "...", "details": { ... } } }
```

| Situation                                                                                                                                                   | HTTP status | `error.code`       |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------------------ |
| No file, missing `publisherId`, malformed manifest/archive, `packageId` outside your namespace, duplicate version, nonexistent Publisher/Category reference | 400         | `VALIDATION_ERROR` |
| `packageId` already owned by a different Publisher                                                                                                          | 403         | `FORBIDDEN`        |

## Where uploaded files are stored

Uploaded archives are stored on local disk, content-addressable by SHA-256 hash, sharded by the hash's first two hex characters (`{root}/{ab}/{hash}.oep`) — the same convention `oep_acquisition`'s Reference Vault already uses. The root directory is `./storage/packages` by default, overridable via the `OEP_EXCHANGE_STORAGE_DIR` environment variable.
