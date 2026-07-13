import 'dart:convert';
import 'dart:io';

import 'view_state.dart';

/// Local-JSON persistence for [ViewState] (WORK_PACKAGE_022,
/// ENGINE-TASK-000088: "serializable independently of the Engineering
/// Graph and Diagram Layout... serialization mechanism shall remain
/// provider-based").
///
/// Deliberately mirrors [JsonFileSerializationProvider] and
/// [JsonFileLayoutSerializer]'s shape rather than sharing an interface
/// with them — `SerializationProvider` is typed to `EngineeringGraph`;
/// genericizing it purely to cover three unrelated read/write pairs would
/// be a bigger interface change than this work package's scope, and
/// three small, obviously-parallel classes are easier to read than one
/// generic one forcing an artificial shared contract.
class JsonFileViewStateSerializer {
  static const int schemaVersion = 1;

  Future<void> write(ViewState state, String destination) async {
    final file = File(destination);
    await file.parent.create(recursive: true);
    final envelope = {
      'schemaVersion': schemaVersion,
      'viewState': state.toJson(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(envelope));
  }

  Future<ViewState> read(String source) async {
    final file = File(source);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final stateJson = decoded['viewState'] as Map<String, Object?>? ?? decoded;
    return ViewState.fromJson(stateJson);
  }
}
