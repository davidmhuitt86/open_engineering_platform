// ignore_for_file: avoid_print
//
// Manual/CI verification (WP-EKE-016) against a REAL compiled package (see
// verify_oerp_reader.dart for why this is not a `flutter test`). Run:
//
//   cd knowledge/reference_library && python -m compiler.cli core_reference
//   cd ../../platform/oep_engine && dart run tool/verify_symbol_binding.dart
//
// Reference Library -> Compiler -> .oerp -> OerpReader -> KnowledgeRuntime
//   -> Symbol Binding -> Engine SymbolDefinition
import 'dart:io';

import 'package:engineering_engine/core/knowledge/discovery/reference_discovery.dart';
import 'package:engineering_engine/core/knowledge/knowledge_runtime.dart';
import 'package:engineering_engine/core/knowledge/oerp/oerp_reader.dart';
import 'package:engineering_engine/core/symbols/binding/symbol_binding.dart';
import 'package:engineering_engine/core/symbols/library/symbol_library.dart';

var _failures = 0;

void check(bool ok, String what) {
  print('${ok ? "PASS" : "FAIL"}  $what');
  if (!ok) _failures++;
}

Future<void> main() async {
  final sep = Platform.pathSeparator;
  final file = File(
    '${Directory.current.path}$sep..$sep..${sep}knowledge${sep}reference_library'
    '${sep}dist${sep}core_reference_v1.oerp',
  );
  if (!file.existsSync()) {
    stderr.writeln('No compiled package at ${file.path}.');
    stderr.writeln('Run: cd knowledge/reference_library && python -m compiler.cli core_reference');
    exit(1);
  }

  const reader = OerpReader();
  final runtime = KnowledgeRuntime.activate(
    reader.readFile(file),
    allowUnsignedDevelopmentPackages: true,
  );
  final symbols = SymbolLibrary(symbolsDirectory: 'assets/symbols');
  await symbols.initialize();
  final adapter = SymbolBindingAdapter(
    runtime: runtime,
    symbols: symbols,
    bindings: SymbolBindingRegistry.loadFile(
      File('assets/symbol_bindings/reference_symbol_bindings.json'),
    ),
  );

  // Discovery still returns Reference ids only; the binding resolves them.
  final discovery = ReferenceDiscovery.create(runtime, reader.readDiscoveryIndexesFile(file));
  final hit = discovery.search('resistor').firstWhere((h) => h.objectId == 'symbol.iec.resistor');
  check(hit.objectId == 'symbol.iec.resistor', 'ReferenceDiscovery returns the Reference id, not an Engine id');

  final resolved = adapter.resolve(hit.objectId);
  print(
    'Reference ${resolved.referenceSymbolId} (${resolved.referenceSymbol.objectType}, '
    '"${resolved.referenceSymbol.name}") -> Engine ${resolved.engineSymbolId} '
    '("${resolved.engineSymbol.name}", ${resolved.engineSymbol.ports.length} renderer-local ports)',
  );
  check(resolved.referenceSymbol.objectType == 'Symbol', 'the real Reference object resolved through KnowledgeRuntime is a Symbol');
  check(resolved.referenceSymbolId == 'symbol.iec.resistor' && resolved.engineSymbolId == 'resistor', 'both identities are preserved and distinct');
  check(identical(resolved.engineSymbol, symbols.lookup('resistor')), 'the Engine definition is the SymbolProvider\'s own');

  // The Reference relationship is untouched by the binding.
  final rel = runtime.getRelationship('component.passive.resistor.represented_by.symbol_iec');
  check(
    rel.relationshipType == 'REPRESENTED_BY' &&
        rel.sourceObjectId == 'component.passive.resistor' &&
        rel.targetObjectId == 'symbol.iec.resistor',
    'component.passive.resistor REPRESENTED_BY symbol.iec.resistor is still a pure Reference relationship (ids are Reference ids)',
  );

  check(adapter.audit().isEmpty, 'every shipped binding resolves against the real package');

  // No inference: a real Reference object that is not a Symbol, and one that is not bound.
  try {
    adapter.resolve('component.passive.resistor');
    check(false, 'a real Component must not resolve as a symbol');
  } on SymbolBindingException catch (e) {
    check(e.code == SymbolBindingErrorCode.referenceObjectNotSymbol, 'a real non-Symbol object fails: ${e.code.name}');
  }
  try {
    adapter.resolve('resistor');
    check(false, 'an Engine id must not resolve as a Reference symbol');
  } on SymbolBindingException catch (e) {
    check(e.code == SymbolBindingErrorCode.referenceSymbolNotFound, 'an Engine id is not a Reference id: ${e.code.name}');
  }

  print(_failures == 0 ? '\nVERIFICATION PASSED' : '\nVERIFICATION FAILED ($_failures)');
  exit(_failures == 0 ? 0 : 1);
}
