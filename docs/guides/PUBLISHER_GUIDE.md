# Publisher Guide

How to register and manage a Publisher on the Open Engineering Exchange (TASK-EXC-0003). This covers the Publisher Registry only — package upload, publication, search, and download are later tasks (TASK-EXC-0004 onward) and aren't described here yet.

## What a Publisher is

A Publisher is the Exchange's record of who owns and distributes engineering packages — an individual, company, OEM, educational institution, government body, standards organization, enterprise, or community organization (see `docs/specifications/exchange/EXC-002-PUBLISHER_MODEL_SPECIFICATION.md` §6). Every package published to the Exchange belongs to exactly one Publisher.

A Publisher has two parts, stored and managed together but conceptually distinct (EXC-002 §3/§7):

- **Identity** — namespace, legal name, display name, contact email, status. Set at registration; the namespace and legal name don't change afterward.
- **Profile** — description and website today (logo, social links, and the rest of EXC-002 §7's public profile fields arrive in a later task). Freely editable at any time.

Authentication and authorization are explicitly out of this task's scope (`docs/tasks/WP-EXC-003.md` §2) — every endpoint below is currently unauthenticated. A future task adds identity/access control in front of these same endpoints.

## Registering as a Publisher

`POST /api/v1/publishers`

```json
{
  "namespace": "com.yourcompany",
  "publisherType": "company",
  "displayName": "Your Company",
  "legalName": "Your Company, Inc.",
  "contactEmail": "engineering@yourcompany.com",
  "description": "What your company publishes.",
  "website": "https://yourcompany.com"
}
```

- `namespace` is a reverse-domain identifier (e.g. `com.yourcompany`) that every package you publish will live under (`com.yourcompany.*`). It cannot collide with another Publisher's namespace and, in practice, shouldn't change once you've published packages under it.
- `publisherType` is one of: `individual`, `company`, `oem`, `educational_institution`, `government`, `standards_organization`, `enterprise`, `community_organization`.
- `namespace`, `publisherType`, `displayName`, `legalName`, and `contactEmail` are required. `description` and `website` are optional.
- `namespace`, `legalName` (the registered/legal name), and `contactEmail` must each be unique across all Publishers.

A successful registration returns `201` with the full Publisher record, including a generated `id` — keep it, since every other endpoint addresses your Publisher by it.

## Looking up Publishers

- `GET /api/v1/publishers` — every active Publisher.
- `GET /api/v1/publishers/{id}` — one Publisher by id (`404` if unknown or already deleted).

## Updating your Publisher

`PUT /api/v1/publishers/{id}` accepts any subset of:

```json
{
  "displayName": "New Display Name",
  "contactEmail": "new-contact@yourcompany.com",
  "description": "Updated description.",
  "website": "https://new-url.example.com",
  "status": "suspended"
}
```

`namespace` and `legalName` cannot be changed through this endpoint — they're part of your Publisher's permanent identity (EXC-002 §4: "Publisher IDs are immutable"; the namespace and legal name follow the same reasoning, since packages already published reference them).

`status` is `active` or `suspended`. Suspending your own Publisher does not remove or hide packages you've already published (EXC-002 §16) — it only marks your account inactive.

## Deleting a Publisher

`DELETE /api/v1/publishers/{id}` — soft-deletes the Publisher (it stops appearing in lookups and listings). Per EXC-002 §17, this never removes history and the Publisher's id is never reused for anyone else.

## Errors

Every error response has the same shape:

```json
{ "error": { "code": "...", "message": "...", "details": { ... } } }
```

| Situation                              | HTTP status | `error.code`       |
| -------------------------------------- | ----------- | ------------------ |
| Missing/malformed field, malformed id  | 400         | `VALIDATION_ERROR` |
| Publisher not found                    | 404         | `NOT_FOUND`        |
| Duplicate namespace/name/contact email | 409         | `CONFLICT`         |

The full request/response schema is also available live at `/documentation` (generated from the same route definitions this guide describes, so it can never drift out of sync — see `docs/architecture/adr/ADR-0001-Repository-Structure.md` "Why Fastify").
