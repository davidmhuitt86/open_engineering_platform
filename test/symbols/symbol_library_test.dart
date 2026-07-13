import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('SymbolLibrary', () {
    late SymbolLibrary library;

    setUp(() async {
      library = SymbolLibrary(symbolsDirectory: 'assets/symbols');
      await library.initialize();
    });

    test('loads all 14 seed symbols', () {
      expect(library.all.length, 14);
      for (final id in const [
        'battery',
        'ground',
        'fuse',
        'relay',
        'spst_switch',
        'spdt_switch',
        'connector',
        'lamp',
        'motor',
        'resistor',
        'capacitor',
        'diode',
        'ignition_coil',
        'generic_module',
      ]) {
        expect(library.lookup(id), isNotNull, reason: 'missing symbol $id');
      }
    });

    test('resolves aliases case-insensitively', () {
      // 'gnd' is a registered alias for 'ground'; lookup lowercases before
      // matching, so 'GND' resolves the same way.
      expect(library.lookup('GND')?.identifier, 'ground');
      expect(library.lookup('gnd')?.identifier, 'ground');
      expect(library.lookup('not_an_alias'), isNull);
    });

    test('resolve falls back to unknown for unregistered identifiers', () {
      final resolved = library.resolve('nonexistent_symbol');
      expect(resolved.identifier, 'nonexistent_symbol');
      expect(resolved.name, contains('Unknown Symbol'));
    });

    test('search matches identifier, name, and aliases', () {
      final results = library.search('switch');
      expect(results.map((s) => s.identifier), containsAll(['spst_switch', 'spdt_switch']));
    });

    test('battery symbol declares positive/negative ports', () {
      final battery = library.lookup('battery')!;
      expect(battery.ports.map((p) => p.id), containsAll(['positive', 'negative']));
      expect(battery.category, SymbolCategory.electrical);
    });
  });
}
