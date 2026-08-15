import 'engineering_entity_type.dart';

/// One deterministic recognition rule (Work Package 014
/// STUDIO-TASK-000040: "Centralize deterministic engineering
/// recognition rules... Patterns shall be configurable. No hardcoded
/// UI logic."). A plain data value — never references a `Widget` or
/// `BuildContext` — so `EngineeringPatternLibrary` can be data-driven
/// and testable independent of any UI, and so patterns are something
/// `EngineeringEntityExtractionService` *consumes*, never something a
/// widget hardcodes inline.
class EngineeringPattern {
  const EngineeringPattern({
    required this.id,
    required this.type,
    required this.label,
    required this.regex,
    required this.normalize,
  });

  /// Stable identifier (e.g. `"torque-metric"`) — persisted on every
  /// `EngineeringEntity.matchedPatternId` it produces, so the Property
  /// Inspector's "Pattern Match" display survives a future pattern-list
  /// reordering without losing track of which rule matched.
  final String id;

  final EngineeringEntityType type;

  /// Human-readable, e.g. `"Torque (Metric)"` — shown in the Property
  /// Inspector, never used for matching itself.
  final String label;

  /// Compiled once, reused for every extraction — matching is "entirely
  /// rule based" (this work package's own text) and deterministic: the
  /// same regex against the same text always produces the same matches.
  final RegExp regex;

  /// Converts one matched substring into its canonical form (e.g.
  /// `"24nm"` → `"24 Nm"`). Pure — no I/O, no randomness — so the same
  /// input always normalizes identically ("every extraction must be
  /// reproducible from the same OCR input").
  final String Function(String matchedText) normalize;
}
