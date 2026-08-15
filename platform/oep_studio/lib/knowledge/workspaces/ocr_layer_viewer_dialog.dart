import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/ocr_bounding_box.dart';
import '../models/ocr_page_result.dart';
import '../models/ocr_processing_status.dart';
import '../models/ocr_search_match.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import '../services/ocr_search_service.dart';
import '../widgets/knowledge_placeholder.dart';
import 'ai_review_workspace_dialog.dart';
import 'context_explorer_dialog.dart';
import 'entity_review_workspace_dialog.dart';

/// The OCR Layer Viewer (Work Package 013 STUDIO-TASK-000035): "Display:
/// Original page, OCR overlay, Confidence heat map, Toggle overlay.
/// Engineers may: Show OCR, Hide OCR. No editing yet." Also hosts
/// STUDIO-TASK-000036's Find/Find Next/Highlight search, "local to
/// Source Material."
///
/// A dialog, not a new panel — SDD-016's seven-panel Knowledge Studio
/// layout stays frozen, the same precedent Work Package 010 (Procedure
/// Builder, Specification Editor) and Work Package 011 (Knowledge
/// Session Graph) already set for a substantial new interactive surface.
/// Opened per Source Material — "OCR augments Source Material only,"
/// there is no session-wide or cross-document view here.
Future<void> showOcrLayerViewerDialog(BuildContext context, {required SourceMaterial source, int? initialPage}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _OcrLayerViewerDialog(source: source, initialPage: initialPage),
  );
}

class _OcrLayerViewerDialog extends ConsumerStatefulWidget {
  const _OcrLayerViewerDialog({required this.source, this.initialPage});

  final SourceMaterial source;

  /// Opens directly on this page instead of page 1 — used by the
  /// Entity Review Workspace's "Navigate to source" (Work Package 014
  /// STUDIO-TASK-000039).
  final int? initialPage;

  @override
  ConsumerState<_OcrLayerViewerDialog> createState() => _OcrLayerViewerDialogState();
}

class _OcrLayerViewerDialogState extends ConsumerState<_OcrLayerViewerDialog> {
  static const _displayWidth = 860.0;

  late int _currentPage = widget.initialPage ?? 1;
  bool _heatMapEnabled = false;
  final _searchController = TextEditingController();
  List<OcrSearchMatch> _matches = const [];
  int? _currentMatchIndex;
  final _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRunOcr());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _maybeRunOcr() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final status = ref.read(foundationRuntimeServiceProvider).ocrProcessingStatus[widget.source.id];
    if (status == OcrProcessingStatus.processing) return;
    // `runOcrForSource` performs its own cheap cache-validity check
    // first — calling it unconditionally on every open is what makes
    // "Reopening a session shall not rerun OCR" *and* "Support cache
    // invalidation when Source Material changes" both true at once; a
    // one-time cache check is exactly what re-verifies neither is
    // needed, not a shortcut around it.
    notifier.runOcrForSource(widget.source.id);
  }

  void _runSearch(String query) {
    final results = ref.read(foundationRuntimeServiceProvider).ocrResultsForSource(widget.source.id);
    final matches = OcrSearchService.find(pageResults: results, query: query);
    setState(() {
      _matches = matches;
      _currentMatchIndex = matches.isEmpty ? null : 0;
    });
    _goToCurrentMatch();
  }

  void _findNext() {
    if (_matches.isEmpty) return;
    setState(() => _currentMatchIndex = ((_currentMatchIndex ?? -1) + 1) % _matches.length);
    _goToCurrentMatch();
  }

  void _goToCurrentMatch() {
    final index = _currentMatchIndex;
    if (index == null) return;
    final match = _matches[index];
    if (match.page != _currentPage) {
      setState(() => _currentPage = match.page);
    }
    if (widget.source.type == SourceMaterialType.pdf && _pdfController.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pdfController.goToPage(pageNumber: match.page));
    }
  }

  // Tracks the last Engineering Entity this viewer auto-navigated to,
  // so a selection made in the Entity Review Workspace ("Navigate to
  // source," Work Package 014 STUDIO-TASK-000039) is followed exactly
  // once rather than on every rebuild — mirrors `PdfSourceViewer`'s own
  // `_lastNavigatedRegionId` pattern for Evidence Regions.
  String? _lastNavigatedEntityId;

  // Same pattern, for Engineering Contexts (Work Package 015
  // STUDIO-TASK-000045: "Selecting a context updates: ... OCR Viewer").
  String? _lastNavigatedContextId;

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final screen = MediaQuery.of(context).size;
    final status = foundation.ocrProcessingStatus[widget.source.id] ?? OcrProcessingStatus.notProcessed;
    final results = foundation.ocrResultsForSource(widget.source.id);
    final pageCount = results.isEmpty ? 1 : results.map((r) => r.page).reduce(math.max);
    final resultsForCurrentPage = results.where((r) => r.page == _currentPage);
    final currentResult = resultsForCurrentPage.isEmpty ? null : resultsForCurrentPage.first;
    final currentMatch = _currentMatchIndex == null ? null : _matches[_currentMatchIndex!];

    final selectedEntity = foundation.selectedEntity;
    if (selectedEntity != null &&
        selectedEntity.sourceId == widget.source.id &&
        selectedEntity.id != _lastNavigatedEntityId) {
      _lastNavigatedEntityId = selectedEntity.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentPage = selectedEntity.page);
        if (widget.source.type == SourceMaterialType.pdf && _pdfController.isReady) {
          _pdfController.goToPage(pageNumber: selectedEntity.page);
        }
      });
    } else if (selectedEntity == null) {
      _lastNavigatedEntityId = null;
    }

    final selectedContext = foundation.selectedContext;
    if (selectedContext != null &&
        selectedContext.sourceId == widget.source.id &&
        selectedContext.id != _lastNavigatedContextId) {
      _lastNavigatedContextId = selectedContext.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentPage = selectedContext.pageStart);
        if (widget.source.type == SourceMaterialType.pdf && _pdfController.isReady) {
          _pdfController.goToPage(pageNumber: selectedContext.pageStart);
        }
      });
    } else if (selectedContext == null) {
      _lastNavigatedContextId = null;
    }

    return Dialog(
      backgroundColor: StudioColors.surfaceRaised,
      child: SizedBox(
        width: math.min(1100, screen.width * 0.9),
        height: math.min(800, screen.height * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'OCR Layer Viewer — ${widget.source.originalFileName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous Context',
                    icon: const Icon(Icons.skip_previous_outlined, size: 18),
                    onPressed: () => ref
                        .read(foundationRuntimeServiceProvider.notifier)
                        .navigateToAdjacentContext(widget.source.id, forward: false),
                  ),
                  IconButton(
                    tooltip: 'Next Context',
                    icon: const Icon(Icons.skip_next_outlined, size: 18),
                    onPressed: () => ref
                        .read(foundationRuntimeServiceProvider.notifier)
                        .navigateToAdjacentContext(widget.source.id, forward: true),
                  ),
                  IconButton(
                    tooltip: 'Context Explorer',
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    onPressed: () => showContextExplorerDialog(context, source: widget.source),
                  ),
                  IconButton(
                    tooltip: 'Extract Entities',
                    icon: const Icon(Icons.rule_outlined, size: 18),
                    onPressed: () => showEntityReviewWorkspaceDialog(context, source: widget.source),
                  ),
                  IconButton(
                    tooltip: 'AI Suggestions',
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    onPressed: () => showAiReviewWorkspaceDialog(context, source: widget.source),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _Toolbar(
              overlayVisible: foundation.ocrOverlayVisible,
              heatMapEnabled: _heatMapEnabled,
              onToggleOverlay: () => ref.read(foundationRuntimeServiceProvider.notifier).toggleOcrOverlay(),
              onToggleHeatMap: () => setState(() => _heatMapEnabled = !_heatMapEnabled),
              currentPage: _currentPage,
              pageCount: pageCount,
              showPager: widget.source.type == SourceMaterialType.pdf,
              onPrevPage: () => setState(() => _currentPage = math.max(1, _currentPage - 1)),
              onNextPage: () => setState(() => _currentPage = math.min(pageCount, _currentPage + 1)),
              searchController: _searchController,
              matchCount: _matches.length,
              currentMatchIndex: _currentMatchIndex,
              onSearchChanged: _runSearch,
              onFindNext: _findNext,
            ),
            const Divider(height: 1),
            if (foundation.ocrErrorMessage != null)
              _ErrorBanner(
                message: foundation.ocrErrorMessage!,
                onDismiss: () => ref.read(foundationRuntimeServiceProvider.notifier).clearOcrErrorMessage(),
              ),
            Expanded(
              child: switch (status) {
                OcrProcessingStatus.notProcessed || OcrProcessingStatus.processing => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Running OCR…', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                OcrProcessingStatus.failed when currentResult == null => const KnowledgePlaceholder(
                  message: 'OCR could not be completed for this source. See the error above.',
                ),
                OcrProcessingStatus.completed || OcrProcessingStatus.failed => _PageView(
                  source: widget.source,
                  page: _currentPage,
                  result: currentResult,
                  overlayVisible: foundation.ocrOverlayVisible,
                  heatMapEnabled: _heatMapEnabled,
                  highlightedWordIndices: currentMatch != null && currentMatch.page == _currentPage
                      ? currentMatch.wordIndices.toSet()
                      : const {},
                  displayWidth: _displayWidth,
                  pdfController: _pdfController,
                  initialPage: widget.initialPage,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.overlayVisible,
    required this.heatMapEnabled,
    required this.onToggleOverlay,
    required this.onToggleHeatMap,
    required this.currentPage,
    required this.pageCount,
    required this.showPager,
    required this.onPrevPage,
    required this.onNextPage,
    required this.searchController,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.onSearchChanged,
    required this.onFindNext,
  });

  final bool overlayVisible;
  final bool heatMapEnabled;
  final VoidCallback onToggleOverlay;
  final VoidCallback onToggleHeatMap;
  final int currentPage;
  final int pageCount;
  final bool showPager;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final TextEditingController searchController;
  final int matchCount;
  final int? currentMatchIndex;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFindNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (showPager) ...[
            IconButton(
              tooltip: 'Previous Page',
              icon: const Icon(Icons.navigate_before, size: 18),
              onPressed: currentPage > 1 ? onPrevPage : null,
            ),
            Text('$currentPage / $pageCount', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
            IconButton(
              tooltip: 'Next Page',
              icon: const Icon(Icons.navigate_next, size: 18),
              onPressed: currentPage < pageCount ? onNextPage : null,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: overlayVisible ? 'Hide OCR' : 'Show OCR',
            icon: Icon(overlayVisible ? Icons.visibility : Icons.visibility_off, size: 18),
            color: overlayVisible ? StudioColors.selection : null,
            onPressed: onToggleOverlay,
          ),
          IconButton(
            tooltip: 'Confidence Heat Map',
            icon: const Icon(Icons.thermostat_outlined, size: 18),
            color: heatMapEnabled ? StudioColors.selection : null,
            onPressed: overlayVisible ? onToggleHeatMap : null,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Find in this document…',
                prefixIcon: Icon(Icons.search, size: 16),
              ),
              onChanged: onSearchChanged,
              onSubmitted: (_) => onFindNext(),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            matchCount == 0 ? '0 of 0' : '${(currentMatchIndex ?? 0) + 1} of $matchCount',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
          ),
          IconButton(
            tooltip: 'Find Next',
            icon: const Icon(Icons.arrow_downward, size: 16),
            onPressed: matchCount > 0 ? onFindNext : null,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: StudioColors.error.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: StudioColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: const TextStyle(color: StudioColors.error, fontSize: 11.5))),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 14),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Renders the current page — the original image plus, when
/// [overlayVisible], the OCR word boxes or confidence heat map — for
/// both source kinds this work package supports viewing:
///
/// * PDF: a real `pdfrx` [PdfViewer], overlaying boxes via
///   `pageOverlaysBuilder` exactly the way `PdfSourceViewer` already
///   overlays Evidence Regions, so pan/zoom/fit come for free and the
///   overlay's fractional coordinates need no separate scaling logic.
/// * PNG/JPG: `Image.file` inside a fixed-size canvas (scaled to
///   [displayWidth], preserving [OcrPageResult]'s own aspect ratio) so
///   the same fraction-based [OcrBoundingBox] math applies uniformly.
/// * TIFF: Flutter's built-in image codecs cannot decode TIFF (unlike
///   PNG/JPG/GIF/BMP/WEBP) — the canvas still renders at the correct
///   aspect ratio and the overlay still works, but the original page
///   itself shows a placeholder instead of true pixels. See
///   `docs/OCR_PIPELINE.md` § Architectural Observations.
class _PageView extends StatelessWidget {
  const _PageView({
    required this.source,
    required this.page,
    required this.result,
    required this.overlayVisible,
    required this.heatMapEnabled,
    required this.highlightedWordIndices,
    required this.displayWidth,
    required this.pdfController,
    this.initialPage,
  });

  final SourceMaterial source;
  final int page;
  final OcrPageResult? result;
  final bool overlayVisible;
  final bool heatMapEnabled;
  final Set<int> highlightedWordIndices;
  final double displayWidth;
  final PdfViewerController pdfController;

  /// STUDIO-TASK-000039's "Navigate to source" — opens the viewer
  /// directly on this page (only honored on first load, like `pdfrx`'s
  /// own `initialPageNumber`; explicit page changes afterward go
  /// through [pdfController] instead).
  final int? initialPage;

  @override
  Widget build(BuildContext context) {
    if (source.type == SourceMaterialType.pdf) {
      return PdfViewer.file(
        source.localPath,
        key: ValueKey('ocr-pdf-viewer-${source.id}'),
        controller: pdfController,
        initialPageNumber: initialPage ?? 1,
        params: PdfViewerParams(
          pageOverlaysBuilder: (context, pageRectInViewer, pdfPage) {
            if (pdfPage.pageNumber != page || !overlayVisible || result == null) return const [];
            return _wordOverlays(result!, pageRectInViewer.size);
          },
        ),
      );
    }

    if (result == null || result!.imageWidth == 0 || result!.imageHeight == 0) {
      return const KnowledgePlaceholder(message: 'OCR has not produced a result for this page yet.');
    }
    final displayHeight = displayWidth * (result!.imageHeight / result!.imageWidth);
    // Flutter's built-in image codecs cannot decode TIFF — see this
    // class's own doc comment.
    final lowerName = source.originalFileName.toLowerCase();
    final canRenderOriginal = !lowerName.endsWith('.tif') && !lowerName.endsWith('.tiff') && File(source.localPath).existsSync();

    return InteractiveViewer(
      maxScale: 6,
      child: Center(
        child: SizedBox(
          width: displayWidth,
          height: displayHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: canRenderOriginal
                    ? Image.file(
                        File(source.localPath),
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.white24),
                      )
                    : const ColoredBox(color: Colors.white24),
              ),
              if (overlayVisible) ..._wordOverlays(result!, Size(displayWidth, displayHeight)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _wordOverlays(OcrPageResult result, Size canvasSize) {
    return [
      for (var i = 0; i < result.words.length; i++)
        _WordBox(
          box: result.words[i].boundingBox,
          confidence: result.words[i].confidence,
          canvasSize: canvasSize,
          heatMapEnabled: heatMapEnabled,
          highlighted: highlightedWordIndices.contains(i),
        ),
    ];
  }
}

class _WordBox extends StatelessWidget {
  const _WordBox({
    required this.box,
    required this.confidence,
    required this.canvasSize,
    required this.heatMapEnabled,
    required this.highlighted,
  });

  final OcrBoundingBox box;
  final double confidence;
  final Size canvasSize;
  final bool heatMapEnabled;
  final bool highlighted;

  /// Interpolates red → yellow → green as [confidence] rises from `0`
  /// to `1` (`docs/OCR_PIPELINE.md` § Confidence Model) — a continuous
  /// gradient rather than a small number of hard buckets, so the "heat
  /// map" name is literal.
  static Color _heatColor(double confidence) {
    if (confidence < 0.5) {
      return Color.lerp(StudioColors.error, StudioColors.warning, confidence / 0.5)!;
    }
    return Color.lerp(StudioColors.warning, StudioColors.success, (confidence - 0.5) / 0.5)!;
  }

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? StudioColors.selection : (heatMapEnabled ? _heatColor(confidence) : StudioColors.info);
    return Positioned(
      left: box.x * canvasSize.width,
      top: box.y * canvasSize.height,
      width: box.width * canvasSize.width,
      height: box.height * canvasSize.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: highlighted ? 2 : 1),
          color: heatMapEnabled ? color.withValues(alpha: 0.28) : color.withValues(alpha: highlighted ? 0.3 : 0.08),
        ),
      ),
    );
  }
}
