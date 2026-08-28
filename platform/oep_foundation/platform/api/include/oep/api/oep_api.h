#ifndef OEP_API_H
#define OEP_API_H

/*
 * OEP Foundation Public C API
 * Per OEP-SPEC-021-PUBLIC_C_API, OEP-SPEC-022-FOUNDATION_BRIDGE_SUPPORT,
 * Work Package 012 (Engineering Object Enumeration, Repository
 * Statistics), Work Package 013 (Engineering Relationship Enumeration,
 * Repository Search), and Work Package 014 (Object Mutation,
 * Relationship Mutation, Transactions, Batch Mutation — the first
 * write-capable surface of this API).
 *
 * This is the only supported native interface into Foundation. It is a
 * pure C ABI: no C++ classes, no STL types, and no exceptions ever cross
 * this boundary. Every function that can fail returns an oep_result_t;
 * native exceptions raised internally are caught at the boundary and
 * translated into OEP_ERROR_INTERNAL results, never propagated.
 *
 * See platform/api/README.md for the full lifecycle, ownership, thread
 * safety, and Bridge integration guidance.
 */

#include <stddef.h> /* size_t, for oep_kge_export_json/oep_kge_export_graphml_placeholder (WP-EKE-002) */

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Versioning (OEP-SPEC-021 section 8)                                 */
/* ------------------------------------------------------------------ */

/* The Public C API's own version. Incremented whenever a function or
   structure is added, changed, or removed. */
/* 21: AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — appended diagram_id to
   oep_object_info_t/oep_relationship_info_t, added
   oep_diagram_create/oep_diagram_get/oep_object_create_with_diagram/
   oep_relationship_create_with_diagram/oep_diagram_get_objects/
   oep_diagram_get_relationships. Additive only — OEP_ABI_VERSION is
   unchanged. */
#define OEP_API_VERSION 21

/* The ABI version. Incremented only when a change would break binary
   compatibility with a previously compiled caller (e.g. a struct
   layout change). Distinct from OEP_API_VERSION, which may advance for
   additions that remain ABI-compatible. */
#define OEP_ABI_VERSION 1

/* Returns the Foundation version this build implements (e.g. "0.1.0"),
   the same version reported by `oep status`/`oep version`. The
   returned pointer references static storage and must not be freed. */
const char* oep_foundation_version(void);

/* Returns OEP_API_VERSION. */
int oep_api_version(void);

/* Returns OEP_ABI_VERSION. */
int oep_abi_version(void);

/* ------------------------------------------------------------------ */
/* Opaque handles (OEP-SPEC-021 section 4)                             */
/* ------------------------------------------------------------------ */

/* Applications shall never inspect handle contents; a handle is only
   ever passed back into this API. */
typedef struct oep_runtime_impl* OEP_Runtime;

/* ------------------------------------------------------------------ */
/* Runtime state (OEP-SPEC-022 section 3)                              */
/* ------------------------------------------------------------------ */

typedef enum oep_runtime_state_t {
    OEP_STATE_UNINITIALIZED = 0,
    OEP_STATE_INITIALIZED = 1,
    OEP_STATE_REPOSITORY_OPEN = 2,
    OEP_STATE_REPOSITORY_CLOSED = 3,
    OEP_STATE_SHUTDOWN = 4,
} oep_runtime_state_t;

/* Returns a static, human-readable name for `state` (e.g.
   "RepositoryOpen"). The returned pointer references static storage
   and must not be freed. Deterministic: the same input always
   produces the same output. */
const char* oep_runtime_state_to_string(oep_runtime_state_t state);

/* ------------------------------------------------------------------ */
/* Error reporting (OEP-SPEC-021 section 6, OEP-SPEC-022 section 4)    */
/* ------------------------------------------------------------------ */

typedef enum oep_error_code_t {
    OEP_ERROR_NONE = 0,
    OEP_ERROR_INVALID_ARGUMENT = 1,
    OEP_ERROR_INVALID_STATE = 2,
    OEP_ERROR_NOT_FOUND = 3,
    OEP_ERROR_OPERATION_FAILED = 4,
    OEP_ERROR_INTERNAL = 5,
} oep_error_code_t;

/* A coarse classification of `oep_error_code_t`, so a Bridge can group
   errors (e.g. to decide whether to surface a retry option) without
   needing to enumerate every individual error code. */
typedef enum oep_error_category_t {
    OEP_ERROR_CATEGORY_NONE = 0,
    OEP_ERROR_CATEGORY_VALIDATION = 1, /* bad input: OEP_ERROR_INVALID_ARGUMENT */
    OEP_ERROR_CATEGORY_STATE = 2,      /* wrong lifecycle state: OEP_ERROR_INVALID_STATE */
    OEP_ERROR_CATEGORY_IO = 3,         /* filesystem/repository access: OEP_ERROR_NOT_FOUND, OEP_ERROR_OPERATION_FAILED */
    OEP_ERROR_CATEGORY_INTERNAL = 4,   /* unexpected internal failure: OEP_ERROR_INTERNAL */
} oep_error_category_t;

/* Returns a static, human-readable name for `code`. Never freed by the
   caller. */
const char* oep_error_code_to_string(oep_error_code_t code);

/* Returns a static, human-readable name for `category`. Never freed by
   the caller. */
const char* oep_error_category_to_string(oep_error_category_t category);

#define OEP_MAX_ERROR_MESSAGE 256

/* Every API function that can fail returns an oep_result_t by value.
   `success` is nonzero on success, in which case error_code is
   OEP_ERROR_NONE, error_category is OEP_ERROR_CATEGORY_NONE, and
   error_message is empty. On failure, error_message is a
   NUL-terminated, human-readable, English-language description
   suitable for logging or for a Bridge to translate/present; it is
   truncated (never overflowed) if longer than
   OEP_MAX_ERROR_MESSAGE - 1 bytes. No heap allocation is associated
   with an oep_result_t: it is a plain value type and requires no
   release function. */
typedef struct oep_result_t {
    int success;
    oep_error_code_t error_code;
    oep_error_category_t error_category;
    char error_message[OEP_MAX_ERROR_MESSAGE];
} oep_result_t;

/* ------------------------------------------------------------------ */
/* Runtime lifecycle (OEP-SPEC-021 section 5)                          */
/* ------------------------------------------------------------------ */

/* Creates a new, Uninitialized Runtime handle representing the given
   Foundation version (NUL-terminated UTF-8; copied internally, so the
   caller's buffer need not outlive the call). Returns NULL if
   `foundation_version` is NULL or allocation fails.

   Ownership: the caller owns the returned handle and must release it
   with oep_runtime_destroy exactly once. */
OEP_Runtime oep_runtime_create(const char* foundation_version);

/* Releases a Runtime handle. If the Runtime has an open repository,
   it is closed first (mirroring FoundationRuntime::shutdown). Safe to
   call with NULL (a no-op). After this call, `runtime` must not be
   used again. */
void oep_runtime_destroy(OEP_Runtime runtime);

/* Transitions the Runtime from Uninitialized to Initialized. Fails
   with OEP_ERROR_INVALID_STATE if not currently Uninitialized. */
oep_result_t oep_runtime_initialize(OEP_Runtime runtime);

/* Opens the repository rooted at `repository_path` (NUL-terminated
   UTF-8). Only valid from Initialized or RepositoryClosed; fails with
   OEP_ERROR_INVALID_STATE otherwise. Fails with OEP_ERROR_NOT_FOUND or
   OEP_ERROR_OPERATION_FAILED if the repository cannot be opened (e.g.
   missing or corrupt repository.json). */
oep_result_t oep_runtime_open_repository(OEP_Runtime runtime, const char* repository_path);

/* Closes the currently open repository. Only valid from
   RepositoryOpen; fails with OEP_ERROR_INVALID_STATE otherwise. */
oep_result_t oep_runtime_close_repository(OEP_Runtime runtime);

/* Transitions the Runtime to Shutdown, closing an open repository
   first if necessary. Idempotent: calling this from Shutdown again
   fails with OEP_ERROR_INVALID_STATE rather than crashing. */
oep_result_t oep_runtime_shutdown(OEP_Runtime runtime);

/* Returns the Runtime's current state. Never fails; returns
   OEP_STATE_UNINITIALIZED if `runtime` is NULL. */
oep_runtime_state_t oep_runtime_get_state(OEP_Runtime runtime);

/* ------------------------------------------------------------------ */
/* Repository status (OEP-SPEC-021 section 5, OEP-SPEC-022 section 5)  */
/* ------------------------------------------------------------------ */

/* A deterministic, fixed-layout snapshot of the currently open
   repository, safe to copy across the API boundary and convert into a
   language-native model by a Bridge (OEP-SPEC-022 section 5). Contains
   no pointers, so it may be copied by value with memcpy. */
typedef struct oep_repository_status_t {
    /* Nonzero iff a repository is currently open; every other field is
       only meaningful when this is nonzero. */
    int repository_open;
    char repository_id[64];
    char repository_name[256];
    char repository_version[32];
    int loaded_package_count;
} oep_repository_status_t;

/* Populates `out_status` from the currently open repository. Only
   valid from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE
   otherwise, in which case `*out_status` is zero-initialized.
   `out_status` must not be NULL. */
oep_result_t oep_runtime_get_repository_status(OEP_Runtime runtime, oep_repository_status_t* out_status);

/* ------------------------------------------------------------------ */
/* Engineering Object Enumeration (Work Package 012, TASK-000023)      */
/* ------------------------------------------------------------------ */

typedef enum oep_object_type_t {
    OEP_OBJECT_TYPE_DOCUMENT = 0,
    OEP_OBJECT_TYPE_DIAGRAM = 1,
    OEP_OBJECT_TYPE_COMPONENT = 2,
    OEP_OBJECT_TYPE_PROCEDURE = 3,
    OEP_OBJECT_TYPE_PROJECT = 4,
    OEP_OBJECT_TYPE_IMAGE = 5,
} oep_object_type_t;

/* The number of distinct oep_object_type_t values. Also the size of
   oep_repository_statistics_t::object_count_by_type. */
#define OEP_OBJECT_TYPE_COUNT 6

/* Returns a static, human-readable name for `type` (e.g. "Component").
   Never freed by the caller. Deterministic. */
const char* oep_object_type_to_string(oep_object_type_t type);

#define OEP_MAX_OBJECT_ID 64
#define OEP_MAX_OBJECT_NAME 256
#define OEP_MAX_OBJECT_AUTHOR 128
#define OEP_MAX_OBJECT_VERSION 32
#define OEP_MAX_OBJECT_DESCRIPTION 1024
#define OEP_MAX_OBJECT_TAGS 16
#define OEP_MAX_TAG_LENGTH 64

/* A deterministic, fixed-layout snapshot of one Engineering Object's
   metadata — no pointers, no STL types, safe to copy by value or
   convert directly into a language-native model. String fields are
   truncated (never overflowed) if the underlying value is longer than
   the field's capacity; `tag_count` is capped at OEP_MAX_OBJECT_TAGS
   (additional tags beyond the cap are simply not included). */
typedef struct oep_object_info_t {
    char object_id[OEP_MAX_OBJECT_ID];
    oep_object_type_t object_type;
    char name[OEP_MAX_OBJECT_NAME];
    char author[OEP_MAX_OBJECT_AUTHOR];
    char version[OEP_MAX_OBJECT_VERSION];
    char description[OEP_MAX_OBJECT_DESCRIPTION];
    int tag_count;
    char tags[OEP_MAX_OBJECT_TAGS][OEP_MAX_TAG_LENGTH];
    /* AP-OEP-FOUNDATION-GRAPH-IDENTITY-001, OEP_API_VERSION 21 — the
       object_id of the OEP_OBJECT_TYPE_DIAGRAM object this object
       belongs to, or empty if it belongs to no diagram/graph. Appended
       at the end, per this header's own struct-extension convention
       (see oep_package_details_t's doc comment for the alternative,
       "new superset struct," convention used when appending isn't
       viable). A caller built against OEP_API_VERSION < 21 that already
       has its own copy of this struct is unaffected as long as it does
       not read past its own compiled struct size. */
    char diagram_id[OEP_MAX_OBJECT_ID];
} oep_object_info_t;

/* Returns the number of Engineering Objects in the currently open
   repository. Only valid from RepositoryOpen; fails with
   OEP_ERROR_INVALID_STATE otherwise, in which case `*out_count` is 0.
   `out_count` must not be NULL. */
oep_result_t oep_object_store_get_count(OEP_Runtime runtime, int* out_count);

/* Populates `out_object` with the Engineering Object identified by
   `object_id`. Only valid from RepositoryOpen; fails with
   OEP_ERROR_INVALID_STATE if no repository is open, or
   OEP_ERROR_NOT_FOUND if no object with that ID exists, in which case
   `*out_object` is zero-initialized. `object_id` and `out_object` must
   not be NULL. */
oep_result_t oep_object_store_get_by_id(OEP_Runtime runtime, const char* object_id, oep_object_info_t* out_object);

/* An enumerated collection of Engineering Objects. `items` is a
   Foundation-owned heap array of `count` elements, sorted
   deterministically by object_id (ascending, byte-wise) — the same
   order every time for unchanged repository contents. A list that was
   never successfully populated (e.g. the owning oep_result_t reported
   failure) has `items == NULL` and `count == 0`, and is always safe to
   pass to oep_object_list_release. */
typedef struct oep_object_list_t {
    oep_object_info_t* items;
    int count;
} oep_object_list_t;

/* Enumerates every Engineering Object in the currently open repository
   into `out_list`, sorted deterministically by object_id. Only valid
   from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE otherwise,
   in which case `*out_list` is zero-initialized (items = NULL,
   count = 0). `out_list` must not be NULL.

   Ownership: on success, the caller owns `out_list->items` and must
   release it with exactly one call to oep_object_list_release. Do not
   call `free`/`delete` on `items` directly — it was allocated by
   Foundation and must be released through the matching Foundation
   function. */
oep_result_t oep_object_store_list(OEP_Runtime runtime, oep_object_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes
   `list->items`/`list->count`. Safe to call on a zero-initialized or
   already-released list (a no-op). `list` itself may be NULL (a
   no-op). */
void oep_object_list_release(oep_object_list_t* list);

/* ------------------------------------------------------------------ */
/* Repository Statistics (Work Package 012, TASK-000024)               */
/* ------------------------------------------------------------------ */

/* A deterministic, fixed-layout snapshot of repository-wide counts,
   computed by Foundation so Studio (or any other API consumer) never
   has to enumerate and count objects/relationships/packages itself.
   No pointers; safe to copy by value or convert directly into a
   language-native model. */
typedef struct oep_repository_statistics_t {
    char repository_id[64];
    char repository_name[256];
    char repository_version[32];
    int total_object_count;
    /* Indexed by oep_object_type_t; object_count_by_type[OEP_OBJECT_TYPE_COMPONENT]
       is the number of Component objects, and so on. */
    int object_count_by_type[OEP_OBJECT_TYPE_COUNT];
    int relationship_count;
    /* Every discovered package, regardless of Loaded/Invalid/Disabled
       state — distinct from oep_repository_status_t::loaded_package_count,
       which counts only Loaded packages. */
    int package_count;
} oep_repository_statistics_t;

/* Populates `out_statistics` from the currently open repository. Only
   valid from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE
   otherwise, in which case `*out_statistics` is zero-initialized.
   `out_statistics` must not be NULL. */
oep_result_t oep_runtime_get_repository_statistics(OEP_Runtime runtime,
                                                    oep_repository_statistics_t* out_statistics);

/* ------------------------------------------------------------------ */
/* Engineering Relationship Enumeration (Work Package 013, TASK-000025)*/
/* ------------------------------------------------------------------ */

typedef enum oep_relationship_type_t {
    OEP_RELATIONSHIP_TYPE_REFERENCES = 0,
    OEP_RELATIONSHIP_TYPE_CONTAINS = 1,
    OEP_RELATIONSHIP_TYPE_DEPENDS_ON = 2,
    OEP_RELATIONSHIP_TYPE_CONNECTED_TO = 3,
    OEP_RELATIONSHIP_TYPE_DOCUMENTS = 4,
    OEP_RELATIONSHIP_TYPE_IMPLEMENTS = 5,
} oep_relationship_type_t;

/* Returns a static, human-readable name for `type` (e.g. "Documents").
   Never freed by the caller. Deterministic. */
const char* oep_relationship_type_to_string(oep_relationship_type_t type);

#define OEP_MAX_RELATIONSHIP_ID 64
#define OEP_MAX_TIMESTAMP 32

/* A deterministic, fixed-layout snapshot of one Relationship's
   metadata — no pointers, no STL types, safe to copy by value or
   convert directly into a language-native model. String fields are
   truncated (never overflowed) if the underlying value is longer than
   the field's capacity. */
typedef struct oep_relationship_info_t {
    char relationship_id[OEP_MAX_RELATIONSHIP_ID];
    char source_object_id[OEP_MAX_OBJECT_ID];
    char target_object_id[OEP_MAX_OBJECT_ID];
    oep_relationship_type_t relationship_type;
    char author[OEP_MAX_OBJECT_AUTHOR];
    char description[OEP_MAX_OBJECT_DESCRIPTION];
    char created_utc[OEP_MAX_TIMESTAMP];
    /* AP-OEP-FOUNDATION-GRAPH-IDENTITY-001, OEP_API_VERSION 21 — same
       meaning as oep_object_info_t::diagram_id. See that field's own
       comment. */
    char diagram_id[OEP_MAX_OBJECT_ID];
} oep_relationship_info_t;

/* Returns the number of Relationships in the currently open
   repository. Only valid from RepositoryOpen; fails with
   OEP_ERROR_INVALID_STATE otherwise, in which case `*out_count` is 0.
   `out_count` must not be NULL. */
oep_result_t oep_relationship_store_get_count(OEP_Runtime runtime, int* out_count);

/* Populates `out_relationship` with the Relationship identified by
   `relationship_id`. Only valid from RepositoryOpen; fails with
   OEP_ERROR_INVALID_STATE if no repository is open, or
   OEP_ERROR_NOT_FOUND if no relationship with that ID exists, in
   which case `*out_relationship` is zero-initialized.
   `relationship_id` and `out_relationship` must not be NULL. */
oep_result_t oep_relationship_store_get_by_id(OEP_Runtime runtime, const char* relationship_id,
                                               oep_relationship_info_t* out_relationship);

/* An enumerated collection of Relationships. `items` is a
   Foundation-owned heap array of `count` elements, sorted
   deterministically by relationship_id (ascending, byte-wise) — the
   same order every time for unchanged repository contents. A list
   that was never successfully populated has `items == NULL` and
   `count == 0`, and is always safe to pass to
   oep_relationship_list_release. Follows the same ownership model as
   oep_object_list_t (Work Package 012, TASK-000023). */
typedef struct oep_relationship_list_t {
    oep_relationship_info_t* items;
    int count;
} oep_relationship_list_t;

/* Enumerates every Relationship in the currently open repository into
   `out_list`, sorted deterministically by relationship_id. Only valid
   from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE otherwise,
   in which case `*out_list` is zero-initialized. `out_list` must not
   be NULL.

   Ownership: on success, the caller owns `out_list->items` and must
   release it with exactly one call to oep_relationship_list_release.
   Do not call `free`/`delete` on `items` directly. */
oep_result_t oep_relationship_store_list(OEP_Runtime runtime, oep_relationship_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes
   `list->items`/`list->count`. Safe to call on a zero-initialized or
   already-released list (a no-op). `list` itself may be NULL (a
   no-op). */
void oep_relationship_list_release(oep_relationship_list_t* list);

/* ------------------------------------------------------------------ */
/* Repository Search (Work Package 013, TASK-000026)                   */
/* ------------------------------------------------------------------ */

/* The field a query matched against, mirroring
   oep::search::MatchLocation (OEP-SPEC-006-REPOSITORY_SEARCH). */
typedef enum oep_match_location_t {
    OEP_MATCH_LOCATION_NAME = 0,
    OEP_MATCH_LOCATION_DESCRIPTION = 1,
    OEP_MATCH_LOCATION_AUTHOR = 2,
    OEP_MATCH_LOCATION_TAGS = 3,
    OEP_MATCH_LOCATION_OBJECT_TYPE = 4,
    OEP_MATCH_LOCATION_RELATIONSHIP_TYPE = 5,
} oep_match_location_t;

/* Returns a static, human-readable name for `location`. Never freed by
   the caller. Deterministic. */
const char* oep_match_location_to_string(oep_match_location_t location);

/* One Engineering Object search hit — a fixed-layout projection of
   oep::search::ObjectSearchResult. */
typedef struct oep_object_search_result_t {
    char object_id[OEP_MAX_OBJECT_ID];
    oep_object_type_t object_type;
    char display_name[OEP_MAX_OBJECT_NAME];
    oep_match_location_t match_location;
    double match_score;
} oep_object_search_result_t;

/* items is a Foundation-owned heap array, in exactly the order
   Foundation's Search Engine produced it — the Public API never
   reorders search results. Follows the same ownership model as
   oep_object_list_t. */
typedef struct oep_object_search_result_list_t {
    oep_object_search_result_t* items;
    int count;
} oep_object_search_result_list_t;

/* One Relationship search hit — a fixed-layout projection of
   oep::search::RelationshipSearchResult. */
typedef struct oep_relationship_search_result_t {
    char relationship_id[OEP_MAX_RELATIONSHIP_ID];
    char source_object_id[OEP_MAX_OBJECT_ID];
    char target_object_id[OEP_MAX_OBJECT_ID];
    oep_relationship_type_t relationship_type;
    oep_match_location_t match_location;
    double match_score;
} oep_relationship_search_result_t;

/* Same ownership model as oep_object_search_result_list_t. */
typedef struct oep_relationship_search_result_list_t {
    oep_relationship_search_result_t* items;
    int count;
} oep_relationship_search_result_list_t;

/* The combined result of a repository-wide search: every matching
   object and every matching relationship, each in its own list and in
   its own Search-Engine-produced order (the two lists are never
   merged or interleaved, matching `oep search`'s own "Objects: ... /
   Relationships: ..." presentation). */
typedef struct oep_repository_search_result_t {
    oep_object_search_result_list_t objects;
    oep_relationship_search_result_list_t relationships;
} oep_repository_search_result_t;

/* Searches both Engineering Objects and Relationships for `query`
   (case-insensitive, partial-match, per oep::search::SearchEngine).
   Only valid from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE
   otherwise. Fails with OEP_ERROR_INVALID_ARGUMENT for a NULL or empty
   `query`. On any failure, `*out_result` is zero-initialized.
   `query` and `out_result` must not be NULL.

   Ownership: on success, the caller owns both
   out_result->objects.items and out_result->relationships.items and
   must release them with exactly one call to
   oep_repository_search_result_release. */
oep_result_t oep_search_repository(OEP_Runtime runtime, const char* query,
                                    oep_repository_search_result_t* out_result);

/* Releases both lists owned by `result` (if any) and zeroes them.
   Safe to call on a zero-initialized or already-released result (a
   no-op). `result` itself may be NULL (a no-op). */
void oep_repository_search_result_release(oep_repository_search_result_t* result);

/* Searches Engineering Objects only for `query`. Same state/argument
   rules as oep_search_repository. Ownership: release with
   oep_object_search_result_list_release. */
oep_result_t oep_search_objects(OEP_Runtime runtime, const char* query, oep_object_search_result_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes it.
   Safe to call on a zero-initialized or already-released list, and
   safe to call with `list == NULL` (both no-ops). */
void oep_object_search_result_list_release(oep_object_search_result_list_t* list);

/* Searches Relationships only for `query`. Same state/argument rules
   as oep_search_repository. Ownership: release with
   oep_relationship_search_result_list_release. */
oep_result_t oep_search_relationships(OEP_Runtime runtime, const char* query,
                                      oep_relationship_search_result_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes it.
   Safe to call on a zero-initialized or already-released list, and
   safe to call with `list == NULL` (both no-ops). */
void oep_relationship_search_result_list_release(oep_relationship_search_result_list_t* list);

/* ------------------------------------------------------------------ */
/* Object Mutation (Work Package 014, TASK-000027)                     */
/* ------------------------------------------------------------------ */
/*
 * Every mutation function below delegates entirely to
 * FoundationRuntime, which delegates entirely to ObjectStore/
 * RelationshipStore — the Public API never manipulates a store
 * directly and never re-implements a validation rule Foundation
 * already enforces. In particular, `name`/`source_object_id`/
 * `target_object_id` are only checked here for a NULL pointer (an ABI
 * safety requirement); an empty or otherwise invalid value is left to
 * fail Foundation's own validation, so the same rule is enforced in
 * exactly one place.
 *
 * If a transaction is active (see "Transactions" below) and a
 * mutation fails, the active transaction is automatically rolled back
 * and deactivated before the failure is returned.
 */

/* Creates a new Engineering Object. `name` must not be NULL (an empty
   name still fails, via Foundation's own validation, with
   OEP_ERROR_INVALID_ARGUMENT). `description`/`author` may be NULL,
   treated as empty. `tags` may be NULL iff `tag_count` is 0;
   otherwise `tags` must point to `tag_count` NUL-terminated strings
   (individual entries may not be NULL). Unlike oep_object_info_t's
   fixed-size `tags` field, there is no cap on how many tags may be
   supplied here — a tag list longer than OEP_MAX_OBJECT_TAGS is
   accepted and stored in full; only reading it back out through a
   fixed oep_object_info_t truncates it.

   Only valid from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE
   otherwise. On success, `out_object` (if non-NULL) is populated with
   the created object, including its generated object_id. */
oep_result_t oep_object_create(OEP_Runtime runtime, oep_object_type_t object_type, const char* name,
                                const char* description, const char* author, const char* const* tags, int tag_count,
                                oep_object_info_t* out_object);

/* Replaces name/description/author/tags on the object identified by
   `object_id`. object_id, object_type, and the object's created
   timestamp are never changed — matching ObjectStore::update's own
   contract exactly, since object_type is immutable throughout
   Foundation's Engineering Object model. Fails with
   OEP_ERROR_NOT_FOUND if no object with `object_id` exists. Argument
   rules for name/description/author/tags/tag_count are the same as
   oep_object_create. */
oep_result_t oep_object_update(OEP_Runtime runtime, const char* object_id, const char* name, const char* description,
                                const char* author, const char* const* tags, int tag_count,
                                oep_object_info_t* out_object);

/* Deletes the Engineering Object identified by `object_id`. Fails
   with OEP_ERROR_NOT_FOUND if no such object exists. Does not cascade
   to Relationships referencing the deleted object — this mirrors
   ObjectStore::remove's own existing behavior and is not a new
   restriction introduced by this API. */
oep_result_t oep_object_delete(OEP_Runtime runtime, const char* object_id);

/* AP-DS-002. Replaces `content` on the object identified by
   `object_id`; every other field (name, description, author, tags,
   object_type, created timestamp) is left unchanged — unlike
   oep_object_update, which always replaces the full editable field
   set. `content` is an opaque, application-owned payload: Foundation
   never parses or interprets it (see EngineeringObject::content's own
   doc comment). `content` may be NULL, treated as empty. Fails with
   OEP_ERROR_NOT_FOUND if no object with `object_id` exists. On
   success, `out_object` (if non-NULL) is populated with the updated
   object. */
oep_result_t oep_object_update_content(OEP_Runtime runtime, const char* object_id, const char* content,
                                        oep_object_info_t* out_object);

/* AP-DS-002. Returns the `content` payload of the object identified by
   `object_id` — the counterpart read to oep_object_update_content,
   kept as a dedicated call rather than added to oep_object_info_t
   because content is unbounded, unlike every other fixed-layout field
   on that struct (the same reasoning already applied to
   oep_kge_export_json's ownership contract). Fails with
   OEP_ERROR_NOT_FOUND if no object with `object_id` exists. `runtime`,
   `object_id`, `out_text`, and `out_length` must not be NULL.

   Ownership: on success, the caller owns `*out_text` and must release
   it with exactly one call to oep_string_release. `*out_length` is the
   string's length in bytes, excluding the NUL terminator. An object
   with no content (including every object that predates AP-DS-002)
   returns success with `*out_text` set to an empty, owned string, not
   OEP_ERROR_NOT_FOUND. */
oep_result_t oep_object_get_content(OEP_Runtime runtime, const char* object_id, char** out_text, size_t* out_length);

/* ------------------------------------------------------------------ */
/* Relationship Mutation (Work Package 014, TASK-000028)               */
/* ------------------------------------------------------------------ */

/* Creates a new Relationship between two existing Engineering Objects.
   `source_object_id`/`target_object_id` must not be NULL. Fails with
   OEP_ERROR_NOT_FOUND if either referenced object does not exist, or
   OEP_ERROR_INVALID_ARGUMENT if the relationship is otherwise invalid
   (e.g. source equals target) — both checks are performed by
   RelationshipStore::create itself, not duplicated here.
   `author`/`description` may be NULL, treated as empty. Only valid
   from RepositoryOpen. On success, `out_relationship` (if non-NULL)
   is populated with the created relationship. */
oep_result_t oep_relationship_create(OEP_Runtime runtime, const char* source_object_id,
                                      const char* target_object_id, oep_relationship_type_t relationship_type,
                                      const char* author, const char* description,
                                      oep_relationship_info_t* out_relationship);

/* Replaces author/description on the relationship identified by
   `relationship_id`. relationship_id, source_object_id,
   target_object_id, relationship_type, and the relationship's created
   timestamp are never changed — matching RelationshipStore::update's
   own contract exactly. Fails with OEP_ERROR_NOT_FOUND if no
   relationship with `relationship_id` exists. */
oep_result_t oep_relationship_update(OEP_Runtime runtime, const char* relationship_id, const char* author,
                                      const char* description, oep_relationship_info_t* out_relationship);

/* Deletes the Relationship identified by `relationship_id`. Fails
   with OEP_ERROR_NOT_FOUND if no such relationship exists. */
oep_result_t oep_relationship_delete(OEP_Runtime runtime, const char* relationship_id);

/* ------------------------------------------------------------------ */
/* Diagram/Graph Identity and Membership                               */
/* (AP-OEP-FOUNDATION-GRAPH-IDENTITY-001, OEP_API_VERSION 21)          */
/* ------------------------------------------------------------------ */
/*
 * A "diagram" (a persisted, named subset of Engineering Objects/
 * Relationships an application such as OEP Studio's Diagram Studio
 * committed together) is an ordinary Engineering Object of type
 * OEP_OBJECT_TYPE_DIAGRAM — not a new primitive, not a new store, not a
 * new identity system. Its object_id (created like any other object's)
 * IS its diagram/graph identity. Membership is recorded via the
 * `diagram_id` field now present on oep_object_info_t/
 * oep_relationship_info_t: empty for an object/relationship that
 * belongs to no diagram (every object/relationship that predates this
 * version, and every one created by the pre-existing oep_object_create/
 * oep_relationship_create, which never populates it).
 *
 * Deliberately named "diagram," not "graph": this repository already
 * has an unrelated, whole-repository, never-persisted traversal concept
 * called a graph (see the Knowledge Graph / Graph Traversal API
 * elsewhere in this header) — reusing that word here for a persisted,
 * named *subset* would collide with it in name only.
 *
 * Referential integrity: oep_object_create_with_diagram/
 * oep_relationship_create_with_diagram both validate that `diagram_id`
 * names an existing OEP_OBJECT_TYPE_DIAGRAM object before persisting
 * anything, failing the whole call with OEP_ERROR_INVALID_ARGUMENT
 * otherwise — a diagram_id is never fabricated or silently accepted.
 * Foundation does not currently cascade-delete or reference-count
 * across this relationship (deleting a diagram object leaves its
 * members' diagram_id pointing at a now-nonexistent object) — this
 * matches the pre-existing, accepted behavior of
 * oep_object_delete/oep_relationship_delete, which likewise do not
 * cascade or reference-count relationship endpoints.
 */

/* Creates a new diagram/graph identity — an OEP_OBJECT_TYPE_DIAGRAM
   Engineering Object. A thin, dedicated entry point rather than
   requiring every caller to remember "call oep_object_create with
   OEP_OBJECT_TYPE_DIAGRAM" — delegates to the exact same creation path
   internally. `name` must not be NULL. `description`/`author` may be
   NULL, treated as empty. Only valid from RepositoryOpen. On success,
   `out_diagram` (if non-NULL) is populated with the created object,
   including its generated object_id (the diagram's identity). */
oep_result_t oep_diagram_create(OEP_Runtime runtime, const char* name, const char* description, const char* author,
                                 oep_object_info_t* out_diagram);

/* Loads the diagram identified by `diagram_id`. Fails with
   OEP_ERROR_NOT_FOUND if no object with that id exists, or if an
   object with that id exists but is not OEP_OBJECT_TYPE_DIAGRAM (never
   silently treated as a valid graph scope). */
oep_result_t oep_diagram_get(OEP_Runtime runtime, const char* diagram_id, oep_object_info_t* out_diagram);

/* Same contract as oep_object_create, plus: `diagram_id` must name an
   existing diagram (see this section's own referential-integrity note)
   — fails with OEP_ERROR_INVALID_ARGUMENT if it does not, and nothing
   is persisted. `diagram_id` must not be NULL (pass an empty string,
   never NULL, for "no diagram" — use plain oep_object_create for that
   case instead). On success, the created object's diagram_id equals
   `diagram_id`. */
oep_result_t oep_object_create_with_diagram(OEP_Runtime runtime, oep_object_type_t object_type, const char* name,
                                             const char* description, const char* author, const char* const* tags,
                                             int tag_count, const char* diagram_id, oep_object_info_t* out_object);

/* Same contract as oep_relationship_create, plus: `diagram_id` must
   name an existing diagram, exactly as oep_object_create_with_diagram
   requires. */
oep_result_t oep_relationship_create_with_diagram(OEP_Runtime runtime, const char* source_object_id,
                                                   const char* target_object_id,
                                                   oep_relationship_type_t relationship_type, const char* author,
                                                   const char* description, const char* diagram_id,
                                                   oep_relationship_info_t* out_relationship);

/* Enumerates the Engineering Objects belonging to `diagram_id`,
   deterministically sorted by object_id (ascending, byte-wise) — the
   same ordering guarantee as oep_object_store_list. Fails with
   OEP_ERROR_INVALID_ARGUMENT if `diagram_id` does not name an existing
   diagram (distinguishable from a valid, empty diagram: an empty
   `*out_objects` with a success result). Ownership: release with
   exactly one call to oep_object_list_release. */
oep_result_t oep_diagram_get_objects(OEP_Runtime runtime, const char* diagram_id, oep_object_list_t* out_objects);

/* Enumerates the Relationships belonging to `diagram_id`, same
   determinism/ownership contract as oep_diagram_get_objects — release
   with oep_relationship_list_release. */
oep_result_t oep_diagram_get_relationships(OEP_Runtime runtime, const char* diagram_id,
                                            oep_relationship_list_t* out_relationships);

/* ------------------------------------------------------------------ */
/* Transactions (Work Package 014, TASK-000029)                        */
/* ------------------------------------------------------------------ */
/*
 * A transaction groups object/relationship mutations into one
 * deterministically reversible unit. Only one transaction may be
 * active per OEP_Runtime handle at a time — nested
 * oep_transaction_begin() calls fail with OEP_ERROR_INVALID_STATE
 * rather than silently stacking.
 *
 * Each mutation still writes to the repository immediately when
 * called (Foundation's stores have no staged/uncommitted write
 * concept); while a transaction is active, Foundation additionally
 * records what each successful mutation would need to undo it.
 * oep_transaction_commit() discards that record (nothing further to
 * do — every mutation already persisted). oep_transaction_rollback()
 * replays the record in reverse, undoing each mutation via the same
 * stores a normal mutation would use.
 *
 * If any object or relationship mutation function above fails while a
 * transaction is active, Foundation automatically rolls back and
 * deactivates the transaction before returning the failure — the
 * caller does not need to (but safely may) call
 * oep_transaction_rollback() afterward.
 *
 * Closing the repository or shutting down the Runtime while a
 * transaction is active automatically rolls it back first.
 */

/* Begins a new transaction. Only valid from RepositoryOpen; fails
   with OEP_ERROR_INVALID_STATE if no repository is open or a
   transaction is already active. */
oep_result_t oep_transaction_begin(OEP_Runtime runtime);

/* Commits the active transaction (discarding its undo record; every
   mutation within it is already persisted). Fails with
   OEP_ERROR_INVALID_STATE if no transaction is currently active. */
oep_result_t oep_transaction_commit(OEP_Runtime runtime);

/* Rolls back the active transaction, undoing every mutation performed
   since oep_transaction_begin() in reverse order. Fails with
   OEP_ERROR_INVALID_STATE if no transaction is currently active. */
oep_result_t oep_transaction_rollback(OEP_Runtime runtime);

/* Returns nonzero iff a transaction is currently active on `runtime`.
   Never fails; returns 0 if `runtime` is NULL. */
int oep_transaction_is_active(OEP_Runtime runtime);

/* ------------------------------------------------------------------ */
/* Batch Mutation (Work Package 014, TASK-000030)                      */
/* ------------------------------------------------------------------ */
/*
 * Batch mutation is a convenience over the transaction primitives
 * above: every spec is created in array order (the deterministic
 * execution order this section requires), inside a transaction. If no
 * transaction is active when the batch function is called, one is
 * begun and committed automatically around the whole batch; if the
 * caller already has a transaction active, the batch participates in
 * it. Any failure rolls back the complete batch (and, if the caller
 * already had a transaction active going in, everything else in that
 * transaction too — the transaction, not the batch call, is the unit
 * of rollback).
 *
 * `specs`/`created` hold `const char*` fields, not fixed buffers:
 * these are input-only structures the caller populates and Foundation
 * only reads for the duration of the call — no ownership transfer,
 * and still no STL/C++ types cross the boundary.
 */

/* One object to create as part of a batch. `name` must not be NULL;
   `description`/`author` may be NULL (treated as empty); `tags` may
   be NULL iff `tag_count` is 0. The caller retains ownership of every
   pointer; Foundation only reads them for the duration of the
   oep_batch_create_objects call. */
typedef struct oep_object_create_spec_t {
    oep_object_type_t object_type;
    const char* name;
    const char* description;
    const char* author;
    const char* const* tags;
    int tag_count;
} oep_object_create_spec_t;

/* `created` is in execution order (the same order as the input
   `specs` array) — it is deliberately NOT sorted by object_id the way
   oep_object_store_list is, since preserving input/execution order is
   exactly the determinism guarantee this section requires. On
   failure, `created` is always empty (items = NULL, count = 0): the
   whole batch was rolled back. */
typedef struct oep_batch_create_objects_result_t {
    int success;
    /* -1 on full success; otherwise the 0-based index into the input
       `specs` array of the item that failed. */
    int failed_index;
    oep_object_list_t created;
} oep_batch_create_objects_result_t;

/* Creates every object in `specs` (an array of `count` specs) in
   order, inside a transaction (see "Batch Mutation" above for the
   begin/commit/rollback semantics). Only valid from RepositoryOpen.
   `specs` must not be NULL if `count` > 0. `out_result` must not be
   NULL.

   Ownership: on success, the caller owns `out_result->created.items`
   and must release it with exactly one call to
   oep_batch_create_objects_result_release. */
oep_result_t oep_batch_create_objects(OEP_Runtime runtime, const oep_object_create_spec_t* specs, int count,
                                       oep_batch_create_objects_result_t* out_result);

/* Releases the heap array owned by `result->created` (if any) and
   zeroes it. Safe to call on a zero-initialized or already-released
   result, and safe to call with `result == NULL` (both no-ops). */
void oep_batch_create_objects_result_release(oep_batch_create_objects_result_t* result);

/* One relationship to create as part of a batch.
   `source_object_id`/`target_object_id` must not be NULL;
   `author`/`description` may be NULL (treated as empty). The caller
   retains ownership of every pointer. */
typedef struct oep_relationship_create_spec_t {
    const char* source_object_id;
    const char* target_object_id;
    oep_relationship_type_t relationship_type;
    const char* author;
    const char* description;
} oep_relationship_create_spec_t;

/* Same execution-order and rollback-on-failure contract as
   oep_batch_create_objects_result_t. */
typedef struct oep_batch_create_relationships_result_t {
    int success;
    int failed_index;
    oep_relationship_list_t created;
} oep_batch_create_relationships_result_t;

/* Creates every relationship in `specs` (an array of `count` specs)
   in order, inside a transaction. Same semantics as
   oep_batch_create_objects. Ownership: release with
   oep_batch_create_relationships_result_release. */
oep_result_t oep_batch_create_relationships(OEP_Runtime runtime, const oep_relationship_create_spec_t* specs,
                                             int count, oep_batch_create_relationships_result_t* out_result);

/* Releases the heap array owned by `result->created` (if any) and
   zeroes it. Safe to call on a zero-initialized or already-released
   result, and safe to call with `result == NULL` (both no-ops). */
void oep_batch_create_relationships_result_release(oep_batch_create_relationships_result_t* result);

/* ------------------------------------------------------------------ */
/* Package Installation (WP-REP-001 -- Repository Runtime, first        */
/* vertical slice; OEP-ARCH-002)                                        */
/* ------------------------------------------------------------------ */
/*
 * Installs a validated .oep package archive (PKG-001/PKG-002) into the
 * currently open repository: extracts its Repository Fragment's
 * Engineering Objects and Relationships, creates them through the same
 * ObjectStore/RelationshipStore paths oep_object_create/
 * oep_relationship_create already use, records the install in the
 * Package Registry, and rebuilds the Search/Graph indexes.
 *
 * Deliberately NOT transactional: a failure partway through does not roll
 * back objects/relationships already created (see
 * oep::runtime::FoundationRuntime::install_package's own documentation).
 * Dependency resolution, digital signature verification, updates, and
 * uninstallation are not part of this surface -- see OEP-ARCH-002 for the
 * roadmap. Only ZIP archives using the "Stored" (uncompressed) entry
 * method can currently be read; a DEFLATE-compressed .oep archive fails
 * with OEP_ERROR_OPERATION_FAILED -- see platform/installer's own
 * documented limitation.
 */

#define OEP_MAX_PACKAGE_ID 256
#define OEP_MAX_PACKAGE_VERSION 32
#define OEP_MAX_PACKAGE_TITLE 256
#define OEP_MAX_PACKAGE_SOURCE 32

/* The outcome of a successful oep_package_install call. Not populated
   (zero-initialized) when the call fails -- see oep_result_t for the
   failure reason. */
typedef struct oep_package_install_result_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    int objects_created;
    int relationships_created;
} oep_package_install_result_t;

/* Installs the .oep archive at `archive_path` (NUL-terminated UTF-8,
   filesystem path) into the currently open repository. Only valid from
   RepositoryOpen; fails with OEP_ERROR_INVALID_STATE otherwise. Fails with
   OEP_ERROR_OPERATION_FAILED if the archive cannot be read/parsed, its
   manifest is invalid, or a package with the same packageId is already
   installed. `archive_path` must not be NULL. `out_result` may be NULL;
   if non-NULL, it is populated on success and zero-initialized on
   failure. */
oep_result_t oep_package_install(OEP_Runtime runtime, const char* archive_path,
                                  oep_package_install_result_t* out_result);

/* A deterministic, fixed-layout snapshot of one installed package's
   Package Registry record -- no pointers, safe to copy by value or
   convert directly into a language-native model. */
typedef struct oep_installed_package_info_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    char title[OEP_MAX_PACKAGE_TITLE];
    char installed_utc[OEP_MAX_TIMESTAMP];
    char source[OEP_MAX_PACKAGE_SOURCE];
    int object_count;
    int relationship_count;
} oep_installed_package_info_t;

/* An enumerated collection of installed packages. `items` is a
   Foundation-owned heap array of `count` elements, sorted deterministically
   by package_id (ascending, byte-wise). Follows the same ownership model
   as oep_object_list_t (Work Package 012, TASK-000023). */
typedef struct oep_installed_package_list_t {
    oep_installed_package_info_t* items;
    int count;
} oep_installed_package_list_t;

/* Enumerates every package the Package Registry has recorded as installed
   in the currently open repository, sorted deterministically by
   package_id. Only valid from RepositoryOpen; fails with
   OEP_ERROR_INVALID_STATE otherwise, in which case `*out_list` is
   zero-initialized. `out_list` must not be NULL.

   Ownership: on success, the caller owns `out_list->items` and must
   release it with exactly one call to
   oep_installed_package_list_release. */
oep_result_t oep_package_list_installed(OEP_Runtime runtime, oep_installed_package_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes
   `list->items`/`list->count`. Safe to call on a zero-initialized or
   already-released list. `list` itself may be NULL (a no-op). */
void oep_installed_package_list_release(oep_installed_package_list_t* list);

/* ------------------------------------------------------------------ */
/* Package Lifecycle Queries (WP-REP-002 -- Repository Registry &       */
/* Lifecycle)                                                           */
/* ------------------------------------------------------------------ */
/*
 * Read-only queries over the Repository Registry -- the authoritative
 * inventory of every .oep package installed in the currently open
 * Foundation Repository. None of these functions mutate anything;
 * update, uninstall, and activation remain out of scope through
 * WP-REP-002. All require RepositoryOpen and fail with
 * OEP_ERROR_INVALID_STATE otherwise.
 */

#define OEP_MAX_PACKAGE_SUMMARY 512
#define OEP_MAX_PACKAGE_CATEGORY 64
#define OEP_MAX_PACKAGE_PUBLISHER 128
#define OEP_MAX_PACKAGE_HASH 72
#define OEP_MAX_PACKAGE_PATH 512
#define OEP_MAX_PACKAGE_STATE 32
#define OEP_MAX_PACKAGE_DOMAINS 8
#define OEP_MAX_PACKAGE_DOMAIN_LENGTH 64

/* The full Repository Registry record for one installed package -- a
   deterministic, fixed-layout, pointer-free superset of
   oep_installed_package_info_t (which is retained unchanged for ABI
   compatibility with OEP_API_VERSION 5 callers). String fields are
   truncated (never overflowed) if longer than the field's capacity;
   `engineering_domain_count` is capped at OEP_MAX_PACKAGE_DOMAINS. */
typedef struct oep_package_details_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    char title[OEP_MAX_PACKAGE_TITLE];
    char summary[OEP_MAX_PACKAGE_SUMMARY];
    char category[OEP_MAX_PACKAGE_CATEGORY];
    char publisher_id[OEP_MAX_PACKAGE_PUBLISHER];
    char publisher_name[OEP_MAX_PACKAGE_PUBLISHER];
    char installed_utc[OEP_MAX_TIMESTAMP];
    char source[OEP_MAX_PACKAGE_SOURCE];
    /* Absolute path of the source .oep archive at install time. The
       archive may have been deleted since; see oep_package_verify. */
    char installation_path[OEP_MAX_PACKAGE_PATH];
    /* SHA-256 hex digest of the archive's bytes at install time. An
       integrity fingerprint only -- NOT a signature or trust mechanism
       (signature verification is a future work package, PKG-005). */
    char package_hash[OEP_MAX_PACKAGE_HASH];
    /* Always "Installed" through WP-REP-002; other PKG-008 lifecycle
       states require update/uninstall/activation functionality that
       does not exist yet. */
    char runtime_state[OEP_MAX_PACKAGE_STATE];
    int engineering_domain_count;
    char engineering_domains[OEP_MAX_PACKAGE_DOMAINS][OEP_MAX_PACKAGE_DOMAIN_LENGTH];
    int object_count;
    int relationship_count;
} oep_package_details_t;

/* Populates `out_details` with the Repository Registry record for
   `package_id`. Fails with OEP_ERROR_NOT_FOUND if no package with that
   ID is installed, in which case `*out_details` is zero-initialized.
   `package_id` and `out_details` must not be NULL. No allocation --
   plain value type, no release function. */
oep_result_t oep_package_get_info(OEP_Runtime runtime, const char* package_id, oep_package_details_t* out_details);

/* Populates `out_objects`/`out_relationships` with the full Engineering
   Objects and Relationships the package identified by `package_id`
   contributed to the repository, loaded live from the repository's own
   stores (the Repository Registry records only their IDs -- Engineering
   Object data is never duplicated into it). An object/relationship that
   was recorded but has since been deleted from the repository is simply
   absent from the returned lists -- use oep_package_verify to detect
   that condition explicitly. Fails with OEP_ERROR_NOT_FOUND if no
   package with that ID is installed.

   Ownership: on success the caller owns both lists and must release
   them with exactly one call each to oep_object_list_release and
   oep_relationship_list_release -- the same release functions every
   other object/relationship list in this API already uses. */
oep_result_t oep_package_get_contents(OEP_Runtime runtime, const char* package_id, oep_object_list_t* out_objects,
                                       oep_relationship_list_t* out_relationships);

/* The kind of entity oep_package_locate resolved. */
typedef enum oep_owned_entity_kind_t {
    OEP_OWNED_ENTITY_NONE = 0,
    OEP_OWNED_ENTITY_OBJECT = 1,
    OEP_OWNED_ENTITY_RELATIONSHIP = 2,
} oep_owned_entity_kind_t;

/* The outcome of oep_package_locate: which installed package (if any)
   contributed the entity. Plain value type, no release function. */
typedef struct oep_package_owner_t {
    /* Nonzero iff some installed package owns the entity; the fields
       below are only meaningful when nonzero. */
    int found;
    oep_owned_entity_kind_t kind;
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    char title[OEP_MAX_PACKAGE_TITLE];
} oep_package_owner_t;

/* Looks up which installed package contributed the Engineering Object
   or Relationship identified by `entity_id`. An entity no installed
   package owns (including one that doesn't exist at all) succeeds with
   `out_owner->found == 0` -- that is a normal answer, not an error.
   `entity_id` and `out_owner` must not be NULL. */
oep_result_t oep_package_locate(OEP_Runtime runtime, const char* entity_id, oep_package_owner_t* out_owner);

/* The outcome of oep_package_verify. Plain value type, no release
   function. `verified` is nonzero iff every contribution the Repository
   Registry recorded for the package still exists in the repository,
   AND -- when the source archive still exists at its recorded
   installation path -- its bytes still hash to the recorded SHA-256.
   A missing archive is NOT a verification failure (archives are
   transport, not the installed content), only reported via
   `archive_available == 0`. */
typedef struct oep_package_verify_result_t {
    int verified;
    int objects_expected;
    int objects_present;
    int relationships_expected;
    int relationships_present;
    int archive_available;
    /* Only meaningful when archive_available is nonzero. */
    int archive_hash_matches;
} oep_package_verify_result_t;

/* Verifies the installation status of `package_id` against live
   repository state. Fails with OEP_ERROR_NOT_FOUND if no package with
   that ID is installed. A package that IS installed but fails
   verification still returns success -- the verification outcome is in
   `out_result->verified`, not the oep_result_t. `package_id` and
   `out_result` must not be NULL. */
oep_result_t oep_package_verify(OEP_Runtime runtime, const char* package_id,
                                 oep_package_verify_result_t* out_result);

/* Searches installed packages for `query` (case-insensitive substring
   match over package ID, title, summary, category, version, publisher,
   engineering domains, and the names of the Engineering Objects each
   package installed). Fails with OEP_ERROR_INVALID_ARGUMENT for a NULL
   or empty query -- a valid, non-matching query still succeeds with a
   zero-length list. Results are sorted deterministically by package_id
   (ascending, byte-wise), matching oep_package_list_installed.

   Ownership: release with oep_installed_package_list_release, exactly
   as for oep_package_list_installed. */
oep_result_t oep_package_search(OEP_Runtime runtime, const char* query, oep_installed_package_list_t* out_list);

/* ------------------------------------------------------------------ */
/* Repository Transaction Engine (WP-REP-003)                          */
/* ------------------------------------------------------------------ */
/*
 * WP-REP-003 upgraded the transaction primitives above (Work Package
 * 014's oep_transaction_begin/_commit/_rollback/_is_active — every
 * signature unchanged) into the Repository Transaction Engine: every
 * transaction now has a UUIDv4 identity, every Runtime write outside an
 * explicit transaction runs inside an implicit one, and every closed
 * transaction writes a permanent journal record under the open
 * repository's `logs/transactions/` directory (PKG-003 §15/§26).
 * oep_package_install is atomic since this version: a failure rolls back
 * every object/relationship it had created, superseding WP-REP-001/002's
 * documented non-transactional behavior.
 *
 * One behavior change to oep_transaction_commit, documented rather than
 * hidden: it can now fail in exactly one new way — the journal record
 * could not be written. The mutations themselves are already persisted
 * in that case; the error exists so a caller knows the audit trail is
 * incomplete, never to signal data loss.
 */

#define OEP_MAX_TRANSACTION_ID 64
#define OEP_MAX_TRANSACTION_STATE 16
#define OEP_MAX_TRANSACTION_DESCRIPTION 128

/* The active transaction's identity and progress. Plain value type, no
   release function. `active == 0` (with a successful oep_result_t)
   means no transaction is open — a normal answer, not an error; every
   other field is only meaningful when `active` is nonzero. */
typedef struct oep_transaction_info_t {
    int active;
    char transaction_id[OEP_MAX_TRANSACTION_ID];
    char description[OEP_MAX_TRANSACTION_DESCRIPTION];
    int journal_entry_count;
} oep_transaction_info_t;

/* Populates `out_info` with the currently active transaction (if any).
   Only valid from RepositoryOpen. `out_info` must not be NULL. */
oep_result_t oep_transaction_get_info(OEP_Runtime runtime, oep_transaction_info_t* out_info);

/* One journaled (closed) transaction. `state` is one of "Committed",
   "RolledBack", or "Failed" (a rollback that could not fully complete).
   Plain value type. */
typedef struct oep_transaction_record_t {
    char transaction_id[OEP_MAX_TRANSACTION_ID];
    char state[OEP_MAX_TRANSACTION_STATE];
    char description[OEP_MAX_TRANSACTION_DESCRIPTION];
    char opened_utc[OEP_MAX_TIMESTAMP];
    char closed_utc[OEP_MAX_TIMESTAMP];
    int journal_entry_count;
} oep_transaction_record_t;

/* `items` is a Foundation-owned heap array, sorted deterministically by
   opened time then transaction id. Follows the same ownership model as
   every other *_list_t in this API. */
typedef struct oep_transaction_record_list_t {
    oep_transaction_record_t* items;
    int count;
} oep_transaction_record_list_t;

/* Enumerates every journaled transaction for the open repository. Only
   valid from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE
   otherwise, in which case `*out_list` is zero-initialized. `out_list`
   must not be NULL.

   Ownership: on success, the caller owns `out_list->items` and must
   release it with exactly one call to
   oep_transaction_record_list_release. */
oep_result_t oep_transaction_history(OEP_Runtime runtime, oep_transaction_record_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_transaction_record_list_release(oep_transaction_record_list_t* list);

/* ------------------------------------------------------------------ */
/* Trust & Signing (WP-REP-004 -- Repository Trust & Signing            */
/* Subsystem)                                                           */
/* ------------------------------------------------------------------ */
/*
 * Per PKG-005 (Package Trust & Digital Signature): every .oep package is
 * verified -- offline, against this repository's own Trust Store of
 * locally trusted publisher certificates -- before installation.
 * oep_package_install (see "Package Installation" above) now performs
 * this verification BEFORE any Repository Transaction begins; a package
 * that is Tampered, has an InvalidSignature, an UnknownPublisher, an
 * ExpiredCertificate, or a RevokedCertificate is rejected outright, with
 * no transaction ever opened. An Unsigned package installs exactly as
 * before UNLESS this repository's trust policy requires signatures
 * (oep_trust_get_policy/oep_trust_set_policy) -- preserving every
 * earlier work package's default unsigned-install behavior.
 *
 * The Trust Store holds certificates entirely locally: there is no
 * certificate authority, online revocation feed, or Engineering Exchange
 * call anywhere in this section (PKG-005 §3: "Verification shall never
 * require access to the Engineering Exchange"). A certificate is trusted
 * by explicit local action (oep_trust_add_certificate) and revoked the
 * same way (oep_trust_revoke_certificate) -- both are local repository
 * writes, not Repository Transactions (they touch `settings/trust/`, not
 * Engineering Objects/Relationships).
 */

typedef enum oep_trust_state_t {
    OEP_TRUST_TRUSTED = 0,
    OEP_TRUST_UNSIGNED = 1,
    OEP_TRUST_UNKNOWN_PUBLISHER = 2,
    OEP_TRUST_EXPIRED_CERTIFICATE = 3,
    OEP_TRUST_REVOKED_CERTIFICATE = 4,
    OEP_TRUST_INVALID_SIGNATURE = 5,
    OEP_TRUST_TAMPERED = 6,
} oep_trust_state_t;

/* Returns a static, human-readable name for `state` (e.g. "Trusted",
   "RevokedCertificate"). Never freed by the caller. Deterministic. */
const char* oep_trust_state_to_string(oep_trust_state_t state);

#define OEP_MAX_PUBLISHER_ID 128
#define OEP_MAX_PUBLISHER_NAME 128
#define OEP_MAX_PUBLIC_KEY_HEX 65
#define OEP_MAX_CERT_ISSUER 128
#define OEP_MAX_CERT_VERSION 16
#define OEP_MAX_FINGERPRINT 65

/* One trusted publisher certificate (PKG-005 §7). Plain, pointer-free
   value type. `fingerprint` is always computed by the Trust Store itself
   (SHA-256 of the raw public key), never taken from caller input. */
typedef struct oep_publisher_certificate_t {
    char publisher_id[OEP_MAX_PUBLISHER_ID];
    char publisher_name[OEP_MAX_PUBLISHER_NAME];
    char public_key_hex[OEP_MAX_PUBLIC_KEY_HEX]; /* 64 hex chars = raw 32-byte Ed25519 public key */
    char issued_utc[OEP_MAX_TIMESTAMP];
    char expires_utc[OEP_MAX_TIMESTAMP]; /* empty = never expires */
    char issuer[OEP_MAX_CERT_ISSUER];
    char version[OEP_MAX_CERT_VERSION];
    char fingerprint[OEP_MAX_FINGERPRINT];
    int revoked;
    char revoked_utc[OEP_MAX_TIMESTAMP];
} oep_publisher_certificate_t;

/* Adds (trusts) a publisher certificate to this repository's Trust
   Store. `publisher_id` and `public_key_hex` (exactly 64 hex characters)
   must not be NULL; `publisher_name`/`issued_utc`/`expires_utc`/
   `issuer`/`version` may be NULL, treated as empty. Fails with
   OEP_ERROR_OPERATION_FAILED if the publisher already has a certificate
   (renewal is not part of this Work Package) or the public key is
   malformed. On success, `out_certificate` (if non-NULL) is populated
   with the stored certificate, including its computed fingerprint. Only
   valid from RepositoryOpen. */
oep_result_t oep_trust_add_certificate(OEP_Runtime runtime, const char* publisher_id, const char* publisher_name,
                                        const char* public_key_hex, const char* issued_utc, const char* expires_utc,
                                        const char* issuer, const char* version,
                                        oep_publisher_certificate_t* out_certificate);

/* Populates `out_certificate` with the certificate trusted for
   `publisher_id`. Fails with OEP_ERROR_NOT_FOUND if no certificate is
   on file for that publisher. Only valid from RepositoryOpen. */
oep_result_t oep_trust_get_certificate(OEP_Runtime runtime, const char* publisher_id,
                                        oep_publisher_certificate_t* out_certificate);

/* `items` is a Foundation-owned heap array, sorted deterministically by
   publisher_id. Follows the same ownership model as every other *_list_t
   in this API. */
typedef struct oep_certificate_list_t {
    oep_publisher_certificate_t* items;
    int count;
} oep_certificate_list_t;

/* Enumerates every certificate in this repository's Trust Store
   (trusted and revoked alike -- check each entry's `revoked` field).
   Only valid from RepositoryOpen.

   Ownership: on success, the caller owns `out_list->items` and must
   release it with exactly one call to oep_certificate_list_release. */
oep_result_t oep_trust_list_certificates(OEP_Runtime runtime, oep_certificate_list_t* out_list);

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_certificate_list_release(oep_certificate_list_t* list);

/* Marks `publisher_id`'s certificate revoked. The certificate record is
   kept (PKG-005 §12/§13's retained-trust-history model) with
   `revoked = 1` and `revoked_utc` set -- this does not uninstall any
   package already installed from that publisher (uninstall is out of
   scope). Fails with OEP_ERROR_NOT_FOUND if no certificate is on file,
   or OEP_ERROR_OPERATION_FAILED if it is already revoked. Only valid
   from RepositoryOpen. */
oep_result_t oep_trust_revoke_certificate(OEP_Runtime runtime, const char* publisher_id);

/* Populates `*out_require_signatures` with this repository's trust
   policy: nonzero iff unsigned packages are rejected at install. The
   default (a fresh repository, or one where the policy was never set)
   is 0 -- unsigned packages install, matching every earlier work
   package's behavior. Only valid from RepositoryOpen. */
oep_result_t oep_trust_get_policy(OEP_Runtime runtime, int* out_require_signatures);

/* Sets this repository's trust policy. Only valid from RepositoryOpen. */
oep_result_t oep_trust_set_policy(OEP_Runtime runtime, int require_signatures);

/* The trust outcome recorded for an installed package. Plain value
   type, no release function. */
typedef struct oep_package_trust_status_t {
    oep_trust_state_t state;
    char fingerprint[OEP_MAX_FINGERPRINT]; /* empty unless a certificate was matched */
} oep_package_trust_status_t;

/* Populates `out_status` with the trust outcome recorded for
   `package_id` at install time (WP-REP-004; recorded once, not
   re-verified on demand -- PKG-005 §16's "revalidate at any time" is
   deferred). Fails with OEP_ERROR_NOT_FOUND if no package with that ID
   is installed. Only valid from RepositoryOpen. */
oep_result_t oep_package_get_trust_status(OEP_Runtime runtime, const char* package_id,
                                           oep_package_trust_status_t* out_status);

/* ------------------------------------------------------------------ */
/* Dependency Resolution (WP-REP-005 -- Dependency Resolution Engine)   */
/* ------------------------------------------------------------------ */
/*
 * Per PKG-004: resolves an archive's declared package dependencies
 * against the currently installed set. Provider-agnostic -- nothing
 * here knows or cares where a package came from -- and entirely
 * offline: this section never downloads, fetches, or contacts the
 * Engineering Exchange (PKG-004 §17/§18). oep_package_install (see
 * "Package Installation" above) now performs this resolution
 * automatically, AFTER trust verification and BEFORE any Repository
 * Transaction begins; oep_package_resolve_dependencies exposes the same
 * resolution as a standalone, side-effect-free query (a pure read
 * against the currently installed set -- it never modifies the
 * repository, per PKG-004 §2's "side-effect free" design principle),
 * usable as a pre-flight check or purely for diagnostics.
 */

typedef enum oep_dependency_state_t {
    OEP_DEPENDENCY_SATISFIED = 0,   /* installed, and its version satisfies the constraint */
    OEP_DEPENDENCY_MISSING = 1,     /* required, but not installed */
    OEP_DEPENDENCY_OPTIONAL = 2,    /* not installed, but the dependency itself is optional */
    OEP_DEPENDENCY_CONFLICTING = 3, /* installed, but its version does not satisfy the constraint */
    OEP_DEPENDENCY_CYCLIC = 4,      /* participates in a circular dependency chain */
    OEP_DEPENDENCY_UNKNOWN = 5,     /* could not be evaluated (e.g. a malformed version constraint) */
} oep_dependency_state_t;

/* Returns a static, human-readable name for `state` (e.g. "Satisfied",
   "Cyclic"). Never freed by the caller. Deterministic. */
const char* oep_dependency_state_to_string(oep_dependency_state_t state);

#define OEP_MAX_VERSION_CONSTRAINT 64

/* One resolved dependency (PKG-004 §6), in the candidate manifest's own
   declaration order. Plain, pointer-free value type. */
typedef struct oep_dependency_entry_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version_constraint[OEP_MAX_VERSION_CONSTRAINT]; /* empty means "any version" */
    int optional;
    oep_dependency_state_t state;
    char installed_version[OEP_MAX_PACKAGE_VERSION]; /* empty iff not installed */
} oep_dependency_entry_t;

/* `items` is a Foundation-owned heap array, in the candidate manifest's
   declaration order (deliberately NOT re-sorted -- PKG-004 §2
   "Deterministic" means reproducing the same input order, not imposing
   an unrelated one). Follows the same ownership model as every other
   *_list_t in this API. */
typedef struct oep_dependency_entry_list_t {
    oep_dependency_entry_t* items;
    int count;
} oep_dependency_entry_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_dependency_entry_list_release(oep_dependency_entry_list_t* list);

/* One package ID, fixed-layout -- used for the deterministic install
   order list below. */
typedef struct oep_package_id_t {
    char id[OEP_MAX_PACKAGE_ID];
} oep_package_id_t;

typedef struct oep_package_id_list_t {
    oep_package_id_t* items;
    int count;
} oep_package_id_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_package_id_list_release(oep_package_id_list_t* list);

#define OEP_MAX_CYCLE_DESCRIPTION 512

/* The overall resolution outcome. Plain value type, no release
   function. */
typedef struct oep_dependency_resolution_result_t {
    /* Nonzero iff every dependency resolved (PKG-004 §6's
       "Resolved" -- no Missing/Conflicting/Cyclic/Unknown entries). */
    int resolved;
    int cycle_detected;
    /* Human-readable cycle chain (e.g. "A -> B -> C -> A"); empty when
       cycle_detected is 0. */
    char cycle_description[OEP_MAX_CYCLE_DESCRIPTION];
} oep_dependency_resolution_result_t;

/* Resolves the .oep archive at `archive_path` (NUL-terminated UTF-8)
   against the currently open repository's installed packages, WITHOUT
   installing anything. Only valid from RepositoryOpen. Fails with
   OEP_ERROR_OPERATION_FAILED if the archive cannot be read/parsed or
   its manifest is invalid -- a resolution that fails on its OWN merits
   (a missing/conflicting/cyclic dependency) is not an API error; it
   still returns a successful oep_result_t, with the verdict in
   `out_result->resolved`. `archive_path` and `out_result` must not be
   NULL; `out_entries`/`out_install_order` may be NULL if the caller
   only needs the overall verdict.

   Ownership: on success, if non-NULL, the caller owns
   `out_entries->items` and `out_install_order->items` and must release
   them with exactly one call each to oep_dependency_entry_list_release
   and oep_package_id_list_release. */
oep_result_t oep_package_resolve_dependencies(OEP_Runtime runtime, const char* archive_path,
                                               oep_dependency_resolution_result_t* out_result,
                                               oep_dependency_entry_list_t* out_entries,
                                               oep_package_id_list_t* out_install_order);

/* ------------------------------------------------------------------ */
/* Package Lifecycle: Uninstall & Update (WP-REP-007)                  */
/* ------------------------------------------------------------------ */
/*
 * Two new package lifecycle operations built on top of Trust
 * (WP-REP-004), Dependency Resolution (WP-REP-005, PKG-004), and the
 * Repository Transaction Engine (WP-REP-003), each with an immutable,
 * side-effect-free Impact Report dry-run query. Per WP-REP-007, these
 * four functions are the exclusive entry point for uninstall/update —
 * unlike oep_package_install, they are routed through RuntimeService
 * only, not FoundationRuntime directly.
 */

#define OEP_MAX_TRUST_STATUS 32

/* The dry-run report oep_package_analyze_uninstall_impact produces.
   Plain value type, no release function; `blocking_dependents` is
   returned separately via the reused oep_package_id_list_t (see
   oep_package_id_list_release above). `removable` is nonzero iff
   `found` and `blocking_dependents` is empty -- oep_package_uninstall
   refuses to touch the repository unless removable would be nonzero. */
typedef struct oep_uninstall_impact_t {
    int found;
    int objects_affected;
    int relationships_affected;
    int removable;
} oep_uninstall_impact_t;

/* Analyzes the impact of uninstalling `package_id` without uninstalling
   anything. Only valid from RepositoryOpen. `package_id` and
   `out_impact` must not be NULL; `out_blocking_dependents` may be NULL
   if the caller only needs the summary counts/verdict. A package that
   is not currently installed is not an API error -- it still returns a
   successful oep_result_t, with `out_impact->found == 0`.

   Ownership: on success, if non-NULL, the caller owns
   `out_blocking_dependents->items` and must release it with exactly one
   call to oep_package_id_list_release. */
oep_result_t oep_package_analyze_uninstall_impact(OEP_Runtime runtime, const char* package_id,
                                                    oep_uninstall_impact_t* out_impact,
                                                    oep_package_id_list_t* out_blocking_dependents);

/* The outcome of a successful oep_package_uninstall call. Not populated
   (zero-initialized) when the call fails. */
typedef struct oep_package_uninstall_result_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    int objects_removed;
    int relationships_removed;
} oep_package_uninstall_result_t;

/* Uninstalls `package_id` from the currently open repository. Only
   valid from RepositoryOpen. Fails with OEP_ERROR_OPERATION_FAILED if
   the package is not installed, or if other installed packages have a
   required dependency on it (see oep_package_analyze_uninstall_impact).
   `package_id` must not be NULL. `out_result` may be NULL; if non-NULL,
   it is populated on success and zero-initialized on failure. */
oep_result_t oep_package_uninstall(OEP_Runtime runtime, const char* package_id,
                                    oep_package_uninstall_result_t* out_result);

/* The dry-run report oep_package_analyze_update_impact produces for
   replacing an installed package with a new version from an archive.
   Plain value type, no release function; `broken_dependents` is
   returned separately via the reused oep_package_id_list_t.
   `trust_status` is the human-readable name the candidate archive's
   trust verification would record (matching
   oep_trust_state_to_string's output), NOT an enum -- the underlying
   RuntimeService field is a plain string, not oep_trust_state_t.
   `updatable` is nonzero iff `currently_installed`, trust does not
   block the update, dependency resolution succeeds, and
   `broken_dependents` is empty.

   Scope note: the nested dependency resolution report
   (RuntimeUpdateImpactResult::dependency_report -- individual
   dependency entries and install order) is intentionally NOT exposed
   here to keep this surface focused; `updatable` and
   `broken_dependents` already summarize everything a caller needs to
   decide whether to proceed. Use oep_package_resolve_dependencies
   separately for the full per-dependency breakdown if needed. */
typedef struct oep_update_impact_t {
    int currently_installed;
    char current_version[OEP_MAX_PACKAGE_VERSION];
    char candidate_version[OEP_MAX_PACKAGE_VERSION];
    char trust_status[OEP_MAX_TRUST_STATUS];
    int updatable;
} oep_update_impact_t;

/* Analyzes the impact of updating the package declared by the archive
   at `archive_path` without updating anything. Only valid from
   RepositoryOpen. `archive_path` and `out_impact` must not be NULL;
   `out_broken_dependents` may be NULL if the caller only needs the
   summary/verdict. A package that is not currently installed is not an
   API error -- it still returns a successful oep_result_t, with
   `out_impact->currently_installed == 0`.

   Ownership: on success, if non-NULL, the caller owns
   `out_broken_dependents->items` and must release it with exactly one
   call to oep_package_id_list_release. */
oep_result_t oep_package_analyze_update_impact(OEP_Runtime runtime, const char* archive_path,
                                                 oep_update_impact_t* out_impact,
                                                 oep_package_id_list_t* out_broken_dependents);

/* The outcome of a successful oep_package_update call. Not populated
   (zero-initialized) when the call fails. `trust_status` follows the
   same convention as oep_update_impact_t's field of the same name. */
typedef struct oep_package_update_result_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char previous_version[OEP_MAX_PACKAGE_VERSION];
    char new_version[OEP_MAX_PACKAGE_VERSION];
    int objects_removed;
    int relationships_removed;
    int objects_created;
    int relationships_created;
    char trust_status[OEP_MAX_TRUST_STATUS];
} oep_package_update_result_t;

/* Replaces the installed package declared by the archive at
   `archive_path` with the candidate version in that archive. Only valid
   from RepositoryOpen. Fails with OEP_ERROR_OPERATION_FAILED if the
   package is not currently installed, trust verification blocks it, its
   dependencies cannot be resolved, or the update would break another
   installed package's required dependency on it (see
   oep_package_analyze_update_impact). `archive_path` must not be NULL.
   `out_result` may be NULL; if non-NULL, it is populated on success and
   zero-initialized on failure. */
oep_result_t oep_package_update(OEP_Runtime runtime, const char* archive_path,
                                 oep_package_update_result_t* out_result);

/* ------------------------------------------------------------------ */
/* Merge Engine (WP-REP-008)                                            */
/* ------------------------------------------------------------------ */
/*
 * Merges a package archive's Repository Fragment (objects/relationships)
 * into the currently open repository, generalizing oep_package_install:
 * rather than assuming the content is entirely new and failing hard on
 * the first collision, a merge is first PLANNED (side-effect-free) --
 * comparing every declared object/relationship against what already
 * exists -- producing a conflict-free RepositoryChangeSet plus a
 * deterministic list of conflicts for anything that already exists with
 * DIFFERENT content. Like Uninstall/Update (WP-REP-007), Merge is
 * RuntimeService-only by design: these two functions are routed through
 * RuntimeService exclusively, never FoundationRuntime directly.
 */

/* Mirrors oep::installer::MergeConflictKind. */
typedef enum oep_merge_conflict_kind_t {
    OEP_MERGE_CONFLICT_OBJECT_CONTENT = 0,
    OEP_MERGE_CONFLICT_RELATIONSHIP_CONTENT = 1,
    OEP_MERGE_CONFLICT_RELATIONSHIP_MISSING_ENDPOINT = 2,
} oep_merge_conflict_kind_t;

/* Returns a static, human-readable name for `kind` (e.g.
   "ObjectContentConflict"). Never returns NULL. */
const char* oep_merge_conflict_kind_to_string(oep_merge_conflict_kind_t kind);

/* One entry from oep::installer::MergePlan::conflicts, fixed-layout. */
typedef struct oep_merge_conflict_t {
    oep_merge_conflict_kind_t kind;
    char entity_id[OEP_MAX_OBJECT_ID];
    char detail[256];
} oep_merge_conflict_t;

typedef struct oep_merge_conflict_list_t {
    oep_merge_conflict_t* items;
    int count;
} oep_merge_conflict_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_merge_conflict_list_release(oep_merge_conflict_list_t* list);

/* The dry-run report oep_repository_plan_merge produces. Plain value
   type, no release function; `conflicts` is returned separately via
   oep_merge_conflict_list_t (see oep_merge_conflict_list_release above).
   `object_to_create`/`relationships_to_create` count
   plan.change_set.object_changes()/relationship_changes() -- always
   Create entries in this Work Package (see MergeConflictKind's doc
   comment). `mergeable` is nonzero iff trust does not block, dependency
   resolution succeeds, and the plan has no conflicts.

   Scope note: mirroring oep_update_impact_t's scope decision, the
   nested dependency resolution report and the full RepositoryChangeSet
   are intentionally NOT exposed here -- `mergeable` and `conflicts`
   already summarize everything a caller needs to decide whether to
   proceed. Use oep_package_resolve_dependencies separately for the full
   per-dependency breakdown if needed. */
typedef struct oep_merge_plan_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    char trust_status[OEP_MAX_TRUST_STATUS];
    int trust_blocks;
    int dependency_blocks;
    int already_registered;
    int objects_to_create;
    int relationships_to_create;
    int mergeable;
} oep_merge_plan_t;

/* Analyzes merging the archive at `archive_path` into the currently open
   repository, without merging anything. Only valid from RepositoryOpen.
   `archive_path` and `out_plan` must not be NULL; `out_conflicts` may be
   NULL if the caller only needs the summary/verdict. A plan that is not
   mergeable on its own merits (trust/dependency/conflicts/already
   registered) is not an API error -- it still returns a successful
   oep_result_t, with the verdict in `out_plan->mergeable`.

   Ownership: on success, if non-NULL, the caller owns
   `out_conflicts->items` and must release it with exactly one call to
   oep_merge_conflict_list_release. */
oep_result_t oep_repository_plan_merge(OEP_Runtime runtime, const char* archive_path, oep_merge_plan_t* out_plan,
                                        oep_merge_conflict_list_t* out_conflicts);

/* The outcome of a successful oep_repository_execute_merge call. Not
   populated (zero-initialized) when the call fails. */
typedef struct oep_merge_result_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    int objects_created;
    int relationships_created;
    char trust_status[OEP_MAX_TRUST_STATUS];
} oep_merge_result_t;

/* Merges the archive at `archive_path` into the currently open
   repository. Only valid from RepositoryOpen. Fails with
   OEP_ERROR_OPERATION_FAILED if the resulting plan is not mergeable
   (blocked by trust, by dependency resolution, or by any detected
   conflict) or if the package_id is already recorded in the Repository
   Registry (see oep_repository_plan_merge). `archive_path` must not be
   NULL. `out_result` may be NULL; if non-NULL, it is populated on
   success and zero-initialized on failure. */
oep_result_t oep_repository_execute_merge(OEP_Runtime runtime, const char* archive_path,
                                           oep_merge_result_t* out_result);

/* ------------------------------------------------------------------ */
/* Repository Events (WP-REP-006)                                      */
/* ------------------------------------------------------------------ */
/*
   Introduced alongside the Runtime Service orchestration layer
   (OEP-SPEC internal: RuntimeService/RuntimeContext, see
   platform/runtime/include/oep/runtime/runtime_service.hpp). Every
   Runtime instance now records a bounded, in-memory log of what
   RuntimeService has sequenced (package installs, object/relationship
   mutations, transactions, dependency resolutions) as it happens.
   This is infrastructure only: as of WP-REP-006 there is no
   subscription mechanism, in this API or internally -- nothing
   currently reacts to a published event. oep_runtime_recent_events
   lets a caller inspect the log for diagnostics; it does not deliver
   events as they occur. */

typedef enum oep_event_type_t {
    OEP_EVENT_OBJECT_CREATED = 0,
    OEP_EVENT_OBJECT_UPDATED = 1,
    OEP_EVENT_OBJECT_DELETED = 2,
    OEP_EVENT_RELATIONSHIP_CREATED = 3,
    OEP_EVENT_RELATIONSHIP_UPDATED = 4,
    OEP_EVENT_RELATIONSHIP_DELETED = 5,
    OEP_EVENT_TRANSACTION_BEGUN = 6,
    OEP_EVENT_TRANSACTION_COMMITTED = 7,
    OEP_EVENT_TRANSACTION_ROLLED_BACK = 8,
    OEP_EVENT_PACKAGE_INSTALLED = 9,
    OEP_EVENT_PACKAGE_INSTALL_FAILED = 10,
    OEP_EVENT_DEPENDENCY_RESOLUTION_COMPLETED = 11,
    OEP_EVENT_PACKAGE_UNINSTALLED = 12,
    OEP_EVENT_PACKAGE_UPDATED = 13,
    OEP_EVENT_REPOSITORY_MERGED = 14,
} oep_event_type_t;

/* Returns a static, human-readable name for `type` (e.g.
   "PackageInstalled"). Never returns NULL. */
const char* oep_event_type_to_string(oep_event_type_t type);

#define OEP_MAX_EVENT_SUBJECT_ID 256
#define OEP_MAX_EVENT_DETAIL 256
#define OEP_MAX_EVENT_TIMESTAMP 32

/* One published Repository Event, fixed-layout. `sequence` is the
   event's 1-based position in this Runtime's publication order. */
typedef struct oep_repository_event_t {
    oep_event_type_t type;
    char subject_id[OEP_MAX_EVENT_SUBJECT_ID];
    char detail[OEP_MAX_EVENT_DETAIL];
    char occurred_at_utc[OEP_MAX_EVENT_TIMESTAMP];
    long long sequence;
} oep_repository_event_t;

typedef struct oep_repository_event_list_t {
    oep_repository_event_t* items;
    int count;
} oep_repository_event_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list`
   itself may be NULL (a no-op). */
void oep_repository_event_list_release(oep_repository_event_list_t* list);

/* The most recently published events for `runtime`, oldest first,
   capped at `limit` (0 means "no limit", subject to the Runtime's own
   internal retention bound). Valid in any Runtime state; a
   freshly-initialized Runtime simply reports zero events. `runtime`
   and `out_list` must not be NULL.

   Ownership: on success, the caller owns `out_list->items` and must
   release it with exactly one call to oep_repository_event_list_release. */
oep_result_t oep_runtime_recent_events(OEP_Runtime runtime, int limit, oep_repository_event_list_t* out_list);

/* ------------------------------------------------------------------ */
/* Engineering Knowledge Runtime (WP-EKE-001)                          */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::EngineeringContext -- the Engineering Knowledge
 * Runtime's (EKR) facade over the Object Loader, Runtime Graph, and
 * Relationship/Query/Traversal Engines -- as the six-function Public
 * Runtime API WP-EKE-001 names: load_object, load_graph, query,
 * traverse, related_objects, dependency_graph. Every function below
 * calls through `runtime`'s EngineeringContext, which itself consumes
 * Foundation EXCLUSIVELY through RuntimeService (never FoundationRuntime
 * directly), matching WP-REP-007/WP-REP-008's RuntimeService-exclusivity
 * pattern for newer capabilities. Only valid from RepositoryOpen; fail
 * with OEP_ERROR_INVALID_STATE otherwise.
 *
 * oep_engine_load_object is lazy and does not require the Runtime Graph
 * to be loaded. oep_engine_query/oep_engine_traverse/
 * oep_engine_related_objects/oep_engine_dependency_graph all require a
 * prior successful oep_engine_load_graph call on this `runtime` handle
 * (EngineeringContext caches the built graph on the handle's engine
 * context -- not the repository -- so it must be (re)loaded once per
 * process/handle, and again after any mutation that should be
 * reflected); calling them beforehand fails with
 * OEP_ERROR_INVALID_STATE, with a message naming the missing
 * oep_engine_load_graph call.
 *
 * ID-list reuse decision: every id-list output below reuses
 * oep_package_id_list_t/oep_package_id_list_release (Work Package
 * WP-REP-005) rather than introducing a new "object id list" or
 * "relationship id list" type. Its layout -- a heap array of
 * fixed-size-buffer id structs plus a count -- is already exactly a
 * generic "list of ids" container (oep::api's own
 * oep_package_analyze_uninstall_impact/oep_package_analyze_update_impact
 * already reuse it the same way, for dependent PACKAGE ids, not just
 * package ids from resolution). OEP_MAX_PACKAGE_ID (256) comfortably
 * exceeds OEP_MAX_OBJECT_ID/OEP_MAX_RELATIONSHIP_ID (64), so no object
 * or relationship id is ever truncated by the reuse. The "package"
 * name in the type is a pre-existing minor imprecision, not something
 * this Work Package introduces.
 */

/* Loads (and caches) exactly one Engineering Object via the Object
   Loader, WITHOUT touching or requiring the Runtime Graph. `object_id`
   and `out_object` must not be NULL. `out_found` may be NULL if the
   caller only needs `out_object`. On success with `*out_found == 0`,
   `*out_object` is zero-initialized -- a nonexistent object_id is not
   an API error. */
oep_result_t oep_engine_load_object(OEP_Runtime runtime, const char* object_id, oep_object_info_t* out_object,
                                     int* out_found);

/* Batch-loads every Engineering Object and Relationship in the
   currently open repository (via the Object Loader) and (re)builds this
   handle's Runtime Graph from that snapshot. Must succeed before
   oep_engine_query/oep_engine_traverse/oep_engine_related_objects/
   oep_engine_dependency_graph. `out_objects_loaded`/
   `out_relationships_loaded` may be NULL if not needed. */
oep_result_t oep_engine_load_graph(OEP_Runtime runtime, int* out_objects_loaded, int* out_relationships_loaded);

/* Mirrors oep::engine::EngineeringContext::QueryKind. */
typedef enum oep_engine_query_kind_t {
    OEP_ENGINE_QUERY_BY_ID = 0,
    OEP_ENGINE_QUERY_BY_TYPE = 1,
    OEP_ENGINE_QUERY_BY_DOMAIN = 2,
    OEP_ENGINE_QUERY_BY_RELATIONSHIP = 3,
    OEP_ENGINE_QUERY_SHORTEST_PATH = 4,
    OEP_ENGINE_QUERY_CONNECTED_COMPONENT = 5,
    OEP_ENGINE_QUERY_SUBGRAPH = 6,
} oep_engine_query_kind_t;

/* A single discriminated request, mirroring
   oep::engine::EngineeringContext::QueryRequest: callers populate only
   the field(s) `kind` needs (documented per field below); the rest are
   ignored. All string/array fields are input-only, read for the
   duration of the oep_engine_query call -- the caller retains
   ownership, exactly like oep_object_create_spec_t. */
typedef struct oep_engine_query_request_t {
    oep_engine_query_kind_t kind;
    const char* object_id;                     /* ById, ConnectedComponent */
    oep_object_type_t object_type;              /* ByType */
    const char* domain;                         /* ByDomain */
    oep_relationship_type_t relationship_type;   /* ByRelationship */
    const char* source_object_id;                /* ShortestPath */
    const char* target_object_id;                /* ShortestPath */
    const char* const* subgraph_object_ids;       /* Subgraph */
    int subgraph_object_id_count;                 /* Subgraph */
} oep_engine_query_request_t;

/* Runs one Graph Query (Find by ID/Type/Domain/Relationship, Shortest
   Path, Connected Component, or Subgraph) against this handle's loaded
   Runtime Graph, per `request->kind`. `runtime` and `request` must not
   be NULL. `out_object_ids` may be NULL if the caller only needs
   `out_path_exists`/`out_relationship_ids`.

   `out_relationship_ids` is only ever populated for
   OEP_ENGINE_QUERY_SUBGRAPH (the induced subgraph's relationship ids);
   left an empty, zero-initialized list for every other `kind`. May be
   NULL if not needed.

   `out_path_exists` is only ever meaningful for
   OEP_ENGINE_QUERY_SHORTEST_PATH: nonzero iff a path was found, in
   which case `out_object_ids` holds the path from source to target
   inclusive, in path order; 0 (with `out_object_ids` empty) if no path
   exists -- NOT an API error. May be NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and `out_relationship_ids->items` and must
   release each with exactly one call to oep_package_id_list_release
   (see the ID-list reuse decision above). */
oep_result_t oep_engine_query(OEP_Runtime runtime, const oep_engine_query_request_t* request,
                               oep_package_id_list_t* out_object_ids, oep_package_id_list_t* out_relationship_ids,
                               int* out_path_exists);

/* Traverses this handle's loaded Runtime Graph starting at
   `start_object_id`. `order` selects oep::engine::TraversalOrder:
   0 = BreadthFirst, 1 = DepthFirst (any other value fails with
   OEP_ERROR_INVALID_ARGUMENT). `has_relationship_filter`/
   `has_max_depth` are the "optional field is set" flags for
   TraversalOptions' two std::optional members: when
   `has_relationship_filter` is 0, `relationship_filter` is ignored and
   every relationship type is followed; when `has_max_depth` is 0,
   `max_depth` is ignored and traversal is unbounded. `start_object_id`
   and `runtime` must not be NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and must release it with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_engine_traverse(OEP_Runtime runtime, const char* start_object_id, int order,
                                  int has_relationship_filter, oep_relationship_type_t relationship_filter,
                                  int has_max_depth, int max_depth, oep_package_id_list_t* out_object_ids);

/* Every object directly connected to `object_id` (any relationship
   type, either direction) in this handle's loaded Runtime Graph, sorted
   and deduplicated -- oep::engine::RelationshipEngine::neighbors.
   `object_id` and `runtime` must not be NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and must release it with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_engine_related_objects(OEP_Runtime runtime, const char* object_id,
                                         oep_package_id_list_t* out_object_ids);

/* The full transitive closure of `object_id`'s outgoing DependsOn
   Relationships in this handle's loaded Runtime Graph: `object_id`
   itself, plus every object reachable by following only DependsOn edges
   outward, plus the DependsOn relationship ids traversed to reach them.
   Fails with OEP_ERROR_NOT_FOUND if `object_id` is not present in the
   loaded graph. `object_id` and `runtime` must not be NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and `out_relationship_ids->items` and must
   release each with exactly one call to oep_package_id_list_release. */
oep_result_t oep_engine_dependency_graph(OEP_Runtime runtime, const char* object_id,
                                          oep_package_id_list_t* out_object_ids,
                                          oep_package_id_list_t* out_relationship_ids);

/* ------------------------------------------------------------------ */
/* Engineering Knowledge Graph Engine (WP-EKE-002)                      */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::KnowledgeGraphEngine -- the canonical, in-memory
 * Knowledge Graph, built/validated/analyzed on top of the same
 * EngineeringContext oep_engine_* (WP-EKE-001) already uses. Every
 * function below calls through `runtime`'s KnowledgeGraphEngine, which
 * itself consumes Foundation EXCLUSIVELY through EngineeringContext
 * (never RuntimeService/FoundationRuntime directly), preserving the
 * "consume only the layer directly beneath you" boundary WP-EKE-001
 * established. Only valid from RepositoryOpen; fail with
 * OEP_ERROR_INVALID_STATE otherwise.
 *
 * oep_kge_build_graph/oep_kge_refresh_graph are identical (both fully
 * re-pull from EngineeringContext and rebuild the graph from scratch),
 * mirroring KnowledgeGraphEngine::build_graph/refresh_graph. Every other
 * function below requires a prior successful oep_kge_build_graph (or
 * oep_kge_refresh_graph) call on this `runtime` handle; calling them
 * beforehand fails with OEP_ERROR_INVALID_STATE.
 *
 * ID-list reuse: oep_kge_shortest_path and oep_kge_subgraph reuse
 * oep_package_id_list_t/oep_package_id_list_release, exactly like every
 * WP-EKE-001 function above (see that section's own "ID-list reuse
 * decision" note) -- OEP_MAX_PACKAGE_ID comfortably exceeds
 * OEP_MAX_OBJECT_ID/OEP_MAX_RELATIONSHIP_ID, so no id is truncated.
 *
 * Scope decision -- statistics distributions: oep_graph_statistics_t
 * exposes the six scalar GraphStatistics fields (object/relationship/
 * connected-component counts, density, maximum_depth, average_degree)
 * but deliberately OMITS relationship_distribution/domain_distribution,
 * mirroring how WP-REP-007/WP-REP-008 omitted nested detail from
 * oep_update_impact_t/oep_merge_plan_t to keep the C surface focused --
 * the scalar summary already answers "how connected/how deep is this
 * graph", and a per-type/per-domain breakdown is a poor fit for a
 * fixed-layout struct (both vectors are open-ended in length). CLI code
 * that wants the full distributions calls the C++ layer
 * (KnowledgeGraphEngine::graph_statistics) directly instead of the C API,
 * per WP-EKE-001's existing precedent of `oep engine` CLI commands
 * talking to EngineeringContext/KnowledgeGraphEngine directly rather than
 * through this C API.
 *
 * Scope decision -- connected components flattening: C has no natural
 * "list of lists". oep_kge_connected_components instead returns a FLAT
 * list of {object_id, component_index} entries, one per object, tagged
 * with which component (0-based, in GraphAlgorithms::ComponentsResult
 * order) it belongs to -- a caller reconstructs the grouping by
 * filtering/sorting on component_index if it needs per-component lists.
 *
 * Multi-id input -- oep_kge_subgraph: the first Public C API function to
 * take an ARRAY of strings as input rather than a single id, mirroring
 * the existing oep_engine_query_request_t::subgraph_object_ids /
 * subgraph_object_id_count convention (WP-EKE-001) exactly: a non-NULL
 * (unless count is 0) array of `object_id_count` NUL-terminated,
 * caller-owned strings, read only for the duration of the call.
 *
 * Owned-heap-string export -- oep_kge_export_json/
 * oep_kge_export_graphml_placeholder: a graph export can be arbitrarily
 * large, a poor fit for this file's usual fixed-size-buffer convention,
 * so these two return a caller-owned, heap-allocated (`new[]`) NUL-
 * terminated buffer via `out_text`/`out_length`, released with exactly
 * one call to the new oep_string_release -- this codebase's first
 * owned-dynamically-sized-string convention, established here for any
 * future function with the same "unbounded text" shape.
 */

/* Builds/rebuilds this handle's Knowledge Graph from EngineeringContext
   (see KnowledgeGraphEngine::build_graph). `out_objects`/
   `out_relationships` may be NULL if not needed. */
oep_result_t oep_kge_build_graph(OEP_Runtime runtime, int* out_objects, int* out_relationships);

/* Identical to oep_kge_build_graph (see KnowledgeGraphEngine::refresh_graph
   for why both are exposed separately). */
oep_result_t oep_kge_refresh_graph(OEP_Runtime runtime, int* out_objects, int* out_relationships);

/* Mirrors oep::engine::GraphIssueKind. */
typedef enum oep_graph_issue_kind_t {
    OEP_GRAPH_ISSUE_MISSING_ENDPOINT = 0,
    OEP_GRAPH_ISSUE_DUPLICATE_RELATIONSHIP = 1,
    OEP_GRAPH_ISSUE_SELF_REFERENCE = 2,
    OEP_GRAPH_ISSUE_BROKEN_REFERENCE = 3,
    OEP_GRAPH_ISSUE_CYCLE = 4,
    OEP_GRAPH_ISSUE_INVALID_RELATIONSHIP_TYPE = 5,
} oep_graph_issue_kind_t;

/* Returns a static, human-readable name for `kind` (e.g.
   "MissingEndpoint"). Never returns NULL. */
const char* oep_graph_issue_kind_to_string(oep_graph_issue_kind_t kind);

/* One entry from oep::engine::GraphValidationReport::issues, fixed-layout.
   `relationship_id` is empty when the issue isn't tied to one specific
   relationship (e.g. a Cycle), matching GraphIssue's own doc comment. */
typedef struct oep_graph_issue_t {
    oep_graph_issue_kind_t kind;
    char relationship_id[OEP_MAX_RELATIONSHIP_ID];
    char detail[256];
} oep_graph_issue_t;

typedef struct oep_graph_issue_list_t {
    oep_graph_issue_t* items;
    int count;
} oep_graph_issue_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_graph_issue_list_release(oep_graph_issue_list_t* list);

/* Validates this handle's currently built Knowledge Graph (see
   KnowledgeGraphEngine::validate_graph). Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. A graph with issues is
   not an API error -- it still returns a successful oep_result_t, with
   the verdict in `*out_valid`. `out_valid` must not be NULL;
   `out_issues` may be NULL if the caller only needs the verdict.

   Ownership: on success, if non-NULL, the caller owns `out_issues->items`
   and must release it with exactly one call to oep_graph_issue_list_release. */
oep_result_t oep_kge_validate_graph(OEP_Runtime runtime, int* out_valid, oep_graph_issue_list_t* out_issues);

/* The six scalar fields of oep::engine::GraphStatistics. See this
   section's "Scope decision -- statistics distributions" note above for
   why relationship_distribution/domain_distribution are not exposed
   here. Plain value type, no release function. */
typedef struct oep_graph_statistics_t {
    int object_count;
    int relationship_count;
    int connected_component_count;
    double density;
    int maximum_depth;
    double average_degree;
} oep_graph_statistics_t;

/* Computes statistics over this handle's currently built Knowledge Graph
   (see KnowledgeGraphEngine::graph_statistics). Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. `runtime` and
   `out_stats` must not be NULL. */
oep_result_t oep_kge_graph_statistics(OEP_Runtime runtime, oep_graph_statistics_t* out_stats);

/* One object's connected-component membership -- see this section's
   "Scope decision -- connected components flattening" note above.
   `component_index` is 0-based, in GraphAlgorithms::ComponentsResult
   order (components sorted by their smallest object id). */
typedef struct oep_component_membership_t {
    char object_id[OEP_MAX_OBJECT_ID];
    int component_index;
} oep_component_membership_t;

typedef struct oep_component_membership_list_t {
    oep_component_membership_t* items;
    int count;
} oep_component_membership_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_component_membership_list_release(oep_component_membership_list_t* list);

/* Every connected component of this handle's currently built Knowledge
   Graph, flattened into one {object_id, component_index} entry per
   object (see KnowledgeGraphEngine::connected_components /
   GraphAlgorithms::connected_components). Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. `out_components` may
   be NULL if the caller only needs `out_count`; `out_count` (component
   COUNT, not entry count) may be NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_components->items` and must release it with exactly one call to
   oep_component_membership_list_release. */
oep_result_t oep_kge_connected_components(OEP_Runtime runtime, oep_component_membership_list_t* out_components,
                                           int* out_count);

/* Shortest path (by hop count) between `source_id` and `target_id` in
   this handle's currently built Knowledge Graph (see
   KnowledgeGraphEngine::shortest_path). Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. No path existing is
   not an API error -- it still returns a successful oep_result_t, with
   `*out_path_exists == 0` and `out_path` (if non-NULL) left empty.
   `source_id`, `target_id`, and `out_path_exists` must not be NULL;
   `out_path` may be NULL if the caller only needs the verdict.

   Ownership: on success, if non-NULL, the caller owns `out_path->items`
   and must release it with exactly one call to
   oep_package_id_list_release (see this section's "ID-list reuse" note). */
oep_result_t oep_kge_shortest_path(OEP_Runtime runtime, const char* source_id, const char* target_id,
                                    int* out_path_exists, oep_package_id_list_t* out_path);

/* The induced subgraph over `object_ids` in this handle's currently
   built Knowledge Graph (see KnowledgeGraphEngine::subgraph /
   GraphAlgorithms::subgraph). Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. `runtime` must not be
   NULL. `object_ids` must be a non-NULL (unless `object_id_count == 0`)
   array of `object_id_count` NUL-terminated, caller-owned strings, read
   only for the duration of this call (see this section's "Multi-id
   input" note above). `out_object_ids`/`out_relationship_ids` may be
   NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and `out_relationship_ids->items` and must
   release each with exactly one call to oep_package_id_list_release. */
oep_result_t oep_kge_subgraph(OEP_Runtime runtime, const char* const* object_ids, int object_id_count,
                               oep_package_id_list_t* out_object_ids, oep_package_id_list_t* out_relationship_ids);

/* Releases a heap-allocated (`new[]`) NUL-terminated buffer previously
   returned via `out_text` by oep_kge_export_json/
   oep_kge_export_graphml_placeholder (see this section's "Owned-heap-
   string export" note above). Safe to call with a NULL `text`. Sets
   `*text` to NULL after releasing when `text` itself is non-NULL. */
void oep_string_release(char** text);

/* A complete, valid JSON document ({"objects": [...], "relationships":
   [...]}) exported from this handle's currently built Knowledge Graph
   (see KnowledgeGraphEngine::export_json / to_json). Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. `runtime`, `out_text`,
   and `out_length` must not be NULL.

   Ownership: on success, the caller owns `*out_text` and must release it
   with exactly one call to oep_string_release. `*out_length` is the
   string's length in bytes, excluding the NUL terminator. */
oep_result_t oep_kge_export_json(OEP_Runtime runtime, char** out_text, size_t* out_length);

/* A minimal, well-formed GraphML PLACEHOLDER document (see
   KnowledgeGraphEngine::export_graphml_placeholder / to_graphml_placeholder
   for the placeholder's documented scope) exported from this handle's
   currently built Knowledge Graph. Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. Same ownership contract
   as oep_kge_export_json. */
oep_result_t oep_kge_export_graphml_placeholder(OEP_Runtime runtime, char** out_text, size_t* out_length);

/* ------------------------------------------------------------------ */
/* Engineering Query Engine (WP-EKE-003)                                */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::EngineeringQueryEngine -- the ten-category
 * Engineering Query Engine (EQE) built on top of WP-EKE-002's Knowledge
 * Graph Engine. Every function below calls through `runtime`'s
 * engineering_query_engine, which itself consumes the Knowledge Graph
 * Engine EXCLUSIVELY (never RuntimeService/FoundationRuntime/
 * EngineeringContext directly), preserving the same "consume only the
 * layer directly beneath you" boundary WP-EKE-001/WP-EKE-002 already
 * established. Only valid from RepositoryOpen; fail with
 * OEP_ERROR_INVALID_STATE otherwise. Every function also requires a
 * prior successful oep_kge_build_graph/oep_kge_refresh_graph call on
 * this `runtime` handle (the EQE queries the already-built Knowledge
 * Graph, never builds one itself); calling beforehand fails with
 * OEP_ERROR_INVALID_STATE.
 *
 * Cache note: plan_query/execute_query cache internally by
 * cache_key(request). Per EngineeringQueryEngine's own doc comment,
 * that cache is invalidated ONLY by an explicit oep_eqe_clear_query_cache
 * call -- callers MUST call it after oep_kge_build_graph/
 * oep_kge_refresh_graph if they want subsequent queries to reflect the
 * rebuilt graph (the EQE has no way to detect the rebuild on its own).
 *
 * Query filter shape: oep_query_filter_t mirrors QueryFilter's optional
 * fields with the "has_X" flag convention oep_engine_query_request_t
 * (WP-EKE-001) already established for discriminated/optional C struct
 * fields. `tags` uses the array-of-strings input convention
 * oep_kge_subgraph (WP-EKE-002) established for multi-value input: a
 * non-NULL (unless tag_count == 0) array of caller-owned strings, read
 * only for the duration of the call.
 *
 * Scope decision -- result fields: oep_query_result_summary_t exposes
 * every QueryStatistics scalar field (execution_time_ms,
 * objects_examined, relationships_examined, traversal_depth,
 * result_count) plus `traversal_summary` as a fixed 256-byte buffer
 * (truncated if longer). `indexes_used` (a vector<string>) is
 * deliberately OMITTED from the result summary -- it is, however, still
 * exposed on oep_query_plan_t via the existing oep_package_id_list_t
 * id-list reuse convention, since QueryPlan's C mapping already needs a
 * list output for execution_order and the same convention covers
 * indexes_used at no extra cost.
 */

/* Mirrors oep::engine::QueryCategory. */
typedef enum oep_query_category_t {
    OEP_QUERY_CATEGORY_OBJECT = 0,
    OEP_QUERY_CATEGORY_RELATIONSHIP = 1,
    OEP_QUERY_CATEGORY_DOMAIN = 2,
    OEP_QUERY_CATEGORY_TYPE = 3,
    OEP_QUERY_CATEGORY_DEPENDENCY = 4,
    OEP_QUERY_CATEGORY_NEIGHBORHOOD = 5,
    OEP_QUERY_CATEGORY_PATH = 6,
    OEP_QUERY_CATEGORY_REFERENCE = 7,
    OEP_QUERY_CATEGORY_METADATA = 8,
    OEP_QUERY_CATEGORY_COMPOSITE = 9,
} oep_query_category_t;

/* Returns a static, human-readable name for `category` (e.g. "Object").
   Never returns NULL. */
const char* oep_query_category_to_string(oep_query_category_t category);

/* Mirrors QueryFilter -- every field optional via a "has_X" flag,
   exactly like oep_engine_query_request_t's existing convention (see
   this section's "Query filter shape" note above). `tags` is read only
   for the duration of the oep_eqe_plan_query/oep_eqe_execute_query call
   that receives it; the caller retains ownership. */
typedef struct oep_query_filter_t {
    int has_object_type;
    oep_object_type_t object_type;
    int has_domain;
    char domain[OEP_MAX_OBJECT_NAME];
    int has_relationship_type;
    oep_relationship_type_t relationship_type;
    int has_publisher_id;
    char publisher_id[OEP_MAX_PACKAGE_ID];
    int has_package_id;
    char package_id[OEP_MAX_PACKAGE_ID];
    const char* const* tags;
    int tag_count;
    int has_max_depth;
    int max_depth;
    int has_outgoing_only; /* 0 = both directions (QueryFilter::outgoing_only == nullopt) */
    int outgoing_only;     /* nonzero = outgoing only, 0 = incoming only; ignored unless has_outgoing_only */
} oep_query_filter_t;

/* Mirrors QueryRequest. `secondary_object_id` is only meaningful for
   OEP_QUERY_CATEGORY_PATH (the path's target); ignored otherwise, per
   QueryRequest's own doc comment. Both id fields may be empty strings
   for categories that don't need one (e.g. Type/Domain/Metadata, which
   select entirely via `filter`). */
typedef struct oep_query_request_t {
    oep_query_category_t category;
    char primary_object_id[OEP_MAX_OBJECT_ID];
    char secondary_object_id[OEP_MAX_OBJECT_ID];
    oep_query_filter_t filter;
} oep_query_request_t;

/* Mirrors QueryPlan's three scalar fields. `strategy` mirrors
   TraversalStrategy: 0 = None, 1 = BreadthFirst, 2 = DepthFirst. */
typedef struct oep_query_plan_t {
    oep_query_category_t category;
    int strategy;
    double estimated_cost;
} oep_query_plan_t;

/* Mirrors QueryStatistics, minus `indexes_used` (see this section's
   "Scope decision -- result fields" note above). Used both as the
   EngineeringQueryResult summary (oep_eqe_execute_query) and as the
   most-recently-executed-query snapshot (oep_eqe_query_statistics). */
typedef struct oep_query_result_summary_t {
    double execution_time_ms;
    int objects_examined;
    int relationships_examined;
    int traversal_depth;
    int result_count;
    char traversal_summary[256];
} oep_query_result_summary_t;

/* Plans (never executes) `request` against this handle's currently
   built Knowledge Graph (see EngineeringQueryEngine::plan_query).
   Requires a prior oep_kge_build_graph/oep_kge_refresh_graph call.
   `runtime` and `request` must not be NULL. `out_plan` may be NULL if
   the caller only needs the id lists. `out_indexes_used`/
   `out_execution_order` may be NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_indexes_used->items` and `out_execution_order->items` and must
   release each with exactly one call to oep_package_id_list_release
   (see the "ID-list reuse" note in this file's WP-EKE-002 section). */
oep_result_t oep_eqe_plan_query(OEP_Runtime runtime, const oep_query_request_t* request, oep_query_plan_t* out_plan,
                                 oep_package_id_list_t* out_indexes_used, oep_package_id_list_t* out_execution_order);

/* Plans (or reuses a cached plan for) and executes `request` against
   this handle's currently built Knowledge Graph in one call (see
   EngineeringQueryEngine::execute_query(const QueryRequest&)). Also
   updates the state oep_eqe_query_statistics reports. Requires a prior
   oep_kge_build_graph/oep_kge_refresh_graph call. `runtime` and
   `request` must not be NULL. `out_summary`/`out_object_ids`/
   `out_relationship_ids` may each be NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and `out_relationship_ids->items` and must
   release each with exactly one call to oep_package_id_list_release. */
oep_result_t oep_eqe_execute_query(OEP_Runtime runtime, const oep_query_request_t* request,
                                    oep_query_result_summary_t* out_summary, oep_package_id_list_t* out_object_ids,
                                    oep_package_id_list_t* out_relationship_ids);

/* The most recently executed query's statistics on this handle (see
   EngineeringQueryEngine::query_statistics). Zero-valued if no query has
   been executed yet via oep_eqe_execute_query on this handle.
   `runtime` and `out_stats` must not be NULL. */
oep_result_t oep_eqe_query_statistics(OEP_Runtime runtime, oep_query_result_summary_t* out_stats);

/* Discards every cached plan and result on this handle's Engineering
   Query Engine (see EngineeringQueryEngine::clear_query_cache). Callers
   MUST call this after oep_kge_build_graph/oep_kge_refresh_graph if
   subsequent queries should reflect the rebuilt graph (see this
   section's "Cache note" above). `runtime` must not be NULL. */
oep_result_t oep_eqe_clear_query_cache(OEP_Runtime runtime);

/* The Engineering Query Engine's current cache occupancy (see
   QueryCache::plan_count/result_count) -- a nice-to-have diagnostic, not
   part of WP-EKE-003's literal five-method Runtime API list.
   `out_plan_count`/`out_result_count` may each be NULL if not needed.
   `runtime` must not be NULL. */
oep_result_t oep_eqe_query_cache_info(OEP_Runtime runtime, int* out_plan_count, int* out_result_count);

/* ------------------------------------------------------------------ */
/* Engineering Rules Engine (WP-EKE-004)                                */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::RulesEngine -- the data-driven Engineering Rules
 * Engine (ERE) built on top of WP-EKE-001's EngineeringContext,
 * WP-EKE-002's Knowledge Graph Engine, and WP-EKE-003's Engineering
 * Query Engine. Every function below calls through `runtime`'s
 * rules_engine, which itself consumes exactly those three layers,
 * preserving the "consume only the layer(s) directly beneath you"
 * boundary WP-EKE-001/002/003 already established -- it never touches
 * RuntimeService/FoundationRuntime directly. Only valid from
 * RepositoryOpen; fail with OEP_ERROR_INVALID_STATE otherwise.
 *
 * Rules are pure DATA -- there is no rule-specific C++ code anywhere in
 * the production module, and no rule-specific C code here either.
 * oep_rules_register lets a caller CONSTRUCT an EngineeringRule
 * entirely from data, at the call site (CLI/API/a future rule-loading
 * mechanism); the engine itself only ever interprets the ~10 generic
 * RuleConditionKind primitives.
 *
 * Registration is IN-MEMORY and per-handle, exactly like
 * oep_engine_load_graph/oep_kge_build_graph's own per-handle state --
 * it is NOT persisted, and does not survive closing/reopening a
 * repository or process exit. A caller wanting the same rule set every
 * run must re-register it every run (e.g. at CLI startup).
 *
 * Graph-readiness precondition: oep_rules_evaluate/oep_rules_evaluate_all
 * require BOTH a prior successful oep_engine_load_graph (WP-EKE-001)
 * AND a prior successful oep_kge_build_graph/oep_kge_refresh_graph
 * (WP-EKE-002) on this handle -- mirroring RulesEngine::graph_ready().
 * Calling either function beforehand fails with OEP_ERROR_INVALID_STATE.
 * Registry-only operations (register/remove/enable/disable/list/get)
 * do NOT require a built graph.
 *
 * Rule input/output struct shape: oep_engineering_rule_t mirrors every
 * EngineeringRule field, using the established "has_X" optional-field
 * convention (oep_query_filter_t, WP-EKE-003) for RuleScope's and
 * RuleCondition's optional fields, folded into oep_rule_scope_t /
 * oep_rule_condition_t respectively. The struct doubles as BOTH the
 * oep_rules_register INPUT shape and the oep_rules_get scalar OUTPUT
 * shape:
 *   - As INPUT (oep_rules_register), `conditions`/`condition_count`
 *     carry the rule's condition vector directly: a non-NULL (unless
 *     condition_count == 0) array of `condition_count` oep_rule_condition_t
 *     values, read only for the duration of the call -- this codebase's
 *     first array-of-STRUCTS input convention (as opposed to
 *     oep_kge_subgraph's array-of-strings), extending the same
 *     "caller-owned, call-duration-only" rule to a struct element type.
 *   - As OUTPUT (oep_rules_get), `conditions`/`condition_count` are
 *     always written as NULL/0 -- a rule's conditions are, on output,
 *     returned separately via `out_conditions`
 *     (oep_rule_condition_list_t), mirroring how WP-EKE-002's
 *     oep_merge_plan_t separates scalar fields from list outputs. This
 *     keeps oep_engineering_rule_t itself a fixed-layout, ownership-free
 *     value type in both directions; only the conditions vector ever
 *     needs a release call.
 *
 * evaluate_all detail level: oep_rules_evaluate_all returns one
 * oep_rule_evaluation_summary_t per ENABLED rule (rule_id, status,
 * message, plus affected/diagnostic COUNTS) rather than each rule's
 * full affected-objects/diagnostics detail -- a faithful vector-of-
 * full-results mapping would require a nested owned-list-of-owned-
 * lists shape this file has no precedent for. A caller wanting one
 * rule's full detail calls oep_rules_evaluate for that rule_id
 * (obtained from oep_rules_list_enabled/oep_rules_list_all).
 */

#define OEP_MAX_RULE_ID 64
#define OEP_MAX_RULE_NAME 256
#define OEP_MAX_RULE_DESCRIPTION 1024
#define OEP_MAX_RULE_MESSAGE 512
#define OEP_MAX_RULE_RECOMMENDATION 512

/* Mirrors oep::engine::RuleCategory. */
typedef enum oep_rule_category_t {
    OEP_RULE_CATEGORY_STRUCTURAL = 0,
    OEP_RULE_CATEGORY_CONNECTIVITY = 1,
    OEP_RULE_CATEGORY_DEPENDENCY = 2,
    OEP_RULE_CATEGORY_REFERENCE = 3,
    OEP_RULE_CATEGORY_DOCUMENTATION = 4,
    OEP_RULE_CATEGORY_METADATA = 5,
    OEP_RULE_CATEGORY_PACKAGE = 6,
} oep_rule_category_t;

/* Returns a static, human-readable name for `category` (e.g.
   "Structural"). Never returns NULL. */
const char* oep_rule_category_to_string(oep_rule_category_t category);

/* Mirrors oep::engine::RuleSeverity. */
typedef enum oep_rule_severity_t {
    OEP_RULE_SEVERITY_INFO = 0,
    OEP_RULE_SEVERITY_WARNING = 1,
    OEP_RULE_SEVERITY_ERROR = 2,
    OEP_RULE_SEVERITY_CRITICAL = 3,
} oep_rule_severity_t;

/* Returns a static, human-readable name for `severity` (e.g.
   "Warning"). Never returns NULL. */
const char* oep_rule_severity_to_string(oep_rule_severity_t severity);

/* Mirrors oep::engine::RuleScopeKind. */
typedef enum oep_rule_scope_kind_t {
    OEP_RULE_SCOPE_ALL_OBJECTS = 0,
    OEP_RULE_SCOPE_BY_OBJECT_TYPE = 1,
    OEP_RULE_SCOPE_BY_DOMAIN = 2,
    OEP_RULE_SCOPE_BY_PACKAGE = 3,
    OEP_RULE_SCOPE_SINGLE_OBJECT = 4,
} oep_rule_scope_kind_t;

/* Returns a static, human-readable name for `kind` (e.g.
   "ByObjectType"). Never returns NULL. */
const char* oep_rule_scope_kind_to_string(oep_rule_scope_kind_t kind);

/* Mirrors RuleScope -- every field beyond `kind` optional via a "has_X"
   flag, exactly like oep_query_filter_t's existing convention. Only the
   field matching `kind` needs to be set; the others are ignored. */
typedef struct oep_rule_scope_t {
    oep_rule_scope_kind_t kind;
    int has_object_type; /* ByObjectType */
    oep_object_type_t object_type;
    int has_domain; /* ByDomain */
    char domain[OEP_MAX_OBJECT_NAME];
    int has_package_id; /* ByPackage */
    char package_id[OEP_MAX_PACKAGE_ID];
    int has_object_id; /* SingleObject */
    char object_id[OEP_MAX_OBJECT_ID];
} oep_rule_scope_t;

/* Mirrors oep::engine::RuleConditionKind. */
typedef enum oep_rule_condition_kind_t {
    OEP_RULE_CONDITION_REQUIRES_RELATIONSHIP = 0,
    OEP_RULE_CONDITION_FORBIDS_RELATIONSHIP = 1,
    OEP_RULE_CONDITION_MIN_RELATIONSHIP_COUNT = 2,
    OEP_RULE_CONDITION_MAX_RELATIONSHIP_COUNT = 3,
    OEP_RULE_CONDITION_REQUIRES_TAG = 4,
    OEP_RULE_CONDITION_FORBIDS_TAG = 5,
    OEP_RULE_CONDITION_HAS_DESCRIPTION = 6,
    OEP_RULE_CONDITION_HAS_AUTHOR = 7,
    OEP_RULE_CONDITION_NO_CYCLES = 8,
    OEP_RULE_CONDITION_NO_ISOLATED_OBJECTS = 9,
} oep_rule_condition_kind_t;

/* Returns a static, human-readable name for `kind` (e.g.
   "RequiresRelationship"). Never returns NULL. */
const char* oep_rule_condition_kind_to_string(oep_rule_condition_kind_t kind);

/* Mirrors RuleCondition -- every field beyond `kind` optional via a
   "has_X" flag. `has_direction`/`direction` mirrors QueryFilter's own
   nullable-bool direction convention (WP-EKE-003): nonzero `direction`
   means outgoing only, 0 means incoming only, and `has_direction == 0`
   means either direction. */
typedef struct oep_rule_condition_t {
    oep_rule_condition_kind_t kind;
    int has_relationship_type;
    oep_relationship_type_t relationship_type;
    int has_direction;
    int direction;
    int has_tag;
    char tag[OEP_MAX_TAG_LENGTH];
    int has_count;
    int count;
} oep_rule_condition_t;

typedef struct oep_rule_condition_list_t {
    oep_rule_condition_t* items;
    int count;
} oep_rule_condition_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_rule_condition_list_release(oep_rule_condition_list_t* list);

/* Mirrors EngineeringRule. Doubles as the oep_rules_register INPUT
   shape and the oep_rules_get scalar OUTPUT shape -- see this section's
   "Rule input/output struct shape" note above for exactly how
   `conditions`/`condition_count` behave differently in each direction. */
typedef struct oep_engineering_rule_t {
    char rule_id[OEP_MAX_RULE_ID];
    char name[OEP_MAX_RULE_NAME];
    char description[OEP_MAX_RULE_DESCRIPTION];
    oep_rule_category_t category;
    oep_rule_severity_t severity;
    oep_rule_scope_t scope;
    /* INPUT only (oep_rules_register): a non-NULL (unless
       condition_count == 0) array of `condition_count` values, read
       only for the duration of the call. Always NULL/0 on OUTPUT
       (oep_rules_get) -- use `out_conditions` there instead. */
    const oep_rule_condition_t* conditions;
    int condition_count;
    char message[OEP_MAX_RULE_MESSAGE];
    char recommendation[OEP_MAX_RULE_RECOMMENDATION];
} oep_engineering_rule_t;

/* Registers `rule` on this handle's Rules Engine (see
   RulesEngine::register_rule), enabled by default. Only valid from
   RepositoryOpen. Fails with OEP_ERROR_OPERATION_FAILED if
   `rule->rule_id` is already registered on this handle (remove it
   first). `runtime` and `rule` must not be NULL. */
oep_result_t oep_rules_register(OEP_Runtime runtime, const oep_engineering_rule_t* rule);

/* Removes the rule identified by `rule_id` from this handle's Rules
   Engine (see RulesEngine::remove_rule). Fails with
   OEP_ERROR_NOT_FOUND if `rule_id` is not registered. `runtime` and
   `rule_id` must not be NULL. */
oep_result_t oep_rules_remove(OEP_Runtime runtime, const char* rule_id);

/* Enables/disables the rule identified by `rule_id` (see
   RulesEngine::enable_rule/disable_rule). Fails with
   OEP_ERROR_NOT_FOUND if `rule_id` is not registered. `runtime` and
   `rule_id` must not be NULL. */
oep_result_t oep_rules_enable(OEP_Runtime runtime, const char* rule_id);
oep_result_t oep_rules_disable(OEP_Runtime runtime, const char* rule_id);

/* Lists every registered rule id on this handle's Rules Engine, sorted
   by rule_id (see RulesEngine::all_rules/enabled_rules/disabled_rules).
   Split into three functions rather than one function with mutually-
   exclusive flags, for the same reason oep_kge_build_graph and
   oep_kge_refresh_graph are separate calls rather than one flagged
   call -- each name states its own contract unambiguously. `runtime`
   and `out_rule_ids` must not be NULL.

   Ownership: on success, the caller owns `out_rule_ids->items` and must
   release it with exactly one call to oep_package_id_list_release. */
oep_result_t oep_rules_list_all(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids);
oep_result_t oep_rules_list_enabled(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids);
oep_result_t oep_rules_list_disabled(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids);

/* Fetches the full definition of the rule identified by `rule_id` (see
   RulesEngine::all_rules / RuleRegistry::find_rule). Not finding
   `rule_id` is not an API error -- it still returns a successful
   oep_result_t, with `*out_found == 0` and `*out_rule` zero-initialized.
   `runtime`, `rule_id`, `out_rule`, and `out_found` must not be NULL;
   `out_conditions` may be NULL if the caller only needs the scalar
   fields.

   Ownership: on success with `*out_found != 0`, if non-NULL, the caller
   owns `out_conditions->items` and must release it with exactly one
   call to oep_rule_condition_list_release. */
oep_result_t oep_rules_get(OEP_Runtime runtime, const char* rule_id, oep_engineering_rule_t* out_rule,
                            oep_rule_condition_list_t* out_conditions, int* out_found);

/* Mirrors oep::engine::RuleEvaluationStatus. */
typedef enum oep_rule_evaluation_status_t {
    OEP_RULE_EVAL_PASSED = 0,
    OEP_RULE_EVAL_FAILED = 1,
    OEP_RULE_EVAL_NOT_APPLICABLE = 2,
    OEP_RULE_EVAL_ERROR = 3,
} oep_rule_evaluation_status_t;

/* Returns a static, human-readable name for `status` (e.g. "Failed").
   Never returns NULL. */
const char* oep_rule_evaluation_status_to_string(oep_rule_evaluation_status_t status);

/* The scalar fields of RuleEvaluationResult -- Status and Message.
   `affected_objects`/`diagnostics` are returned separately (see
   oep_rules_evaluate). */
typedef struct oep_rule_evaluation_result_t {
    oep_rule_evaluation_status_t status;
    char message[OEP_MAX_RULE_MESSAGE];
} oep_rule_evaluation_result_t;

/* One entry from RuleEvaluationResult::diagnostics, fixed-layout.
   `object_id` is empty for a graph-level diagnostic (e.g. a NoCycles
   violation), matching RuleDiagnostic's own doc comment. */
typedef struct oep_rule_diagnostic_t {
    char object_id[OEP_MAX_OBJECT_ID];
    char detail[256];
} oep_rule_diagnostic_t;

typedef struct oep_rule_diagnostic_list_t {
    oep_rule_diagnostic_t* items;
    int count;
} oep_rule_diagnostic_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_rule_diagnostic_list_release(oep_rule_diagnostic_list_t* list);

/* Evaluates one registered rule by id, REGARDLESS of its
   enabled/disabled state (see RulesEngine::evaluate_rule -- an explicit
   request to evaluate a specific rule overrides the enabled flag, which
   only gates oep_rules_evaluate_all). Requires a prior
   oep_engine_load_graph AND oep_kge_build_graph/oep_kge_refresh_graph
   call (see this section's "Graph-readiness precondition" note above).
   Not finding `rule_id` is treated as OEP_ERROR_NOT_FOUND. `runtime` and
   `rule_id` must not be NULL. `out_result` may be NULL if the caller
   only needs the affected-objects/diagnostics lists;
   `out_affected_objects`/`out_diagnostics` may each be NULL if not
   needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_affected_objects->items` and `out_diagnostics->items` and must
   release each with exactly one call to oep_package_id_list_release /
   oep_rule_diagnostic_list_release respectively. */
oep_result_t oep_rules_evaluate(OEP_Runtime runtime, const char* rule_id, oep_rule_evaluation_result_t* out_result,
                                 oep_package_id_list_t* out_affected_objects,
                                 oep_rule_diagnostic_list_t* out_diagnostics);

/* One per-rule summary entry produced by oep_rules_evaluate_all -- see
   this section's "evaluate_all detail level" note above for why this is
   a summary (counts only) rather than full per-rule detail. */
typedef struct oep_rule_evaluation_summary_t {
    char rule_id[OEP_MAX_RULE_ID];
    oep_rule_evaluation_status_t status;
    char message[OEP_MAX_RULE_MESSAGE];
    int affected_object_count;
    int diagnostic_count;
} oep_rule_evaluation_summary_t;

typedef struct oep_rule_evaluation_summary_list_t {
    oep_rule_evaluation_summary_t* items;
    int count;
} oep_rule_evaluation_summary_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list` itself
   may be NULL (a no-op). */
void oep_rule_evaluation_summary_list_release(oep_rule_evaluation_summary_list_t* list);

/* Evaluates every ENABLED rule on this handle's Rules Engine, sorted by
   rule_id (see RulesEngine::evaluate_all). Requires a prior
   oep_engine_load_graph AND oep_kge_build_graph/oep_kge_refresh_graph
   call. `runtime` and `out_summaries` must not be NULL.

   Ownership: on success, the caller owns `out_summaries->items` and
   must release it with exactly one call to
   oep_rule_evaluation_summary_list_release. */
oep_result_t oep_rules_evaluate_all(OEP_Runtime runtime, oep_rule_evaluation_summary_list_t* out_summaries);

/* ------------------------------------------------------------------ */
/* Engineering Validation Engine (WP-EKE-005)                          */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::ValidationEngine (EVE) -- runs already-
 * registered Engineering Rules (WP-EKE-004) against a Validation
 * Target and aggregates the results into an immutable
 * ValidationReport. Every function below calls through `runtime`'s
 * validation_engine, which itself consumes exactly EngineeringContext,
 * KnowledgeGraphEngine, EngineeringQueryEngine, and RulesEngine --
 * preserving the "consume only the layer(s) directly beneath you"
 * boundary WP-EKE-001/002/003/004 already established. It never
 * touches RuntimeService/FoundationRuntime directly. Only valid from
 * RepositoryOpen; fail with OEP_ERROR_INVALID_STATE otherwise.
 *
 * Session lifecycle: oep_validation_create_session starts a session
 * and returns its session_id (a UUIDv4 string). Sessions are held
 * IN-MEMORY, per-handle, for the handle's lifetime -- exactly like
 * WP-EKE-004's rule registry, they are NOT persisted and do not
 * survive closing/reopening a repository or process exit. A
 * session_id from a previous process (or a different oep_runtime_impl
 * handle) is always OEP_ERROR_NOT_FOUND here.
 *
 * Graph-readiness precondition: every oep_validation_validate_*
 * function requires a prior successful oep_engine_load_graph AND
 * oep_kge_build_graph/oep_kge_refresh_graph on this handle, mirroring
 * ValidationEngine::graph_ready() (itself RulesEngine::graph_ready()).
 * oep_validation_create_session does NOT require this -- a session may
 * be created before the graph is built, matching
 * create_validation_session()'s own doc comment (the target/statistics
 * are only finalized by the first validate_* call against it).
 *
 * Report/finding detail level: oep_validation_finding_t deliberately
 * OMITS ValidationFinding's affected_objects/diagnostics fields --
 * the same "avoid nested owned-list-of-owned-lists" scope decision
 * WP-EKE-004's oep_rules_evaluate_all made for
 * oep_rule_evaluation_summary_t. A caller wanting a finding's full
 * affected-objects/diagnostics detail calls oep_rules_evaluate for
 * that finding's rule_id (obtained from oep_validation_finding_t
 * itself), exactly as this section's WP-EKE-004 cross-reference
 * describes. oep_validation_report_summary_t/oep_validation_finding_list_t
 * split scalar report fields from the variable-length findings list,
 * mirroring WP-EKE-002's oep_graph_statistics_t / WP-EKE-003's
 * oep_query_result_summary_t precedent.
 *
 * Scope decision -- no oep_validation_validate_query_result: a
 * QueryResult (oep_query_result_t / EngineeringQueryResult) isn't
 * naturally passable across the C boundary without significant extra
 * plumbing (it isn't itself a stored, id-addressable value the way a
 * rule or an object is). This is a deliberate omission, not an
 * oversight. A caller wanting query-result-scoped validation calls
 * oep_eqe_execute_query first, then passes the resulting object ids to
 * oep_validation_validate_objects.
 */

#define OEP_MAX_SESSION_ID 40
#define OEP_MAX_FINDING_ID 64

/* Mirrors oep::engine::ValidationProfile. */
typedef enum oep_validation_profile_t {
    OEP_VALIDATION_PROFILE_STRUCTURAL = 0,
    OEP_VALIDATION_PROFILE_CONNECTIVITY = 1,
    OEP_VALIDATION_PROFILE_DOCUMENTATION = 2,
    OEP_VALIDATION_PROFILE_METADATA = 3,
    OEP_VALIDATION_PROFILE_COMPLETE = 4,
} oep_validation_profile_t;

/* Returns a static, human-readable name for `profile` (e.g.
   "Structural"). Never returns NULL. */
const char* oep_validation_profile_to_string(oep_validation_profile_t profile);

/* Mirrors oep::engine::ValidationTargetKind. */
typedef enum oep_validation_target_kind_t {
    OEP_VALIDATION_TARGET_SINGLE_OBJECT = 0,
    OEP_VALIDATION_TARGET_MULTIPLE_OBJECTS = 1,
    OEP_VALIDATION_TARGET_ENGINEERING_CONTEXT = 2,
    OEP_VALIDATION_TARGET_PACKAGE = 3,
    OEP_VALIDATION_TARGET_QUERY_RESULT = 4,
} oep_validation_target_kind_t;

/* Creates a new ValidationSession for `profile` on this handle's
   Validation Engine (see ValidationEngine::create_validation_session)
   and writes its session_id into `out_session_id` (truncated to
   `session_id_buffer_size` bytes, always NUL-terminated -- see
   copy_truncated's documented contract). Does NOT require a built
   graph (see this section's "Graph-readiness precondition" note).
   `runtime` and `out_session_id` must not be NULL;
   `session_id_buffer_size` must be greater than 0. */
oep_result_t oep_validation_create_session(OEP_Runtime runtime, oep_validation_profile_t profile,
                                            char* out_session_id, size_t session_id_buffer_size);

/* The scalar fields of ValidationReport -- everything except the
   findings list (see oep_validation_finding_list_t) and the nested
   ValidationSession (not separately exposed; its own fields --
   target/active_rule_ids/profile -- are implied by the call that
   produced this report). `rules_evaluated` mirrors
   ValidationStatistics::rules_evaluated. */
typedef struct oep_validation_report_summary_t {
    oep_validation_target_kind_t target_kind;
    int pass_count;
    int warning_count;
    int error_count;
    int critical_count;
    double execution_time_ms;
    int rules_evaluated;
} oep_validation_report_summary_t;

/* One entry from ValidationReport::findings, fixed-layout. Deliberately
   omits affected_objects/diagnostics -- see this section's "Report/
   finding detail level" note above; call oep_rules_evaluate with
   `rule_id` for that detail. */
typedef struct oep_validation_finding_t {
    char finding_id[OEP_MAX_FINDING_ID];
    char rule_id[OEP_MAX_RULE_ID];
    oep_rule_severity_t severity;
    oep_rule_category_t category;
    char message[OEP_MAX_RULE_MESSAGE];
    char recommendation[OEP_MAX_RULE_RECOMMENDATION];
} oep_validation_finding_t;

typedef struct oep_validation_finding_list_t {
    oep_validation_finding_t* items;
    int count;
} oep_validation_finding_list_t;

/* Releases the heap array owned by `list` (if any) and zeroes it. Safe
   to call on a zero-initialized or already-released list. `list`
   itself may be NULL (a no-op). */
void oep_validation_finding_list_release(oep_validation_finding_list_t* list);

/* Mirrors ValidationStatistics. */
typedef struct oep_validation_statistics_t {
    int rules_evaluated;
    int rules_passed;
    int rules_failed;
    int rules_not_applicable;
    int rules_errored;
    double execution_time_ms;
} oep_validation_statistics_t;

/* The five Validation Scopes (WP-EKE-005), minus QueryResult (see this
   section's "Scope decision" note above). Each finalizes `session_id`'s
   session and returns the resulting ValidationReport, split into
   `out_summary` (scalars) and `out_findings` (the findings list).
   Requires a prior oep_engine_load_graph AND oep_kge_build_graph/
   oep_kge_refresh_graph call (OEP_ERROR_INVALID_STATE otherwise).
   `session_id` not created via oep_validation_create_session on this
   handle is OEP_ERROR_NOT_FOUND. `runtime`, `session_id`, and (for
   validate_object/validate_package) the id argument must not be NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_findings->items` and must release it with exactly one call to
   oep_validation_finding_list_release. */
oep_result_t oep_validation_validate_object(OEP_Runtime runtime, const char* session_id, const char* object_id,
                                             oep_validation_report_summary_t* out_summary,
                                             oep_validation_finding_list_t* out_findings);

/* Same contract as oep_validation_validate_object, but for
   `object_id_count` objects (mirrors oep_kge_subgraph's array-of-
   strings input convention). `object_ids` may be NULL only if
   `object_id_count == 0`. */
oep_result_t oep_validation_validate_objects(OEP_Runtime runtime, const char* session_id,
                                              const char* const* object_ids, int object_id_count,
                                              oep_validation_report_summary_t* out_summary,
                                              oep_validation_finding_list_t* out_findings);

/* Same contract as oep_validation_validate_object, scoped to the whole
   Engineering Context (unfiltered). */
oep_result_t oep_validation_validate_context(OEP_Runtime runtime, const char* session_id,
                                              oep_validation_report_summary_t* out_summary,
                                              oep_validation_finding_list_t* out_findings);

/* Same contract as oep_validation_validate_object, scoped to
   `package_id`. */
oep_result_t oep_validation_validate_package(OEP_Runtime runtime, const char* session_id, const char* package_id,
                                              oep_validation_report_summary_t* out_summary,
                                              oep_validation_finding_list_t* out_findings);

/* The most recent ValidationReport for `session_id` (see
   ValidationEngine::validation_report). `session_id` not created via
   oep_validation_create_session on this handle is OEP_ERROR_NOT_FOUND;
   a session that exists but has never been validated is
   OEP_ERROR_INVALID_STATE with `out_summary`/`out_findings` zeroed.
   `runtime` and `session_id` must not be NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_findings->items` and must release it with exactly one call to
   oep_validation_finding_list_release. */
oep_result_t oep_validation_report(OEP_Runtime runtime, const char* session_id,
                                    oep_validation_report_summary_t* out_summary,
                                    oep_validation_finding_list_t* out_findings);

/* The most recent ValidationStatistics for `session_id` (see
   ValidationEngine::validation_statistics). Same not-found/not-yet-
   validated error contract as oep_validation_report. `runtime`,
   `session_id`, and `out_stats` must not be NULL. */
oep_result_t oep_validation_statistics(OEP_Runtime runtime, const char* session_id,
                                        oep_validation_statistics_t* out_stats);

/* ------------------------------------------------------------------ */
/* Engineering Analysis & Reasoning Engine (WP-EKE-006)                */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::AnalysisEngine and oep::engine::ReasoningEngine.
 * Every function below calls through `runtime`'s reasoning_engine,
 * which itself consumes exactly EngineeringContext, KnowledgeGraphEngine,
 * EngineeringQueryEngine, RulesEngine, and ValidationEngine --
 * preserving the "consume only the layer(s) directly beneath you"
 * boundary WP-EKE-001 through WP-EKE-005 already established. It never
 * touches RuntimeService/FoundationRuntime directly. Only valid from
 * RepositoryOpen; fail with OEP_ERROR_INVALID_STATE otherwise.
 *
 * Graph-readiness precondition: every function below requires a prior
 * successful oep_engine_load_graph AND oep_kge_build_graph/
 * oep_kge_refresh_graph on this handle, mirroring
 * ReasoningEngine::graph_ready(). oep_reasoning_create_session does NOT
 * require this (mirroring oep_validation_create_session's own
 * precedent) -- only oep_reasoning_execute (and the four analysis
 * functions, which need no session at all) do.
 *
 * Session lifecycle: oep_reasoning_create_session starts a
 * ReasoningSession and returns its session_id (a UUIDv4 string).
 * Sessions are held IN-MEMORY, per-handle, for the handle's lifetime --
 * exactly like WP-EKE-005's ValidationSession registry -- and are NOT
 * persisted; a session_id from a previous process (or a different
 * oep_runtime_impl handle) is always OEP_ERROR_NOT_FOUND here.
 *
 * Analysis functions (dependencies/impact/reachability/root_cause) need
 * no session at all -- they are direct, stateless graph algorithms
 * (AnalysisEngine, held inside ReasoningEngine), matching this work
 * package's own Runtime API split between "Analysis Engine" (pure graph
 * algorithms) and "Reasoning Engine" (session-based, evidence-backed
 * conclusions/recommendations). oep_analysis_root_cause routes through
 * ReasoningEngine::analyze_root_cause(symptom_object_id) -- the
 * overload that runs its own Complete-profile validation internally --
 * never AnalysisEngine's two-argument overload directly, since the C
 * API has no separate way for a caller to supply a finding-object-id
 * list of its own.
 *
 * Conclusion/recommendation detail-fetching shape: oep_reasoning_execute
 * and oep_reasoning_report return only conclusion_ids/recommendation_ids
 * (via the reused oep_package_id_list_t) alongside a scalar
 * oep_reasoning_summary_t, mirroring WP-EKE-004/005's "avoid nested
 * owned-list-of-owned-lists" scope decision. Full detail for one
 * conclusion or recommendation is fetched separately, BY ID (the
 * engine already assigns stable conclusion_id/recommendation_id
 * strings, so this mirrors oep_rules_evaluate's by-rule_id lookup
 * rather than inventing an index-based convention) via
 * oep_reasoning_get_conclusion / oep_reasoning_get_recommendation.
 *
 * Evidence Graph exposure: minimal and OPTIONAL, per this work
 * package's own scope note. oep_reasoning_get_evidence_node exposes a
 * single EvidenceNode's kind/reference_id/detail by evidence_id (every
 * evidence_id referenced from a conclusion's supporting_evidence_ids or
 * a recommendation's supporting_evidence_ids is resolvable this way).
 * EvidenceRelationship edges and full-graph enumeration are NOT exposed
 * -- Studio's own scope only needs individual evidence node detail
 * reachable from a conclusion/recommendation's already-exposed id
 * lists; a caller wanting the full graph shape can reconstruct it from
 * per-conclusion/recommendation evidence ids plus each node's own
 * `detail` text. This is a deliberate omission, not an oversight.
 */

/* Fixed-capacity output for DependencyReport/ImpactReport's own object_id
   field -- both reuse OEP_MAX_OBJECT_ID for consistency with every other
   object-id field in this API. `evidence` is written into a caller-owned
   fixed buffer rather than allocated, keeping this section's outputs
   free of an extra owned-string-release convention. */
#define OEP_MAX_EVIDENCE_TEXT 256

/* Dependency Analysis: the transitive outgoing DependsOn closure of
   `object_id` (see AnalysisEngine::analyze_dependencies). Requires a
   prior oep_engine_load_graph AND oep_kge_build_graph/
   oep_kge_refresh_graph call. `runtime` and `object_id` must not be
   NULL. `out_max_depth`/`out_dependency_object_ids`/
   `out_dependency_relationship_ids`/`out_evidence` may each be NULL if
   not needed; `out_evidence`, if non-NULL, must point at a buffer of at
   least OEP_MAX_EVIDENCE_TEXT bytes.

   Ownership: on success, if non-NULL, the caller owns
   `out_dependency_object_ids->items` and
   `out_dependency_relationship_ids->items` and must release each with
   exactly one call to oep_package_id_list_release. */
oep_result_t oep_analysis_dependencies(OEP_Runtime runtime, const char* object_id, int* out_max_depth,
                                        oep_package_id_list_t* out_dependency_object_ids,
                                        oep_package_id_list_t* out_dependency_relationship_ids,
                                        char* out_evidence);

/* Impact Analysis: the transitive INCOMING DependsOn closure of
   `object_id` (see AnalysisEngine::analyze_impact). Same contract as
   oep_analysis_dependencies. */
oep_result_t oep_analysis_impact(OEP_Runtime runtime, const char* object_id, int* out_max_depth,
                                  oep_package_id_list_t* out_affected_object_ids,
                                  oep_package_id_list_t* out_affected_relationship_ids, char* out_evidence);

/* Reachability Analysis: whether `target_id` is reachable from
   `source_id` (see AnalysisEngine::analyze_reachability). `out_reachable`
   is written 0/1. `runtime`, `source_id`, and `target_id` must not be
   NULL. `out_reachable`/`out_path`/`out_evidence` may each be NULL if
   not needed.

   Ownership: on success, if non-NULL, the caller owns `out_path->items`
   and must release it with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_analysis_reachability(OEP_Runtime runtime, const char* source_id, const char* target_id,
                                        int* out_reachable, oep_package_id_list_t* out_path, char* out_evidence);

/* Root Cause Analysis: routes through
   ReasoningEngine::analyze_root_cause(symptom_object_id) (the overload
   that runs its own Complete-profile validation internally -- see this
   section's header note). `runtime` and `symptom_object_id` must not be
   NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_candidate_root_causes->items` and `out_failure_chain->items` and
   must release each with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_analysis_root_cause(OEP_Runtime runtime, const char* symptom_object_id,
                                      oep_package_id_list_t* out_candidate_root_causes,
                                      oep_package_id_list_t* out_failure_chain, char* out_evidence);

/* Creates a new ReasoningSession for `objective`, scoped to
   `starting_object_ids` (mirrors oep_kge_subgraph's array-of-strings
   input convention), on this handle's Reasoning Engine (see
   ReasoningEngine::create_reasoning_session) and writes its session_id
   into `out_session_id` (truncated to `session_id_buffer_size` bytes,
   always NUL-terminated). Does NOT require a built graph (see this
   section's "Graph-readiness precondition" note). `runtime`,
   `objective`, and `out_session_id` must not be NULL;
   `session_id_buffer_size` must be greater than 0.
   `starting_object_ids` may be NULL only if `starting_object_id_count
   == 0`. */
oep_result_t oep_reasoning_create_session(OEP_Runtime runtime, const char* objective,
                                           const char* const* starting_object_ids, int starting_object_id_count,
                                           char* out_session_id, size_t session_id_buffer_size);

/* The scalar fields of a ReasoningReport -- everything except the
   conclusion/recommendation id lists (see oep_reasoning_execute/
   oep_reasoning_report), mirroring WP-EKE-005's
   oep_validation_report_summary_t precedent. */
typedef struct oep_reasoning_summary_t {
    int conclusion_count;
    int recommendation_count;
    double execution_time_ms;
} oep_reasoning_summary_t;

/* Runs `session_id`'s reasoning (see ReasoningEngine::execute_reasoning):
   for each starting object, performs dependency/impact/root-cause
   analysis, validates it, builds the session's Evidence Graph, derives
   EngineeringConclusions, and generates EngineeringRecommendations.
   Requires a prior oep_engine_load_graph AND oep_kge_build_graph/
   oep_kge_refresh_graph call (OEP_ERROR_INVALID_STATE otherwise).
   `session_id` not created via oep_reasoning_create_session on this
   handle is OEP_ERROR_NOT_FOUND. `runtime` and `session_id` must not be
   NULL.

   Ownership: on success, if non-NULL, the caller owns
   `out_conclusion_ids->items` and `out_recommendation_ids->items` and
   must release each with exactly one call to
   oep_package_id_list_release. Full detail for any one id is fetched
   via oep_reasoning_get_conclusion / oep_reasoning_get_recommendation. */
oep_result_t oep_reasoning_execute(OEP_Runtime runtime, const char* session_id, oep_reasoning_summary_t* out_summary,
                                    oep_package_id_list_t* out_conclusion_ids,
                                    oep_package_id_list_t* out_recommendation_ids);

/* The most recent ReasoningReport for `session_id` (see
   ReasoningEngine::reasoning_report). `session_id` not created via
   oep_reasoning_create_session on this handle is OEP_ERROR_NOT_FOUND; a
   session that exists but has never been executed is
   OEP_ERROR_INVALID_STATE with outputs zeroed. `runtime` and
   `session_id` must not be NULL.

   Ownership: same as oep_reasoning_execute. */
oep_result_t oep_reasoning_report(OEP_Runtime runtime, const char* session_id, oep_reasoning_summary_t* out_summary,
                                   oep_package_id_list_t* out_conclusion_ids,
                                   oep_package_id_list_t* out_recommendation_ids);

/* Convenience accessor equivalent to oep_reasoning_report's
   `out_recommendation_ids`, per this work package's own explicit
   `engineering_recommendations()` Runtime API entry (see
   ReasoningEngine::engineering_recommendations). Same not-found/
   not-yet-executed error contract as oep_reasoning_report.

   Ownership: on success, if non-NULL, the caller owns
   `out_recommendation_ids->items` and must release it with exactly one
   call to oep_package_id_list_release. */
oep_result_t oep_reasoning_recommendations(OEP_Runtime runtime, const char* session_id,
                                            oep_package_id_list_t* out_recommendation_ids);

#define OEP_MAX_CONCLUSION_ID 64
#define OEP_MAX_RECOMMENDATION_ID 64
#define OEP_MAX_CONCLUSION_STATEMENT 512
#define OEP_MAX_CONCLUSION_EXPLANATION 1024
#define OEP_MAX_RECOMMENDATION_MESSAGE 512
#define OEP_MAX_EVIDENCE_ID 64
#define OEP_MAX_EVIDENCE_REFERENCE_ID 64
#define OEP_MAX_EVIDENCE_DETAIL 512

/* One EngineeringConclusion, fixed-layout, minus the four id lists
   (supporting_evidence_ids/referenced_objects/referenced_rules/
   referenced_findings), each fetched separately via the matching
   out_ parameter below -- mirrors this section's own "avoid nested
   owned-list-of-owned-lists" scope decision. */
typedef struct oep_conclusion_t {
    char conclusion_id[OEP_MAX_CONCLUSION_ID];
    char statement[OEP_MAX_CONCLUSION_STATEMENT];
    double confidence;
    char explanation[OEP_MAX_CONCLUSION_EXPLANATION];
} oep_conclusion_t;

/* Fetches one EngineeringConclusion by `conclusion_id` from
   `session_id`'s most recent ReasoningReport. `session_id` not created
   on this handle, or `conclusion_id` not found within that report's
   session, is OEP_ERROR_NOT_FOUND. `runtime`, `session_id`, and
   `conclusion_id` must not be NULL. `out_conclusion` and the four
   out_ id-list parameters may each be NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns each non-NULL
   out_ list's `items` and must release each with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_reasoning_get_conclusion(OEP_Runtime runtime, const char* session_id, const char* conclusion_id,
                                           oep_conclusion_t* out_conclusion,
                                           oep_package_id_list_t* out_supporting_evidence_ids,
                                           oep_package_id_list_t* out_referenced_objects,
                                           oep_package_id_list_t* out_referenced_rules,
                                           oep_package_id_list_t* out_referenced_findings);

/* Mirrors oep::engine::RecommendationKind. */
typedef enum oep_recommendation_kind_t {
    OEP_RECOMMENDATION_RELATED_PROCEDURE = 0,
    OEP_RECOMMENDATION_SIMILAR_COMPONENT = 1,
    OEP_RECOMMENDATION_ADDITIONAL_INSPECTION = 2,
    OEP_RECOMMENDATION_CONNECTED_SYSTEM = 3,
    OEP_RECOMMENDATION_FOLLOW_UP_VALIDATION = 4,
} oep_recommendation_kind_t;

/* Returns a static, human-readable name for `kind` (e.g.
   "RelatedProcedure"). Never returns NULL. */
const char* oep_recommendation_kind_to_string(oep_recommendation_kind_t kind);

/* One EngineeringRecommendation, fixed-layout, minus
   supporting_evidence_ids (fetched separately via `out_evidence_ids`
   below). */
typedef struct oep_recommendation_t {
    char recommendation_id[OEP_MAX_RECOMMENDATION_ID];
    oep_recommendation_kind_t kind;
    char object_id[OEP_MAX_OBJECT_ID];
    char message[OEP_MAX_RECOMMENDATION_MESSAGE];
} oep_recommendation_t;

/* Fetches one EngineeringRecommendation by `recommendation_id` from
   `session_id`'s most recent ReasoningReport. Same not-found contract
   as oep_reasoning_get_conclusion. `runtime`, `session_id`, and
   `recommendation_id` must not be NULL. `out_recommendation` and
   `out_evidence_ids` may each be NULL if not needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_evidence_ids->items` and must release it with exactly one call
   to oep_package_id_list_release. */
oep_result_t oep_reasoning_get_recommendation(OEP_Runtime runtime, const char* session_id,
                                               const char* recommendation_id, oep_recommendation_t* out_recommendation,
                                               oep_package_id_list_t* out_evidence_ids);

/* One EvidenceNode, fixed-layout (see this section's "Evidence Graph
   exposure" header note -- EvidenceRelationship edges and full-graph
   enumeration are NOT exposed). */
typedef struct oep_evidence_node_t {
    char evidence_id[OEP_MAX_EVIDENCE_ID];
    int kind; /* mirrors oep::engine::EvidenceKind's declared order */
    char reference_id[OEP_MAX_EVIDENCE_REFERENCE_ID];
    char detail[OEP_MAX_EVIDENCE_DETAIL];
} oep_evidence_node_t;

/* Fetches one EvidenceNode by `evidence_id` from `session_id`'s most
   recent ReasoningReport's Evidence Graph. `session_id` not created on
   this handle, or `evidence_id` not found within that session's
   Evidence Graph, is OEP_ERROR_NOT_FOUND. `runtime`, `session_id`, and
   `evidence_id` must not be NULL. */
oep_result_t oep_reasoning_get_evidence_node(OEP_Runtime runtime, const char* session_id, const char* evidence_id,
                                              oep_evidence_node_t* out_node);

/* ------------------------------------------------------------------ */
/* Engineering Intelligence Platform (WP-EKE-007)                      */
/* ------------------------------------------------------------------ */
/*
 * Exposes oep::engine::EngineeringIntelligencePlatform (EIP), the
 * top-level facade over every lower engine (Knowledge Graph, Query,
 * Rules, Validation, Analysis, Reasoning). Every function below calls
 * through `runtime`'s intelligence_platform, which itself only touches
 * those six engines (via their existing constructor references) --
 * never RuntimeService/FoundationRuntime directly. Only valid from
 * RepositoryOpen; fail with OEP_ERROR_INVALID_STATE otherwise.
 *
 * Graph-readiness precondition: the five Workflow functions
 * (oep_eip_query/inspect/validate/analyze/reason -- oep_eip_recommend
 * too) and the three stateless Service Orchestrator functions
 * (oep_eip_engineering_summary/engineering_health/
 * engineering_recommendations) all require a prior successful
 * oep_engine_load_graph AND oep_kge_build_graph/oep_kge_refresh_graph,
 * mirroring EngineeringIntelligencePlatform::graph_ready(). Session
 * management (create/resume/clone/close/switch/list/get/export_summary)
 * does NOT require this, mirroring oep_reasoning_create_session's own
 * precedent.
 *
 * Session lifecycle: sessions are held IN-MEMORY, per-handle, for the
 * handle's lifetime -- exactly like every prior EKE session registry
 * (WP-EKE-005's ValidationSessions, WP-EKE-006's ReasoningSessions) --
 * and are NOT persisted; a session_id from a previous process (or a
 * different oep_runtime_impl handle) is always OEP_ERROR_NOT_FOUND
 * here. Every Workflow function requires `session_id` to already exist
 * on this handle (via oep_eip_create_session/resume_session/
 * clone_session) -- an unknown session_id is OEP_ERROR_NOT_FOUND,
 * checked explicitly here since the underlying C++ KnowledgeSessionManager
 * mutation methods silently no-op on an unknown id rather than
 * signaling an error (see knowledge_session_manager.hpp).
 *
 * Session summary shape: oep_knowledge_session_summary_t exposes
 * COUNTS only for each history/active-set list (query_history_count,
 * etc.), not the underlying description strings themselves -- mirroring
 * every prior work package's "summary struct, fetch detail separately"
 * precedent (WP-EKE-004/005/006's oep_*_summary_t structs). The
 * descriptions themselves remain available via
 * oep_eip_export_session_summary's human-readable text export.
 *
 * oep_eip_engineering_recommendations shape: EngineeringRecommendation
 * objects normally live inside a caller's own ReasoningSession
 * (fetchable by id via oep_reasoning_get_recommendation), but
 * EngineeringIntelligencePlatform::engineering_recommendations creates
 * its own EPHEMERAL internal ReasoningSession each call, which is never
 * exposed and cannot be queried afterward. Given this, this function
 * returns just the recommendation MESSAGE strings via the reused
 * oep_package_id_list_t (a step further from its literal "package id
 * list" name than any prior reuse in this API, but the simplest shape
 * that avoids inventing a retrieval path into a session nothing else
 * can ever reach) -- a caller wanting full EngineeringRecommendation
 * objects (kind/object_id/evidence) should instead use
 * oep_reasoning_create_session + oep_reasoning_execute +
 * oep_reasoning_recommendations / oep_reasoning_get_recommendation
 * directly (WP-EKE-006), over their OWN session.
 */

#define OEP_MAX_WORKFLOW_SUMMARY 512

/* Mirrors oep::engine::WorkflowKind. */
typedef enum oep_workflow_kind_t {
    OEP_WORKFLOW_INSPECT = 0,
    OEP_WORKFLOW_QUERY = 1,
    OEP_WORKFLOW_VALIDATE = 2,
    OEP_WORKFLOW_ANALYZE = 3,
    OEP_WORKFLOW_REASON = 4,
    OEP_WORKFLOW_RECOMMEND = 5,
} oep_workflow_kind_t;

/* Returns a static, human-readable name for `kind` (e.g. "Inspect").
   Never returns NULL. */
const char* oep_workflow_kind_to_string(oep_workflow_kind_t kind);

/* Mirrors oep::engine::InspectionTargetKind. */
typedef enum oep_inspection_target_kind_t {
    OEP_INSPECTION_TARGET_OBJECT = 0,
    OEP_INSPECTION_TARGET_PACKAGE = 1,
    OEP_INSPECTION_TARGET_CONTEXT = 2,
} oep_inspection_target_kind_t;

/* Returns a static, human-readable name for `kind` (e.g. "Object").
   Never returns NULL. */
const char* oep_inspection_target_kind_to_string(oep_inspection_target_kind_t kind);

/* The one shape every workflow returns (see intelligence_types.hpp's
   WorkflowResult), fixed-layout except for the object_id list, which is
   returned separately via the paired `oep_package_id_list_t` output
   parameter every oep_eip_* workflow function below takes. */
typedef struct oep_workflow_result_t {
    oep_workflow_kind_t kind;
    int success;
    char summary[OEP_MAX_WORKFLOW_SUMMARY];
    double execution_time_ms;
} oep_workflow_result_t;

/* Creates a new KnowledgeSession (see
   EngineeringIntelligencePlatform::create_session) and writes its
   session_id into `out_session_id` (truncated to `buffer_size` bytes,
   always NUL-terminated). Does NOT require a built graph. `runtime` and
   `out_session_id` must not be NULL; `buffer_size` must be greater than
   0. */
oep_result_t oep_eip_create_session(OEP_Runtime runtime, char* out_session_id, size_t buffer_size);

/* Marks `session_id` as resumed / most-recently-active (see
   EngineeringIntelligencePlatform::resume_session). Fails with
   OEP_ERROR_NOT_FOUND for an unknown or already-closed session_id.
   `runtime` and `session_id` must not be NULL. */
oep_result_t oep_eip_resume_session(OEP_Runtime runtime, const char* session_id);

/* Clones `session_id`'s history/active-set snapshot into a new session
   (statistics reset to zero -- see
   EngineeringIntelligencePlatform::clone_session) and writes the new
   session_id into `out_session_id` (same buffer contract as
   oep_eip_create_session). Fails with OEP_ERROR_NOT_FOUND if
   `session_id` is unknown. `runtime`, `session_id`, and `out_session_id`
   must not be NULL; `buffer_size` must be greater than 0. */
oep_result_t oep_eip_clone_session(OEP_Runtime runtime, const char* session_id, char* out_session_id,
                                    size_t buffer_size);

/* Closes `session_id` (see EngineeringIntelligencePlatform::close_session).
   Fails with OEP_ERROR_NOT_FOUND for an unknown session_id. `runtime`
   and `session_id` must not be NULL. */
oep_result_t oep_eip_close_session(OEP_Runtime runtime, const char* session_id);

/* Sets this handle's "current" session pointer to `session_id` (a CLI/
   convenience concept -- see EngineeringIntelligencePlatform::switch_session's
   own doc comment; every Workflow function below always takes an
   explicit session_id and never relies on this). Fails with
   OEP_ERROR_NOT_FOUND for an unknown or closed session_id. `runtime`
   and `session_id` must not be NULL. */
oep_result_t oep_eip_switch_session(OEP_Runtime runtime, const char* session_id);

/* Every session_id ever created on this handle (including closed ones),
   sorted (see EngineeringIntelligencePlatform::list_sessions). `runtime`
   and `out_session_ids` must not be NULL.

   Ownership: on success, the caller owns `out_session_ids->items` and
   must release it with exactly one call to oep_package_id_list_release. */
oep_result_t oep_eip_list_sessions(OEP_Runtime runtime, oep_package_id_list_t* out_session_ids);

/* Scalar, count-only summary of one KnowledgeSession -- see this
   section's "Session summary shape" header note. */
typedef struct oep_knowledge_session_summary_t {
    char session_id[OEP_MAX_SESSION_ID];
    char created_utc[OEP_MAX_TIMESTAMP];
    char last_active_utc[OEP_MAX_TIMESTAMP];
    int closed;
    int query_history_count;
    int validation_history_count;
    int analysis_history_count;
    int reasoning_history_count;
    int recommendation_count;
    int active_object_count;
    int active_package_count;
    double total_execution_time_ms;
} oep_knowledge_session_summary_t;

/* Fetches `session_id`'s KnowledgeSession (see
   EngineeringIntelligencePlatform::get_session). Fails with
   OEP_ERROR_NOT_FOUND for an unknown session_id. `runtime`, `session_id`,
   and `out_session` must not be NULL. */
oep_result_t oep_eip_get_session(OEP_Runtime runtime, const char* session_id,
                                  oep_knowledge_session_summary_t* out_session);

/* A short, human-readable text summary of `session_id` (see
   EngineeringIntelligencePlatform::export_session_summary), allocated
   on the heap. Fails with OEP_ERROR_NOT_FOUND for an unknown session_id.
   `runtime`, `session_id`, `out_summary`, and `out_length` must not be
   NULL.

   Ownership: on success, the caller owns `*out_summary` and must
   release it with exactly one call to oep_string_release. */
oep_result_t oep_eip_export_session_summary(OEP_Runtime runtime, const char* session_id, char** out_summary,
                                             size_t* out_length);

/* "Query" workflow (see EngineeringIntelligencePlatform::query).
   `session_id` must already exist on this handle (OEP_ERROR_NOT_FOUND
   otherwise). Requires a built graph. `runtime`, `session_id`, and
   `primary_object_id` must not be NULL (`primary_object_id` may be
   empty). `out_result` and `out_object_ids` may each be NULL if not
   needed.

   Ownership: on success, if non-NULL, the caller owns
   `out_object_ids->items` and must release it with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_eip_query(OEP_Runtime runtime, const char* session_id, oep_query_category_t category,
                            const char* primary_object_id, oep_workflow_result_t* out_result,
                            oep_package_id_list_t* out_object_ids);

/* "Inspect" workflow (see EngineeringIntelligencePlatform::inspect).
   Same session_id/graph-readiness contract as oep_eip_query. `target_id`
   must not be NULL (may be empty when `kind` is
   OEP_INSPECTION_TARGET_CONTEXT). Same ownership as oep_eip_query. */
oep_result_t oep_eip_inspect(OEP_Runtime runtime, const char* session_id, oep_inspection_target_kind_t kind,
                              const char* target_id, oep_workflow_result_t* out_result,
                              oep_package_id_list_t* out_object_ids);

/* "Validate" workflow (see EngineeringIntelligencePlatform::validate).
   Same session_id/graph-readiness contract as oep_eip_query. `object_id`
   must not be NULL. Same ownership as oep_eip_query. */
oep_result_t oep_eip_validate(OEP_Runtime runtime, const char* session_id, const char* object_id,
                               oep_validation_profile_t profile, oep_workflow_result_t* out_result,
                               oep_package_id_list_t* out_object_ids);

/* "Analyze" workflow (see EngineeringIntelligencePlatform::analyze).
   Same session_id/graph-readiness contract as oep_eip_query. `object_id`
   must not be NULL. Same ownership as oep_eip_query. */
oep_result_t oep_eip_analyze(OEP_Runtime runtime, const char* session_id, const char* object_id,
                              oep_workflow_result_t* out_result, oep_package_id_list_t* out_object_ids);

/* "Reason" workflow (see EngineeringIntelligencePlatform::reason).
   Same session_id/graph-readiness contract as oep_eip_query.
   `starting_object_ids` may be NULL only if `starting_object_id_count
   == 0` (mirrors oep_reasoning_create_session's array-of-strings
   convention). `objective` must not be NULL (may be empty). Same
   ownership as oep_eip_query. */
oep_result_t oep_eip_reason(OEP_Runtime runtime, const char* session_id, const char* objective,
                             const char* const* starting_object_ids, int starting_object_id_count,
                             oep_workflow_result_t* out_result, oep_package_id_list_t* out_object_ids);

/* "Recommend" workflow (see EngineeringIntelligencePlatform::recommend).
   Same session_id/graph-readiness contract as oep_eip_query. `object_id`
   must not be NULL. `out_object_ids`, if non-NULL, is filled with each
   recommendation's target object_id (one entry per recommendation, see
   WorkflowResult::object_ids). Same ownership as oep_eip_query. */
oep_result_t oep_eip_recommend(OEP_Runtime runtime, const char* session_id, const char* object_id,
                                oep_workflow_result_t* out_result, oep_package_id_list_t* out_object_ids);

#define OEP_MAX_REPORT_SUMMARY 512

/* Scalar mirror of oep::engine::EngineeringSummaryReport. */
typedef struct oep_engineering_summary_report_t {
    int object_count;
    int relationship_count;
    int connected_component_count;
    int validation_pass_count;
    int validation_finding_count;
    char summary[OEP_MAX_REPORT_SUMMARY];
} oep_engineering_summary_report_t;

/* Stateless Service Orchestrator call (see
   EngineeringIntelligencePlatform::engineering_summary). No session
   required. Requires a built graph. `runtime` and `out_summary` must
   not be NULL. */
oep_result_t oep_eip_engineering_summary(OEP_Runtime runtime, oep_engineering_summary_report_t* out_summary);

/* Scalar mirror of oep::engine::EngineeringHealthReport. */
typedef struct oep_engineering_health_report_t {
    double health_score;
    int passed;
    int failed;
    int warnings;
    int errors;
    int critical;
    char summary[OEP_MAX_REPORT_SUMMARY];
} oep_engineering_health_report_t;

/* Stateless Service Orchestrator call (see
   EngineeringIntelligencePlatform::engineering_health). No session
   required. Requires a built graph. `runtime` and `out_health` must not
   be NULL. */
oep_result_t oep_eip_engineering_health(OEP_Runtime runtime, oep_engineering_health_report_t* out_health);

/* Stateless Service Orchestrator call (see
   EngineeringIntelligencePlatform::engineering_recommendations and this
   section's "oep_eip_engineering_recommendations shape" header note).
   No session required. Requires a built graph. `runtime`, `object_id`,
   and `out_recommendation_messages` must not be NULL.

   Ownership: on success, the caller owns
   `out_recommendation_messages->items` (each `.id` field holding one
   recommendation's message text, truncated to OEP_MAX_PACKAGE_ID bytes)
   and must release it with exactly one call to
   oep_package_id_list_release. */
oep_result_t oep_eip_engineering_recommendations(OEP_Runtime runtime, const char* object_id,
                                                  oep_package_id_list_t* out_recommendation_messages);

/* Scalar mirror of oep::engine::RuntimeMetrics. */
typedef struct oep_runtime_metrics_t {
    int query_count;
    int validation_count;
    int analysis_count;
    int reasoning_count;
    int cache_hits;
    int cache_misses;
    int active_session_count;
    int total_session_count;
    double total_execution_time_ms;
} oep_runtime_metrics_t;

/* Snapshot of this handle's Runtime Metrics (see
   EngineeringIntelligencePlatform::runtime_metrics). No session
   required, no graph-readiness precondition (a fresh handle simply
   reports all zeros). `runtime` and `out_metrics` must not be NULL. */
oep_result_t oep_eip_runtime_metrics(OEP_Runtime runtime, oep_runtime_metrics_t* out_metrics);

/* Clears the Query Engine's cache (see
   EngineeringIntelligencePlatform::invalidate_caches). No session
   required, no graph-readiness precondition. `runtime` must not be
   NULL. */
oep_result_t oep_eip_invalidate_caches(OEP_Runtime runtime);

/* Closes every open session on this handle and clears every lower
   engine's cache (see EngineeringIntelligencePlatform::cleanup).
   `runtime` must not be NULL. */
oep_result_t oep_eip_cleanup(OEP_Runtime runtime);

#ifdef __cplusplus
}
#endif

#endif /* OEP_API_H */
