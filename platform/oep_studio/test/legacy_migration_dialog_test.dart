import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/migration/legacy_migration_dialog.dart';
import 'package:oep_studio/diagram_studio/migration/legacy_migration_models.dart';

/// A fake `LegacyMigrator` (AP-DS-002's migration UI has no production
/// implementation yet — the parallel data-layer agent builds that; this
/// dialog is built and tested against the assumed
/// `Future<LegacyMigrationResult> migrate(String legacyFilePath)`
/// interface, matching how other Studio tests fake bridge-backed
/// services — see `test/workflow/unified_workflow_test.dart`).
class _FakeMigrator implements LegacyMigrator {
  _FakeMigrator(this._result);
  final LegacyMigrationResult _result;

  @override
  Future<LegacyMigrationResult> migrate(String legacyFilePath) async => _result;
}

class _ThrowingMigrator implements LegacyMigrator {
  @override
  Future<LegacyMigrationResult> migrate(String legacyFilePath) async {
    throw StateError('repository connection lost');
  }
}

void main() {
  Widget harness(LegacyMigrator migrator, String path) {
    return MaterialApp(
      theme: StudioTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<LegacyMigrationResult>(
                context: context,
                builder: (_) => LegacyMigrationDialog(migrator: migrator, legacyFilePath: path),
              ),
              child: const Text('Migrate'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a running state, then a success result with item detail', (tester) async {
    final migrator = _FakeMigrator(
      const LegacyMigrationResult(
        success: true,
        legacyFilePath: 'C:/fake/diagram.json',
        projectObjectId: 'obj-42',
        repositoryName: 'MyRepo',
        items: [
          LegacyMigrationItem(description: "Sheet 'Main' → Diagram Object", succeeded: true),
        ],
      ),
    );

    await tester.pumpWidget(harness(migrator, 'C:/fake/diagram.json'));
    await tester.tap(find.text('Migrate'));
    await tester.pump();

    expect(find.text('Migrating to Repository…'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Migration Complete'), findsOneWidget);
    expect(find.textContaining('obj-42'), findsOneWidget);
    expect(find.textContaining("Sheet 'Main'"), findsOneWidget);
  });

  testWidgets('shows failure and rollback status honestly, not a generic toast', (tester) async {
    final migrator = _FakeMigrator(
      const LegacyMigrationResult(
        success: false,
        legacyFilePath: 'C:/fake/diagram.json',
        errorMessage: 'Object mapping failed for Sheet "Main": unsupported element type.',
        rolledBack: true,
      ),
    );

    await tester.pumpWidget(harness(migrator, 'C:/fake/diagram.json'));
    await tester.tap(find.text('Migrate'));
    await tester.pumpAndSettle();

    expect(find.text('Migration Failed — Rolled Back'), findsOneWidget);
    expect(find.textContaining('unsupported element type'), findsOneWidget);
    expect(find.textContaining('left unchanged'), findsOneWidget);
  });

  testWidgets('a thrown exception from the migrator is surfaced, not swallowed', (tester) async {
    await tester.pumpWidget(harness(_ThrowingMigrator(), 'C:/fake/diagram.json'));
    await tester.tap(find.text('Migrate'));
    await tester.pumpAndSettle();

    expect(find.text('Migration Failed'), findsOneWidget);
    expect(find.textContaining('repository connection lost'), findsOneWidget);
  });
}
