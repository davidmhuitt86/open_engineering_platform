# Public C API — Mutation, Transactions, and Batch Mutation

Per Work Package 014 (TASK-000027 through TASK-000030). This document covers the first write-capable surface of the Public C API — everything in `platform/api/README.md` up to this point was read-only.

Every function described here is declared in `platform/api/include/oep/api/oep_api.h`, is a pure C ABI, and delegates entirely through `FoundationRuntime`. No store (`ObjectStore`/`RelationshipStore`) is ever reachable from this API directly, and no validation rule is re-implemented here — Foundation's existing validation (`validate_object`/`validate_relationship`) is the single source of truth for what makes a mutation valid.

---

## Object Mutation (TASK-000027)

```c
const char* tags[2] = {"electrical", "ignition"};

oep_object_info_t created;
oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Ignition Coil", "Generates spark", "Jane", tags, 2, &created);

oep_object_info_t updated;
oep_object_update(runtime, created.object_id, "Ignition Coil (Rev B)", "Updated", "Jane Doe", NULL, 0, &updated);

oep_object_delete(runtime, created.object_id);
```

- `oep_object_create(runtime, object_type, name, description, author, tags, tag_count, out_object)` — `name` must not be `NULL`; an empty name is rejected, but by Foundation's own `validate_object` (via `ObjectStore::create`), not by a check duplicated in this API. `description`/`author` may be `NULL` (treated as empty). `tags` may be `NULL` iff `tag_count` is `0`. Unlike `oep_object_info_t`'s fixed-size `tags` array, there is no cap on how many tags may be supplied at creation time — only reading a tag list back out through a fixed `oep_object_info_t` truncates it at `OEP_MAX_OBJECT_TAGS`.
- `oep_object_update(runtime, object_id, name, description, author, tags, tag_count, out_object)` — replaces name/description/author/tags wholesale (a full-record replace, matching `ObjectStore::update`'s own contract exactly — there is no partial-patch semantics at either layer). `object_id`, `object_type`, and the object's creation timestamp are never changed; `object_type` is immutable throughout Foundation's Engineering Object model, not a restriction this API introduces. Fails with `OEP_ERROR_NOT_FOUND` if no object with `object_id` exists.
- `oep_object_delete(runtime, object_id)` — fails with `OEP_ERROR_NOT_FOUND` if no such object exists. Does not cascade to Relationships referencing the deleted object; this mirrors `ObjectStore::remove`'s own pre-existing behavior and is not a new restriction.

All three require `RepositoryOpen`; all three delegate to new `FoundationRuntime` methods (`create_object`/`update_object`/`delete_object`), which delegate to `ObjectStore` — no logic is duplicated at the API boundary.

## Relationship Mutation (TASK-000028)

```c
oep_relationship_info_t created;
oep_relationship_create(runtime, manual_id, coil_id, OEP_RELATIONSHIP_TYPE_DOCUMENTS, "Jane",
                         "Manual documents the coil", &created);

oep_relationship_info_t updated;
oep_relationship_update(runtime, created.relationship_id, "Jane Doe", "Revised description", &updated);

oep_relationship_delete(runtime, created.relationship_id);
```

- `oep_relationship_create(runtime, source_object_id, target_object_id, relationship_type, author, description, out_relationship)` — `source_object_id`/`target_object_id` must not be `NULL`. Fails with `OEP_ERROR_NOT_FOUND` if either referenced object does not exist, or `OEP_ERROR_INVALID_ARGUMENT` for an otherwise-invalid relationship (e.g. source equals target) — both checks happen inside `RelationshipStore::create`, not duplicated here.
- `oep_relationship_update(runtime, relationship_id, author, description, out_relationship)` — replaces only author/description, matching `RelationshipStore::update`'s own contract: `relationship_id`, `source_object_id`, `target_object_id`, `relationship_type`, and the created timestamp are all immutable. Fails with `OEP_ERROR_NOT_FOUND` for an unknown `relationship_id`.
- `oep_relationship_delete(runtime, relationship_id)` — fails with `OEP_ERROR_NOT_FOUND` if no such relationship exists.

## Transactions (TASK-000029)

```c
oep_transaction_begin(runtime);

oep_object_info_t a, b;
oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "A", "", "", NULL, 0, &a);
oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "B", "", "", NULL, 0, &b);

oep_transaction_commit(runtime); /* both A and B are kept */
/* — or — */
oep_transaction_rollback(runtime); /* both A and B are undone */
```

A transaction groups object and relationship mutations into one deterministically reversible unit.

**How it works, precisely.** `ObjectStore`/`RelationshipStore` have no concept of a staged, uncommitted write — every `create`/`update`/`remove` call still writes to disk immediately, transaction or not. What a transaction adds is bookkeeping: while active, `FoundationRuntime` records, for each successful mutation, exactly what would undo it:

| Mutation | Undo, on rollback |
|---|---|
| object/relationship created | `remove()` the created record |
| object/relationship updated | `update()` back to the pre-update record |
| object/relationship deleted | `restore()` the pre-delete record (exact original ID and timestamps) |

`oep_transaction_commit()` simply discards that log — every mutation is already persisted, so there is nothing further to do. `oep_transaction_rollback()` replays the log in reverse, undoing each mutation via the same `ObjectStore`/`RelationshipStore` methods a normal mutation would use — no second, parallel persistence mechanism was introduced to make this possible.

**Only one transaction at a time.** `oep_transaction_begin()` fails with `OEP_ERROR_INVALID_STATE` if a transaction is already active — nesting is not supported, keeping rollback unambiguous (there is exactly one log, not a stack of them).

**Automatic rollback on failure.** If any object or relationship mutation fails while a transaction is active, Foundation automatically rolls back and deactivates the transaction *before* returning the failure to the caller:

```c
oep_transaction_begin(runtime);
oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "First", "", "", NULL, 0, &first);   /* succeeds */
oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "",      "", "", NULL, 0, &failed);   /* fails: empty name */
/* the transaction is already rolled back and inactive here — "First" no longer exists */
oep_transaction_is_active(runtime); /* == 0 */
```

The caller does not need to (but may safely) call `oep_transaction_rollback()` afterward — it will simply report `OEP_ERROR_INVALID_STATE` ("no transaction is currently active"), which is not itself an error worth treating specially.

**Closing the repository mid-transaction.** `oep_runtime_close_repository()`/`oep_runtime_shutdown()`/`oep_runtime_destroy()` all automatically roll back an active transaction first, so a repository is never left with a transaction stranded open.

- `oep_transaction_begin(runtime)` / `oep_transaction_commit(runtime)` / `oep_transaction_rollback(runtime)` all require `RepositoryOpen` and return `oep_result_t`, using the existing error model.
- `oep_transaction_is_active(runtime)` returns nonzero iff a transaction is currently active; never fails (returns `0` for a `NULL` handle).

## Batch Mutation (TASK-000030)

```c
oep_object_create_spec_t specs[3] = {
    {OEP_OBJECT_TYPE_DOCUMENT,  "Batch A", "", "", NULL, 0},
    {OEP_OBJECT_TYPE_COMPONENT, "Batch B", "", "", NULL, 0},
    {OEP_OBJECT_TYPE_DOCUMENT,  "Batch C", "", "", NULL, 0},
};

oep_batch_create_objects_result_t result;
oep_batch_create_objects(runtime, specs, 3, &result);
/* result.created.items[0..2] are Batch A, Batch B, Batch C, in that exact order */
oep_batch_create_objects_result_release(&result);
```

Batch mutation is sugar over the transaction primitives above, not a separate mechanism: every spec is created **in array order** (the deterministic execution order this task requires), inside a transaction.

- If no transaction is active when `oep_batch_create_objects`/`oep_batch_create_relationships` is called, one is begun and committed automatically around the whole batch.
- If the caller already has a transaction active, the batch participates in it — a failure rolls back **everything in that transaction**, not just the batch's own entries. The transaction, not the batch call, is the unit of rollback; this is a direct, intentional consequence of batch mutation being built on the same transaction primitives rather than a second, independent rollback mechanism.

```c
oep_object_create_spec_t bad_specs[3] = {
    {OEP_OBJECT_TYPE_DOCUMENT, "Should Not Survive 1", "", "", NULL, 0},
    {OEP_OBJECT_TYPE_DOCUMENT, "",                      "", "", NULL, 0}, /* invalid: empty name */
    {OEP_OBJECT_TYPE_DOCUMENT, "Should Not Survive 3", "", "", NULL, 0},
};

oep_batch_create_objects_result_t result;
oep_result_t call_result = oep_batch_create_objects(runtime, bad_specs, 3, &result);
/* call_result.success == 0
   result.failed_index == 1        (0-based index of the item that failed)
   result.created.count == 0       (nothing survives — the whole batch rolled back) */
```

`oep_object_create_spec_t`/`oep_relationship_create_spec_t` are input-only structures: their `const char*` fields point to caller-owned memory that Foundation only reads for the duration of the call — no ownership transfer, and still no STL or C++ type crosses the boundary.

`oep_batch_create_objects_result_t::created` (an `oep_object_list_t`) is deliberately **not** sorted by `object_id` the way `oep_object_store_list` is — it is left in execution order, since preserving input/execution order is exactly the determinism guarantee this task requires. The same is true of `oep_batch_create_relationships_result_t::created`.

---

## Memory Ownership

- `oep_object_create`/`oep_object_update`/`oep_relationship_create`/`oep_relationship_update` allocate nothing — they fill a caller-supplied `oep_object_info_t`/`oep_relationship_info_t` (which may be `NULL` if the caller doesn't need the resulting record).
- `oep_object_delete`/`oep_relationship_delete` and every `oep_transaction_*` function allocate nothing — they return a plain `oep_result_t`.
- `oep_batch_create_objects_result_t`/`oep_batch_create_relationships_result_t` each own one Foundation-allocated heap array (`created.items`), exactly like `oep_object_list_t`/`oep_relationship_list_t` already do. Release with exactly one call to `oep_batch_create_objects_result_release`/`oep_batch_create_relationships_result_release`. A result that never succeeded has `created.items == NULL`/`created.count == 0` and is always safe to release (a no-op).

## Error Handling

All six error codes from `oep_error_code_t` are exercised by this surface:

| Scenario | `error_code` |
|---|---|
| `NULL` handle, `NULL` required pointer, unrecognized enum value, negative `tag_count`/`count`, `tags`/`specs` `NULL` with a nonzero count | `OEP_ERROR_INVALID_ARGUMENT` |
| No repository open; a transaction already active on begin; no transaction active on commit/rollback | `OEP_ERROR_INVALID_STATE` |
| Unknown `object_id`/`relationship_id` on update/delete; a relationship referencing a nonexistent source/target object | `OEP_ERROR_NOT_FOUND` |
| An otherwise-invalid mutation Foundation's own validation rejects (e.g. an empty name, source equal to target) | `OEP_ERROR_INVALID_ARGUMENT` |
| A filesystem-level write failure, or any other operational failure not covered above | `OEP_ERROR_OPERATION_FAILED` |
| An unexpected internal exception | `OEP_ERROR_INTERNAL` |

Classification is performed once, by a single shared helper (`classify_mutation_error`, private to `oep_api.cpp`) that pattern-matches the small, stable set of message substrings `ObjectStore`/`RelationshipStore` actually produce — the same substring-matching approach already established for `oep_runtime_open_repository` in Work Package 011. No native exception crosses the API boundary under any condition exercised by this surface, including a mid-transaction failure.

## Thread Safety

No new thread-safety guarantee is introduced by this section — it follows the same single-handle rule as every other `OEP_Runtime`-taking function in this API (see `platform/api/README.md`'s "Thread Safety" section): a single handle is not safe for concurrent calls, distinct handles are fully independent, and every `*_release` function may be called from any thread as long as no other thread concurrently uses or releases the same structure.

One guarantee worth stating explicitly for this section: **a transaction is per-handle, not global.** `transaction_active_`/the undo log live inside the `FoundationRuntime` a given `OEP_Runtime` wraps; two distinct handles opened against the same repository directory have entirely independent transactions (and, since Foundation's stores perform no file locking, concurrent mutation through two handles against the same repository is not a supported configuration regardless of transactions — this is a pre-existing characteristic of `ObjectStore`/`RelationshipStore`, not something this work package changes).

---

## Out of Scope

Per Work Package 014's explicit scope:

- No object/relationship mutation is exposed beyond create/update/delete — no partial-patch semantics, no bulk update or bulk delete (only bulk *create*, per TASK-000030).
- No nested transactions.
- No cross-repository or cross-handle transactions.
- No change to `FoundationRuntime`'s read-only Service Registry accessors (`object_store()`/`relationship_store()`/etc.) — they remain `const`-returning and unchanged; mutation is exposed through new, separate `FoundationRuntime` methods, not by making the existing accessors non-`const`.
