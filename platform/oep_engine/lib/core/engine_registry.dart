import 'bridge/foundation_bridge_port.dart';
import 'interfaces/clipboard_provider.dart';
import 'interfaces/export_provider.dart';
import 'interfaces/graph_provider.dart';
import 'interfaces/import_provider.dart';
import 'interfaces/layout_provider.dart';
import 'interfaces/navigation_provider.dart';
import 'interfaces/routing_provider.dart';
import 'interfaces/search_provider.dart';
import 'interfaces/selection_provider.dart';
import 'interfaces/serialization_provider.dart';
import 'interfaces/simulation_provider.dart';
import 'interfaces/symbol_provider.dart';
import 'simulation/simulation_engine.dart';
import 'interfaces/validation_provider.dart';
import 'interfaces/view_state_provider.dart';

/// Thrown when [EngineRegistry.require] is called for a provider that was
/// never registered.
class ProviderNotRegisteredException implements Exception {
  final Type providerType;

  ProviderNotRegisteredException(this.providerType);

  @override
  String toString() =>
      'ProviderNotRegisteredException: no $providerType has been registered '
      'with the EngineRegistry.';
}

/// The sole extension point of the Engineering Engine.
///
/// `EngineeringEngine` never resolves a provider directly — every provider
/// lookup goes through this registry:
///
/// ```
/// EngineeringEngine
///     -> EngineRegistry
///         -> GraphProvider
///         -> SymbolProvider
///         -> ValidationProvider
///         -> NavigationProvider
///         -> SelectionProvider
///         -> ImportProvider
///         -> ExportProvider
///         -> SimulationProvider
///         -> LayoutProvider
///         -> ClipboardProvider
///         -> RoutingProvider
///         -> ViewStateProvider
///         -> SearchProvider
/// ```
///
/// Registration is by interface type. A future Marketplace package, an
/// alternate implementation, or a test double all register the same way —
/// `EngineeringEngine`'s core never needs to change (SDD-029: "Extensions
/// never modify Core. Extensions register through Engine.").
class EngineRegistry {
  final Map<Type, Object> _providers = {};

  void register<T extends Object>(T provider) {
    _providers[T] = provider;
  }

  bool isRegistered<T extends Object>() => _providers.containsKey(T);

  T? resolve<T extends Object>() => _providers[T] as T?;

  T require<T extends Object>() {
    final provider = _providers[T];
    if (provider == null) {
      throw ProviderNotRegisteredException(T);
    }
    return provider as T;
  }

  GraphProvider get graph => require<GraphProvider>();
  SymbolProvider get symbols => require<SymbolProvider>();
  ValidationProvider get validation => require<ValidationProvider>();
  NavigationProvider get navigation => require<NavigationProvider>();
  SelectionProvider get selection => require<SelectionProvider>();
  ImportProvider get import => require<ImportProvider>();
  ExportProvider get export => require<ExportProvider>();
  SimulationProvider get simulation => require<SimulationProvider>();
  SimulationEngine get simulationEngine => require<SimulationEngine>();
  SerializationProvider get serialization => require<SerializationProvider>();
  LayoutProvider get layout => require<LayoutProvider>();
  ClipboardProvider get clipboard => require<ClipboardProvider>();
  RoutingProvider get routing => require<RoutingProvider>();
  ViewStateProvider get viewState => require<ViewStateProvider>();
  SearchProvider get search => require<SearchProvider>();

  /// AP-OEP-FOUNDATION-BRIDGE-001 — nullable, unlike every other getter
  /// above: SDD-025 is explicit that "Engineering Engine shall operate
  /// without an open Repository where practical," so no
  /// `EngineRegistry` construction site should be forced to register a
  /// bridge (or crash) just because it never calls `commitGraph`.
  /// Callers that need commit capability check for `null` themselves.
  FoundationBridgePort? get foundationBridge => resolve<FoundationBridgePort>();

  List<Type> get registeredTypes => _providers.keys.toList(growable: false);
}
