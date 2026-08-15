# Search

Status: Foundation (Repository Search System)

Purpose: Deterministic, offline discovery of Engineering Objects and Relationships, per OEP-SPEC-006-REPOSITORY_SEARCH.

## Architecture

- `include/oep/search/search_engine.hpp` — public `SearchEngine` (`build_index` / `clear_index` / `search_objects` / `search_relationships`), `MatchLocation`, and result types
- `src/search_engine.cpp` — index construction from `oep::repository::ObjectStore` / `RelationshipStore`, case-insensitive partial-match scoring, deterministic result ordering

The index is in-memory only and is rebuilt on demand via `build_index`; it is never persisted. `SearchEngine` never modifies repository contents and remains independent of the CLI and Studios.
