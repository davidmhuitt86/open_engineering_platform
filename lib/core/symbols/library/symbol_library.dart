import 'dart:convert';
import 'dart:io';

import '../../interfaces/symbol_provider.dart';
import '../models/symbol_definition.dart';

/// The Symbol Library (SDD-025/026/028): a data-driven [SymbolProvider].
///
/// Loads `*.json` [SymbolDefinition]s from [symbolsDirectory] via `dart:io`
/// — deliberately not Flutter's `rootBundle`, so this class stays usable
/// (and testable) without a Flutter binding, honoring "No Flutter Widgets"
/// for the engine core. The Demonstration Host's `pubspec.yaml` bundles
/// the same directory as a Flutter asset separately, for rendering.
class SymbolLibrary implements SymbolProvider {
  final String symbolsDirectory;
  final Map<String, SymbolDefinition> _byIdentifier = {};
  final Map<String, String> _aliasToIdentifier = {};

  SymbolLibrary({this.symbolsDirectory = 'assets/symbols'});

  @override
  Future<void> initialize() async {
    final dir = Directory(symbolsDirectory);
    if (!await dir.exists()) return;
    final jsonFiles = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    for (final file in jsonFiles) {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, Object?>;
      register(SymbolDefinition.fromJson(json));
    }
  }

  /// Parses and registers a single symbol definition from raw JSON text.
  ///
  /// Used by hosts that can't rely on `dart:io` directory listing (e.g. a
  /// Flutter app loading bundled assets via `rootBundle`, which has no
  /// concept of "list files in this directory" at runtime). [initialize]
  /// remains the right choice for plain-Dart contexts (tests, tooling)
  /// where the symbols directory is a real filesystem path.
  void registerFromJson(String rawJson) {
    register(SymbolDefinition.fromJson(jsonDecode(rawJson) as Map<String, Object?>));
  }

  @override
  void register(SymbolDefinition definition) {
    _byIdentifier[definition.identifier] = definition;
    for (final alias in definition.aliases) {
      _aliasToIdentifier[alias.toLowerCase()] = definition.identifier;
    }
  }

  @override
  SymbolDefinition? lookup(String identifier) {
    return _byIdentifier[identifier] ??
        _byIdentifier[_aliasToIdentifier[identifier.toLowerCase()]];
  }

  @override
  SymbolDefinition resolve(String identifier) =>
      lookup(identifier) ?? SymbolDefinition.unknown(identifier);

  @override
  List<SymbolDefinition> get all => _byIdentifier.values.toList(growable: false);

  @override
  List<SymbolDefinition> search(String query) {
    final needle = query.toLowerCase();
    return _byIdentifier.values.where((s) {
      return s.identifier.toLowerCase().contains(needle) ||
          s.name.toLowerCase().contains(needle) ||
          s.aliases.any((a) => a.toLowerCase().contains(needle));
    }).toList();
  }
}
