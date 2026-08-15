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

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Versioning (OEP-SPEC-021 section 8)                                 */
/* ------------------------------------------------------------------ */

/* The Public C API's own version. Incremented whenever a function or
   structure is added, changed, or removed. */
#define OEP_API_VERSION 9

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
 * Atomic since WP-REP-003 (see oep_package_install's own documentation):
 * a failure partway through rolls back every object/relationship already
 * created. oep_package_uninstall (WP-REP-005, below the Package Lifecycle
 * Queries section) is the inverse operation. Dependency resolution and
 * updates are not part of this surface -- see OEP-ARCH-002 for the
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

/* The outcome of a successful oep_package_uninstall call. Not populated
   (zero-initialized) when the call fails -- see oep_result_t for the
   failure reason. */
typedef struct oep_package_uninstall_result_t {
    char package_id[OEP_MAX_PACKAGE_ID];
    char version[OEP_MAX_PACKAGE_VERSION];
    int objects_deleted;
    int relationships_deleted;
} oep_package_uninstall_result_t;

/* Uninstalls the package identified by `package_id` from the currently
   open repository: deletes every Engineering Object and Relationship the
   Repository Registry recorded for it (via the same paths
   oep_object_delete/oep_relationship_delete already use), then removes
   the Repository Registry record itself. Atomic (WP-REP-003 Repository
   Transaction): a failure partway through rolls back every delete
   already performed, leaving the package installed exactly as it was.
   Only valid from RepositoryOpen; fails with OEP_ERROR_INVALID_STATE
   otherwise. Fails with OEP_ERROR_NOT_FOUND if no package with that ID
   is installed. `package_id` must not be NULL. `out_result` may be NULL;
   if non-NULL, it is populated on success and zero-initialized on
   failure. Does not delete or otherwise touch the source .oep archive
   the package was originally installed from. */
oep_result_t oep_package_uninstall(OEP_Runtime runtime, const char* package_id,
                                    oep_package_uninstall_result_t* out_result);

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

#ifdef __cplusplus
}
#endif

#endif /* OEP_API_H */
