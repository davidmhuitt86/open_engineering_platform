# Engineering Exchange — Release Candidate 1 Release Notes

**Work Package:** WP-EXC-010
**Repositories:** `oep_exchange`, `oep_studio` (integration only)
**Status:** Release Candidate 1

## Summary

The Engineering Exchange — the REST API (`apps/exchange-api`), its web application (`apps/publisher-portal`), and now a native OEP Studio workspace — is declared Release Candidate 1. This release adds no new backend capability; it integrates the already-complete MVP (TASK-EXC-0001 through TASK-EXC-0009) into OEP Studio as a first-class workspace, validates the whole system end to end, and completes documentation.

## What's new in RC1

- **OEP Studio integration** — a native "Engineering Exchange" Studio workspace (`oep_studio/lib/exchange/`), reached from the permanent Navigation Rail, implementing Marketplace Home, Search, Package Detail (with inline Installation Progress), Publisher Profile, My Library, and Downloads against `exchange-api`'s existing REST surface — no new backend endpoint was added for this.
- **Repository Integration** — Install Package, Show Installation Status, Refresh Repository, and (best-effort) Open Installed Package, all reachable from Studio's Package Detail and My Library views.
- **Settings, Search, and Command Palette integration** — Engineering Exchange gets its own Settings page (service address), participates in Studio's Unified Search (best-effort, cache-only), and exposes three Command Palette commands (`exchange.search`, `exchange.refreshMarketplace`, `exchange.refreshRepository`).
- **Documentation** — a new Studio Integration Guide, plus updates to the Developer, Frontend, Component, and Installation Guides noting the Studio integration; this Validation Report, Known Issues, Deployment Guide, and MVP Completion Report.

## What did not change

- No `exchange-api` route, service, persistence, or wire-contract change. Every endpoint the Studio workspace calls (`/publishers`, `/packages`, `/search`, `/packages/{id}/install`, `/installations/{id}`) already existed and is unmodified.
- `apps/publisher-portal` (the web application) is unchanged — it remains a fully independent front end to the same API.

## Excluded from this release (unchanged from the MVP)

Authentication, Commerce, Licensing, Reviews, Ratings, Organizations, Publisher administration — all out of scope for RC1, per WP-EXC-010 §2 and every prior task's own stated scope.

## Upgrade notes

None — this release adds a new consumer of an unchanged API. Existing `exchange-api`/`publisher-portal` deployments require no migration or configuration change. OEP Studio users get the new "Engineering Exchange" navigation entry automatically; it points at `http://127.0.0.1:3000/api/v1` by default and is configurable under Settings > Engineering Exchange.

See `docs/KNOWN_ISSUES.md`, `docs/VALIDATION_REPORT.md`, and `docs/DEPLOYMENT_GUIDE.md` for details.
