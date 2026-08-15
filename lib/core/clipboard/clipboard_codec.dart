import 'dart:convert';

import 'clipboard_entry.dart';

/// Encodes/decodes a [ClipboardEntry] to/from a namespaced JSON string,
/// for pushing to the OS clipboard (AP-DS-001A: "Symbols > Copy/Paste"
/// must survive a paste into a *different* Diagram Studio instance/
/// window, not just the in-process `ClipboardProvider`).
///
/// The payload is tagged with [_marker] so [decode] can cheaply reject
/// arbitrary OS-clipboard text (a copied URL, a snippet from another app,
/// ...) without attempting — and failing loudly on — a full JSON parse of
/// content that was never a Diagram Studio payload.
class ClipboardCodec {
  ClipboardCodec._();

  static const String _marker = 'oep_diagram_studio_clipboard_v1';

  static String encode(ClipboardEntry entry) {
    return jsonEncode({'__marker__': _marker, 'entry': entry.toJson()});
  }

  /// Returns `null` if [text] is not a Diagram Studio clipboard payload
  /// (not JSON, missing the marker, or otherwise malformed) — callers
  /// treat that as "nothing pasteable on the OS clipboard" rather than an
  /// error.
  static ClipboardEntry? decode(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['__marker__'] != _marker) return null;
      return ClipboardEntry.fromJson(Map<String, Object?>.from(decoded['entry'] as Map));
    } catch (_) {
      return null;
    }
  }
}
