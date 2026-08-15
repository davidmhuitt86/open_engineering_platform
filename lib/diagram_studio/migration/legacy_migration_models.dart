/// Models for AP-DS-002's local-JSON → Engineering Repository migration.
///
/// These types describe the UI-side contract this work package assumes
/// for the parallel data-layer agent's migration implementation. The
/// exact assumed call is:
///
/// ```dart
/// Future<LegacyMigrationResult> migrate(String legacyFilePath);
/// ```
///
/// exposed by [LegacyMigrator] (an abstract interface only — no
/// implementation lives in this file; production code is expected to
/// supply a concrete implementation once the data layer lands, and
/// tests supply a fake). See `legacy_migration_dialog.dart` for the UI
/// that drives this call and presents [LegacyMigrationResult] honestly,
/// including failure and rollback, per the spec's "Error reporting" and
/// "Rollback on failure" requirements.
library;

/// One item converted (or attempted) during migration — e.g. one
/// diagram element mapped to an Engineering Object or Relationship.
class LegacyMigrationItem {
  const LegacyMigrationItem({
    required this.description,
    required this.succeeded,
    this.detail,
  });

  /// Human-readable description, e.g. "Sheet 'Main' → Engineering
  /// Object (Diagram)" or "Wire W-104 → Relationship".
  final String description;
  final bool succeeded;

  /// Failure detail (error message) when [succeeded] is false; null
  /// otherwise.
  final String? detail;
}

/// The outcome of a single `LegacyMigrator.migrate(...)` call.
class LegacyMigrationResult {
  const LegacyMigrationResult({
    required this.success,
    required this.legacyFilePath,
    this.projectObjectId,
    this.repositoryName,
    this.items = const [],
    this.errorMessage,
    this.rolledBack = false,
  });

  /// Overall success. `false` means nothing durable was left behind —
  /// per the spec's "Rollback on failure" requirement, a failed
  /// migration must not leave a partially-converted project in the
  /// repository.
  final bool success;

  final String legacyFilePath;

  /// The migrated Project's Engineering Object id, when [success].
  final String? projectObjectId;

  /// Which repository received the migrated project, when [success].
  final String? repositoryName;

  /// Per-element conversion outcomes, for the result dialog's detail
  /// list — shown regardless of overall success so the user can see
  /// exactly what was (or would have been) converted.
  final List<LegacyMigrationItem> items;

  /// Present when `!success`. Surfaced verbatim in the UI — never
  /// collapsed into a generic toast, per the spec.
  final String? errorMessage;

  /// True if a partial migration was detected and undone. Distinct
  /// from `!success` alone so the dialog can say "failed, and your
  /// repository was left unchanged" rather than leaving that
  /// ambiguous.
  final bool rolledBack;
}

/// The interface this UI assumes the parallel data-layer agent's
/// migration system will expose (likely as a method on
/// `DiagramRepositoryService` or a sibling class). Kept abstract here —
/// no production implementation — so this file compiles standalone and
/// the migration dialog can be built and tested against a fake today.
abstract class LegacyMigrator {
  /// Converts the legacy local JSON document at [legacyFilePath] into a
  /// repository-backed Engineering Project: automatic conversion,
  /// verification, and rollback-on-failure all happen inside this call
  /// per the spec; the UI only presents [LegacyMigrationResult].
  Future<LegacyMigrationResult> migrate(String legacyFilePath);
}
