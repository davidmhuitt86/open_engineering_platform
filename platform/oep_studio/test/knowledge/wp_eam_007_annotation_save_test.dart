import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart';

// Animations (dialog routes, ExpansionTile) start on the first frame after
// the trigger, so they need a frame to begin and another to run to the end.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// WP-EAM-007 § A: the Inspector's explicit "Save Changes". These tests read
/// the PERSISTED session (reloaded from storage), never a TextEditingController.
void main() {
  final now = DateTime(2026, 1, 1);

  // Real file IO cannot complete under the widget tester's fake clock, so the
  // physical write is swapped for an in-memory sink; the "reload" below decodes
  // exactly the JSON that `KnowledgeSessionStorage.save` would have written.
  final written = <String, String>{};

  setUp(() {
    written.clear();
    KnowledgeSessionStorage.debugSetWriter((id, json) async => written[id] = json);
  });

  tearDown(() => KnowledgeSessionStorage.debugSetWriter(null));

  late ProviderContainer container;
  late String sessionId;
  late SourceMaterial source;
  late List<EvidenceRegion> regions;

  Future<void> openInspector(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);
    sessionId = 'wp-eam-007-${DateTime.now().microsecondsSinceEpoch}';
    source = SourceMaterial(
      id: 'source-1',
      originalFileName: 'trx300.png',
      localPath: 'unused.png',
      type: SourceMaterialType.image,
      sizeBytes: 1,
      importDate: now,
      addedBy: 'test',
    );
    container = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(
        () => _SeededNotifier(
          KnowledgeSession(
            id: sessionId,
            name: 'save test',
            repositoryName: 'Repo',
            author: 'jsmith',
            createdTime: now,
            lastModified: now,
          ),
          source,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);
    regions = [
      for (var i = 0; i < 2; i++)
        notifier.createHumanAnnotation(
          sourceId: source.id,
          page: 1,
          x: 0.1 + i * 0.3,
          y: 0.1,
          width: 0.2,
          height: 0.1,
          annotatorId: 'jsmith',
        ),
    ];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExtractionInspectorDialog(context, source: source),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<EvidenceRegion> persisted(WidgetTester tester, String regionId) async {
    await KnowledgeSessionStorage.flushPendingForTest();
    final record = KnowledgeSessionRecord.fromJson(jsonDecode(written[sessionId]!) as Map<String, dynamic>);
    return record.evidenceRegions.firstWhere((r) => r.id == regionId);
  }

  Finder nameField(int index) =>
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Name (optional)').at(index);

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const ValueKey('save-annotation-changes')));

  testWidgets('Save Changes is disabled until an annotation field is dirty', (tester) async {
    await openInspector(tester);
    expect(saveButton(tester).onPressed, isNull);
    await tester.enterText(nameField(0), 'Pump Relay');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a typed name (no Enter, no type) is persisted by Save Changes, and survives autosave + reload', (tester) async {
    await openInspector(tester);
    await tester.enterText(nameField(0), 'Pump Relay');
    await tester.pump();
    // Not persisted yet: focus/typing alone is not a persistence path.
    expect((await persisted(tester, regions[0].id)).annotation?.name, isNull);

    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull, reason: 'clean after save');
    expect((await persisted(tester, regions[0].id)).annotation?.name, 'Pump Relay');

    // A later autosave triggered by an unrelated edit must not erase it.
    container.read(foundationRuntimeServiceProvider.notifier).createHumanAnnotation(
          sourceId: source.id,
          page: 1,
          x: 0.6,
          y: 0.6,
          width: 0.1,
          height: 0.1,
          annotatorId: 'jsmith',
        );
    await tester.pump();
    expect((await persisted(tester, regions[0].id)).annotation?.name, 'Pump Relay');
  });

  testWidgets('name + type + notes + property across multiple annotations persist together', (tester) async {
    await openInspector(tester);
    // Annotation 0: classify, name, notes, property.
    await tester.tap(find.byType(DropdownButton<KnowledgeCandidateType>).at(0));
    await settle(tester);
    await tester.tap(find.text(KnowledgeCandidateType.values.first.label).last);
    await settle(tester);
    await tester.enterText(nameField(0), 'First');
    await tester.enterText(nameField(1), 'Second');
    Finder inCard(Finder f) => find.descendant(of: find.byKey(ValueKey('annotation-${regions[0].id}')), matching: f);
    Finder field(String hint) =>
        inCard(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint));
    await tester.tap(inCard(find.text('Details')));
    await settle(tester);
    await tester.enterText(
      inCard(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Description / Notes')),
      'checked in the field',
    );
    await tester.ensureVisible(inCard(find.text('Add Property')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(inCard(find.text('Add Property')));
    await tester.pump();
    await tester.enterText(field('key'), 'Part Number');
    await tester.enterText(field('value'), '123-456');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await tester.pump();

    final first = await persisted(tester, regions[0].id);
    expect(first.annotation?.name, 'First');
    expect(first.annotation?.type, KnowledgeCandidateType.values.first.name);
    expect(first.notes, 'checked in the field');
    expect(first.annotation?.properties.single.key, 'part_number');
    expect(first.annotation?.properties.single.value, '123-456');
    expect((await persisted(tester, regions[1].id)).annotation?.name, 'Second');
  });

  testWidgets('closing with unsaved changes asks; Discard drops them, Save keeps them, Cancel stays', (tester) async {
    await openInspector(tester);
    await tester.enterText(nameField(0), 'Unsaved');
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('unsaved-cancel')));
    await settle(tester);
    expect(find.text('Save changes?'), findsNothing);
    expect(find.textContaining('Extraction Inspector —'), findsOneWidget, reason: 'Cancel keeps the Inspector open');

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('unsaved-discard')));
    await settle(tester);
    expect(find.textContaining('Extraction Inspector —'), findsNothing);
    expect((await persisted(tester, regions[0].id)).annotation?.name, isNull);
  });

  testWidgets('choosing Save on close persists and closes', (tester) async {
    await openInspector(tester);
    await tester.enterText(nameField(0), 'Saved on close');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('unsaved-save')));
    await settle(tester);
    expect(find.textContaining('Extraction Inspector —'), findsNothing);
    expect((await persisted(tester, regions[0].id)).annotation?.name, 'Saved on close');
  });

  testWidgets('closing with no changes closes immediately', (tester) async {
    await openInspector(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Save changes?'), findsNothing);
    expect(find.textContaining('Extraction Inspector —'), findsNothing);
  });

  testWidgets('Save shows a confirmation and the Inspector then closes without a prompt', (tester) async {
    await openInspector(tester);
    await tester.enterText(nameField(0), 'Confirmed');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await tester.pump();
    expect(find.text('Changes saved'), findsOneWidget);
    // Let the autosave state update rebuild the dialog, then close: no prompt.
    await settle(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Save changes?'), findsNothing);
    expect(find.textContaining('Extraction Inspector —'), findsNothing);
  });

  testWidgets('a classified name that duplicates another candidate is reported, not swallowed', (tester) async {
    await openInspector(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(DropdownButton<KnowledgeCandidateType>).at(i));
      await settle(tester);
      await tester.tap(find.text(KnowledgeCandidateType.component.label).last);
      await settle(tester);
      await tester.enterText(nameField(i), 'Relay');
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await tester.pump();
    // One saved, the duplicate is reported and stays unsaved.
    expect(find.textContaining('Not saved:'), findsOneWidget);
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull, reason: 'the duplicate is still dirty');
    expect((await persisted(tester, regions[0].id)).annotation?.name, 'Relay');
    // Fixing the name saves it.
    await tester.enterText(nameField(1), 'Relay 2');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await tester.pump();
    expect(find.text('Changes saved'), findsOneWidget);
    expect((await persisted(tester, regions[1].id)).annotation?.name, 'Relay 2');
  });

  testWidgets('reopening shows the persisted values', (tester) async {
    await openInspector(tester);
    await tester.enterText(nameField(0), 'Persisted Name');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
    final field = tester.widget<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Name (optional)').first);
    expect(field.controller!.text, 'Persisted Name');
  });
}

class _SeededNotifier extends FoundationRuntimeNotifier {
  _SeededNotifier(this.session, this.source);

  final KnowledgeSession session;
  final SourceMaterial source;

  @override
  FoundationServiceState build() => FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        knowledgeSession: session,
        sourceMaterials: [source],
      );
}
