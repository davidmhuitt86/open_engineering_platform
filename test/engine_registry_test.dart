import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

abstract class _FakeService {}

class _FakeServiceImpl implements _FakeService {}

void main() {
  group('EngineRegistry', () {
    test('register/resolve round-trips by interface type', () {
      final registry = EngineRegistry();
      final service = _FakeServiceImpl();
      registry.register<_FakeService>(service);

      expect(registry.isRegistered<_FakeService>(), isTrue);
      expect(registry.resolve<_FakeService>(), same(service));
    });

    test('resolve returns null when unregistered', () {
      final registry = EngineRegistry();
      expect(registry.resolve<_FakeService>(), isNull);
    });

    test('require throws ProviderNotRegisteredException when unregistered', () {
      final registry = EngineRegistry();
      expect(
        () => registry.require<_FakeService>(),
        throwsA(isA<ProviderNotRegisteredException>()),
      );
    });

    test('typed convenience getters resolve through the interface', () async {
      final symbols = SymbolLibrary(symbolsDirectory: 'assets/symbols');
      final serialization = JsonFileSerializationProvider();
      final registry = EngineRegistry()
        ..register<SerializationProvider>(serialization)
        ..register<GraphProvider>(InMemoryGraphProvider(serialization: serialization))
        ..register<SymbolProvider>(symbols)
        ..register<ValidationProvider>(ValidationService(symbols: symbols));

      expect(registry.symbols, same(symbols));
      expect(registry.validation, isA<ValidationService>());
    });
  });
}
