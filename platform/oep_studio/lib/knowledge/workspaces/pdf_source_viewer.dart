import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/source_material.dart';
import 'evidence_browser_dialog.dart';
import 'ocr_layer_viewer_dialog.dart';

/// The PDF Source Viewer (Work Package 009 STUDIO-TASK-000019): a real
/// PDF renderer — page navigation, zoom, fit, rotate, continuous
/// scrolling — plus the manual Evidence Region drawing tool
/// (STUDIO-TASK-000020) and Page Selection toggle (STUDIO-TASK-000019 §
/// Selection). "This is a viewer only. No parsing. No OCR. No
/// extraction." — nothing here reads the PDF's text or content, only
/// its rendered pages and page geometry.
///
/// Built on `pdfrx` (MIT; PDFium-backed; supports Windows desktop — see
/// `docs/EVIDENCE_MODEL.md` § Flutter Package Decision). Keyed by
/// [source]'s ID at the call site (`source_viewer_panel.dart`) so
/// switching between two different PDFs tears down and recreates this
/// widget's `PdfViewerController` rather than reusing one across
/// documents.
class PdfSourceViewer extends ConsumerStatefulWidget {
  const PdfSourceViewer({required this.source, super.key});

  final SourceMaterial source;

  @override
  ConsumerState<PdfSourceViewer> createState() => _PdfSourceViewerState();
}

class _PdfSourceViewerState extends ConsumerState<PdfSourceViewer> {
  final _controller = PdfViewerController();
  int _rotationQuarterTurns = 0;
  bool _addRegionArmed = false;

  // Evidence Region drag-to-create state, in the viewer's own local
  // (unscrolled-widget) coordinate space — see [_buildViewerOverlay].
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _dragPageNumber;

  // Tracks the last Evidence Region this viewer auto-navigated to, so a
  // selection made elsewhere (Evidence Browser, Property Inspector) is
  // followed exactly once rather than on every rebuild — see `build()`.
  String? _lastNavigatedRegionId;

  // Same pattern, for Engineering Contexts (Work Package 015
  // STUDIO-TASK-000045: "Selecting a context updates: Source Viewer").
  String? _lastNavigatedContextId;

  void _openEvidenceBrowser() {
    showEvidenceBrowserDialog(context, sourceId: widget.source.id, sourceName: widget.source.originalFileName);
  }

  void _openOcrLayerViewer() {
    showOcrLayerViewerDialog(context, source: widget.source);
  }

  void _toggleAddRegion() {
    setState(() {
      _addRegionArmed = !_addRegionArmed;
      _dragStart = null;
      _dragCurrent = null;
      _dragPageNumber = null;
    });
  }

  void _rotate() {
    setState(() => _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4);
  }

  Future<void> _fitWidth() async {
    final page = _controller.pageNumber;
    if (page == null) return;
    final matrix = _controller.calcMatrixFitWidthForPage(pageNumber: page);
    if (matrix != null) await _controller.goTo(matrix);
  }

  Future<void> _fitPage() async {
    final page = _controller.pageNumber;
    if (page == null) return;
    final matrix = _controller.calcMatrixForFit(pageNumber: page);
    if (matrix != null) await _controller.goTo(matrix);
  }

  Future<void> _goToPage(int delta) async {
    final current = _controller.pageNumber ?? 1;
    final target = (current + delta).clamp(1, _controller.pageCount);
    await _controller.goToPage(pageNumber: target);
  }

  void _finishDrag() {
    final start = _dragStart;
    final current = _dragCurrent;
    final page = _dragPageNumber;
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      _dragPageNumber = null;
    });
    if (start == null || current == null || page == null) return;
    if ((current - start).distance < 8) return; // Ignore accidental clicks.

    final startHit = _controller.getPdfPageHitTestResult(start, useDocumentLayoutCoordinates: false);
    final endHit = _controller.getPdfPageHitTestResult(current, useDocumentLayoutCoordinates: false);
    if (startHit == null || endHit == null) return;
    if (startHit.page.pageNumber != page || endHit.page.pageNumber != page) return;

    final pageWidth = startHit.page.width;
    final pageHeight = startHit.page.height;
    final x1 = startHit.offset.x / pageWidth;
    final x2 = endHit.offset.x / pageWidth;
    // PdfPoint's y origin is the page's bottom-left corner; region storage
    // uses a top-left-origin fraction (see EvidenceRegion's doc comment),
    // so y is inverted here.
    final y1 = 1 - (startHit.offset.y / pageHeight);
    final y2 = 1 - (endHit.offset.y / pageHeight);

    final left = x1 < x2 ? x1 : x2;
    final top = y1 < y2 ? y1 : y2;
    final width = (x2 - x1).abs();
    final height = (y2 - y1).abs();
    if (width <= 0 || height <= 0) return;

    try {
      ref
          .read(foundationRuntimeServiceProvider.notifier)
          .createEvidenceRegion(
            sourceId: widget.source.id,
            page: page,
            x: left.clamp(0.0, 1.0),
            y: top.clamp(0.0, 1.0),
            width: width.clamp(0.0, 1.0 - left),
            height: height.clamp(0.0, 1.0 - top),
          );
    } on KnowledgeValidationException catch (error) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text("Couldn't Create Evidence Region"),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  // `pageOverlaysBuilder`/`viewerOverlayBuilder` are invoked by
  // `PdfViewer`'s own descendant build, not synchronously within this
  // widget's `build()` call — `ref.watch` is only valid inside the
  // latter. `_foundation` is captured once per `build()` (see `build()`
  // below) so these callbacks can read the current snapshot without
  // calling `ref.watch` themselves.
  late FoundationServiceState _foundation;

  List<Widget> _buildPageOverlays(BuildContext context, Rect pageRectInViewer, PdfPage page) {
    final foundation = _foundation;
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final regions = foundation.evidenceRegionsForPage(widget.source.id, page.pageNumber);
    final selectedCandidate = foundation.selectedCandidate;
    final linkedRegionIds = selectedCandidate == null
        ? const <String>{}
        : foundation.evidenceRegionsLinkedToCandidate(selectedCandidate.id).map((region) => region.id).toSet();
    final selectedRegionId = foundation.selectedEvidenceRegion?.id;
    final isPageSelected = foundation.pageSelections.any(
      (selection) => selection.sourceId == widget.source.id && selection.page == page.pageNumber,
    );

    return [
      for (final region in regions)
        Positioned(
          left: region.x * pageRectInViewer.width,
          top: region.y * pageRectInViewer.height,
          width: region.width * pageRectInViewer.width,
          height: region.height * pageRectInViewer.height,
          // A plain `GestureDetector` scoped to just this small rect —
          // not `PdfOverlayInteractionRegion` — since the region rect
          // is far smaller than the viewer, a normal tap here never
          // competes with the viewer's own pan/zoom gesture arena for
          // touches starting elsewhere on the page.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => notifier.selectEvidenceRegion(region),
            child: _RegionBox(
              selected: region.id == selectedRegionId,
              linked: linkedRegionIds.contains(region.id),
              label: region.label,
            ),
          ),
        ),
      Positioned(
        left: 4,
        top: 4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            try {
              notifier.togglePageSelection(sourceId: widget.source.id, page: page.pageNumber);
            } on KnowledgeValidationException {
              // No session — the toggle silently has no effect; the rest
              // of the Source Viewer already requires an active session
              // to reach this panel in practice.
            }
          },
          child: Icon(
            isPageSelected ? Icons.check_box : Icons.check_box_outline_blank,
            color: isPageSelected ? StudioColors.selection : Colors.white,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
            size: 20,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildViewerOverlay(BuildContext context, Size size, PdfViewerHandleLinkTap handleLinkTap) {
    if (!_addRegionArmed) return const [];
    return [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) {
          final hit = _controller.getPdfPageHitTestResult(details.localPosition, useDocumentLayoutCoordinates: false);
          setState(() {
            _dragStart = details.localPosition;
            _dragCurrent = details.localPosition;
            _dragPageNumber = hit?.page.pageNumber;
          });
        },
        onPanUpdate: (details) {
          if (_dragStart == null) return;
          setState(() => _dragCurrent = details.localPosition);
        },
        onPanEnd: (_) => _finishDrag(),
        onPanCancel: () => setState(() {
          _dragStart = null;
          _dragCurrent = null;
          _dragPageNumber = null;
        }),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: _dragStart != null && _dragCurrent != null
              ? CustomPaint(painter: _DragRectPainter(_dragStart!, _dragCurrent!))
              : null,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _foundation = ref.watch(foundationRuntimeServiceProvider);

    // Following a selection made elsewhere (Evidence Browser, Property
    // Inspector) into view — "Navigation shall work in both directions"
    // (Work Package 009 § Source Viewer Interaction). Runs at most once
    // per newly-selected region, as a post-frame callback since a
    // controller navigation must not happen mid-build.
    final selected = _foundation.selectedEvidenceRegion;
    if (selected != null && selected.sourceId == widget.source.id && selected.id != _lastNavigatedRegionId) {
      _lastNavigatedRegionId = selected.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isReady) _controller.goToPage(pageNumber: selected.page);
      });
    } else if (selected == null) {
      _lastNavigatedRegionId = null;
    }

    final selectedContext = _foundation.selectedContext;
    if (selectedContext != null &&
        selectedContext.sourceId == widget.source.id &&
        selectedContext.id != _lastNavigatedContextId) {
      _lastNavigatedContextId = selectedContext.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isReady) _controller.goToPage(pageNumber: selectedContext.pageStart);
      });
    } else if (selectedContext == null) {
      _lastNavigatedContextId = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Toolbar(
          controller: _controller,
          addRegionArmed: _addRegionArmed,
          onPrevPage: () => _goToPage(-1),
          onNextPage: () => _goToPage(1),
          onZoomIn: () => _controller.zoomUp(),
          onZoomOut: () => _controller.zoomDown(),
          onFitWidth: _fitWidth,
          onFitPage: _fitPage,
          onRotate: _rotate,
          onToggleAddRegion: _toggleAddRegion,
          onOpenEvidenceBrowser: _openEvidenceBrowser,
          onOpenOcrLayerViewer: _openOcrLayerViewer,
        ),
        const Divider(height: 1),
        Expanded(
          child: RotatedBox(
            quarterTurns: _rotationQuarterTurns,
            child: PdfViewer.file(
              widget.source.localPath,
              key: ValueKey('pdf-viewer-${widget.source.id}'),
              controller: _controller,
              params: PdfViewerParams(
                onPageChanged: (page) {
                  if (page != null) ref.read(foundationRuntimeServiceProvider.notifier).setCurrentPage(page);
                },
                pageOverlaysBuilder: _buildPageOverlays,
                viewerOverlayBuilder: _buildViewerOverlay,
                errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This PDF could not be opened. It may be invalid or corrupted.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: StudioColors.error, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegionBox extends StatelessWidget {
  const _RegionBox({required this.selected, required this.linked, required this.label});

  final bool selected;
  final bool linked;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StudioColors.selection : (linked ? StudioColors.warning : StudioColors.success);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: selected ? 3 : 2),
        color: color.withValues(alpha: selected || linked ? 0.18 : 0.06),
      ),
      alignment: Alignment.topLeft,
      child: (selected || linked)
          ? Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              color: color,
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
            )
          : null,
    );
  }
}

class _DragRectPainter extends CustomPainter {
  _DragRectPainter(this.start, this.end);

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(rect, Paint()..color = StudioColors.selection.withValues(alpha: 0.18));
    canvas.drawRect(
      rect,
      Paint()
        ..color = StudioColors.selection
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _DragRectPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.addRegionArmed,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onFitPage,
    required this.onRotate,
    required this.onToggleAddRegion,
    required this.onOpenEvidenceBrowser,
    required this.onOpenOcrLayerViewer,
  });

  final PdfViewerController controller;
  final bool addRegionArmed;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final VoidCallback onRotate;
  final VoidCallback onToggleAddRegion;
  final VoidCallback onOpenEvidenceBrowser;
  final VoidCallback onOpenOcrLayerViewer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final ready = controller.isReady;
            final pageLabel = ready ? '${controller.pageNumber ?? 1} / ${controller.pageCount}' : '— / —';
            final zoomLabel = ready ? '${(controller.currentZoom * 100).round()}%' : '—';
            return Row(
              children: [
                IconButton(
                  tooltip: 'Previous Page',
                  icon: const Icon(Icons.navigate_before, size: 18),
                  onPressed: ready ? onPrevPage : null,
                ),
                Text(pageLabel, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                IconButton(
                  tooltip: 'Next Page',
                  icon: const Icon(Icons.navigate_next, size: 18),
                  onPressed: ready ? onNextPage : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Zoom Out',
                  icon: const Icon(Icons.zoom_out, size: 18),
                  onPressed: ready ? onZoomOut : null,
                ),
                Text(zoomLabel, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                IconButton(
                  tooltip: 'Zoom In',
                  icon: const Icon(Icons.zoom_in, size: 18),
                  onPressed: ready ? onZoomIn : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Fit Width',
                  icon: const Icon(Icons.fit_screen, size: 18),
                  onPressed: ready ? onFitWidth : null,
                ),
                IconButton(
                  tooltip: 'Fit Page',
                  icon: const Icon(Icons.crop_free, size: 18),
                  onPressed: ready ? onFitPage : null,
                ),
                IconButton(
                  tooltip: 'Rotate',
                  icon: const Icon(Icons.rotate_right, size: 18),
                  onPressed: ready ? onRotate : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: addRegionArmed ? 'Stop Drawing Evidence Regions' : 'Draw Evidence Region',
                  icon: const Icon(Icons.crop_din, size: 18),
                  color: addRegionArmed ? StudioColors.selection : null,
                  onPressed: ready ? onToggleAddRegion : null,
                ),
                IconButton(
                  tooltip: 'Evidence Browser',
                  icon: const Icon(Icons.list_alt, size: 18),
                  onPressed: onOpenEvidenceBrowser,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'OCR Layer Viewer',
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  onPressed: onOpenOcrLayerViewer,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
