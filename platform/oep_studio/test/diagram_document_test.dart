import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';

/// Exercises `DiagramDocument` against a real temp directory
/// (WORK_PACKAGE_024, ENGINE-TASK-000111) — Open/Save/Save As/Close/
/// Dirty State, and that Graph + Layout round-trip together as one
/// file (the Repository Integration resolution documented in
/// `docs/REPOSITORY_INTEGRATION.md`).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('diagram_document_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EngineeringGraph buildGraph() {
    final graph = EngineeringGraph.empty('g1');
    return graph.withNode(const EngineeringNode(
      id: 'battery',
      category: NodeCategory.component,
      displayName: 'Battery',
      symbolId: 'battery',
    ));
  }

  DiagramLayoutState buildLayout() {
    return DiagramLayoutState.empty.withPositions({'battery': const Point2D(10, 20)});
  }

  test('saveAs writes graph and layout together, sets path, clears dirty', () async {
    final document = DiagramDocument();
    document.markDirty();
    final filePath = '${tempDir.path}/diagram.json';

    await document.saveAs(filePath, buildGraph(), buildLayout());

    expect(document.path, filePath);
    expect(document.isDirty, isFalse);
    expect(File(filePath).existsSync(), isTrue);
  });

  test('open reads back an equivalent graph and layout', () async {
    final document = DiagramDocument();
    final filePath = '${tempDir.path}/diagram.json';
    await document.saveAs(filePath, buildGraph(), buildLayout());

    final reopened = DiagramDocument();
    final result = await reopened.open(filePath);

    expect(result.graph.nodes['battery']?.displayName, 'Battery');
    expect(result.layout.positionOf('battery'), const Point2D(10, 20));
    expect(reopened.path, filePath);
    expect(reopened.isDirty, isFalse);
  });

  test('save() without a prior path throws StateError', () async {
    final document = DiagramDocument();
    expect(
      () => document.save(buildGraph(), buildLayout()),
      throwsA(isA<StateError>()),
    );
  });

  test('save() writes to the existing path after saveAs', () async {
    final document = DiagramDocument();
    final filePath = '${tempDir.path}/diagram.json';
    await document.saveAs(filePath, buildGraph(), buildLayout());

    final updatedGraph = buildGraph().withNode(const EngineeringNode(
      id: 'ground',
      category: NodeCategory.ground,
      displayName: 'Ground',
    ));
    await document.save(updatedGraph, buildLayout());

    final reopened = DiagramDocument();
    final result = await reopened.open(filePath);
    expect(result.graph.nodes.containsKey('ground'), isTrue);
  });

  test('close() resets path and dirty state', () async {
    final document = DiagramDocument();
    final filePath = '${tempDir.path}/diagram.json';
    await document.saveAs(filePath, buildGraph(), buildLayout());

    document.close();

    expect(document.path, isNull);
    expect(document.isDirty, isFalse);
  });

  test('markDirty() sets isDirty until the next save', () async {
    final document = DiagramDocument();
    expect(document.isDirty, isFalse);
    document.markDirty();
    expect(document.isDirty, isTrue);

    await document.saveAs('${tempDir.path}/diagram.json', buildGraph(), buildLayout());
    expect(document.isDirty, isFalse);
  });

  group('metadata', () {
    test('saveAs populates title/createdAt/modifiedAt', () async {
      final document = DiagramDocument();
      final filePath = '${tempDir.path}/diagram.json';

      await document.saveAs(filePath, buildGraph(), buildLayout());

      expect(document.metadata.title, 'diagram');
      expect(document.metadata.createdAt, isNotNull);
      expect(document.metadata.modifiedAt, isNotNull);
    });

    test('open restores metadata written by a prior saveAs', () async {
      final document = DiagramDocument();
      final filePath = '${tempDir.path}/diagram.json';
      await document.saveAs(filePath, buildGraph(), buildLayout());
      final savedTitle = document.metadata.title;

      final reopened = DiagramDocument();
      await reopened.open(filePath);

      expect(reopened.metadata.title, savedTitle);
      expect(reopened.metadata.createdAt, isNotNull);
    });

    test('open falls back to a filename-derived title for legacy files with no metadata', () async {
      final filePath = '${tempDir.path}/legacy_diagram.json';
      await File(filePath).writeAsString(jsonEncode({
        'schemaVersion': 1,
        'graph': buildGraph().toJson(),
        'layout': buildLayout().toJson(),
      }));

      final document = DiagramDocument();
      await document.open(filePath);

      expect(document.metadata.title, 'legacy_diagram');
    });
  });

  group('autosave and recovery', () {
    // Autosave/recovery share the real %APPDATA%/oep_studio/autosave
    // directory (there is no override hook, matching the existing
    // WorkspaceStateStorage convention exercised in
    // diagram_workspace_state_test.dart) — each test cleans up the
    // specific autosave files it creates.
    final createdAutosaveFiles = <File>[];

    tearDown(() async {
      for (final file in createdAutosaveFiles) {
        if (file.existsSync()) await file.delete();
      }
      createdAutosaveFiles.clear();
    });

    test('autosave writes a recovery file distinct from the save path, without touching it', () async {
      final document = DiagramDocument();
      final filePath = '${tempDir.path}/diagram.json';
      await document.saveAs(filePath, buildGraph(), buildLayout());
      final savedContents = await File(filePath).readAsString();

      final editedGraph = buildGraph().withNode(const EngineeringNode(
        id: 'ground',
        category: NodeCategory.ground,
        displayName: 'Ground',
      ));
      await document.autosave(editedGraph, buildLayout());

      // The user's own save file must be untouched by autosave.
      expect(await File(filePath).readAsString(), savedContents);

      final candidate = await DiagramDocument.findRecovery(filePath);
      expect(candidate, isNotNull);
      createdAutosaveFiles.add(File(candidate!.autosaveFilePath));

      final recovered = DiagramDocument();
      final result = await recovered.recoverFrom(candidate);
      expect(result.graph.nodes.containsKey('ground'), isTrue);
    });

    test('findRecovery returns null when no autosave exists for the path', () async {
      final candidate = await DiagramDocument.findRecovery('${tempDir.path}/never_autosaved.json');
      expect(candidate, isNull);
    });

    test('save() clears any prior autosave for the document', () async {
      final document = DiagramDocument();
      final filePath = '${tempDir.path}/diagram.json';
      await document.saveAs(filePath, buildGraph(), buildLayout());
      await document.autosave(buildGraph(), buildLayout());

      final beforeSave = await DiagramDocument.findRecovery(filePath);
      expect(beforeSave, isNotNull);

      await document.save(buildGraph(), buildLayout());

      final afterSave = await DiagramDocument.findRecovery(filePath);
      expect(afterSave, isNull);
    });
  });
}
