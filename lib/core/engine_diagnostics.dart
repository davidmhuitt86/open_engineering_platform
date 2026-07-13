import 'engine_state.dart';

/// Snapshot of engine health, returned by `EngineeringEngine.diagnostics`
/// (SDD-026: "Health Monitoring").
class EngineDiagnostics {
  final EngineState state;
  final String version;
  final List<String> registeredProviders;
  final List<String> openGraphIds;
  final int registeredSymbolCount;

  const EngineDiagnostics({
    required this.state,
    required this.version,
    required this.registeredProviders,
    required this.openGraphIds,
    required this.registeredSymbolCount,
  });

  Map<String, Object?> toJson() => {
        'state': state.name,
        'version': version,
        'registeredProviders': registeredProviders,
        'openGraphIds': openGraphIds,
        'registeredSymbolCount': registeredSymbolCount,
      };

  @override
  String toString() => toJson().toString();
}
