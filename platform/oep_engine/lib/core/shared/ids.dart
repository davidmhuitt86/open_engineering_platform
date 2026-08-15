import 'dart:math';

/// Generates runtime-unique identifiers for Engineering Graph objects.
///
/// Not a persistence identifier — [repositoryObjectId] on [EngineeringNode]
/// is what maps to Foundation once a Repository is attached.
class EngineIds {
  EngineIds._();

  static final Random _random = Random.secure();

  static String generate(String prefix) {
    final millis = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_${millis}_$rand';
  }
}
