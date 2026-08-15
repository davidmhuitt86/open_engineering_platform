#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace oep::runtime {

// The Repository Transaction Engine's persistent journal (WP-REP-003,
// implementing the install-scope subset of PKG-003 — Package Transaction
// Engine). One JSON record per completed transaction under
// `<repository>/logs/transactions/<transactionId>.json` — inside the
// `logs/` directory OEP-SPEC-002 §5 already reserves, so no new
// repository-layout concept is introduced.
//
// The journal records what happened; the in-memory undo log inside
// FoundationRuntime (Work Package 014's compensating-action mechanism,
// reused unchanged) is what actually performs a rollback. A journal
// record is written once, when the transaction closes (Committed,
// RolledBack, or Failed) — there is no partially-written journal state
// to recover from, deliberately: crash-recovery/repair is PKG-003 §21
// (Repair Transactions) territory, deferred with update/uninstall.

// The subset of PKG-003 §5's transaction states WP-REP-003 implements.
// The full lifecycle (Pending/Planning/WaitingForApproval/Indexing/
// Activating/...) belongs to capabilities this Work Package excludes
// (dependency resolution, previews, activation).
enum class TransactionState {
    Opened,
    Committed,
    RolledBack,
    Failed, // rollback itself was attempted but could not fully complete
};

std::string to_string(TransactionState state);

// One journaled operation within a transaction (PKG-003 §15: operation,
// target, previous state, new state, status).
struct JournalEntry {
    std::string timestamp_utc;
    std::string operation;      // e.g. "ObjectCreated", "RelationshipDeleted", "PackageRecorded"
    std::string target_id;      // the object/relationship/package id the operation touched
    std::string previous_state; // e.g. "absent" or a short pre-state summary
    std::string new_state;      // e.g. "present" or a short post-state summary
};

// The permanent record of one closed transaction (PKG-003 §26).
struct TransactionRecord {
    std::string transaction_id; // UUIDv4
    TransactionState state = TransactionState::Opened;
    std::string description; // e.g. "install com.oep.demo.x" or "object mutation"
    std::string opened_utc;
    std::string closed_utc;
    std::vector<JournalEntry> entries;
};

struct JournalWriteResult {
    bool success = false;
    std::string error;
};

struct JournalListResult {
    bool success = false;
    std::string error;
    std::vector<TransactionRecord> records;
};

struct JournalLoadResult {
    bool success = false;
    std::string error;
    TransactionRecord record;
};

// Persists and reads transaction records. Writing is best-effort from the
// caller's perspective in one specific sense: FoundationRuntime treats a
// failed journal write on COMMIT as an error (the caller must know the
// audit trail is incomplete), but never lets a journal problem prevent a
// ROLLBACK from restoring repository state — restoring data always
// outranks recording history.
class TransactionJournal {
public:
    explicit TransactionJournal(std::filesystem::path journal_root);

    JournalWriteResult write(const TransactionRecord& record) const;

    // Every record in the journal, sorted by opened_utc then
    // transaction_id (deterministic). Records that fail to parse are
    // skipped, mirroring how RepositoryRegistry::list_installed treats a
    // corrupt registry file.
    JournalListResult list() const;

    JournalLoadResult load(const std::string& transaction_id) const;

private:
    std::filesystem::path journal_root_;
    std::filesystem::path path_for(const std::string& transaction_id) const;
};

} // namespace oep::runtime
