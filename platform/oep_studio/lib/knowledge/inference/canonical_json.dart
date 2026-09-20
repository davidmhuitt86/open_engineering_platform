import 'dart:convert';

/// Structured, delimiter-free JSON canonicalization, the same rules
/// `IngestionRun.processingIdentity` uses (WP-INGEST-006 / INGEST-FOLLOWUP-003):
/// `Map` keys are sorted at every level, `List` order is preserved (it is
/// semantically significant), and scalars are encoded with [jsonEncode] so a
/// string and a similar-looking number never collide.
String canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    final entries = keys
        .map((key) => '${jsonEncode(key)}:${canonicalJson(value[key])}')
        .join(',');
    return '{$entries}';
  }
  if (value is List) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
