import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/capability/capability.dart';
import 'package:oep_instruments_runtime/capability/capability_category.dart';
import 'package:oep_instruments_runtime/capability/capability_registry.dart';

void main() {
  Capability fixture(String id, {List<String> dependencies = const []}) => Capability(
        id: id,
        displayName: id,
        description: 'test capability',
        category: CapabilityCategory.measurement,
        version: '1.0',
        dependencies: dependencies,
      );

  group('CapabilityRegistry', () {
    test('registers and looks up capabilities by id and category', () {
      final registry = CapabilityRegistry()..register(fixture('measurement.dcVoltage'));
      expect(registry.supports('measurement.dcVoltage'), isTrue);
      expect(registry.byId('measurement.dcVoltage'), isNotNull);
      expect(registry.byCategory(CapabilityCategory.measurement), hasLength(1));
      expect(registry.byCategory(CapabilityCategory.playback), isEmpty);
    });

    test('rejects a duplicate id', () {
      final registry = CapabilityRegistry()..register(fixture('a'));
      expect(() => registry.register(fixture('a')), throwsStateError);
    });

    test('validateDependencies reports an unregistered dependency', () {
      final registry = CapabilityRegistry()..register(fixture('waveformRecording', dependencies: ['waveformDisplay']));
      final issues = registry.validateDependencies();
      expect(issues, isNotEmpty);
      expect(issues.first, contains('waveformDisplay'));
    });

    test('validateDependencies is clean when every dependency resolves', () {
      final registry = CapabilityRegistry()
        ..register(fixture('waveformDisplay'))
        ..register(fixture('waveformRecording', dependencies: ['waveformDisplay']));
      expect(registry.validateDependencies(), isEmpty);
    });

    test('negotiate returns only the requested capabilities this registry actually supports', () {
      final registry = CapabilityRegistry()
        ..register(fixture('measurement.dcVoltage'))
        ..register(fixture('measurement.resistance'));
      final negotiated = registry.negotiate(['measurement.dcVoltage', 'measurement.acVoltage']);
      expect(negotiated, {'measurement.dcVoltage'});
    });
  });
}
