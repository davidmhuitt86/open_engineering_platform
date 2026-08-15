import '../protocol/oip_version_negotiation.dart';
import '../runtime/instrument_lifecycle_state.dart';
import '../runtime/instrument_lifecycle_state_machine.dart';
import 'instrument_plugin.dart';
import 'plugin_context.dart';

/// One registered plugin plus the Runtime's own bookkeeping for it —
/// the plugin instance never owns its own lifecycle machine (OIP-PLUGIN
/// -001 §9: "The Runtime owns invocation").
class _PluginRegistration {
  _PluginRegistration(this.plugin) : lifecycle = InstrumentLifecycleStateMachine();

  final InstrumentPlugin plugin;
  final InstrumentLifecycleStateMachine lifecycle;
}

/// OIP-ARCH-001 §9 / OIP-PLUGIN-001 — the Runtime's Plugin Manager:
/// discovery, registration, version compatibility, loading, unloading,
/// dependency validation, plugin lifecycle. "Plugins remain isolated" —
/// this manager is the only thing that invokes plugin lifecycle methods;
/// plugins never call each other directly (OIP-PLUGIN-001 §13).
class PluginManager {
  PluginManager({required this.runtimeVersion, required this.protocolVersion});

  final String runtimeVersion;
  final String protocolVersion;

  final Map<String, _PluginRegistration> _registrations = {};

  List<String> get registeredPluginIds => List.unmodifiable(_registrations.keys);

  InstrumentLifecycleState? lifecycleOf(String pluginId) => _registrations[pluginId]?.lifecycle.current;

  /// OIP-PLUGIN-001 §19 — "Incompatible Plugins shall not load." Checks
  /// the plugin's declared supported runtime/protocol versions against
  /// this Manager's own, using the same negotiation logic
  /// [negotiateProtocolVersion] uses for Host<->Client version exchange
  /// (a plugin's compatibility check is the same kind of "do these two
  /// declared version sets overlap" question, not a different concept
  /// needing separate logic).
  bool isCompatible(InstrumentPlugin plugin) {
    final runtimeMatch = negotiateProtocolVersion(
      [runtimeVersion],
      [plugin.manifest.supportedRuntimeVersion],
    );
    final protocolMatch = negotiateProtocolVersion(
      [protocolVersion],
      [plugin.manifest.supportedProtocolVersion],
    );
    return runtimeMatch != null && protocolMatch != null;
  }

  /// Registers [plugin] (transitions it Not Installed -> Installed ->
  /// Discovered) if compatible. Throws [StateError] on a duplicate
  /// [PluginManifest.pluginId] or an incompatible plugin — a plugin
  /// manager silently accepting either would violate §19's "shall not
  /// load."
  void register(InstrumentPlugin plugin) {
    final id = plugin.manifest.pluginId;
    if (_registrations.containsKey(id)) {
      throw StateError('PluginManager: a plugin with id "$id" is already registered.');
    }
    if (!isCompatible(plugin)) {
      throw StateError(
        'PluginManager: plugin "$id" is incompatible with runtime $runtimeVersion / protocol $protocolVersion.',
      );
    }
    final registration = _PluginRegistration(plugin);
    registration.lifecycle.transitionTo(InstrumentLifecycleState.installed);
    registration.lifecycle.transitionTo(InstrumentLifecycleState.discovered);
    _registrations[id] = registration;
  }

  /// OIP-PLUGIN-001 §9 — Discovered -> Loaded -> Initializing -> Ready.
  Future<void> load(String pluginId, PluginContext context) async {
    final registration = _require(pluginId);
    registration.lifecycle.transitionTo(InstrumentLifecycleState.loaded);
    registration.lifecycle.transitionTo(InstrumentLifecycleState.initializing);
    await registration.plugin.initialize(context);
    registration.lifecycle.transitionTo(InstrumentLifecycleState.ready);
  }

  Future<void> connect(String pluginId) async {
    _require(pluginId).lifecycle.transitionTo(InstrumentLifecycleState.connected);
  }

  Future<void> activate(String pluginId) async {
    final registration = _require(pluginId);
    await registration.plugin.activate();
    registration.lifecycle.transitionTo(InstrumentLifecycleState.active);
  }

  Future<void> suspend(String pluginId) async {
    final registration = _require(pluginId);
    await registration.plugin.suspend();
    registration.lifecycle.transitionTo(InstrumentLifecycleState.paused);
  }

  Future<void> resumePlugin(String pluginId) async {
    final registration = _require(pluginId);
    await registration.plugin.resume();
    registration.lifecycle.transitionTo(InstrumentLifecycleState.active);
  }

  Future<void> disconnect(String pluginId) async {
    _require(pluginId).lifecycle.transitionTo(InstrumentLifecycleState.disconnected);
  }

  /// OIP-PLUGIN-001 §9 — Unloaded -> Destroyed. "Plugin failures shall
  /// not terminate other plugins" (§13) — a throw from [InstrumentPlugin
  /// .shutdown] here only affects [pluginId]'s own registration, never
  /// propagates to unrelated plugins (there is no shared mutable state
  /// between registrations for a failure to corrupt).
  Future<void> unload(String pluginId) async {
    final registration = _require(pluginId);
    await registration.plugin.shutdown();
    registration.lifecycle.transitionTo(InstrumentLifecycleState.unloaded);
    registration.lifecycle.transitionTo(InstrumentLifecycleState.destroyed);
    _registrations.remove(pluginId);
  }

  InstrumentPlugin get(String pluginId) => _require(pluginId).plugin;

  _PluginRegistration _require(String pluginId) {
    final registration = _registrations[pluginId];
    if (registration == null) {
      throw StateError('PluginManager: no plugin registered with id "$pluginId".');
    }
    return registration;
  }
}
