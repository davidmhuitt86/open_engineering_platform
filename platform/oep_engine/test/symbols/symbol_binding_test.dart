import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// WP-EKE-016 (Symbol Binding Contract). The Reference side is an in-memory
/// `KnowledgeRuntime` (a real compiled package is verified by
/// `tool/verify_symbol_binding.dart`); the Engine side is the REAL
/// `SymbolLibrary` over `assets/symbols`, and the shipped binding file is the
/// real `assets/symbol_bindings/reference_symbol_bindings.json`.
KnowledgeObject _obj(String id, String type) => KnowledgeObject(
  id: id,
  objectType: type,
  name: id,
  shortName: id,
  version: '1.0.0',
  lifecycleState: 'Published',
  uuid: 'u-$id',
  domain: 'Electrical',
  tags: const [],
  provenanceId: 'prov.unit.volt',
);

KnowledgeRuntime _runtime() {
  final base = buildElectricalCorePackage();
  return KnowledgeRuntime.activate(
    KnowledgePackage(
      manifest: base.manifest,
      dimensions: base.dimensions,
      units: base.units,
      componentModels: base.componentModels,
      laws: base.laws,
      equations: base.equations,
      constraints: base.constraints,
      provenance: base.provenance,
      objects: [
        _obj('symbol.iec.resistor', 'Symbol'),
        _obj('symbol.iec.battery', 'Symbol'), // Engine has "battery"; no binding
        _obj('symbol.iec.cell', 'Symbol'),
        _obj('symbol.iec.ghost', 'Symbol'),
        _obj('component.passive.resistor', 'Component'),
      ],
      developmentModeUnsigned: true,
    ),
    allowUnsignedDevelopmentPackages: true,
  );
}

Matcher _failsWith(SymbolBindingErrorCode code) => throwsA(
  isA<SymbolBindingException>().having((e) => e.code, 'code', code),
);

void main() {
  late SymbolLibrary symbols;
  late KnowledgeRuntime runtime;
  late SymbolBindingRegistry shipped;

  setUp(() async {
    symbols = SymbolLibrary(symbolsDirectory: 'assets/symbols');
    await symbols.initialize();
    runtime = _runtime();
    shipped = SymbolBindingRegistry.loadFile(
      File('assets/symbol_bindings/reference_symbol_bindings.json'),
    );
  });

  SymbolBindingAdapter adapter([SymbolBindingRegistry? registry]) =>
      SymbolBindingAdapter(
        runtime: runtime,
        symbols: symbols,
        bindings: registry ?? shipped,
      );

  group('Known mapping', () {
    test('A/H: symbol.iec.resistor resolves to Engine "resistor" and both identities are preserved', () {
      final r = adapter().resolve('symbol.iec.resistor');
      expect(r.referenceSymbolId, 'symbol.iec.resistor');
      expect(r.engineSymbolId, 'resistor');
      expect(r.binding.referenceSymbolId, isNot(r.binding.engineSymbolId));
    });

    test('B: the Reference Symbol is the KnowledgeRuntime\'s own object', () {
      final r = adapter().resolve('symbol.iec.resistor');
      expect(identical(r.referenceSymbol, runtime.getObject('symbol.iec.resistor')), isTrue);
      expect(r.referenceSymbol.objectType, 'Symbol');
    });

    test('C: the Engine symbol is the SymbolProvider\'s own definition (no second library)', () {
      final r = adapter().resolve('symbol.iec.resistor');
      expect(identical(r.engineSymbol, symbols.lookup('resistor')), isTrue);
    });

    test('the shipped binding file is the one explicit binding, with its rendering caveat recorded', () {
      expect(shipped.bindings.map((b) => '${b.referenceSymbolId}->${b.engineSymbolId}'), [
        'symbol.iec.resistor->resistor',
      ]);
      expect(shipped.bindings.single.notes, contains('zigzag'));
    });
  });

  group('Failure semantics', () {
    test('D: an unknown Reference Symbol fails explicitly', () {
      expect(() => adapter().resolve('symbol.iec.nope'), _failsWith(SymbolBindingErrorCode.referenceSymbolNotFound));
    });

    test('E: an unknown Engine symbol fails explicitly and is not fabricated', () {
      final registry = SymbolBindingRegistry([
        const SymbolBinding(referenceSymbolId: 'symbol.iec.ghost', engineSymbolId: 'no_such_engine_symbol'),
      ]);
      expect(() => adapter(registry).resolve('symbol.iec.ghost'), _failsWith(SymbolBindingErrorCode.engineSymbolNotFound));
    });

    test('F: a Reference object that is not a Symbol fails explicitly, even if a binding names it', () {
      final registry = SymbolBindingRegistry([
        const SymbolBinding(referenceSymbolId: 'component.passive.resistor', engineSymbolId: 'resistor'),
      ]);
      expect(() => adapter(registry).resolve('component.passive.resistor'), _failsWith(SymbolBindingErrorCode.referenceObjectNotSymbol));
    });

    test('M: a Symbol with no binding is an explicit bindingMissing', () {
      expect(() => adapter().resolve('symbol.iec.cell'), _failsWith(SymbolBindingErrorCode.bindingMissing));
    });

    test('an Engine alias is not an identifier: aliased targets are invalidBinding', () {
      // "cell" is an alias of Engine "battery"; lookup("cell") succeeds.
      expect(symbols.lookup('cell')?.identifier, 'battery');
      final registry = SymbolBindingRegistry([
        const SymbolBinding(referenceSymbolId: 'symbol.iec.cell', engineSymbolId: 'cell'),
      ]);
      expect(() => adapter(registry).resolve('symbol.iec.cell'), _failsWith(SymbolBindingErrorCode.invalidBinding));
    });
  });

  group('No inference (I)', () {
    test('an Engine symbol of a similar name is not chosen: symbol.iec.battery does not resolve to "battery"', () {
      expect(symbols.lookup('battery'), isNotNull);
      expect(() => adapter().resolve('symbol.iec.battery'), _failsWith(SymbolBindingErrorCode.bindingMissing));
    });

    test('an Engine identifier is not a Reference id: resolve("resistor") does not reach the symbol', () {
      expect(() => adapter().resolve('resistor'), _failsWith(SymbolBindingErrorCode.referenceSymbolNotFound));
    });

    test('a prefix-stripped or case-changed Reference id is not accepted', () {
      for (final id in ['SYMBOL.IEC.RESISTOR', 'iec.resistor', ' symbol.iec.resistor']) {
        expect(() => adapter().resolve(id), throwsA(isA<SymbolBindingException>()), reason: id);
      }
    });
  });

  group('Registry validation (G)', () {
    test('the same Reference id bound twice is ambiguous', () {
      expect(
        () => SymbolBindingRegistry([
          const SymbolBinding(referenceSymbolId: 'symbol.iec.resistor', engineSymbolId: 'resistor'),
          const SymbolBinding(referenceSymbolId: 'symbol.iec.resistor', engineSymbolId: 'capacitor'),
        ]),
        _failsWith(SymbolBindingErrorCode.ambiguousBinding),
      );
    });

    test('an exact duplicate binding is also rejected, not merged', () {
      const b = SymbolBinding(referenceSymbolId: 'symbol.iec.resistor', engineSymbolId: 'resistor');
      expect(() => SymbolBindingRegistry([b, b]), _failsWith(SymbolBindingErrorCode.ambiguousBinding));
    });

    test('one Engine definition serving two Reference symbols is ambiguous', () {
      expect(
        () => SymbolBindingRegistry([
          const SymbolBinding(referenceSymbolId: 'symbol.iec.resistor', engineSymbolId: 'resistor'),
          const SymbolBinding(referenceSymbolId: 'symbol.ansi.resistor', engineSymbolId: 'resistor'),
        ]),
        _failsWith(SymbolBindingErrorCode.ambiguousBinding),
      );
    });

    test('empty or whitespace-padded ids are invalid', () {
      for (final bad in [
        const SymbolBinding(referenceSymbolId: '', engineSymbolId: 'resistor'),
        const SymbolBinding(referenceSymbolId: 'symbol.x', engineSymbolId: ''),
        const SymbolBinding(referenceSymbolId: ' symbol.x', engineSymbolId: 'resistor'),
      ]) {
        expect(() => SymbolBindingRegistry([bad]), _failsWith(SymbolBindingErrorCode.invalidBinding));
      }
    });

    test('malformed binding files and unsupported versions are invalidBinding', () {
      for (final bad in [
        'nope',
        '[]',
        '{"bindings": []}',
        '{"version": 2, "bindings": []}',
        '{"version": 1}',
        '{"version": 1, "bindings": [1]}',
        '{"version": 1, "bindings": [{"referenceSymbolId": "a"}]}',
        '{"version": 1, "bindings": [{"referenceSymbolId": "a", "engineSymbolId": "b", "notes": 3}]}',
      ]) {
        expect(() => SymbolBindingRegistry.parse(bad), _failsWith(SymbolBindingErrorCode.invalidBinding), reason: bad);
      }
    });

    test('bindings are sorted, immutable, and round-trip; there is no reverse lookup', () {
      final r = SymbolBindingRegistry.parse(jsonEncode({
        'version': 1,
        'bindings': [
          {'referenceSymbolId': 'symbol.b', 'engineSymbolId': 'e2'},
          {'referenceSymbolId': 'symbol.a', 'engineSymbolId': 'e1'},
        ],
      }));
      expect(r.bindings.map((b) => b.referenceSymbolId), ['symbol.a', 'symbol.b']);
      expect(() => r.bindings.add(r.bindings.first), throwsUnsupportedError);
      expect(r.lookup('e1'), isNull, reason: 'an Engine id is never a Reference key');
    });

    test('audit() lists exactly the bindings that do not resolve', () {
      final registry = SymbolBindingRegistry([
        const SymbolBinding(referenceSymbolId: 'symbol.iec.resistor', engineSymbolId: 'resistor'),
        const SymbolBinding(referenceSymbolId: 'symbol.iec.ghost', engineSymbolId: 'nope'),
        const SymbolBinding(referenceSymbolId: 'symbol.absent', engineSymbolId: 'battery'),
      ]);
      final issues = adapter(registry).audit();
      expect(issues.map((i) => '${i.referenceSymbolId}:${i.code.name}'), [
        'symbol.absent:referenceSymbolNotFound',
        'symbol.iec.ghost:engineSymbolNotFound',
      ]);
      expect(adapter().audit(), isEmpty);
    });
  });

  group('Engine compatibility (J)', () {
    test('existing diagrams using symbolId "resistor" still resolve through SymbolProvider, untouched by binding', () {
      const node = EngineeringNode(
        id: 'r1',
        category: NodeCategory.component,
        displayName: 'R1',
        symbolId: 'resistor',
      );
      final before = node.toJson();
      adapter().resolve('symbol.iec.resistor');
      expect(symbols.lookup(node.symbolId!)?.identifier, 'resistor');
      expect(node.toJson(), before);
      expect(EngineeringNode.fromJson(before).symbolId, 'resistor');
    });

    test('a Reference id is not a valid Engine symbolId (no implicit dual identity)', () {
      expect(symbols.lookup('symbol.iec.resistor'), isNull);
    });
  });

  group('Ports (K)', () {
    test('the adapter builds no graph ports: Engine port geometry stays renderer-local', () {
      const node = EngineeringNode(
        id: 'r1',
        category: NodeCategory.component,
        displayName: 'R1',
        symbolId: 'resistor',
      );
      final graph = EngineeringGraph.empty('g').withNode(node);
      final r = adapter().resolve('symbol.iec.resistor');
      // The Engine definition carries its own renderer-local ports...
      expect(r.engineSymbol.ports.map((p) => p.id), ['terminal_a', 'terminal_b']);
      // ...but resolving changes nothing in the Engineering Graph.
      expect(graph.nodes['r1']!.ports, isEmpty);
      expect(node.ports, isEmpty);
    });

    test('the Reference Symbol object carries no port semantics to map', () {
      final ref = adapter().resolve('symbol.iec.resistor').referenceSymbol;
      expect(ref.toJson().keys, isNot(contains('ports')));
    });
  });

  group('Validation rules status (L)', () {
    test('SymbolDefinition.validationRules are metadata only: ValidationService does not enforce them', () async {
      final resistor = symbols.lookup('resistor')!;
      expect(resistor.validationRules.requiredPortIds, ['terminal_a', 'terminal_b']);
      expect(resistor.validationRules.allowedConnectionTypes, ['signal', 'power']);
      // A node that violates every rule: missing required ports, wrong type.
      final graph = EngineeringGraph.empty('g').withNode(
        const EngineeringNode(
          id: 'r1',
          category: NodeCategory.component,
          displayName: 'R1',
          symbolId: 'resistor',
          ports: [Port(id: 'weird', name: 'weird', type: 'hydraulic')],
        ),
      );
      final report = ValidationService(symbols: symbols).validate(graph);
      // Only the unrelated graph-level "no relationships" note is reported;
      // nothing about required ports or connection types.
      expect(report.findings.map((f) => f.code), ['floating_node']);
    });
  });

  group('Real Engine symbol set', () {
    test('Engine symbol identifiers are not Reference ids (no overlap today)', () {
      for (final s in symbols.all) {
        expect(s.identifier.startsWith('symbol.'), isFalse);
      }
    });
  });
}
