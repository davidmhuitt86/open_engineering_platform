import 'dart:convert';
import 'dart:io';

import 'diagram_layout_state.dart';

/// Local-JSON persistence for a [DiagramLayoutState] (WORK_PACKAGE_022,
/// ENGINE-TASK-000089). Mirrors [JsonFileSerializationProvider]'s shape —
/// see [JsonFileViewStateSerializer] for why this isn't a shared generic
/// interface.
class JsonFileLayoutSerializer {
  static const int schemaVersion = 1;

  Future<void> write(DiagramLayoutState layout, String destination) async {
    final file = File(destination);
    await file.parent.create(recursive: true);
    final envelope = {
      'schemaVersion': schemaVersion,
      'layout': layout.toJson(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(envelope));
  }

  Future<DiagramLayoutState> read(String source) async {
    final file = File(source);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final layoutJson = decoded['layout'] as Map<String, Object?>? ?? decoded;
    return DiagramLayoutState.fromJson(layoutJson);
  }
}
