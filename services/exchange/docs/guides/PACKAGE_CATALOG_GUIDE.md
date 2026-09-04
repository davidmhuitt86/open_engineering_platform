# Package Catalog Guide

How to register and manage Packages in the Engineering Exchange's catalog (TASK-EXC-0004). This covers the Package Catalog only — actual package upload (submitting a real `.oep` file, manifest parsing, signature verification, metadata extraction) is a later task; this task's `POST /api/v1/packages` registers the catalog _record_ for a package, not a file.

## What a Package is

A Package is the Exchange's catalog record for one published engineering knowledge package — always owned by exactly one Publisher (see `docs/guides/PUBLISHER_GUIDE.md`). A Package's identity is separate from any particular version of it:

- **The Package** — its identity (`packageId`, the reverse-domain identifier packages are addressed by), its display name/description/category, and its status.
- **Package Versions** — individual published releases (`1.0.0`, `1.1.0`, ...), each with its own manifest. Registering versions isn't exposed through this task's REST API yet (see "Current Version" below); a `Package`'s `currentVersion` field simply reports whichever version is currently the package's latest, once one exists.

Authentication and authorization are out of scope for this task, same as the Publisher Registry — every endpoint below is currently unauthenticated.

## Registering a Package

`POST /api/v1/packages`

```json
{
  "packageId": "com.divad.honda.gl1200.electrical",
  "publisherId": "3f1b2c4d-...",
  "displayName": "Honda GL1200 Electrical",
  "description": "Wiring diagrams and electrical system reference for the 1985 Honda GL1200 Gold Wing.",
  "categoryId": "a92e7f10-..."
}
```

- `packageId` is the package's permanent, globally unique reverse-domain identifier (PKG-001/PKG-002), lowercase with no spaces (e.g. `com.yourcompany.product-name`). It never changes after registration.
- `publisherId` must be an existing, active Publisher's id (`GET /api/v1/publishers` to find one).
- `categoryId`, if provided, must be an existing category's id (`GET /api/v1/packages` doesn't currently expose a categories-listing endpoint — categories are seeded at the platform level; see `db/migrations/V2__seed_categories.sql` for the initial set).
- `packageId`, `publisherId`, and `displayName` are required. `description` and `categoryId` are optional.
- `displayName` must be unique among a given Publisher's packages (two different Publishers may each have a package with the same display name).

A successful registration returns `201` with the full Package record, `status: "draft"`, and `currentVersion: null`.

## Looking up Packages

- `GET /api/v1/packages` — every active Package, across every Publisher.
- `GET /api/v1/packages/{id}` — one Package by id (`404` if unknown or already deleted).

## Updating a Package

`PUT /api/v1/packages/{id}` accepts any subset of:

```json
{
  "displayName": "New Display Name",
  "description": "Updated description.",
  "categoryId": null,
  "status": "published"
}
```

`packageId` and `publisherId` cannot be changed — they're the Package's permanent identity and ownership. Setting `categoryId` to `null` clears the category.

### Status

A Package's `status` is one of `draft`, `published`, `deprecated`, `suspended`. Allowed transitions:

| From         | May move to               |
| ------------ | ------------------------- |
| `draft`      | `published`, `suspended`  |
| `published`  | `deprecated`, `suspended` |
| `suspended`  | `draft`, `published`      |
| `deprecated` | `suspended`               |

`deprecated` has no way back to `published` — once a Package is deprecated, superseding it means publishing a new Package, not resurrecting the old one.

## Deleting a Package

`DELETE /api/v1/packages/{id}` — soft-deletes the Package (it stops appearing in lookups and listings), consistent with the platform's history-preserving deletion convention.

## Errors

Same shared envelope as every other Exchange endpoint:

```json
{ "error": { "code": "...", "message": "...", "details": { ... } } }
```

| Situation                                                                  | HTTP status | `error.code`       |
| -------------------------------------------------------------------------- | ----------- | ------------------ |
| Missing/malformed field, malformed id, invalid status transition           | 400         | `VALIDATION_ERROR` |
| Reference to a Publisher or Category that doesn't exist                    | 400         | `VALIDATION_ERROR` |
| Package not found                                                          | 404         | `NOT_FOUND`        |
| Duplicate `packageId`, or duplicate display name within the same Publisher | 409         | `CONFLICT`         |

The full request/response schema is also available live at `/documentation`.
