# Search Guide

How to search the Engineering Exchange's Package Catalog (TASK-EXC-0006). This covers the single read-only search endpoint over already-registered Packages (`docs/guides/PACKAGE_CATALOG_GUIDE.md`) — it does not cover registering or uploading packages.

Authentication and authorization are out of scope for this task, same as every other Exchange endpoint so far — `GET /api/v1/search` is currently unauthenticated.

## Searching

`GET /api/v1/search`

```
GET /api/v1/search?q=turbocharger&status=published&sortBy=name&sortDirection=asc&page=1&pageSize=20
```

All query parameters are optional; an empty query (`GET /api/v1/search`) returns every non-deleted Package, paginated.

| Parameter       | Meaning                                                                                                                                                                                             |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `q`             | Keyword search — matches Package name, display name, description, Publisher name, category, current version, and keywords (via a PostgreSQL full-text index; see "How keyword search works" below). |
| `publisherId`   | Restrict results to one Publisher (must be a well-formed UUID).                                                                                                                                     |
| `categoryId`    | Restrict results to one Category (must be a well-formed UUID).                                                                                                                                      |
| `status`        | Restrict results to one status: `draft`, `published`, `deprecated`, `suspended`.                                                                                                                    |
| `sortBy`        | `name`, `createdAt`, or `updatedAt`. Defaults to `createdAt`.                                                                                                                                       |
| `sortDirection` | `asc` or `desc`. Defaults to `desc`.                                                                                                                                                                |
| `page`          | 1-based page number. Defaults to `1`. Out-of-range values are clamped to `1` rather than rejected.                                                                                                  |
| `pageSize`      | Results per page, 1–100. Defaults to `20`. Out-of-range values are clamped rather than rejected.                                                                                                    |

A filter for a `publisherId`/`categoryId` that doesn't exist isn't an error — it simply matches zero Packages, the same as any other filter combination with no matches.

### Response shape

```json
{
  "items": [
    {
      "id": "b6b6...",
      "packageId": "com.divad.honda.gl1200.electrical",
      "publisherId": "3f1b2c4d-...",
      "publisherName": "Divad Engineering LLC",
      "displayName": "Honda GL1200 Electrical",
      "description": "Wiring diagrams and electrical system reference.",
      "categoryId": "a92e7f10-...",
      "categoryName": "Automotive",
      "currentVersion": "1.0.0",
      "status": "published",
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  ],
  "totalCount": 1,
  "totalPages": 1,
  "currentPage": 1,
  "pageSize": 20
}
```

`totalCount` is the number of Packages matching the filters across every page, not just the current page's `items.length`.

## How keyword search works

Every Package's searchable text (package id, title, summary, description, publisher name/display name, category name, keywords, current version) is kept in a separate `search_index` table, maintained automatically by a database trigger whenever a Package is inserted or updated — no separate "reindex" step is needed after registering or updating a Package. Keyword matching (`q`) uses PostgreSQL's `websearch_to_tsquery`, so `q=turbocharger diagram` matches Packages containing both words, in any order, and common stemming (`brakes` matches `brake`) is applied automatically.

Keyword search only affects _which_ Packages match — it does not affect result order. Ordering is always driven by `sortBy`/`sortDirection`; there is no "relevance" sort mode.

## Errors

Same shared envelope as every other Exchange endpoint:

```json
{ "error": { "code": "...", "message": "...", "details": { ... } } }
```

| Situation                                      | HTTP status | `error.code`       |
| ---------------------------------------------- | ----------- | ------------------ |
| Malformed `publisherId`/`categoryId`           | 400         | `VALIDATION_ERROR` |
| Unrecognized `status`/`sortBy`/`sortDirection` | 400         | `VALIDATION_ERROR` |

`page`/`pageSize` are never rejected — see the table above.

The full request/response schema is also available live at `/documentation`.
