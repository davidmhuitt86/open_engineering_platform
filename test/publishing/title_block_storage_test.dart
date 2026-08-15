import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/publishing/title_block_storage.dart';

/// Uses [TitleBlockStorage.testRootOverride]/[TitleBlockPresetStorage.
/// testRootOverride] to point at a private temp directory rather than
/// the real `%APPDATA%/oep_studio/` path. Found during AP-DS-004's own
/// independent verification: this file, `title_block_editor_dialog_test.dart`,
/// and `publishing_center_dialog_test.dart` all previously read/wrote the
/// SAME real global file, and `flutter test`'s default cross-file
/// parallelism turned that into a genuine, reproducible file-handle
/// race (not a hypothetical risk — it reproduced twice in a row).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('title_block_storage_test_');
    TitleBlockStorage.testRootOverride = tempDir;
    TitleBlockPresetStorage.testRootOverride = tempDir;
  });

  tearDown(() {
    TitleBlockStorage.testRootOverride = null;
    TitleBlockPresetStorage.testRootOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('TitleBlockStorage', () {
    test('load() returns TitleBlock.empty for an unknown diagram key', () async {
      final block = await TitleBlockStorage.load('unknown-key-${DateTime.now().microsecondsSinceEpoch}');
      expect(block.company, '');
      expect(block.revisionHistory, isEmpty);
    });

    test('save() then load() round-trips a title block, keyed per diagram', () async {
      final block = TitleBlock(
        company: 'Acme',
        project: 'Widget Line',
        drawingNumber: 'DWG-100',
        revision: 'B',
        customFields: {'Program': 'Alpha'},
        revisionHistory: [
          RevisionEntry(
            revisionNumber: 'A',
            description: 'Initial release',
            author: 'J. Engineer',
            date: DateTime(2026, 1, 1),
            approvalStatus: RevisionApprovalStatus.approved,
          ),
        ],
      );

      await TitleBlockStorage.save('diagram-a.json', block);
      final loaded = await TitleBlockStorage.load('diagram-a.json');

      expect(loaded.company, 'Acme');
      expect(loaded.drawingNumber, 'DWG-100');
      expect(loaded.customFields['Program'], 'Alpha');
      expect(loaded.revisionHistory.single.revisionNumber, 'A');
      expect(loaded.revisionHistory.single.approvalStatus, RevisionApprovalStatus.approved);
    });

    test('two diagram keys keep independent title blocks', () async {
      await TitleBlockStorage.save('diagram-a.json', const TitleBlock(drawingNumber: 'A'));
      await TitleBlockStorage.save('diagram-b.json', const TitleBlock(drawingNumber: 'B'));

      expect((await TitleBlockStorage.load('diagram-a.json')).drawingNumber, 'A');
      expect((await TitleBlockStorage.load('diagram-b.json')).drawingNumber, 'B');
    });
  });

  group('TitleBlockPresetStorage', () {
    test('loadAll() is empty with no presets saved', () async {
      expect(await TitleBlockPresetStorage.loadAll(), isEmpty);
    });

    test('savePreset()/deletePreset() manage named presets', () async {
      await TitleBlockPresetStorage.savePreset('Standard', const TitleBlock(company: 'Acme'));
      var all = await TitleBlockPresetStorage.loadAll();
      expect(all['Standard']!.company, 'Acme');

      await TitleBlockPresetStorage.deletePreset('Standard');
      all = await TitleBlockPresetStorage.loadAll();
      expect(all, isEmpty);
    });
  });
}
