import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Knowledge Session Manager (WP-EKE-008): Create, Resume, Clone,
/// Close, Inspect, and Export Summary for KnowledgeSessions on the
/// Engineering Intelligence Platform (WP-EKE-007).
class KnowledgeSessionManagerPage extends ConsumerStatefulWidget {
  const KnowledgeSessionManagerPage({super.key});

  @override
  ConsumerState<KnowledgeSessionManagerPage> createState() => _KnowledgeSessionManagerPageState();
}

class _KnowledgeSessionManagerPageState extends ConsumerState<KnowledgeSessionManagerPage> {
  List<String> _sessionIds = const [];
  String? _selectedSessionId;
  OepKnowledgeSessionSummary? _selectedSummary;
  String? _exportedSummary;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  void _refresh() {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    try {
      setState(() => _sessionIds = bridge.listEipSessions());
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sessionId = bridge.createEipSession();
      _refresh();
      setState(() => _selectedSessionId = sessionId);
      await _inspect(sessionId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _inspect(String sessionId) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _exportedSummary = null;
      _selectedSessionId = sessionId;
    });
    try {
      final summary = bridge.getEipSession(sessionId);
      setState(() => _selectedSummary = summary);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _resume(String sessionId) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    try {
      bridge.resumeEipSession(sessionId);
      await _inspect(sessionId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _clone(String sessionId) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    try {
      final newId = bridge.cloneEipSession(sessionId);
      _refresh();
      await _inspect(newId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _close(String sessionId) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    try {
      bridge.closeEipSession(sessionId);
      if (_selectedSessionId == sessionId) await _inspect(sessionId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _exportSummary(String sessionId) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    try {
      final summary = bridge.exportEipSessionSummary(sessionId);
      setState(() => _exportedSummary = summary);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Knowledge Sessions (${_sessionIds.length})',
                          style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null) EiErrorBanner(message: _error!),
                Expanded(
                  child: _sessionIds.isEmpty
                      ? const EiEmptyState(icon: Icons.folder_off_outlined, message: 'No sessions yet. Create one to get started.')
                      : ListView.builder(
                          itemCount: _sessionIds.length,
                          itemBuilder: (context, index) {
                            final id = _sessionIds[index];
                            final isSelected = id == _selectedSessionId;
                            return Material(
                              color: isSelected ? StudioColors.selection.withValues(alpha: 0.1) : Colors.transparent,
                              child: InkWell(
                                onTap: () => _inspect(id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(id, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontFamily: 'Consolas')),
                                      ),
                                      IconButton(
                                        tooltip: 'Resume',
                                        icon: const Icon(Icons.play_circle_outline, size: 16),
                                        onPressed: () => _resume(id),
                                      ),
                                      IconButton(
                                        tooltip: 'Clone',
                                        icon: const Icon(Icons.copy_outlined, size: 16),
                                        onPressed: () => _clone(id),
                                      ),
                                      IconButton(
                                        tooltip: 'Close',
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () => _close(id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedSummary == null)
                    const EiEmptyState(icon: Icons.touch_app_outlined, message: 'Select a session to inspect it.')
                  else ...[
                    EiSectionCard(
                      title: 'Session ${_selectedSummary!.sessionId}',
                      icon: Icons.folder_shared_outlined,
                      trailing: EiChip(_selectedSummary!.closed ? 'Closed' : 'Open',
                          color: _selectedSummary!.closed ? StudioColors.inactive : StudioColors.success),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EiKeyValueRow('Created', _selectedSummary!.createdUtc),
                          EiKeyValueRow('Last Active', _selectedSummary!.lastActiveUtc),
                          EiKeyValueRow('Query History', '${_selectedSummary!.queryHistoryCount}'),
                          EiKeyValueRow('Validation History', '${_selectedSummary!.validationHistoryCount}'),
                          EiKeyValueRow('Analysis History', '${_selectedSummary!.analysisHistoryCount}'),
                          EiKeyValueRow('Reasoning History', '${_selectedSummary!.reasoningHistoryCount}'),
                          EiKeyValueRow('Recommendations', '${_selectedSummary!.recommendationCount}'),
                          EiKeyValueRow('Active Objects', '${_selectedSummary!.activeObjectCount}'),
                          EiKeyValueRow('Active Packages', '${_selectedSummary!.activePackageCount}'),
                          EiKeyValueRow('Total Execution Time', '${_selectedSummary!.totalExecutionTimeMs.toStringAsFixed(3)} ms'),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _exportSummary(_selectedSummary!.sessionId),
                            icon: const Icon(Icons.ios_share, size: 16),
                            label: const Text('Export Summary'),
                          ),
                        ],
                      ),
                    ),
                    if (_exportedSummary != null)
                      EiSectionCard(
                        title: 'Exported Summary',
                        icon: Icons.description_outlined,
                        child: SelectableText(_exportedSummary!, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontFamily: 'Consolas')),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
