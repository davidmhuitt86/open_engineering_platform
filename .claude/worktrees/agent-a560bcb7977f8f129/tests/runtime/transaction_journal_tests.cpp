#include "oep/runtime/transaction_journal.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

oep::runtime::TransactionRecord sample_record(const std::string& id, const std::string& opened_utc) {
    oep::runtime::TransactionRecord record;
    record.transaction_id = id;
    record.state = oep::runtime::TransactionState::Committed;
    record.description = "sample transaction";
    record.opened_utc = opened_utc;
    record.closed_utc = opened_utc;

    oep::runtime::JournalEntry entry;
    entry.timestamp_utc = opened_utc;
    entry.operation = "ObjectCreated";
    entry.target_id = "obj-1";
    entry.previous_state = "absent";
    entry.new_state = "present:Widget";
    record.entries.push_back(entry);
    return record;
}

void test_write_then_load(const oep::runtime::TransactionJournal& journal) {
    const oep::runtime::JournalWriteResult written =
        journal.write(sample_record("11111111-0000-4000-8000-000000000001", "2026-01-01T00:00:00Z"));
    check(written.success, "write succeeds for a valid record: " + written.error);

    const oep::runtime::JournalLoadResult loaded = journal.load("11111111-0000-4000-8000-000000000001");
    check(loaded.success, "load succeeds for a written record");
    check(loaded.record.state == oep::runtime::TransactionState::Committed, "load preserves the state");
    check(loaded.record.description == "sample transaction", "load preserves the description");
    check(loaded.record.entries.size() == 1, "load preserves the journal entries");
    check(loaded.record.entries[0].operation == "ObjectCreated", "load preserves an entry's operation");
    check(loaded.record.entries[0].new_state == "present:Widget", "load preserves an entry's new state");
}

void test_write_rejects_an_empty_id(const oep::runtime::TransactionJournal& journal) {
    oep::runtime::TransactionRecord record = sample_record("", "2026-01-01T00:00:00Z");
    const oep::runtime::JournalWriteResult written = journal.write(record);
    check(!written.success, "write rejects a record with an empty transactionId");
}

void test_load_fails_for_an_unknown_id(const oep::runtime::TransactionJournal& journal) {
    const oep::runtime::JournalLoadResult loaded = journal.load("00000000-0000-4000-8000-00000000dead");
    check(!loaded.success, "load fails for a transaction that was never journaled");
}

void test_list_is_sorted_and_skips_corrupt_files(const std::filesystem::path& journal_root,
                                                  const oep::runtime::TransactionJournal& journal) {
    journal.write(sample_record("22222222-0000-4000-8000-000000000002", "2026-01-02T00:00:00Z"));
    journal.write(sample_record("33333333-0000-4000-8000-000000000003", "2026-01-01T12:00:00Z"));

    // A corrupt journal file must be skipped, not crash the listing.
    {
        std::ofstream corrupt(journal_root / "not-json.json", std::ios::trunc);
        corrupt << "{corrupt";
    }

    const oep::runtime::JournalListResult listed = journal.list();
    check(listed.success, "list succeeds with a corrupt file present");
    check(listed.records.size() == 3, "list returns every valid record and skips the corrupt one");
    bool sorted = true;
    for (std::size_t i = 1; i < listed.records.size(); ++i) {
        if (listed.records[i - 1].opened_utc > listed.records[i].opened_utc) sorted = false;
    }
    check(sorted, "list is sorted by opened time");
}

void test_list_empty_for_a_fresh_journal() {
    const std::filesystem::path root = std::filesystem::temp_directory_path() / "oep_transaction_journal_tests_empty";
    std::filesystem::remove_all(root);
    const oep::runtime::TransactionJournal journal(root);
    const oep::runtime::JournalListResult listed = journal.list();
    check(listed.success && listed.records.empty(), "a fresh journal lists no records");
    std::filesystem::remove_all(root);
}

void test_state_to_string() {
    check(oep::runtime::to_string(oep::runtime::TransactionState::Committed) == "Committed",
          "Committed stringifies correctly");
    check(oep::runtime::to_string(oep::runtime::TransactionState::RolledBack) == "RolledBack",
          "RolledBack stringifies correctly");
    check(oep::runtime::to_string(oep::runtime::TransactionState::Failed) == "Failed",
          "Failed stringifies correctly");
}

} // namespace

int main() {
    const std::filesystem::path root = std::filesystem::temp_directory_path() / "oep_transaction_journal_tests";
    std::filesystem::remove_all(root);
    const oep::runtime::TransactionJournal journal(root);

    test_write_then_load(journal);
    test_write_rejects_an_empty_id(journal);
    test_load_fails_for_an_unknown_id(journal);
    test_list_is_sorted_and_skips_corrupt_files(root, journal);
    test_list_empty_for_a_fresh_journal();
    test_state_to_string();

    std::filesystem::remove_all(root);

    if (g_failures == 0) {
        std::cout << "All TransactionJournal tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " TransactionJournal test(s) failed.\n";
    return 1;
}
