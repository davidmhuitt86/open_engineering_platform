import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/evidence_annotation_status.dart';
import '../models/evidence_origin.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/ocr_bounding_box.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import '../review/relationship_candidate_form_dialog.dart';
import '../widgets/knowledge_placeholder.dart';

/// WP-INGEST-010 / AP-INGEST-009 §N: the "UIF-produced data, hosted as a
/// Knowledge Studio surface" Extraction Inspector. Deliberately built the
/// same way `ocr_layer_viewer_dialog.dart` is (a dedicated dialog with its
/// own `pdfrx` `PdfViewer` instance, independent of the main `PdfSourceViewer`)
/// rather than a second document-rendering system — see this work
/// package's own explicit "Do not duplicate PDF rendering infrastructure."
///
/// **Direct product feedback revision**: annotating a region no longer
/// opens an intrusive popup dialog. Drawing a rectangle immediately
/// creates a real, persisted `EvidenceRegion` (origin: human, status:
/// unverified, an honest "Unclassified" label) and it appears in a
/// non-modal side panel next to the document, listed live as each one is
/// drawn, with its own thumbnail and a type dropdown — never blocking
/// the document view. Setting a type also creates (or updates) a linked
/// `KnowledgeCandidate` via the existing `addKnowledgeCandidate`/
/// `linkEvidence`/`editKnowledgeCandidate` methods (the same mechanism
/// `CandidateGenerationService` already uses automatically for machine
/// detections), so relationships between annotated regions can be
/// created using the EXISTING, unmodified `RelationshipCandidateFormDialog`
/// — no new relationship model, no new candidate-creation path.
///
/// **UIF orchestration, the OCR engine, `EngineeringEntityExtractionService`,
/// and `CandidateGenerationService`'s own generation logic are never
/// called from here.** This dialog only ever READS already-produced
/// `OcrPageResult`/`EngineeringEntity`/`EvidenceRegion`/`KnowledgeCandidate`/
/// `RelationshipCandidate` state and writes through the existing,
/// unmodified `FoundationRuntimeNotifier` methods listed above.
Future<void> showExtractionInspectorDialog(BuildContext context,
    {required SourceMaterial source, int? initialPage}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _ExtractionInspectorDialog(source: source, initialPage: initialPage),
  );
}

/// Which extraction layer(s) currently render as page overlays.
/// AP-INGEST-009 §L: Relationships carry no spatial coordinates of their
/// own (a relationship is topology, not a page location) — that layer is
/// exposed only as a count, never an overlay toggle, per this work
/// package's own "Do not manufacture a layer for data that does not
/// exist."
enum _OverlayLayer { ocr, entities, evidence }

class _ExtractionInspectorDialog extends ConsumerStatefulWidget {
  const _ExtractionInspectorDialog({required this.source, this.initialPage});

  final SourceMaterial source;
  final int? initialPage;

  @override
  ConsumerState<_ExtractionInspectorDialog> createState() =>
      _ExtractionInspectorDialogState();
}

class _ExtractionInspectorDialogState
    extends ConsumerState<_ExtractionInspectorDialog> {
  late int _currentPage = widget.initialPage ?? 1;
  final _pdfController = PdfViewerController();
  final Set<_OverlayLayer> _visibleLayers = {
    _OverlayLayer.ocr,
    _OverlayLayer.entities,
    _OverlayLayer.evidence
  };
  final _annotatorController = TextEditingController();

  bool _drawArmed = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _dragPageNumber;

  // Zoom/rotate: the exact same mechanism `PdfSourceViewer` already
  // establishes for its own PDF instance -- `PdfViewerController.zoomUp`/
  // `zoomDown` for zoom (pdfrx's own interactive-viewer zoom, which also
  // still responds to pinch/scroll independently of these buttons), and
  // a `RotatedBox` wrapping the *entire* `PdfViewer` for rotate, cycling
  // 0°→90°→180°→270°→0°. Wrapping the whole widget (not just the
  // rendered page) means every overlay drawn via `pageOverlaysBuilder`
  // (OCR/entity/evidence boxes, all built on the same mechanism
  // `PdfSourceViewer` already uses for Evidence Regions) rotates together
  // with the page automatically, and the draw-to-annotate gesture's own
  // `details.localPosition` is already reported in the rotated widget's
  // own local space by Flutter's gesture system -- no separate
  // coordinate transform needed here either, exactly as `PdfSourceViewer`
  // itself needs none.
  int _rotationQuarterTurns = 0;

  // One rendered page image per page number, cached for the life of this
  // dialog and reused by every thumbnail on that page -- a page is never
  // re-rendered per-region. High enough resolution that a small annotated
  // region still crops crisply when scaled up to fill its thumbnail (see
  // `_renderPageThumbnailSource`'s own doc comment for the resolution
  // this was raised to and why), but still a second, throwaway raster
  // purely for the side panel's own previews -- the main viewer already
  // renders the real page at full quality via `PdfViewer` itself, and
  // this is never persisted and never used for OCR/extraction (that
  // pipeline is untouched, § this file's own top doc comment).
  final Map<int, ui.Image?> _pageImageCache = {};
  final Map<int, Future<ui.Image?>> _pageImageLoads = {};

  @override
  void dispose() {
    _annotatorController.dispose();
    for (final image in _pageImageCache.values) {
      image?.dispose();
    }
    super.dispose();
  }

  Future<ui.Image?> _pageImageFor(int page) {
    final cached = _pageImageCache[page];
    if (cached != null) return Future.value(cached);
    final inFlight = _pageImageLoads[page];
    if (inFlight != null) return inFlight;

    final future = _renderPageThumbnailSource(page);
    _pageImageLoads[page] = future;
    future.then((image) {
      if (!mounted) {
        image?.dispose();
        return;
      }
      _pageImageCache[page] = image;
      _pageImageLoads.remove(page);
      setState(() {});
    });
    return future;
  }

  Future<ui.Image?> _renderPageThumbnailSource(int page) async {
    if (widget.source.type != SourceMaterialType.pdf) return null;
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(widget.source.localPath);
      if (page < 1 || page > document.pages.length) return null;
      final pdfPage = document.pages[page - 1];
      // Direct product feedback: 360px was too low-resolution once a
      // small drawn region got scaled UP to fill the thumbnail box --
      // a handful of source pixels blown up to 88x88 is unavoidably
      // blurry no matter how correct the crop math is. Rendered once per
      // page and cached (§ `_pageImageCache`'s own doc comment), so a
      // higher-resolution source here is a one-time cost per page, not
      // per annotation -- still well below OCR's own 300 DPI render (this
      // is a thumbnail source, not a reading/extraction surface).
      const targetWidth = 1400.0;
      final scale = targetWidth / pdfPage.width;
      final rendered = await pdfPage.render(
          fullWidth: pdfPage.width * scale, fullHeight: pdfPage.height * scale);
      if (rendered == null) return null;
      try {
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          rendered.pixels,
          rendered.width,
          rendered.height,
          ui.PixelFormat.bgra8888,
          completer.complete,
        );
        return await completer.future;
      } finally {
        rendered.dispose();
      }
    } catch (_) {
      // Best-effort thumbnail source only -- a failure here must never
      // block annotation, which does not depend on it (§ this class's
      // own field doc comment).
      return null;
    } finally {
      await document?.dispose();
    }
  }

  void _rotate() {
    setState(() => _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4);
  }

  void _toggleLayer(_OverlayLayer layer) {
    setState(() {
      if (!_visibleLayers.remove(layer)) _visibleLayers.add(layer);
    });
  }

  void _toggleDraw() {
    setState(() {
      _drawArmed = !_drawArmed;
      _dragStart = null;
      _dragCurrent = null;
      _dragPageNumber = null;
    });
  }

  /// WP-INGEST-010 §7/§10, revised per direct product feedback: drawing a
  /// rectangle immediately creates the annotation -- no popup, no
  /// intermediate "pending" state. `observationRef` starts `null` (the
  /// TRX300 case: no machine observation exists here). Reuses the
  /// identical hit-test-based coordinate computation
  /// `PdfSourceViewer._finishDrag` already established (PDF-point space,
  /// bottom-left origin, inverted once here to the same top-left
  /// fractional convention every other overlay already uses) rather than
  /// inventing a second one.
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
    if ((current - start).distance < 8) return;

    final startHit = _pdfController.getPdfPageHitTestResult(start,
        useDocumentLayoutCoordinates: false);
    final endHit = _pdfController.getPdfPageHitTestResult(current,
        useDocumentLayoutCoordinates: false);
    if (startHit == null || endHit == null) return;
    if (startHit.page.pageNumber != page || endHit.page.pageNumber != page)
      return;

    final pageWidth = startHit.page.width;
    final pageHeight = startHit.page.height;
    final x1 = startHit.offset.x / pageWidth;
    final x2 = endHit.offset.x / pageWidth;
    final y1 = 1 - (startHit.offset.y / pageHeight);
    final y2 = 1 - (endHit.offset.y / pageHeight);

    final left = x1 < x2 ? x1 : x2;
    final top = y1 < y2 ? y1 : y2;
    final width = (x2 - x1).abs();
    final height = (y2 - y1).abs();
    if (width <= 0 || height <= 0) return;

    _createAnnotation(
      page: page,
      x: left.clamp(0.0, 1.0),
      y: top.clamp(0.0, 1.0),
      width: width.clamp(0.0, 1.0 - left),
      height: height.clamp(0.0, 1.0 - top),
      observationRef: null,
    );
  }

  /// WP-INGEST-010 §10: annotating an EXISTING region — if it is
  /// machine-generated, the new human annotation's `observationRef`
  /// points back at it, demonstrating the two are related but distinct
  /// records (a new `EvidenceRegion`, not an edit of the machine one —
  /// "must not modify... machine observation").
  void _annotateExisting(EvidenceRegion region) {
    _createAnnotation(
      page: region.page,
      x: region.x,
      y: region.y,
      width: region.width,
      height: region.height,
      observationRef: region.origin == EvidenceOrigin.machine
          ? region.id
          : region.observationRef,
    );
  }

  void _createAnnotation({
    required int page,
    required double x,
    required double y,
    required double width,
    required double height,
    required String? observationRef,
  }) {
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).createHumanAnnotation(
            sourceId: widget.source.id,
            page: page,
            x: x,
            y: y,
            width: width,
            height: height,
            annotatorId: _annotatorController.text.trim(),
            label: 'Unclassified',
            observationRef: observationRef,
          );
    } on KnowledgeValidationException catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text("Couldn't Create Annotation"),
          content: Text(error.message),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'))
          ],
        ),
      );
    }
  }

  static String _shortId(String id) =>
      id.length <= 6 ? id : id.substring(id.length - 6);

  /// Sets [region]'s classification. Reuses the existing `label` field
  /// (`"<Type>: <name>"`, exactly the convention `CandidateGenerationService`
  /// already uses for machine-generated regions) -- no new field was
  /// added to `EvidenceRegion` for this. Also creates (first time) or
  /// updates (every time after) a linked `KnowledgeCandidate` via the
  /// existing `addKnowledgeCandidate`/`linkEvidence`/`editKnowledgeCandidate`
  /// methods, so the existing, unmodified relationship-creation dialog
  /// (`showRelationshipCandidateFormDialog`) already has real candidates
  /// to connect -- no second candidate-creation path, no new relationship
  /// model.
  void _classify(
      EvidenceRegion region, KnowledgeCandidateType type, String customName) {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final name = customName.trim().isEmpty
        ? '${type.label} ${_shortId(region.id)}'
        : customName.trim();
    final label = customName.trim().isEmpty
        ? type.label
        : '${type.label}: ${customName.trim()}';

    notifier.renameEvidenceRegion(region.id, label);

    final linked = ref
        .read(foundationRuntimeServiceProvider)
        .candidatesLinkedToEvidenceRegion(region.id);
    if (linked.isEmpty) {
      final candidate = notifier.addKnowledgeCandidate(
          type: type, name: name, author: _annotatorController.text.trim());
      notifier.linkEvidence(candidateId: candidate.id, regionId: region.id);
    } else {
      notifier.editKnowledgeCandidate(linked.first.id, type: type, name: name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final screen = MediaQuery.of(context).size;

    final ocrResults = foundation.ocrResultsForSource(widget.source.id);
    final entities = foundation.engineeringEntitiesForSource(widget.source.id);
    final candidates =
        foundation.knowledgeCandidatesForSource(widget.source.id);
    final relationships =
        foundation.relationshipCandidatesForSource(widget.source.id);
    final allRegionsForSource = foundation.evidenceRegions
        .where((r) => r.sourceId == widget.source.id)
        .toList();
    final humanAnnotations = allRegionsForSource
        .where((r) => r.origin == EvidenceOrigin.human)
        .toList()
      ..sort((a, b) => a.createdTime.compareTo(b.createdTime));
    final regionsForPage =
        allRegionsForSource.where((r) => r.page == _currentPage).toList();
    final ocrForPage = ocrResults.where((r) => r.page == _currentPage);
    final ocrWordCount =
        ocrResults.fold<int>(0, (sum, r) => sum + r.words.length);
    final pageCount =
        ocrResults.isEmpty ? 1 : ocrResults.map((r) => r.page).reduce(math.max);

    return Dialog(
      backgroundColor: StudioColors.surfaceRaised,
      child: SizedBox(
        width: math.min(1400, screen.width * 0.95),
        height: math.min(880, screen.height * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Extraction Inspector — ${widget.source.originalFileName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: StudioColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
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
            _LayerBar(
              ocrWordCount: ocrWordCount,
              entityCount: entities.length,
              relationshipCount: relationships.length,
              candidateCount: candidates.length,
              visibleLayers: _visibleLayers,
              onToggleLayer: _toggleLayer,
              currentPage: _currentPage,
              pageCount: pageCount,
              showPager: widget.source.type == SourceMaterialType.pdf,
              onPrevPage: () =>
                  setState(() => _currentPage = math.max(1, _currentPage - 1)),
              onNextPage: () => setState(
                  () => _currentPage = math.min(pageCount, _currentPage + 1)),
              drawArmed: _drawArmed,
              onToggleDraw: _toggleDraw,
              onZoomIn: () => _pdfController.zoomUp(),
              onZoomOut: () => _pdfController.zoomDown(),
              onRotate: _rotate,
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: widget.source.type != SourceMaterialType.pdf
                        ? const KnowledgePlaceholder(
                            message:
                                'The Extraction Inspector currently supports PDF Source Material only.')
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  RotatedBox(
                                    quarterTurns: _rotationQuarterTurns,
                                    child: PdfViewer.file(
                                      widget.source.localPath,
                                      key: ValueKey(
                                          'extraction-inspector-pdf-${widget.source.id}'),
                                      controller: _pdfController,
                                      initialPageNumber:
                                          widget.initialPage ?? 1,
                                      params: PdfViewerParams(
                                        pageOverlaysBuilder: (context,
                                            pageRectInViewer, pdfPage) {
                                          if (pdfPage.pageNumber !=
                                              _currentPage) return const [];
                                          return [
                                            if (_visibleLayers
                                                .contains(_OverlayLayer.ocr))
                                              for (final result in ocrForPage)
                                                for (final word in result.words)
                                                  _BoxOverlay(
                                                    box: word.boundingBox,
                                                    canvasSize:
                                                        pageRectInViewer.size,
                                                    color: StudioColors.info,
                                                    tooltip: word.text,
                                                  ),
                                            if (_visibleLayers.contains(
                                                _OverlayLayer.entities))
                                              for (final entity
                                                  in entities.where((e) =>
                                                      e.page == _currentPage))
                                                _BoxOverlay(
                                                  box: entity.boundingBox,
                                                  canvasSize:
                                                      pageRectInViewer.size,
                                                  color: StudioColors.warning,
                                                  tooltip:
                                                      '${entity.type.label}: ${entity.normalizedValue}',
                                                ),
                                            if (_visibleLayers.contains(
                                                _OverlayLayer.evidence))
                                              for (final region
                                                  in regionsForPage)
                                                _RegionOverlay(
                                                  region: region,
                                                  canvasSize:
                                                      pageRectInViewer.size,
                                                  onTap: () =>
                                                      _annotateExisting(region),
                                                ),
                                          ];
                                        },
                                        viewerOverlayBuilder: !_drawArmed
                                            ? null
                                            : (context, size, handleLinkTap) =>
                                                [
                                                  GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onPanStart: (details) {
                                                      final hit = _pdfController
                                                          .getPdfPageHitTestResult(
                                                              details
                                                                  .localPosition,
                                                              useDocumentLayoutCoordinates:
                                                                  false);
                                                      setState(() {
                                                        _dragStart = details
                                                            .localPosition;
                                                        _dragCurrent = details
                                                            .localPosition;
                                                        _dragPageNumber = hit
                                                            ?.page.pageNumber;
                                                      });
                                                    },
                                                    onPanUpdate: (details) =>
                                                        setState(() =>
                                                            _dragCurrent = details
                                                                .localPosition),
                                                    onPanEnd: (_) =>
                                                        _finishDrag(),
                                                    // The live preview rectangle is painted HERE,
                                                    // inside pdfrx's own `viewerOverlayBuilder`
                                                    // coordinate space (which already accounts for
                                                    // the current zoom/pan/rotation transform,
                                                    // exactly the same space `details.localPosition`
                                                    // above is reported in) -- never as a sibling
                                                    // `Positioned` in an outer, untransformed
                                                    // `Stack`. Mirrors
                                                    // `PdfSourceViewer._buildViewerOverlay`'s own
                                                    // `CustomPaint` exactly.
                                                    child: SizedBox(
                                                      width: size.width,
                                                      height: size.height,
                                                      child: _dragStart !=
                                                                  null &&
                                                              _dragCurrent !=
                                                                  null
                                                          ? CustomPaint(
                                                              painter: _DragRectPainter(
                                                                  _dragStart!,
                                                                  _dragCurrent!),
                                                            )
                                                          : null,
                                                    ),
                                                  ),
                                                ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 320,
                    child: _AnnotationPanel(
                      annotatorController: _annotatorController,
                      annotations: humanAnnotations,
                      pageImageFor: _pageImageFor,
                      onJumpTo: (region) {
                        setState(() => _currentPage = region.page);
                        if (_pdfController.isReady)
                          _pdfController.goToPage(pageNumber: region.page);
                      },
                      onClassify: _classify,
                      onDelete: (region) => ref
                          .read(foundationRuntimeServiceProvider.notifier)
                          .deleteEvidenceRegion(region.id),
                      onNewRelationship: () =>
                          showRelationshipCandidateFormDialog(context),
                      classifiedCount: candidates.length,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerBar extends StatelessWidget {
  const _LayerBar({
    required this.ocrWordCount,
    required this.entityCount,
    required this.relationshipCount,
    required this.candidateCount,
    required this.visibleLayers,
    required this.onToggleLayer,
    required this.currentPage,
    required this.pageCount,
    required this.showPager,
    required this.onPrevPage,
    required this.onNextPage,
    required this.drawArmed,
    required this.onToggleDraw,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotate,
  });

  final int ocrWordCount;
  final int entityCount;
  final int relationshipCount;
  final int candidateCount;
  final Set<_OverlayLayer> visibleLayers;
  final ValueChanged<_OverlayLayer> onToggleLayer;
  final int currentPage;
  final int pageCount;
  final bool showPager;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final bool drawArmed;
  final VoidCallback onToggleDraw;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          if (showPager) ...[
            IconButton(
              tooltip: 'Previous Page',
              icon: const Icon(Icons.navigate_before, size: 18),
              onPressed: currentPage > 1 ? onPrevPage : null,
            ),
            Text('$currentPage / $pageCount',
                style: const TextStyle(
                    color: StudioColors.textSecondary, fontSize: 11.5)),
            IconButton(
              tooltip: 'Next Page',
              icon: const Icon(Icons.navigate_next, size: 18),
              onPressed: currentPage < pageCount ? onNextPage : null,
            ),
            const SizedBox(width: 8),
          ],
          // WP-INGEST-010 §6: "If a stage contains zero results, the UI
          // should explicitly show zero" — every chip below always
          // renders its real count, including 0, never hidden.
          _LayerChip(
            label: 'OCR',
            count: ocrWordCount,
            visible: visibleLayers.contains(_OverlayLayer.ocr),
            onTap: () => onToggleLayer(_OverlayLayer.ocr),
          ),
          _LayerChip(
            label: 'Entities',
            count: entityCount,
            visible: visibleLayers.contains(_OverlayLayer.entities),
            onTap: () => onToggleLayer(_OverlayLayer.entities),
          ),
          // Relationships carry no spatial coordinates of their own
          // (AP-INGEST-009 §L) — count only, no overlay toggle to draw.
          _LayerChip(
              label: 'Relationships',
              count: relationshipCount,
              visible: null,
              onTap: null),
          _LayerChip(
            label: 'Evidence/Candidates',
            count: candidateCount,
            visible: visibleLayers.contains(_OverlayLayer.evidence),
            onTap: () => onToggleLayer(_OverlayLayer.evidence),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Zoom In',
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: onZoomIn,
          ),
          IconButton(
            tooltip: 'Zoom Out',
            icon: const Icon(Icons.zoom_out, size: 18),
            onPressed: onZoomOut,
          ),
          IconButton(
            tooltip: 'Rotate',
            icon: const Icon(Icons.rotate_right, size: 18),
            onPressed: onRotate,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: drawArmed ? 'Stop Annotating' : 'Annotate a Region',
            icon: const Icon(Icons.crop_din, size: 18),
            color: drawArmed ? StudioColors.selection : null,
            onPressed: onToggleDraw,
          ),
        ],
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip(
      {required this.label,
      required this.count,
      required this.visible,
      required this.onTap});

  final String label;
  final int count;

  /// `null` means this layer has no overlay to toggle at all (e.g.
  /// Relationships) — rendered as a plain, non-interactive count.
  final bool? visible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = visible ?? false;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
              color: active ? StudioColors.selection : StudioColors.border),
          borderRadius: BorderRadius.circular(4),
          color: active ? StudioColors.selection.withValues(alpha: 0.12) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null)
              Icon(active ? Icons.visibility : Icons.visibility_off,
                  size: 13, color: StudioColors.textSecondary),
            if (onTap != null) const SizedBox(width: 4),
            Text('$label $count',
                style: const TextStyle(
                    fontSize: 11.5, color: StudioColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BoxOverlay extends StatelessWidget {
  const _BoxOverlay(
      {required this.box,
      required this.canvasSize,
      required this.color,
      this.tooltip});

  final OcrBoundingBox box;
  final Size canvasSize;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final rect = Positioned(
      left: box.x * canvasSize.width,
      top: box.y * canvasSize.height,
      width: box.width * canvasSize.width,
      height: box.height * canvasSize.height,
      child: IgnorePointer(
        child: Container(
            decoration:
                BoxDecoration(border: Border.all(color: color, width: 1))),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) return rect;
    return Positioned(
      left: box.x * canvasSize.width,
      top: box.y * canvasSize.height,
      width: box.width * canvasSize.width,
      height: box.height * canvasSize.height,
      child: Tooltip(
          message: tooltip!,
          child: Container(
              decoration: BoxDecoration(border: Border.all(color: color)))),
    );
  }
}

/// The live drag-to-annotate preview rectangle — identical to
/// `PdfSourceViewer`'s own `_DragRectPainter`, duplicated here rather than
/// shared because both are private to their own files; painted inside
/// `viewerOverlayBuilder`'s own coordinate space (see the call site's doc
/// comment for why that placement, not an outer `Positioned`, is required
/// for this to draw correctly once the page is zoomed or rotated).
class _DragRectPainter extends CustomPainter {
  _DragRectPainter(this.start, this.end);

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(
        rect, Paint()..color = StudioColors.selection.withValues(alpha: 0.18));
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

/// WP-INGEST-010 §10: renders an [EvidenceRegion] tinted by [EvidenceRegion.origin]
/// — the visible demonstration that machine observations and human
/// annotations are different things, never styled identically.
class _RegionOverlay extends StatelessWidget {
  const _RegionOverlay(
      {required this.region, required this.canvasSize, required this.onTap});

  final EvidenceRegion region;
  final Size canvasSize;
  final VoidCallback onTap;

  Color get _color => switch (region.origin) {
        EvidenceOrigin.machine => StudioColors.warning,
        EvidenceOrigin.human => StudioColors.success,
        null => StudioColors.textSecondary,
      };

  String get _badge => switch (region.origin) {
        EvidenceOrigin.machine => 'machine',
        EvidenceOrigin.human =>
          region.status == EvidenceAnnotationStatus.verified
              ? 'human · verified'
              : 'human',
        null => 'unrecorded',
      };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: region.x * canvasSize.width,
      top: region.y * canvasSize.height,
      width: region.width * canvasSize.width,
      height: region.height * canvasSize.height,
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: '${region.label} ($_badge)',
          child: Container(
            decoration:
                BoxDecoration(border: Border.all(color: _color, width: 2)),
          ),
        ),
      ),
    );
  }
}

/// WP-INGEST-010 §5/§9 revised — the non-modal side panel replacing the
/// old popup: every human annotation for this source, listed live as
/// drawn, each with a thumbnail, a type dropdown, and a delete action.
/// "New Relationship" opens the existing, unmodified
/// `RelationshipCandidateFormDialog` directly -- annotations become
/// connectable the moment they are classified (§ `_classify`'s own doc
/// comment).
class _AnnotationPanel extends StatelessWidget {
  const _AnnotationPanel({
    required this.annotatorController,
    required this.annotations,
    required this.pageImageFor,
    required this.onJumpTo,
    required this.onClassify,
    required this.onDelete,
    required this.onNewRelationship,
    required this.classifiedCount,
  });

  final TextEditingController annotatorController;
  final List<EvidenceRegion> annotations;
  final Future<ui.Image?> Function(int page) pageImageFor;
  final ValueChanged<EvidenceRegion> onJumpTo;
  final void Function(
          EvidenceRegion region, KnowledgeCandidateType type, String customName)
      onClassify;
  final ValueChanged<EvidenceRegion> onDelete;
  final VoidCallback onNewRelationship;
  final int classifiedCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: StudioColors.surfaceRaised),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Annotations',
                    style: TextStyle(
                        color: StudioColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: annotatorController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                      isDense: true, labelText: 'Annotator'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: classifiedCount >= 2 ? onNewRelationship : null,
                  icon: const Icon(Icons.timeline, size: 16),
                  label: const Text('New Relationship'),
                ),
                if (classifiedCount < 2)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Classify at least two annotations to connect them.',
                      style: TextStyle(
                          color: StudioColors.textDisabled, fontSize: 10.5),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: annotations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Draw a rectangle on the document to start annotating -- it will appear here immediately.',
                      style: TextStyle(
                          color: StudioColors.textDisabled,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: annotations.length,
                    itemBuilder: (context, index) => _AnnotationListItem(
                      region: annotations[index],
                      pageImageFor: pageImageFor,
                      onJumpTo: () => onJumpTo(annotations[index]),
                      onClassify: (type, name) =>
                          onClassify(annotations[index], type, name),
                      onDelete: () => onDelete(annotations[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationListItem extends StatefulWidget {
  const _AnnotationListItem({
    required this.region,
    required this.pageImageFor,
    required this.onJumpTo,
    required this.onClassify,
    required this.onDelete,
  });

  final EvidenceRegion region;
  final Future<ui.Image?> Function(int page) pageImageFor;
  final VoidCallback onJumpTo;
  final void Function(KnowledgeCandidateType type, String name) onClassify;
  final VoidCallback onDelete;

  @override
  State<_AnnotationListItem> createState() => _AnnotationListItemState();
}

class _AnnotationListItemState extends State<_AnnotationListItem> {
  static const double _thumbSize = 88;

  late final _nameController =
      TextEditingController(text: _customNameFrom(widget.region.label));

  static String _customNameFrom(String label) {
    for (final type in KnowledgeCandidateType.values) {
      if (label.startsWith('${type.label}: '))
        return label.substring(type.label.length + 2);
    }
    return '';
  }

  static KnowledgeCandidateType? _typeFrom(String label) {
    for (final type in KnowledgeCandidateType.values) {
      if (label == type.label || label.startsWith('${type.label}: '))
        return type;
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    final selectedType = _typeFrom(region.label);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: StudioColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onJumpTo,
              child: SizedBox(
                width: _thumbSize,
                height: _thumbSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      border: Border.all(color: StudioColors.border)),
                  // Centered rather than filling the frame: the actual
                  // rendered thumbnail below sizes itself to the region's
                  // OWN aspect ratio (never distorted/stretched to a
                  // square), so a wide or tall region shows fully and
                  // legibly, with the frame providing letterboxing rather
                  // than the image being squeezed to match it.
                  child: Center(
                    child: FutureBuilder<ui.Image?>(
                      future: widget.pageImageFor(region.page),
                      builder: (context, snapshot) {
                        final image = snapshot.data;
                        if (image == null) {
                          return const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          );
                        }
                        return _RegionThumbnail(
                          image: image,
                          region: region,
                          maxWidth: _thumbSize,
                          maxHeight: _thumbSize,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Page ${region.page}',
                            style: const TextStyle(
                                color: StudioColors.textSecondary,
                                fontSize: 10.5)),
                      ),
                      InkWell(
                        onTap: widget.onDelete,
                        child: const Icon(Icons.delete_outline,
                            size: 15, color: StudioColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  DropdownButton<KnowledgeCandidateType>(
                    isDense: true,
                    isExpanded: true,
                    value: selectedType,
                    hint: const Text('Unclassified',
                        style: TextStyle(fontSize: 11.5)),
                    style: const TextStyle(
                        fontSize: 11.5, color: StudioColors.textPrimary),
                    items: [
                      for (final type in KnowledgeCandidateType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (type) {
                      if (type == null) return;
                      widget.onClassify(type, _nameController.text);
                    },
                  ),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                        isDense: true, hintText: 'Name (optional)'),
                    onSubmitted: (name) {
                      if (selectedType != null)
                        widget.onClassify(selectedType, name);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crops [image] (a full rendered page) down to [region]'s own fractional
/// bounds, via widget composition (`OverflowBox` pinned top-left +
/// `Transform.translate` + `ClipRect`) -- no raw pixel manipulation/
/// re-encoding needed.
///
/// **Direct product feedback fix**: the previous version forced the
/// cropped region into a fixed square by scaling its width and height
/// independently ("size / widthFraction" and "size / heightFraction" as
/// two different factors) -- for any region that wasn't itself
/// square-shaped, that distorted/stretched the crop, making text
/// unreadable. This version computes a SINGLE uniform scale factor from
/// the region's real pixel dimensions (never distorting x differently
/// from y) and sizes the rendered thumbnail itself to the region's own
/// aspect ratio, clamped within [maxWidth]/[maxHeight] -- a wide region
/// renders wide, a tall one renders tall, and the full region is always
/// visible, exactly as drawn, just scaled down (or up) uniformly to fit.
class _RegionThumbnail extends StatelessWidget {
  const _RegionThumbnail(
      {required this.image,
      required this.region,
      required this.maxWidth,
      required this.maxHeight});

  final ui.Image image;
  final EvidenceRegion region;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final regionWidthFraction = region.width <= 0 ? 1.0 : region.width;
    final regionHeightFraction = region.height <= 0 ? 1.0 : region.height;
    final regionPixelWidth = regionWidthFraction * image.width;
    final regionPixelHeight = regionHeightFraction * image.height;
    if (regionPixelWidth <= 0 || regionPixelHeight <= 0) {
      return SizedBox(width: maxWidth, height: maxHeight);
    }

    // One shared scale for both axes -- never two independent ones.
    // Capped so a genuinely tiny region (a single letter) doesn't get
    // blown up far past what even the higher-resolution thumbnail source
    // can render crisply -- it shows smaller within the frame instead of
    // larger-but-blurrier.
    final scale = math.min(
        math.min(maxWidth / regionPixelWidth, maxHeight / regionPixelHeight),
        8.0);
    final boxWidth = regionPixelWidth * scale;
    final boxHeight = regionPixelHeight * scale;
    final displayedFullWidth = image.width * scale;
    final displayedFullHeight = image.height * scale;

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: displayedFullWidth,
          maxWidth: displayedFullWidth,
          minHeight: displayedFullHeight,
          maxHeight: displayedFullHeight,
          child: Transform.translate(
            offset: Offset(-region.x * displayedFullWidth,
                -region.y * displayedFullHeight),
            child: RawImage(
                image: image,
                width: displayedFullWidth,
                height: displayedFullHeight,
                fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}
