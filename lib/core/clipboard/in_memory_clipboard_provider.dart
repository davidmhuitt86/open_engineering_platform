import '../interfaces/clipboard_provider.dart';
import 'clipboard_entry.dart';

/// Phase-2 (WORK_PACKAGE_021) [ClipboardProvider]: a single in-memory
/// entry, scoped to the running engine.
class InMemoryClipboardProvider implements ClipboardProvider {
  ClipboardEntry? _content;

  @override
  ClipboardEntry? get content => _content;

  @override
  void write(ClipboardEntry entry) => _content = entry;

  @override
  void clear() => _content = null;
}
