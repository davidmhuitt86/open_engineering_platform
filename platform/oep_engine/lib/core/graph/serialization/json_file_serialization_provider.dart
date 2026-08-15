import 'dart:convert';
import 'dart:io';

import '../../interfaces/serialization_provider.dart';
import '../models/engineering_graph.dart';

/// Local-JSON implementation of [SerializationProvider].
///
/// Phase 1's only concrete serializer, used for verification while no
/// reusable Foundation Bridge package exists (see `FoundationBridgePort`
/// and docs/ARCHITECTURE_DECISIONS.md ADR-004). `[destination]`/`[source]`
/// are treated as file paths. A future Foundation- or OEP-Package-backed
/// serializer implements the same [SerializationProvider] contract —
/// `GraphProvider` never depends on this class directly.
class JsonFileSerializationProvider implements SerializationProvider {
  static const int schemaVersion = 1;

  @override
  Future<void> write(EngineeringGraph graph, String destination) async {
    final file = File(destination);
    await file.parent.create(recursive: true);
    final envelope = {
      'schemaVersion': schemaVersion,
      'graph': graph.toJson(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(envelope),
    );
  }

  @override
  Future<EngineeringGraph> read(String source) async {
    final file = File(source);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final graphJson = decoded['graph'] as Map<String, Object?>? ?? decoded;
    return EngineeringGraph.fromJson(graphJson);
  }
}
