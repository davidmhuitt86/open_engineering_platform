import 'engine_diagnostics.dart';
import 'engine_registry.dart';
import 'engine_state.dart';
import 'events/engine_event_bus.dart';
import 'exporters/json/json_export_provider.dart';
import 'exporters/shared/export_request.dart';
import 'exporters/shared/export_result.dart';
import 'graph/models/engineering_graph.dart';
import 'graph/serialization/json_file_serialization_provider.dart';
import 'graph/services/graph_service.dart';
import 'graph/services/in_memory_graph_provider.dart';
import 'importers/json/json_import_provider.dart';
import 'importers/shared/import_request.dart';
import 'importers/shared/import_result.dart';
import 'interfaces/export_provider.dart';
import 'interfaces/graph_provider.dart';
import 'interfaces/import_provider.dart';
import 'interfaces/navigation_provider.dart';
import 'interfaces/selection_provider.dart';
import 'interfaces/serialization_provider.dart';
import 'interfaces/simulation_provider.dart';
import 'interfaces/symbol_provider.dart';
import 'interfaces/validation_provider.dart';
import 'navigation/navigation_service.dart';
import 'selection/selection_service.dart';
import 'simulation/no_op_simulation_provider.dart';
import 'symbols/library/symbol_library.dart';
import 'validation/validation_report.dart';
import 'validation/validation_service.dart';
import 'views/diagram/diagram_renderer.dart';
import 'views/diagram/diagram_view.dart';

/// Primary runtime object of the Engineering Engine (SDD-025/026,
/// STUDIO-TASK-000060).
///
/// Owns nothing directly — every capability is a provider resolved through
/// [registry]. `EngineeringEngine` is the only class a consumer needs to
/// import; it exposes typed convenience getters over the registry so
/// callers rarely need to touch [EngineRegistry] themselves.
///
/// No Flutter Widgets. No `BuildContext`. No Widget dependencies
/// (SDD-025/026) — this entire `lib/core` tree is plain Dart.
class EngineeringEngine {
  static const String version = '0.1.0';

  final EngineRegistry registry;
  final EngineEventBus _events = EngineEventBus();
  final DiagramRendererRegistry diagramRenderers = DiagramRendererRegistry();
  final DiagramView diagramView = DiagramView();

  final SelectionService? _selectionService;
  final NavigationService? _navigationService;

  EngineState _state = EngineState.uninitialized;

  late final GraphService graph = GraphService(
    provider: registry.graph,
    validation: registry.validation,
    events: _events,
  );

  EngineeringEngine(
    this.registry, {
    SelectionService? selectionService,
    NavigationService? navigationService,
  })  : _selectionService = selectionService,
        _navigationService = navigationService;

  /// Builds an engine wired with Phase 1's default providers:
  /// [InMemoryGraphProvider] + [JsonFileSerializationProvider] for the
  /// graph, [SymbolLibrary] loading from [symbolsDirectory],
  /// [ValidationService], [NavigationService], [SelectionService],
  /// [JsonImportProvider]/[JsonExportProvider], and
  /// [NoOpSimulationProvider]. Call [initialize] before use.
  factory EngineeringEngine.create({String symbolsDirectory = 'assets/symbols'}) {
    final registry = EngineRegistry();
    final events = EngineEventBus();

    final serialization = JsonFileSerializationProvider();
    final symbols = SymbolLibrary(symbolsDirectory: symbolsDirectory);
    final selectionService = SelectionService(events: events);
    final navigationService = NavigationService();

    registry
      ..register<SerializationProvider>(serialization)
      ..register<GraphProvider>(InMemoryGraphProvider(serialization: serialization))
      ..register<SymbolProvider>(symbols)
      ..register<ValidationProvider>(ValidationService(symbols: symbols))
      ..register<NavigationProvider>(navigationService)
      ..register<SelectionProvider>(selectionService)
      ..register<ImportProvider>(JsonImportProvider())
      ..register<ExportProvider>(JsonExportProvider())
      ..register<SimulationProvider>(NoOpSimulationProvider());

    return EngineeringEngine(
      registry,
      selectionService: selectionService,
      navigationService: navigationService,
    );
  }

  EngineState get state => _state;

  Future<void> initialize() async {
    if (_state == EngineState.initialized) return;
    await registry.symbols.initialize();
    _state = EngineState.initialized;
  }

  Future<void> shutdown() async {
    if (_state == EngineState.shutdown) return;
    await _selectionService?.dispose();
    await _navigationService?.dispose();
    await _events.dispose();
    _state = EngineState.shutdown;
  }

  ValidationReport validate(EngineeringGraph target) => registry.validation.validate(target);

  Future<ImportResult> import(ImportRequest request) => registry.import.import(request);

  Future<ExportResult> exportGraph(ExportRequest request) => registry.export.export(request);

  EngineDiagnostics diagnostics() {
    return EngineDiagnostics(
      state: _state,
      version: version,
      registeredProviders:
          registry.registeredTypes.map((t) => t.toString()).toList(),
      openGraphIds:
          _state == EngineState.uninitialized ? const [] : registry.graph.openGraphIds,
      registeredSymbolCount:
          _state == EngineState.uninitialized ? 0 : registry.symbols.all.length,
    );
  }
}
