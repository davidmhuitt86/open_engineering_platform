import '../symbols/models/symbol_definition.dart';

/// Backing store/loader for the Symbol Library (SDD-026/028).
///
/// Symbols are data, never code — a `SymbolProvider` implementation is
/// responsible for loading [SymbolDefinition]s from wherever they're
/// authored (Phase 1: JSON under `assets/symbols/`) and never for defining
/// symbol behavior in Dart.
abstract class SymbolProvider {
  Future<void> initialize();

  /// `null` if [identifier] (or one of its aliases) is not registered.
  SymbolDefinition? lookup(String identifier);

  /// Same as [lookup] but never returns `null` — falls back to
  /// `SymbolDefinition.unknown` so a missing symbol never blocks rendering
  /// (SDD-028: "Unknown Symbols remain valid").
  SymbolDefinition resolve(String identifier);

  List<SymbolDefinition> get all;

  void register(SymbolDefinition definition);

  List<SymbolDefinition> search(String query);
}
