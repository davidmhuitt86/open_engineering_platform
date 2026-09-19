import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/evidence_annotation_status.dart';
import '../models/evidence_origin.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/ocr_bounding_box.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import '../widgets/knowledge_placeholder.dart';

/// WP-INGEST-010 / AP-INGEST-009 §N: the "UIF-produced data, hosted as a
/// Knowledge Studio surface" Extraction Inspector. Deliberately built the
/// same way `ocr_layer_viewer_dialog.dart` is (a dedicated dialog with its
/// own `pdfrx` `PdfViewer` instance, independent of the main `PdfSourceViewer`)
/// rather than a second document-rendering system — see this work
/// package's own explicit "Do not duplicate PDF rendering infrastructure."
///
/// **UIF orchestration, the OCR engine, `EngineeringEntityExtractionService`,
/// and `CandidateGenerationService` are never called from here.** This
/// dialog only ever READS already-produced `OcrPageResult`/
/// `EngineeringEntity`/`EvidenceRegion`/`KnowledgeCandidate`/
/// `RelationshipCandidate` state and WRITES new `EvidenceRegion`s via the
/// existing `FoundationRuntimeNotifier.createHumanAnnotation` — the exact
/// same public entry point `PdfSourceViewer`'s own drag-to-draw tool uses,
/// never a second write path.
Future<void> showExtractionInspectorDialog(BuildContext context, {required SourceMaterial source, int? initialPage}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ExtractionInspectorDialog(source: source, initialPage: initialPage),
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
  ConsumerState<_ExtractionInspectorDialog> createState() => _ExtractionInspectorDialogState();
}

class _ExtractionInspectorDialogState extends ConsumerState<_ExtractionInspectorDialog> {
  late int _currentPage = widget.initialPage ?? 1;
  final _pdfController = PdfViewerController();
  final Set<_OverlayLayer> _visibleLayers = {_OverlayLayer.ocr, _OverlayLayer.entities, _OverlayLayer.evidence};

  bool _drawArmed = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _dragPageNumber;

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

  /// WP-INGEST-010 §7/§10: drag-to-draw a brand-new rectangle where no
  /// machine observation exists — `observationRef` starts `null` (the
  /// TRX300 case). Reuses the identical hit-test-based coordinate
  /// computation `PdfSourceViewer._finishDrag` already established
  /// (PDF-point space, bottom-left origin, inverted once here to the
  /// same top-left fractional convention every other overlay already
  /// uses) rather than inventing a second one.
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

    final startHit = _pdfController.getPdfPageHitTestResult(start, useDocumentLayoutCoordinates: false);
    final endHit = _pdfController.getPdfPageHitTestResult(current, useDocumentLayoutCoordinates: false);
    if (startHit == null || endHit == null) return;
    if (startHit.page.pageNumber != page || endHit.page.pageNumber != page) return;

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

    _openClassifyDialog(
      page: page,
      x: left.clamp(0.0, 1.0),
      y: top.clamp(0.0, 1.0),
      width: width.clamp(0.0, 1.0 - left),
      height: height.clamp(0.0, 1.0 - top),
      observationRef: null,
      suggestedLabel: null,
    );
  }

  /// WP-INGEST-010 §10: annotating an EXISTING region — if it is
  /// machine-generated, the new human annotation's `observationRef`
  /// points back at it, demonstrating the two are related but distinct
  /// records (a new `EvidenceRegion`, not an edit of the machine one —
  /// "must not modify... machine observation").
  void _annotateExisting(EvidenceRegion region) {
    _openClassifyDialog(
      page: region.page,
      x: region.x,
      y: region.y,
      width: region.width,
      height: region.height,
      observationRef: region.origin == EvidenceOrigin.machine ? region.id : region.observationRef,
      suggestedLabel: region.label,
    );
  }

  Future<void> _openClassifyDialog({
    required int page,
    required double x,
    required double y,
    required double width,
    required double height,
    required String? observationRef,
    required String? suggestedLabel,
  }) async {
    final result = await showDialog<_ClassificationChoice>(
      context: context,
      builder: (context) => _ClassifyRegionDialog(initialLabel: suggestedLabel, observationRef: observationRef),
    );
    if (result == null || !mounted) return;
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).createHumanAnnotation(
            sourceId: widget.source.id,
            page: page,
            x: x,
            y: y,
            width: width,
            height: height,
            annotatorId: result.annotatorId,
            label: result.label,
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
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final screen = MediaQuery.of(context).size;

    final ocrResults = foundation.ocrResultsForSource(widget.source.id);
    final entities = foundation.engineeringEntitiesForSource(widget.source.id);
    final candidates = foundation.knowledgeCandidatesForSource(widget.source.id);
    final relationships = foundation.relationshipCandidatesForSource(widget.source.id);
    final regionsForPage = foundation.evidenceRegionsForPage(widget.source.id, _currentPage);
    final ocrForPage = ocrResults.where((r) => r.page == _currentPage);
    final ocrWordCount = ocrResults.fold<int>(0, (sum, r) => sum + r.words.length);
    final pageCount = ocrResults.isEmpty ? 1 : ocrResults.map((r) => r.page).reduce(math.max);

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
                      'Extraction Inspector — ${widget.source.originalFileName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
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
              onPrevPage: () => setState(() => _currentPage = math.max(1, _currentPage - 1)),
              onNextPage: () => setState(() => _currentPage = math.min(pageCount, _currentPage + 1)),
              drawArmed: _drawArmed,
              onToggleDraw: _toggleDraw,
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.source.type != SourceMaterialType.pdf
                  ? const KnowledgePlaceholder(
                      message: 'The Extraction Inspector currently supports PDF Source Material only.')
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            PdfViewer.file(
                              widget.source.localPath,
                              key: ValueKey('extraction-inspector-pdf-${widget.source.id}'),
                              controller: _pdfController,
                              initialPageNumber: widget.initialPage ?? 1,
                              params: PdfViewerParams(
                                pageOverlaysBuilder: (context, pageRectInViewer, pdfPage) {
                                  if (pdfPage.pageNumber != _currentPage) return const [];
                                  return [
                                    if (_visibleLayers.contains(_OverlayLayer.ocr))
                                      for (final result in ocrForPage)
                                        for (final word in result.words)
                                          _BoxOverlay(
                                            box: word.boundingBox,
                                            canvasSize: pageRectInViewer.size,
                                            color: StudioColors.info,
                                            tooltip: word.text,
                                          ),
                                    if (_visibleLayers.contains(_OverlayLayer.entities))
                                      for (final entity in entities.where((e) => e.page == _currentPage))
                                        _BoxOverlay(
                                          box: entity.boundingBox,
                                          canvasSize: pageRectInViewer.size,
                                          color: StudioColors.warning,
                                          tooltip: '${entity.type.label}: ${entity.normalizedValue}',
                                        ),
                                    if (_visibleLayers.contains(_OverlayLayer.evidence))
                                      for (final region in regionsForPage)
                                        _RegionOverlay(
                                          region: region,
                                          canvasSize: pageRectInViewer.size,
                                          onTap: () => _annotateExisting(region),
                                        ),
                                  ];
                                },
                                viewerOverlayBuilder: !_drawArmed
                                    ? null
                                    : (context, size, handleLinkTap) => [
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (details) {
                                              final hit = _pdfController.getPdfPageHitTestResult(
                                                  details.localPosition,
                                                  useDocumentLayoutCoordinates: false);
                                              setState(() {
                                                _dragStart = details.localPosition;
                                                _dragCurrent = details.localPosition;
                                                _dragPageNumber = hit?.page.pageNumber;
                                              });
                                            },
                                            onPanUpdate: (details) =>
                                                setState(() => _dragCurrent = details.localPosition),
                                            onPanEnd: (_) => _finishDrag(),
                                            child: SizedBox(width: size.width, height: size.height),
                                          ),
                                        ],
                              ),
                            ),
                            if (_drawArmed && _dragStart != null && _dragCurrent != null)
                              Positioned(
                                left: math.min(_dragStart!.dx, _dragCurrent!.dx),
                                top: math.min(_dragStart!.dy, _dragCurrent!.dy),
                                width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
                                height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: StudioColors.selection, width: 2),
                                      color: StudioColors.selection.withValues(alpha: 0.15),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
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
            Text('$currentPage / $pageCount', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
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
          _LayerChip(label: 'Relationships', count: relationshipCount, visible: null, onTap: null),
          _LayerChip(
            label: 'Evidence/Candidates',
            count: candidateCount,
            visible: visibleLayers.contains(_OverlayLayer.evidence),
            onTap: () => onToggleLayer(_OverlayLayer.evidence),
          ),
          const SizedBox(width: 12),
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
  const _LayerChip({required this.label, required this.count, required this.visible, required this.onTap});

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
          border: Border.all(color: active ? StudioColors.selection : StudioColors.border),
          borderRadius: BorderRadius.circular(4),
          color: active ? StudioColors.selection.withValues(alpha: 0.12) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null)
              Icon(active ? Icons.visibility : Icons.visibility_off, size: 13, color: StudioColors.textSecondary),
            if (onTap != null) const SizedBox(width: 4),
            Text('$label $count', style: const TextStyle(fontSize: 11.5, color: StudioColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BoxOverlay extends StatelessWidget {
  const _BoxOverlay({required this.box, required this.canvasSize, required this.color, this.tooltip});

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
        child: Container(decoration: BoxDecoration(border: Border.all(color: color, width: 1))),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) return rect;
    return Positioned(
      left: box.x * canvasSize.width,
      top: box.y * canvasSize.height,
      width: box.width * canvasSize.width,
      height: box.height * canvasSize.height,
      child: Tooltip(message: tooltip!, child: Container(decoration: BoxDecoration(border: Border.all(color: color)))),
    );
  }
}

/// WP-INGEST-010 §10: renders an [EvidenceRegion] tinted by [EvidenceRegion.origin]
/// — the visible demonstration that machine observations and human
/// annotations are different things, never styled identically.
class _RegionOverlay extends StatelessWidget {
  const _RegionOverlay({required this.region, required this.canvasSize, required this.onTap});

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
        EvidenceOrigin.human => region.status == EvidenceAnnotationStatus.verified ? 'human · verified' : 'human',
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
            decoration: BoxDecoration(border: Border.all(color: _color, width: 2)),
          ),
        ),
      ),
    );
  }
}

class _ClassificationChoice {
  const _ClassificationChoice({required this.label, required this.annotatorId});
  final String label;
  final String annotatorId;
}

/// WP-INGEST-010 §8: "Classify this region." Deliberately limited — a
/// free-text name plus a dropdown of the ALREADY-EXISTING
/// `KnowledgeCandidateType` values (Component/Procedure/Specification/
/// Tool/Material/Fluid/Warning/Measurement/Image/Document), reusing
/// `EvidenceRegion.label`'s existing free-text field for the result
/// exactly the way `CandidateGenerationService` already does for
/// machine-generated regions (`label: entity.type.label`) — no new
/// "classification" field was added to the model, and no new ontology was
/// created. **Known limitation, disclosed rather than worked around**:
/// none of `Wire`/`Connector`/`Pin`/`Splice` (this work package's own
/// example vocabulary) has a dedicated existing type; the closest
/// existing reusable value is `Component`. See this work package's final
/// report § M.
class _ClassifyRegionDialog extends StatefulWidget {
  const _ClassifyRegionDialog({required this.initialLabel, required this.observationRef});

  final String? initialLabel;
  final String? observationRef;

  @override
  State<_ClassifyRegionDialog> createState() => _ClassifyRegionDialogState();
}

class _ClassifyRegionDialogState extends State<_ClassifyRegionDialog> {
  static const _typeLabels = [
    'Component',
    'Procedure',
    'Specification',
    'Tool',
    'Material',
    'Fluid',
    'Warning',
    'Measurement',
  ];

  late final _nameController = TextEditingController(text: widget.initialLabel ?? '');
  final _annotatorController = TextEditingController();
  String _selectedType = _typeLabels.first;

  @override
  void dispose() {
    _nameController.dispose();
    _annotatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Classify This Region'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.observationRef != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'This annotation is linked to an existing machine observation.',
                  style: TextStyle(fontSize: 11.5, color: StudioColors.textSecondary),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final type in _typeLabels) DropdownMenuItem(value: type, child: Text(type))],
              onChanged: (value) => setState(() => _selectedType = value ?? _selectedType),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name (e.g. "Ignition Switch")'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _annotatorController,
              decoration: const InputDecoration(labelText: 'Annotator'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final resolvedLabel = name.isEmpty ? _selectedType : '$_selectedType: $name';
            Navigator.of(context).pop(
              _ClassificationChoice(label: resolvedLabel, annotatorId: _annotatorController.text.trim()),
            );
          },
          child: const Text('Save Annotation'),
        ),
      ],
    );
  }
}
