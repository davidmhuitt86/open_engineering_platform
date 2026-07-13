import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('JsonFileSerializationProvider', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oep_engine_serialize_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('write then read round-trips a graph', () async {
      final provider = JsonFileSerializationProvider();
      final graph = (GraphBuilder(id: 'demo')
            ..addNode(
              id: 'a',
              category: NodeCategory.component,
              displayName: 'A',
              symbolId: 'battery',
            ))
          .build();

      final path = '${tempDir.path}/demo.json';
      await provider.write(graph, path);
      expect(await File(path).exists(), isTrue);

      final restored = await provider.read(path);
      expect(restored.id, 'demo');
      expect(restored.nodes['a']!.displayName, 'A');
    });
  });

  group('JsonImportProvider / JsonExportProvider', () {
    test('export then import round-trips through bytes', () async {
      final graph = (GraphBuilder(id: 'demo')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A'))
          .build();

      final exporter = JsonExportProvider();
      final exportResult = await exporter.export(ExportRequest(
        formatId: JsonExportProvider.formatId,
        graph: graph,
      ));
      expect(exportResult.success, isTrue);
      expect(exportResult.bytes, isNotNull);

      final importer = JsonImportProvider();
      final importResult = await importer.import(ImportRequest(
        formatId: JsonImportProvider.formatId,
        bytes: exportResult.bytes,
      ));
      expect(importResult.success, isTrue);
      expect(importResult.graph!.nodes['a']!.displayName, 'A');
    });

    test('rejects unsupported formats', () async {
      final importer = JsonImportProvider();
      final result = await importer.import(const ImportRequest(formatId: 'dxf'));
      expect(result.success, isFalse);
    });
  });
}
