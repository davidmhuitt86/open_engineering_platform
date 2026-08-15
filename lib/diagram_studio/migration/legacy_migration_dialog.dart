import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'legacy_migration_models.dart';

/// The migration UI entry point (AP-DS-002, "Migration" section): a
/// modal that drives one [LegacyMigrator.migrate] call for a local
/// legacy JSON document and presents the result — including failure
/// and rollback — honestly, never behind a generic error toast.
///
/// Intended call site (documented for reconciliation, not wired here
/// per scope — see the document-bar integration notes in the task
/// report): a "Migrate to Repository…" action on the document bar or
/// Project Browser, invoked as:
///
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => LegacyMigrationDialog(
///     migrator: repositoryService, // implements LegacyMigrator
///     legacyFilePath: currentDocumentPath,
///   ),
/// );
/// ```
class LegacyMigrationDialog extends StatefulWidget {
  const LegacyMigrationDialog({
    required this.migrator,
    required this.legacyFilePath,
    super.key,
  });

  final LegacyMigrator migrator;
  final String legacyFilePath;

  @override
  State<LegacyMigrationDialog> createState() => _LegacyMigrationDialogState();
}

enum _MigrationPhase { running, done }

class _LegacyMigrationDialogState extends State<LegacyMigrationDialog> {
  _MigrationPhase _phase = _MigrationPhase.running;
  LegacyMigrationResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    LegacyMigrationResult result;
    try {
      result = await widget.migrator.migrate(widget.legacyFilePath);
    } catch (error) {
      // A thrown exception is still a migration failure the user must
      // see plainly — not swallowed into a toast.
      result = LegacyMigrationResult(
        success: false,
        legacyFilePath: widget.legacyFilePath,
        errorMessage: error.toString(),
      );
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _phase = _MigrationPhase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(
        _phase == _MigrationPhase.running ? 'Migrating to Repository…' : _resultTitle(),
        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 16),
      ),
      content: SizedBox(
        width: 440,
        child: _phase == _MigrationPhase.running ? _RunningBody(path: widget.legacyFilePath) : _ResultBody(result: _result!),
      ),
      actions: [
        if (_phase == _MigrationPhase.done)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('Close'),
          ),
      ],
    );
  }

  String _resultTitle() {
    final result = _result!;
    if (result.success) return 'Migration Complete';
    return result.rolledBack ? 'Migration Failed — Rolled Back' : 'Migration Failed';
  }
}

class _RunningBody extends StatelessWidget {
  const _RunningBody({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: StudioColors.selection),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Converting "$path" to a repository-backed Engineering Project…',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result});

  final LegacyMigrationResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.success ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: result.success ? StudioColors.success : StudioColors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.success
                    ? 'Migrated to "${result.repositoryName ?? 'repository'}" as project '
                        '${result.projectObjectId ?? ''}.'
                    : result.errorMessage ?? 'Migration failed for an unknown reason.',
                style: TextStyle(
                  color: result.success ? StudioColors.textPrimary : StudioColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        if (!result.success)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              result.rolledBack
                  ? 'Your repository was left unchanged — no partial project was created.'
                  : 'Rollback status unknown — check the repository before retrying.',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
            ),
          ),
        if (result.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text(
            'Conversion detail',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: result.items.length,
              itemBuilder: (context, index) {
                final item = result.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.succeeded ? Icons.check : Icons.close,
                        size: 14,
                        color: item.succeeded ? StudioColors.success : StudioColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                            ),
                            if (item.detail != null)
                              Text(
                                item.detail!,
                                style: const TextStyle(color: StudioColors.error, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
