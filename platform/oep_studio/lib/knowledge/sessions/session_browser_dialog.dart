import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../models/knowledge_session_record.dart';
import '../models/knowledge_validation_exception.dart';
import '../services/knowledge_session_storage.dart';

/// The Session Browser (Work Package 008 STUDIO-TASK-000015): lists
/// every persisted Knowledge Curation Session and supports Open,
/// Duplicate, Archive/Unarchive, and Delete (with confirmation). Opens
/// as a dialog rather than a workspace panel — SDD-016's seven-panel
/// Knowledge Studio layout is frozen, and browsing/switching sessions
/// is an occasional action, not something that needs permanent screen
/// space (see `docs/KNOWLEDGE_SESSION_FORMAT.md` § Session Browser).
Future<void> showSessionBrowserDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _SessionBrowserDialog());
}

class _SessionBrowserDialog extends ConsumerStatefulWidget {
  const _SessionBrowserDialog();

  @override
  ConsumerState<_SessionBrowserDialog> createState() => _SessionBrowserDialogState();
}

class _SessionBrowserDialogState extends ConsumerState<_SessionBrowserDialog> {
  late Future<SessionBrowserListing> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(foundationRuntimeServiceProvider.notifier).listKnowledgeSessions();
  }

  void _reload() {
    setState(() {
      _future = ref.read(foundationRuntimeServiceProvider.notifier).listKnowledgeSessions();
    });
  }

  Future<void> _runAction(Future<void> Function() action, {required String failureTitle}) async {
    try {
      await action();
      _reload();
    } on KnowledgeValidationException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: Text(failureTitle),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _confirmDelete(String sessionId, String sessionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Delete Session'),
        content: Text('Permanently delete "$sessionName" and its source material? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: StudioColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    await _runAction(() => notifier.deleteKnowledgeSession(sessionId), failureTitle: "Couldn't Delete Session");
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final activeSessionId = ref.watch(foundationRuntimeServiceProvider.select((state) => state.knowledgeSession?.id));

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Session Browser'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: FutureBuilder<SessionBrowserListing>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final listing = snapshot.data!;
            if (listing.sessions.isEmpty && listing.corruptedSessionIds.isEmpty) {
              return const Center(
                child: Text('No sessions yet.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              );
            }
            return ListView(
              children: [
                for (final record in listing.sessions)
                  _SessionRow(
                    record: record,
                    isActive: record.session.id == activeSessionId,
                    onOpen: () => _runAction(
                      () => notifier.openKnowledgeSession(record.session.id),
                      failureTitle: "Couldn't Open Session",
                    ).then((_) {
                      if (context.mounted) Navigator.of(context).pop();
                    }),
                    onDuplicate: () => _runAction(
                      () => notifier.duplicateKnowledgeSession(record.session.id),
                      failureTitle: "Couldn't Duplicate Session",
                    ),
                    onToggleArchive: () => _runAction(
                      () => notifier.setKnowledgeSessionArchived(record.session.id, archived: !record.session.archived),
                      failureTitle: "Couldn't Update Session",
                    ),
                    onDelete: () => _confirmDelete(record.session.id, record.session.name),
                  ),
                for (final corruptedId in listing.corruptedSessionIds)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.error_outline, color: StudioColors.error, size: 18),
                    title: Text(corruptedId, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                    subtitle: const Text(
                      'This session file is corrupted and could not be loaded.',
                      style: TextStyle(color: StudioColors.error, fontSize: 11),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.record,
    required this.isActive,
    required this.onOpen,
    required this.onDuplicate,
    required this.onToggleArchive,
    required this.onDelete,
  });

  final KnowledgeSessionRecord record;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final session = record.session;
    return ListTile(
      dense: true,
      leading: Icon(
        session.archived ? Icons.archive_outlined : Icons.folder_outlined,
        size: 18,
        color: isActive ? StudioColors.selection : StudioColors.textSecondary,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              session.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudioColors.textPrimary,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            const Text('(Active)', style: TextStyle(color: StudioColors.selection, fontSize: 11)),
          ],
        ],
      ),
      subtitle: Text(
        '${session.status.label}${session.archived ? ' · Archived' : ''} · '
        '${session.repositoryName} · Modified ${formatDateTime(session.lastModified)}',
        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: 'Open', icon: const Icon(Icons.open_in_new, size: 16), onPressed: onOpen),
          IconButton(tooltip: 'Duplicate', icon: const Icon(Icons.copy_outlined, size: 16), onPressed: onDuplicate),
          IconButton(
            tooltip: session.archived ? 'Unarchive' : 'Archive',
            icon: Icon(session.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 16),
            onPressed: onToggleArchive,
          ),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 16), onPressed: onDelete),
        ],
      ),
    );
  }
}
