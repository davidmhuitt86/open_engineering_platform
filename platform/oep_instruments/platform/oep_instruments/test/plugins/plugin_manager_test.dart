import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/capability/capability_registry.dart';
import 'package:oep_instruments_runtime/plugins/instrument_plugin.dart';
import 'package:oep_instruments_runtime/plugins/plugin_context.dart';
import 'package:oep_instruments_runtime/plugins/plugin_manager.dart';
import 'package:oep_instruments_runtime/plugins/plugin_manifest.dart';
import 'package:oep_instruments_runtime/protocol/oip_message.dart';
import 'package:oep_instruments_runtime/runtime/instrument_lifecycle_state.dart';
import 'package:oep_instruments_runtime/session/engineering_session.dart';

class _FakePlugin implements InstrumentPlugin {
  _FakePlugin({String protocolVersion = '1.0', String runtimeVersion = '1.0'})
      : manifest = PluginManifest(
          pluginId: 'test.plugin',
          displayName: 'Test Plugin',
          version: '1.0',
          author: 'test',
          description: 'test',
          supportedProtocolVersion: protocolVersion,
          supportedRuntimeVersion: runtimeVersion,
          instrumentCategory: 'measurement',
          entryPoint: 'test.plugin',
          capabilities: const [],
        );

  @override
  final PluginManifest manifest;

  @override
  final CapabilityRegistry capabilities = CapabilityRegistry();

  bool initialized = false;
  bool shutdownCalled = false;

  @override
  Future<void> initialize(PluginContext context) async => initialized = true;

  @override
  Future<void> shutdown() async => shutdownCalled = true;

  @override
  Future<void> activate() async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> suspend() async {}

  @override
  Future<void> resume() async {}

  @override
  Widget render(BuildContext context) => const SizedBox();

  @override
  void receiveEvent(OipMessage event) {}

  @override
  void receiveMeasurement(OipMessage measurement) {}
}

void main() {
  group('PluginManager', () {
    late EngineeringSession session;
    late PluginContext context;

    setUp(() {
      session = EngineeringSession(id: 's1', hostId: 'host1', owner: 'diagramStudio');
      context = PluginContext(hostId: 'host1', session: session);
    });

    test('registers a compatible plugin and walks it through the real lifecycle', () async {
      final manager = PluginManager(runtimeVersion: '1.0', protocolVersion: '1.0');
      final plugin = _FakePlugin();
      manager.register(plugin);
      expect(manager.lifecycleOf('test.plugin'), InstrumentLifecycleState.discovered);

      await manager.load('test.plugin', context);
      expect(plugin.initialized, isTrue);
      expect(manager.lifecycleOf('test.plugin'), InstrumentLifecycleState.ready);

      await manager.connect('test.plugin');
      await manager.activate('test.plugin');
      expect(manager.lifecycleOf('test.plugin'), InstrumentLifecycleState.active);

      await manager.unload('test.plugin');
      expect(plugin.shutdownCalled, isTrue);
      expect(manager.registeredPluginIds, isEmpty);
    });

    test('rejects an incompatible plugin', () {
      final manager = PluginManager(runtimeVersion: '2.0', protocolVersion: '2.0');
      expect(() => manager.register(_FakePlugin(protocolVersion: '1.0', runtimeVersion: '1.0')), throwsStateError);
    });

    test('rejects a duplicate plugin id', () {
      final manager = PluginManager(runtimeVersion: '1.0', protocolVersion: '1.0');
      manager.register(_FakePlugin());
      expect(() => manager.register(_FakePlugin()), throwsStateError);
    });

    test('operating on an unregistered plugin id throws', () {
      final manager = PluginManager(runtimeVersion: '1.0', protocolVersion: '1.0');
      expect(() => manager.get('missing'), throwsStateError);
    });
  });
}
