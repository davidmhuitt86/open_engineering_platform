/*
 * Standalone Public C API manual verification program, per Work
 * Package 014's requirement for "Manual verification through a
 * standalone C API test program."
 *
 * This file is compiled as C (not C++) and includes only oep_api.h —
 * no Foundation internal header, no C++ type, nothing beyond what an
 * external application (Studio, an SDK, a Bridge) would have access
 * to. Successfully building and running this program from a plain C
 * translation unit is itself part of the verification: it demonstrates
 * the Public C API is a genuine, consumable C ABI, not merely a C-style
 * header implemented in a way only C++ can actually call.
 *
 * Usage: capi_manual_test <scratch-directory>
 * The scratch directory must not already exist; it is created fresh.
 * Exit code 0 means every check passed; nonzero means at least one
 * check failed (see stderr for which).
 */

#include "oep/api/oep_api.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <direct.h>
#define MAKE_DIR(path) _mkdir(path)
#else
#include <sys/stat.h>
#define MAKE_DIR(path) mkdir(path, 0755)
#endif

static int g_failures = 0;
static int g_checks = 0;

static void check(int condition, const char* description) {
    g_checks++;
    if (!condition) {
        g_failures++;
        fprintf(stderr, "FAIL: %s\n", description);
    } else {
        printf("ok:   %s\n", description);
    }
}

/* Writes a minimal, valid repository.json directly (no dependency on
   any Foundation C++ type — this program only ever touches oep_api.h). */
static int write_repository_metadata(const char* repository_json_path) {
    FILE* file = fopen(repository_json_path, "wb");
    if (file == NULL) {
        return 0;
    }
    fputs("{\n"
          "  \"repositoryId\": \"1b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
          "  \"repositoryName\": \"capi-manual-test\",\n"
          "  \"repositoryVersion\": \"1.0.0\",\n"
          "  \"foundationVersion\": \"0.1.0\",\n"
          "  \"templateVersion\": \"1.0\",\n"
          "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
          "  \"lastModifiedUtc\": \"2026-01-01T00:00:00Z\",\n"
          "  \"description\": \"\",\n"
          "  \"author\": \"\",\n"
          "  \"organization\": \"\",\n"
          "  \"tags\": []\n"
          "}\n",
          file);
    fclose(file);
    return 1;
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <scratch-directory>\n", argv[0]);
        return 2;
    }
    const char* scratch_dir = argv[1];

    printf("== Versioning ==\n");
    printf("Foundation version: %s\n", oep_foundation_version());
    printf("API version:        %d\n", oep_api_version());
    printf("ABI version:        %d\n", oep_abi_version());

    if (MAKE_DIR(scratch_dir) != 0) {
        fprintf(stderr, "could not create scratch directory '%s' (does it already exist?)\n", scratch_dir);
        return 2;
    }

    char repository_json_path[1024];
    snprintf(repository_json_path, sizeof(repository_json_path), "%s/repository.json", scratch_dir);
    if (!write_repository_metadata(repository_json_path)) {
        fprintf(stderr, "could not write '%s'\n", repository_json_path);
        return 2;
    }

    printf("\n== Lifecycle ==\n");
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    check(runtime != NULL, "oep_runtime_create succeeds");

    oep_result_t result = oep_runtime_initialize(runtime);
    check(result.success != 0, "oep_runtime_initialize succeeds");

    result = oep_runtime_open_repository(runtime, scratch_dir);
    check(result.success != 0, "oep_runtime_open_repository succeeds");
    check(oep_runtime_get_state(runtime) == OEP_STATE_REPOSITORY_OPEN, "state is RepositoryOpen after open");

    printf("\n== Object Creation (TASK-000027) ==\n");
    const char* manual_tags[2];
    manual_tags[0] = "docs";
    manual_tags[1] = "manual-test";
    oep_object_info_t manual_object;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Manual", "A test document", "Jane", manual_tags, 2,
                                &manual_object);
    check(result.success != 0, "oep_object_create succeeds for a valid document");
    check(strlen(manual_object.object_id) == 36, "created object has a generated object_id");
    check(strcmp(manual_object.name, "Manual") == 0, "created object reports the given name");
    check(manual_object.tag_count == 2, "created object reports both tags");

    oep_object_info_t coil_object;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Ignition Coil", "", "Jane", NULL, 0, &coil_object);
    check(result.success != 0, "oep_object_create succeeds for a second object with no tags");

    oep_object_info_t null_name_object;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, NULL, "", "", NULL, 0, &null_name_object);
    check(result.success == 0 && result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_create fails with OEP_ERROR_INVALID_ARGUMENT for a NULL name");

    oep_object_info_t empty_name_object;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "", "", "", NULL, 0, &empty_name_object);
    check(result.success == 0 && result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_create fails for an empty name (Foundation's own validation, not duplicated here)");

    int object_count = -1;
    result = oep_object_store_get_count(runtime, &object_count);
    check(result.success != 0 && object_count == 2, "object count reflects both created objects");

    printf("\n== Object Update (TASK-000027) ==\n");
    oep_object_info_t updated_object;
    result = oep_object_update(runtime, manual_object.object_id, "Manual (Revised)", "Updated description", "Jane",
                                NULL, 0, &updated_object);
    check(result.success != 0, "oep_object_update succeeds");
    check(strcmp(updated_object.name, "Manual (Revised)") == 0, "updated object reports the new name");
    check(strcmp(updated_object.object_id, manual_object.object_id) == 0, "updated object keeps its object_id");

    result = oep_object_update(runtime, "00000000-0000-4000-8000-000000000000", "X", "", "", NULL, 0, NULL);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_object_update fails with OEP_ERROR_NOT_FOUND for a nonexistent object_id");

    printf("\n== Relationship Creation (TASK-000028) ==\n");
    oep_relationship_info_t relationship;
    result = oep_relationship_create(runtime, manual_object.object_id, coil_object.object_id,
                                      OEP_RELATIONSHIP_TYPE_DOCUMENTS, "Jane", "Manual documents the coil",
                                      &relationship);
    check(result.success != 0, "oep_relationship_create succeeds for two existing objects");
    check(strlen(relationship.relationship_id) == 36, "created relationship has a generated relationship_id");

    result = oep_relationship_create(runtime, "00000000-0000-4000-8000-000000000000", coil_object.object_id,
                                      OEP_RELATIONSHIP_TYPE_REFERENCES, "", "", NULL);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_relationship_create fails with OEP_ERROR_NOT_FOUND for a nonexistent source object");

    printf("\n== Relationship Update (TASK-000028) ==\n");
    oep_relationship_info_t updated_relationship;
    result = oep_relationship_update(runtime, relationship.relationship_id, "Jane Doe", "Revised description",
                                      &updated_relationship);
    check(result.success != 0, "oep_relationship_update succeeds");
    check(strcmp(updated_relationship.author, "Jane Doe") == 0, "updated relationship reports the new author");
    check(updated_relationship.relationship_type == OEP_RELATIONSHIP_TYPE_DOCUMENTS,
          "updated relationship keeps its original relationship_type");

    printf("\n== Transaction Rollback (TASK-000029) ==\n");
    check(oep_transaction_is_active(runtime) == 0, "no transaction is active before begin");
    result = oep_transaction_begin(runtime);
    check(result.success != 0, "oep_transaction_begin succeeds");
    check(oep_transaction_is_active(runtime) != 0, "transaction reports active after begin");

    oep_object_info_t transacted_object;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Doomed Object", "", "", NULL, 0,
                                &transacted_object);
    check(result.success != 0, "object create inside a transaction succeeds (and is visible immediately)");

    int count_during_transaction = -1;
    oep_object_store_get_count(runtime, &count_during_transaction);
    check(count_during_transaction == 3, "the object created inside the transaction is visible before rollback");

    result = oep_transaction_rollback(runtime);
    check(result.success != 0, "oep_transaction_rollback succeeds");
    check(oep_transaction_is_active(runtime) == 0, "transaction reports inactive after rollback");

    int count_after_rollback = -1;
    oep_object_store_get_count(runtime, &count_after_rollback);
    check(count_after_rollback == 2, "the object created inside the rolled-back transaction is gone");

    oep_object_info_t missing_after_rollback;
    result = oep_object_store_get_by_id(runtime, transacted_object.object_id, &missing_after_rollback);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "the rolled-back object cannot be looked up by ID");

    printf("\n== Automatic Rollback on Failure (TASK-000029) ==\n");
    result = oep_transaction_begin(runtime);
    check(result.success != 0, "a new transaction begins after the previous one was rolled back");

    oep_object_info_t survivor;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Survivor?", "", "", NULL, 0, &survivor);
    check(result.success != 0, "first create inside the second transaction succeeds");

    /* Empty name fails Foundation's own validation; this should abort
       and roll back the entire transaction automatically. */
    oep_object_info_t failed_create;
    result = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "", "", "", NULL, 0, &failed_create);
    check(result.success == 0, "second create inside the transaction fails (invalid empty name)");
    check(oep_transaction_is_active(runtime) == 0, "the transaction was automatically deactivated by the failure");

    oep_object_info_t missing_survivor;
    result = oep_object_store_get_by_id(runtime, survivor.object_id, &missing_survivor);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "the first create was automatically rolled back along with the failed second create");

    int count_after_auto_rollback = -1;
    oep_object_store_get_count(runtime, &count_after_auto_rollback);
    check(count_after_auto_rollback == 2, "object count is back to 2 after the automatic rollback");

    printf("\n== Batch Mutation (TASK-000030) ==\n");
    oep_object_create_spec_t batch_specs[3];
    batch_specs[0].object_type = OEP_OBJECT_TYPE_DOCUMENT;
    batch_specs[0].name = "Batch A";
    batch_specs[0].description = "";
    batch_specs[0].author = "";
    batch_specs[0].tags = NULL;
    batch_specs[0].tag_count = 0;
    batch_specs[1].object_type = OEP_OBJECT_TYPE_COMPONENT;
    batch_specs[1].name = "Batch B";
    batch_specs[1].description = "";
    batch_specs[1].author = "";
    batch_specs[1].tags = NULL;
    batch_specs[1].tag_count = 0;
    batch_specs[2].object_type = OEP_OBJECT_TYPE_DOCUMENT;
    batch_specs[2].name = "Batch C";
    batch_specs[2].description = "";
    batch_specs[2].author = "";
    batch_specs[2].tags = NULL;
    batch_specs[2].tag_count = 0;

    oep_batch_create_objects_result_t batch_result;
    result = oep_batch_create_objects(runtime, batch_specs, 3, &batch_result);
    check(result.success != 0, "oep_batch_create_objects succeeds for three valid specs");
    check(batch_result.success != 0, "batch result reports success");
    check(batch_result.created.count == 3, "batch result reports three created objects");
    check(strcmp(batch_result.created.items[0].name, "Batch A") == 0,
          "batch result preserves execution order (item 0 is Batch A)");
    check(strcmp(batch_result.created.items[2].name, "Batch C") == 0,
          "batch result preserves execution order (item 2 is Batch C)");
    oep_batch_create_objects_result_release(&batch_result);
    check(batch_result.created.items == NULL, "oep_batch_create_objects_result_release zeroes the created list");

    int count_after_batch = -1;
    oep_object_store_get_count(runtime, &count_after_batch);
    check(count_after_batch == 5, "object count reflects the 3 batch-created objects plus the original 2");

    /* A batch with a failing item in the middle must roll back completely. */
    oep_object_create_spec_t failing_batch_specs[3];
    failing_batch_specs[0].object_type = OEP_OBJECT_TYPE_DOCUMENT;
    failing_batch_specs[0].name = "Should Not Survive 1";
    failing_batch_specs[0].description = "";
    failing_batch_specs[0].author = "";
    failing_batch_specs[0].tags = NULL;
    failing_batch_specs[0].tag_count = 0;
    failing_batch_specs[1].object_type = OEP_OBJECT_TYPE_DOCUMENT;
    failing_batch_specs[1].name = ""; /* invalid: empty name */
    failing_batch_specs[1].description = "";
    failing_batch_specs[1].author = "";
    failing_batch_specs[1].tags = NULL;
    failing_batch_specs[1].tag_count = 0;
    failing_batch_specs[2].object_type = OEP_OBJECT_TYPE_DOCUMENT;
    failing_batch_specs[2].name = "Should Not Survive 3";
    failing_batch_specs[2].description = "";
    failing_batch_specs[2].author = "";
    failing_batch_specs[2].tags = NULL;
    failing_batch_specs[2].tag_count = 0;

    oep_batch_create_objects_result_t failing_batch_result;
    result = oep_batch_create_objects(runtime, failing_batch_specs, 3, &failing_batch_result);
    check(result.success == 0, "oep_batch_create_objects fails when one spec is invalid");
    check(failing_batch_result.failed_index == 1, "failed_index correctly identifies the second (0-based) spec");
    check(failing_batch_result.created.count == 0, "failing batch result reports zero created objects (rolled back)");

    int count_after_failed_batch = -1;
    oep_object_store_get_count(runtime, &count_after_failed_batch);
    check(count_after_failed_batch == 5, "object count is unchanged after the failed batch rolled back completely");

    printf("\n== Object and Relationship Deletion (TASK-000027, TASK-000028) ==\n");
    result = oep_relationship_delete(runtime, relationship.relationship_id);
    check(result.success != 0, "oep_relationship_delete succeeds");

    result = oep_relationship_delete(runtime, relationship.relationship_id);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "deleting the same relationship twice fails with OEP_ERROR_NOT_FOUND");

    result = oep_object_delete(runtime, coil_object.object_id);
    check(result.success != 0, "oep_object_delete succeeds");

    result = oep_object_delete(runtime, coil_object.object_id);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "deleting the same object twice fails with OEP_ERROR_NOT_FOUND");

    printf("\n== Shutdown ==\n");
    result = oep_runtime_close_repository(runtime);
    check(result.success != 0, "oep_runtime_close_repository succeeds");
    result = oep_runtime_shutdown(runtime);
    check(result.success != 0, "oep_runtime_shutdown succeeds");
    oep_runtime_destroy(runtime);

    printf("\n%d/%d checks passed.\n", g_checks - g_failures, g_checks);
    return g_failures == 0 ? 0 : 1;
}
