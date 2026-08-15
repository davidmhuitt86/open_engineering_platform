import 'package:flutter/material.dart';

import '../../core/foundation/foundation_bridge.dart';
import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../intelligence/diagram_intelligence_service.dart';

/// AP-DS-003 Engineering Sessions panel: Create/Resume/Clone/Close,
/// history, and exported summary for Engineering Intelligence Platform
/// KnowledgeSessions (WP-EKE-007), embedded into Diagram Studio.
///
/// **Deliberate constructor deviation**: unlike the other four panels,
/// this one takes a third required parameter, [bridge]. Session
/// lifecycle management (`createEipSession`/`resumeEipSession`/
/// `cloneEipSession`/`closeEipSession`/`listEipSessions`/`getEipSession`/
/// `exportEipSessionSummary`) is explicitly NOT exposed by
/// [DiagramIntelligenceService] — per that class's own doc comment it
/// owns exactly one Knowledge Session for the diagram's lifetime and
/// exposes no session-management surface beyond [DiagramIntelligenceService.ensureSessionReady].
/// The governing spec is explicit that Session management "uses
/// SEPARATE `FoundationBridge` methods directly", so this panel talks
/// to [bridge] for every session operation instead. [intelligence] is
/// still accepted (kept for interface consistency with the other four
/// panels) and used for one thing: showing
/// [DiagramIntelligenceService.diagramObjectId], so the user can tell
/// which of the listed sessions (if any) is the one this diagram's own
/// Validate/Analyze/Reason/Recommend/Query calls are actually scoped
/// to. [onSelectNode] is likewise accepted for interface consistency
/// but never invoked here — sessions are not canvas-addressable
/// objects, so there is nothing meaningful for it to be called with.
class KnowledgeSessionsPanel extends StatefulWidget {
  const KnowledgeSessionsPanel({
    super.key,
    required this.intelligence,
    required this.onSelectNode,
    required this.bridge,
  });

  final DiagramIntelligenceService intelligence;
  final void Function(String nodeId) onSelectNode;
  final FoundationBridge bridge;

  @override
  State<KnowledgeSessionsPanel> createState() => _KnowledgeSessionsPanelState();
}

class _KnowledgeSessionsPanelState extends State<KnowledgeSessionsPanel> {
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
    try {
      setState(() => _sessionIds = widget.bridge.listEipSessions());
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sessionId = widget.bridge.createEipSession();
      _refresh();
      await _inspect(sessionId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inspect(String sessionId) async {
    setState(() {
      _busy = true;
      _error = null;
      _exportedSummary = null;
      _selectedSessionId = sessionId;
    });
    try {
      final summary = widget.bridge.getEipSession(sessionId);
      setState(() => _selectedSummary = summary);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume(String sessionId) async {
    try {
      widget.bridge.resumeEipSession(sessionId);
      await _inspect(sessionId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _clone(String sessionId) async {
    try {
      final newId = widget.bridge.cloneEipSession(sessionId);
      _refresh();
      await _inspect(newId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _close(String sessionId) async {
    try {
      widget.bridge.closeEipSession(sessionId);
      if (_selectedSessionId == sessionId) await _inspect(sessionId);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _exportSummary(String sessionId) async {
    try {
      final summary = widget.bridge.exportEipSessionSummary(sessionId);
      setState(() => _exportedSummary = summary);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagramObjectId = widget.intelligence.diagramObjectId;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sessions (${_sessionIds.length})${diagramObjectId != null ? ' — diagram: $diagramObjectId' : ''}',
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Create'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
            ),
          if (_error != null) EiErrorBanner(message: _error!),
          if (_sessionIds.isEmpty && !_busy)
            const EiEmptyState(icon: Icons.folder_off_outlined, message: 'No sessions yet. Create one to get started.')
          else
            for (final id in _sessionIds)
              Material(
                color: id == _selectedSessionId ? StudioColors.selection.withValues(alpha: 0.1) : Colors.transparent,
                child: InkWell(
                  onTap: () => _inspect(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(id, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5, fontFamily: 'Consolas')),
                        ),
                        IconButton(tooltip: 'Resume', iconSize: 15, icon: const Icon(Icons.play_circle_outline), onPressed: () => _resume(id)),
                        IconButton(tooltip: 'Clone', iconSize: 15, icon: const Icon(Icons.copy_outlined), onPressed: () => _clone(id)),
                        IconButton(tooltip: 'Close', iconSize: 15, icon: const Icon(Icons.close), onPressed: () => _close(id)),
                      ],
                    ),
                  ),
                ),
              ),
          if (_selectedSummary != null) ...[
            const SizedBox(height: 8),
            EiSectionCard(
              title: 'Session ${_selectedSummary!.sessionId}',
              icon: Icons.folder_shared_outlined,
              trailing: EiChip(
                _selectedSummary!.closed ? 'Closed' : 'Open',
                color: _selectedSummary!.closed ? StudioColors.inactive : StudioColors.success,
              ),
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
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _exportSummary(_selectedSummary!.sessionId),
                    icon: const Icon(Icons.ios_share, size: 15),
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
          ] else if (!_busy && _sessionIds.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Select a session to inspect it.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
