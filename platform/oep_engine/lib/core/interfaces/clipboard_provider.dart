import '../clipboard/clipboard_entry.dart';

/// Clipboard backing store (WORK_PACKAGE_021, ENGINE-TASK-000083).
/// Resolved through [EngineRegistry] like every other capability
/// (ADR-001) — a future OS-clipboard-backed or cross-document provider
/// implements the same contract.
abstract class ClipboardProvider {
  ClipboardEntry? get content;

  void write(ClipboardEntry entry);

  void clear();
}
