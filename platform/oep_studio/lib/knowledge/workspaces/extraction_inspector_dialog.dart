import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../models/document_orientation.dart';
import '../models/evidence_annotation.dart';
import '../models/evidence_annotation_status.dart';
import '../models/evidence_geometry.dart';
import '../models/evidence_origin.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/ocr_bounding_box.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import '../review/relationship_candidate_form_dialog.dart';
import '../services/knowledge_session_service.dart';
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

/// WP-INGEST-015: what a new annotation gesture creates.
enum _DrawMode { area, path }

/// The [KnowledgeCandidateType] a human annotation's [EvidenceRegion.label]
/// represents (`"<Type>"` or `"<Type>: <name>"`), or `null` for the
/// unclassified state (`"Unclassified"` or any other label that is not a
/// selected type). The label is the single source of truth for a
/// classification -- no separate field exists (WP-INGEST-010).
KnowledgeCandidateType? classifiedTypeFromLabel(String label) {
  for (final type in KnowledgeCandidateType.values) {
    if (label == type.label || label.startsWith('${type.label}: ')) {
      return type;
    }
  }
  return null;
}

/// WP-INGEST-012: the Inspector's per-source summary, as one pure
/// calculation over existing state (no new state model) so the displayed
/// counts and the "New Relationship" eligibility are testable without
/// rendering the private dialog.
class ExtractionInspectorSummary {
  const ExtractionInspectorSummary({
    required this.evidenceCount,
    required this.candidateCount,
    required this.classifiedHumanAnnotationCount,
  });

  factory ExtractionInspectorSummary.from(
      FoundationServiceState state, String sourceId) {
    final regions =
        state.evidenceRegions.where((r) => r.sourceId == sourceId).toList();
    return ExtractionInspectorSummary(
      evidenceCount: regions.length,
      candidateCount: state.knowledgeCandidatesForSource(sourceId).length,
      classifiedHumanAnnotationCount: regions
          .where((r) =>
              r.origin == EvidenceOrigin.human &&
              classifiedTypeFromLabel(r.label) != null)
          .length,
    );
  }

  /// Every [EvidenceRegion] for the source, of any origin.
  final int evidenceCount;

  /// Every `KnowledgeCandidate` reachable from the source through an
  /// Evidence Link (`FoundationServiceState.knowledgeCandidatesForSource`).
  /// Deliberately independent of [evidenceCount].
  final int candidateCount;

  /// Human-origin regions of this source whose label is a selected type.
  final int classifiedHumanAnnotationCount;

  /// "New Relationship" is enabled only when at least two HUMAN
  /// annotations of this source are classified -- never from
  /// [candidateCount], which also counts machine-generated candidates
  /// and (via any shared evidence) is not a statement about annotations.
  bool get canCreateRelationship => classifiedHumanAnnotationCount >= 2;
}

/// Classifies [region] (a human annotation): renames it to the selected
/// type and creates -- first time -- or updates -- every time after -- the
/// ONE `KnowledgeCandidate` linked to it, using the existing
/// `addKnowledgeCandidate`/`linkEvidence`/`editKnowledgeCandidate`
/// methods. A candidate-level human interpretation only: this never
/// creates an Engineering Object, never touches the Repository, and never
/// alters the region beyond its label. [linkedCandidateIds] must be the
/// candidates currently linked to [region] (from
/// `FoundationServiceState.candidatesLinkedToEvidenceRegion`).
void applyRegionClassification({
  required FoundationRuntimeNotifier notifier,
  required EvidenceRegion region,
  required List<String> linkedCandidateIds,
  required KnowledgeCandidateType type,
  required String customName,
  required String annotatorId,
}) {
  final trimmed = customName.trim();
  final shortId = region.id.length <= 6
      ? region.id
      : region.id.substring(region.id.length - 6);
  final name = trimmed.isEmpty ? '${type.label} $shortId' : trimmed;
  final label = trimmed.isEmpty ? type.label : '${type.label}: $trimmed';

  notifier.renameEvidenceRegion(region.id, label);
  notifier.setObservationClassification(region.id, type: type.name, name: name);

  if (linkedCandidateIds.isEmpty) {
    final candidate = notifier.addKnowledgeCandidate(
        type: type, name: name, author: annotatorId);
    notifier.linkEvidence(candidateId: candidate.id, regionId: region.id);
  } else {
    notifier.editKnowledgeCandidate(linkedCandidateIds.first,
        type: type, name: name);
  }
}

/// One editable property row inside an [_AnnotationDraft]; [uid] keeps the
/// row's text controllers stable while its content is edited.
class _DraftProperty {
  _DraftProperty(this.uid, this.property);
  final int uid;
  AnnotationProperty property;
}

/// Unsaved edits for one annotation. Edits mutate only the draft; the
/// explicit Save applies it through the existing runtime notifier.
class _AnnotationDraft {
  _AnnotationDraft({
    required this.name,
    required this.type,
    required this.notes,
    required this.properties,
    this.strokeWidth,
  });

  factory _AnnotationDraft.fromRegion(EvidenceRegion region) {
    final type = classifiedTypeFromLabel(region.label);
    return _AnnotationDraft(
      name: type != null
          ? _customNameFromLabel(region.label)
          : (region.annotation?.name ?? ''),
      type: type,
      notes: region.notes,
      properties: [
        for (final p in region.annotation?.properties ?? const <AnnotationProperty>[])
          _DraftProperty(_nextUid++, p),
      ],
      strokeWidth: region.geometry is PolylineGeometry
          ? (region.geometry as PolylineGeometry).strokeWidth
          : null,
    );
  }

  static int _nextUid = 0;

  String name;
  KnowledgeCandidateType? type;
  String notes;
  final List<_DraftProperty> properties;

  /// Visual path width in PDF points; null for area annotations. NaN while the
  /// field holds text that is not a number (rejected on Save).
  double? strokeWidth;

  static String _customNameFromLabel(String label) {
    for (final type in KnowledgeCandidateType.values) {
      if (label.startsWith('${type.label}: ')) {
        return label.substring(type.label.length + 2);
      }
    }
    return '';
  }

  static List<AnnotationProperty> _normalized(Iterable<AnnotationProperty> list) => [
        for (final p in list) p.copyWith(key: AnnotationProperty.normalizeKey(p.key)),
      ];

  bool differsFrom(EvidenceRegion region) {
    final baseline = _AnnotationDraft.fromRegion(region);
    if (name.trim() != baseline.name.trim()) return true;
    if (type != baseline.type) return true;
    if (notes.trim() != baseline.notes.trim()) return true;
    if (strokeWidth != null && strokeWidth != baseline.strokeWidth) return true;
    final mine = _normalized(properties.map((d) => d.property));
    final theirs = _normalized(baseline.properties.map((d) => d.property));
    if (mine.length != theirs.length) return true;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return true;
    }
    return false;
  }
}

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
  _DrawMode _drawMode = _DrawMode.area;
  // In-progress path (oriented normalized points).
  final PathDraft _path = PathDraft();
  String? _selectedRegionId;
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

  /// Persistent Extraction Orientation (WP-INGEST-014): the coordinate frame
  /// of every stored OCR box, entity and region. Distinct from
  /// [_rotationQuarterTurns], which is a temporary viewer-only rotation.
  DocumentOrientation get _orientation => widget.source.extractionOrientation;

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
    _hover.dispose();
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
      final pdfPage = document.pages[page - 1]
          .rotatedBy(PdfPageRotation.values[_orientation.quarterTurns]);
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

  final Map<String, _AnnotationDraft> _drafts = {};

  _AnnotationDraft _draftFor(EvidenceRegion region) =>
      _drafts.putIfAbsent(region.id, () => _AnnotationDraft.fromRegion(region));

  List<EvidenceRegion> _humanRegions() => ref
      .read(foundationRuntimeServiceProvider)
      .evidenceRegions
      .where((r) => r.sourceId == widget.source.id && r.origin == EvidenceOrigin.human)
      .toList();

  bool _hasUnsavedChanges() {
    for (final region in _humanRegions()) {
      final draft = _drafts[region.id];
      if (draft != null && draft.differsFrom(region)) return true;
    }
    return false;
  }

  String? _saveMessage;
  bool _saveFailed = false;

  /// Applies every dirty draft through the existing notifier methods (which
  /// persist via the session autosave path). Each annotation is validated
  /// BEFORE anything is applied and saved independently: one that cannot be
  /// saved (e.g. a duplicate candidate name) keeps its draft, stays dirty and
  /// is reported, while the rest are still saved. Returns true when nothing
  /// is left unsaved.
  bool _saveChanges() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final failures = <String>[];
    var saved = 0;
    for (final region in _humanRegions()) {
      final draft = _drafts[region.id];
      if (draft == null || !draft.differsFrom(region)) continue;
      try {
        final pendingWidth = draft.strokeWidth;
        if (pendingWidth != null && region.geometry is PolylineGeometry) {
          // Validate first (throws) so an invalid width applies nothing.
          (region.geometry as PolylineGeometry).withStrokeWidth(pendingWidth);
        }
        final type = draft.type;
        if (type != null) {
          final foundation = ref.read(foundationRuntimeServiceProvider);
          final linked = foundation.candidatesLinkedToEvidenceRegion(region.id);
          final trimmed = draft.name.trim();
          final shortId = region.id.length <= 6 ? region.id : region.id.substring(region.id.length - 6);
          KnowledgeSessionService.validateCandidateName(
            trimmed.isEmpty ? '${type.label} $shortId' : trimmed,
            foundation.candidates,
            excludingId: linked.isEmpty ? null : linked.first.id,
          );
          _classify(region, type, draft.name);
        } else if (draft.name.trim().isNotEmpty) {
          notifier.setObservationName(region.id, draft.name);
        }
        if (draft.notes.trim() != region.notes.trim()) {
          notifier.setEvidenceRegionNotes(region.id, draft.notes);
        }
        final width = draft.strokeWidth;
        if (width != null &&
            region.geometry is PolylineGeometry &&
            width != (region.geometry as PolylineGeometry).strokeWidth) {
          notifier.setEvidenceRegionStrokeWidth(region.id, width);
        }
        notifier.setAnnotationProperties(
            region.id, [for (final d in draft.properties) d.property]);
        _drafts.remove(region.id);
        saved++;
      } on KnowledgeValidationException catch (error) {
        failures.add(error.message);
      }
    }
    setState(() {
      _saveFailed = failures.isNotEmpty;
      _saveMessage = failures.isNotEmpty
          ? 'Not saved: ${failures.first}'
          : (saved > 0 ? 'Changes saved' : null);
    });
    return failures.isEmpty;
  }

  Future<void> _confirmClose() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Save changes?'),
        content: const Text('You have unsaved annotation changes.'),
        actions: [
          TextButton(
              key: const ValueKey('unsaved-cancel'),
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel')),
          TextButton(
              key: const ValueKey('unsaved-discard'),
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text('Discard')),
          FilledButton(
              key: const ValueKey('unsaved-save'),
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      if (!_saveChanges()) return;
    } else if (choice == 'discard') {
      _drafts.clear();
    } else {
      return;
    }
    Navigator.of(context).pop();
  }

  void _rotate() {
    setState(() => _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4);
  }

  void _toggleLayer(_OverlayLayer layer) {
    setState(() {
      if (!_visibleLayers.remove(layer)) _visibleLayers.add(layer);
    });
  }

  void _setDrawMode(_DrawMode mode) {
    setState(() {
      _drawMode = mode;
      _path.cancel();
    });
  }

  /// Adds one vertex of the in-progress path: the tapped viewer point is
  /// hit-tested to a page position (PDF points, bottom-left origin), converted
  /// to the same top-left normalized fractions rectangles use, then into the
  /// source's oriented space.
  void _addPathPoint(Offset local) {
    final hit = _pdfController.getPdfPageHitTestResult(local,
        useDocumentLayoutCoordinates: false);
    if (hit == null) return;
    final px = (hit.offset.x / hit.page.width).clamp(0.0, 1.0);
    final py = (1 - hit.offset.y / hit.page.height).clamp(0.0, 1.0);
    final o = _orientation.pageToOriented(px, py);
    setState(() => _path.add(hit.page.pageNumber,
        GeometryPoint(o.x.clamp(0.0, 1.0), o.y.clamp(0.0, 1.0))));
  }

  void _cancelPath() => setState(_path.cancel);

  void _undoPathPoint() => setState(_path.undoLast);

  /// Cursor position over the viewer while tracing a path, for the magnifier.
  /// A notifier (not setState) so mouse moves repaint only the loupe.
  final ValueNotifier<_LoupeTarget?> _hover = ValueNotifier<_LoupeTarget?>(null);

  /// Converts the cursor to a page position (and the current document-points-
  /// per-pixel scale) for the loupe; also makes sure the page render it crops
  /// is loading.
  void _onPathHover(Offset? pos) {
    if (pos == null) {
      _hover.value = null;
      return;
    }
    final a = _pdfController.getPdfPageHitTestResult(pos,
        useDocumentLayoutCoordinates: false);
    if (a == null) {
      _hover.value = null;
      return;
    }
    _pageImageFor(a.page.pageNumber);
    // Scale: hit-test a second point nearby (either side, to stay on the page).
    double? ptPerPx;
    for (final delta in const [Offset(40, 0), Offset(-40, 0), Offset(0, 40), Offset(0, -40)]) {
      final b = _pdfController.getPdfPageHitTestResult(pos + delta,
          useDocumentLayoutCoordinates: false);
      if (b == null || b.page.pageNumber != a.page.pageNumber) continue;
      final dx = b.offset.x - a.offset.x;
      final dy = b.offset.y - a.offset.y;
      ptPerPx = math.sqrt(dx * dx + dy * dy) / delta.distance;
      break;
    }
    if (ptPerPx == null || ptPerPx <= 0) return;
    _hover.value = _LoupeTarget(
      screen: pos,
      page: a.page.pageNumber,
      pageX: (a.offset.x / a.page.width).clamp(0.0, 1.0),
      pageY: (1 - a.offset.y / a.page.height).clamp(0.0, 1.0),
      pageWidthPt: a.page.width,
      pageHeightPt: a.page.height,
      ptPerScreenPx: ptPerPx,
    );
  }

  void _finishPath() {
    final page = _path.page;
    if (page == null || !_path.canFinish) return;
    try {
      final region = ref
          .read(foundationRuntimeServiceProvider.notifier)
          .createHumanPathAnnotation(
            sourceId: widget.source.id,
            page: page,
            points: _path.points,
            annotatorId: _annotatorController.text.trim(),
            label: 'Unclassified',
          );
      setState(() => _selectedRegionId = region.id);
    } on KnowledgeValidationException catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text("Couldn't Create Path"),
          content: Text(error.message),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'))
          ],
        ),
      );
    }
    _cancelPath();
  }

  void _toggleDraw() {
    setState(() {
      _drawArmed = !_drawArmed;
      if (!_drawArmed) _path.cancel();
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

    final pageLeft = x1 < x2 ? x1 : x2;
    final pageTop = y1 < y2 ? y1 : y2;
    final pageRect = _orientation.rectPageToOriented(
        pageLeft.clamp(0.0, 1.0),
        pageTop.clamp(0.0, 1.0),
        (x2 - x1).abs(),
        (y2 - y1).abs());
    final left = pageRect.x;
    final top = pageRect.y;
    final width = pageRect.width;
    final height = pageRect.height;
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

  /// Sets [region]'s classification -- see [applyRegionClassification].
  void _classify(
      EvidenceRegion region, KnowledgeCandidateType type, String customName) {
    applyRegionClassification(
      notifier: ref.read(foundationRuntimeServiceProvider.notifier),
      region: region,
      linkedCandidateIds: ref
          .read(foundationRuntimeServiceProvider)
          .candidatesLinkedToEvidenceRegion(region.id)
          .map((c) => c.id)
          .toList(),
      type: type,
      customName: customName,
      annotatorId: _annotatorController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final screen = MediaQuery.of(context).size;

    final ocrResults = foundation.ocrResultsForSource(widget.source.id);
    final entities = foundation.engineeringEntitiesForSource(widget.source.id);
    final summary =
        ExtractionInspectorSummary.from(foundation, widget.source.id);
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

    final dirty = _hasUnsavedChanges();
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Dialog(
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
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _LayerBar(
              ocrWordCount: ocrWordCount,
              entityCount: entities.length,
              relationshipCount: relationships.length,
              evidenceCount: summary.evidenceCount,
              candidateCount: summary.candidateCount,
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
              drawMode: _drawMode,
              onDrawMode: _setDrawMode,
              pathPointCount: _path.length,
              onFinishPath: _finishPath,
              onCancelPath: _cancelPath,
              onUndoPathPoint: _undoPathPoint,
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
                                    quarterTurns:
                                        (_orientation.quarterTurns +
                                                _rotationQuarterTurns) %
                                            4,
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
                                                    orientation: _orientation,
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
                                                  orientation: _orientation,
                                                  tooltip:
                                                      '${entity.type.label}: ${entity.normalizedValue}',
                                                ),
                                            if (_visibleLayers.contains(
                                                _OverlayLayer.evidence))
                                              for (final region
                                                  in regionsForPage)
                                                if (region.geometry
                                                    is PolylineGeometry)
                                                  _PathOverlay(
                                                    points: (region.geometry
                                                            as PolylineGeometry)
                                                        .points,
                                                    strokeWidthPt: _drafts[region.id]
                                                                ?.strokeWidth
                                                                .validOrNull ??
                                                        (region.geometry
                                                                as PolylineGeometry)
                                                            .strokeWidth,
                                                    pageWidthPt: pdfPage.width,
                                                    canvasSize:
                                                        pageRectInViewer.size,
                                                    orientation: _orientation,
                                                    color: StudioColors.success,
                                                    selected: region.id ==
                                                        _selectedRegionId,
                                                    tooltip: region.label,
                                                    onTap: () => setState(() =>
                                                        _selectedRegionId =
                                                            region.id),
                                                  )
                                                else
                                                  _RegionOverlay(
                                                    region: region,
                                                    orientation: _orientation,
                                                    canvasSize:
                                                        pageRectInViewer.size,
                                                    onTap: () =>
                                                        _annotateExisting(region),
                                                  ),
                                            if (_path.page == pdfPage.pageNumber &&
                                                !_path.isEmpty)
                                              _PathOverlay(
                                                key: const ValueKey('path-in-progress'),
                                                points: _path.points,
                                                strokeWidthPt:
                                                    PolylineGeometry.defaultStrokeWidth,
                                                pageWidthPt: pdfPage.width,
                                                canvasSize: pageRectInViewer.size,
                                                orientation: _orientation,
                                                color: StudioColors.selection,
                                                selected: true,
                                                showVertices: true,
                                              ),
                                          ];
                                        },
                                        viewerOverlayBuilder: !_drawArmed
                                            ? null
                                            : _drawMode == _DrawMode.path
                                            ? (context, size, handleLinkTap) => [
                                                _PathCaptureLayer(
                                                  size: size,
                                                  hover: _hover,
                                                  onHover: _onPathHover,
                                                  onPoint: _addPathPoint,
                                                  imageFor: (page) =>
                                                      _pageImageCache[page],
                                                  orientation: _orientation,
                                                  pathPoints: _path.points,
                                                ),
                                              ]
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
                      draftFor: _draftFor,
                      onDraftChanged: () => setState(() => _saveMessage = null),
                      saveMessage: _saveMessage,
                      saveFailed: _saveFailed,
                      hasUnsavedChanges: dirty,
                      onSave: _saveChanges,
                      selectedRegionId: _selectedRegionId,
                      onSelect: (region) =>
                          setState(() => _selectedRegionId = region.id),
                      pageImageFor: _pageImageFor,
                      onJumpTo: (region) {
                        setState(() => _currentPage = region.page);
                        if (_pdfController.isReady)
                          _pdfController.goToPage(pageNumber: region.page);
                      },
                      onDelete: (region) {
                        _drafts.remove(region.id);
                        ref
                            .read(foundationRuntimeServiceProvider.notifier)
                            .deleteEvidenceRegion(region.id);
                      },
                      onNewRelationship: () =>
                          showRelationshipCandidateFormDialog(context),
                      canCreateRelationship: summary.canCreateRelationship,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _LayerBar extends StatelessWidget {
  const _LayerBar({
    required this.ocrWordCount,
    required this.entityCount,
    required this.relationshipCount,
    required this.evidenceCount,
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
    required this.drawMode,
    required this.onDrawMode,
    required this.pathPointCount,
    required this.onFinishPath,
    required this.onCancelPath,
    required this.onUndoPathPoint,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotate,
  });

  final int ocrWordCount;
  final int entityCount;
  final int relationshipCount;
  final int evidenceCount;
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
  final _DrawMode drawMode;
  final ValueChanged<_DrawMode> onDrawMode;
  final int pathPointCount;
  final VoidCallback onFinishPath;
  final VoidCallback onCancelPath;
  final VoidCallback onUndoPathPoint;
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
          // WP-INGEST-012: two independent quantities, never conflated.
          // Evidence is the spatial overlay layer (toggleable); Candidates
          // has no overlay of its own, so it is a plain count.
          _LayerChip(
            label: 'Evidence',
            count: evidenceCount,
            visible: visibleLayers.contains(_OverlayLayer.evidence),
            onTap: () => onToggleLayer(_OverlayLayer.evidence),
          ),
          _LayerChip(
              label: 'Candidates',
              count: candidateCount,
              visible: null,
              onTap: null),
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
          SegmentedButton<_DrawMode>(
            key: const ValueKey('annotation-mode-selector'),
            showSelectedIcon: false,
            style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white
                        : StudioColors.textPrimary),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? StudioColors.selection.withValues(alpha: 0.45)
                        : null)),
            segments: const [
              ButtonSegment(value: _DrawMode.area, label: Text('Area')),
              ButtonSegment(value: _DrawMode.path, label: Text('Path')),
            ],
            selected: {drawMode},
            onSelectionChanged: (selection) => onDrawMode(selection.first),
          ),
          if (drawArmed && drawMode == _DrawMode.path) ...[
            FilledButton(
              key: const ValueKey('finish-path'),
              onPressed: pathPointCount >= 2 ? onFinishPath : null,
              child: Text('Finish Path ($pathPointCount pts)'),
            ),
            TextButton(
              key: const ValueKey('undo-path-point'),
              onPressed: pathPointCount > 0 ? onUndoPathPoint : null,
              child: const Text('Undo Last'),
            ),
            TextButton(
              key: const ValueKey('cancel-path'),
              onPressed: pathPointCount > 0 ? onCancelPath : null,
              child: const Text('Cancel Path'),
            ),
          ],
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
  _BoxOverlay(
      {required OcrBoundingBox box,
      required this.canvasSize,
      required this.color,
      DocumentOrientation orientation = DocumentOrientation.deg0,
      this.tooltip})
      : box = _toPageSpace(box, orientation);

  /// Stored boxes are in oriented space; the viewer draws in page space and
  /// applies the orientation as its base rotation.
  static OcrBoundingBox _toPageSpace(
      OcrBoundingBox box, DocumentOrientation orientation) {
    if (orientation == DocumentOrientation.deg0) return box;
    final r = orientation.rectOrientedToPage(
        box.x, box.y, box.width, box.height);
    return OcrBoundingBox(x: r.x, y: r.y, width: r.width, height: r.height);
  }

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

/// Where the cursor is over the page, for the path-tracing loupe.
class _LoupeTarget {
  const _LoupeTarget({
    required this.screen,
    required this.page,
    required this.pageX,
    required this.pageY,
    required this.pageWidthPt,
    required this.pageHeightPt,
    required this.ptPerScreenPx,
  });

  /// Cursor in the viewer overlay's coordinates.
  final Offset screen;
  final int page;

  /// Cursor as normalized page fractions (top-left origin, unoriented page).
  final double pageX;
  final double pageY;
  final double pageWidthPt;
  final double pageHeightPt;

  /// Document points per screen pixel at the current zoom.
  final double ptPerScreenPx;
}

/// Path-tracing input layer: a click places a vertex, and a magnifier loupe
/// follows the cursor so the exact placement point can be seen (the viewer
/// cannot be panned or zoomed by mouse while tracing). The loupe crops the
/// page's cached high-resolution render, so it shows real page detail and does
/// not depend on any compositor backdrop effect.
class _PathCaptureLayer extends StatelessWidget {
  const _PathCaptureLayer({
    required this.size,
    required this.hover,
    required this.onHover,
    required this.onPoint,
    required this.imageFor,
    required this.orientation,
    required this.pathPoints,
  });

  final Size size;
  final ValueNotifier<_LoupeTarget?> hover;
  final ValueChanged<Offset?> onHover;
  final ValueChanged<Offset> onPoint;
  final ui.Image? Function(int page) imageFor;
  final DocumentOrientation orientation;
  final List<GeometryPoint> pathPoints;

  static const double loupeSize = 176;
  static const double magnification = 3.5;
  static const double gap = 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (e) => onHover(e.localPosition),
              onExit: (_) => onHover(null),
              child: GestureDetector(
                key: const ValueKey('path-capture'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => onPoint(details.localPosition),
              ),
            ),
          ),
          ValueListenableBuilder<_LoupeTarget?>(
            valueListenable: hover,
            builder: (context, target, _) {
              if (target == null) return const SizedBox.shrink();
              final pos = target.screen;
              // Prefer above-right of the cursor; flip to stay inside the viewer.
              var left = pos.dx + gap;
              var top = pos.dy - gap - loupeSize;
              if (left + loupeSize > size.width) left = pos.dx - gap - loupeSize;
              if (top < 0) top = pos.dy + gap;
              left = left.clamp(0.0, math.max(0.0, size.width - loupeSize));
              top = top.clamp(0.0, math.max(0.0, size.height - loupeSize));
              final image = imageFor(target.page);
              return Positioned(
                left: left,
                top: top,
                width: loupeSize,
                height: loupeSize,
                child: IgnorePointer(
                  key: const ValueKey('path-magnifier'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: StudioColors.selection, width: 2),
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                    child: ClipOval(
                      child: image == null
                          ? const ColoredBox(
                              color: Colors.white,
                              child: Center(
                                  child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))),
                            )
                          // This layer sits inside the viewer's rotated frame
                          // (base rotation = the source orientation); the loupe
                          // paints the already-oriented page render, so undo it.
                          : RotatedBox(
                              quarterTurns: (4 - orientation.quarterTurns) % 4,
                              child: CustomPaint(
                                size: const Size(loupeSize, loupeSize),
                                painter: _LoupePainter(
                                  image: image,
                                  orientation: orientation,
                                  target: target,
                                  path: pathPoints,
                                  magnification: magnification,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Paints the magnified page crop under the cursor, the in-progress path and a
/// crosshair at the exact placement point. [image] is the page rendered in the
/// source's oriented space, so the cursor's page position is first converted
/// to oriented space.
class _LoupePainter extends CustomPainter {
  _LoupePainter({
    required this.image,
    required this.orientation,
    required this.target,
    required this.path,
    required this.magnification,
  });

  final ui.Image image;
  final DocumentOrientation orientation;
  final _LoupeTarget target;
  final List<GeometryPoint> path;
  final double magnification;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final o = orientation.pageToOriented(target.pageX, target.pageY);
    final odd = orientation.quarterTurns.isOdd;
    final orientedWidthPt = odd ? target.pageHeightPt : target.pageWidthPt;
    final imagePxPerPt = image.width / orientedWidthPt;
    // The loupe shows `magnification` times what is on screen.
    final windowPt = size.width * target.ptPerScreenPx / magnification;
    final srcSize = windowPt * imagePxPerPt;
    final cx = o.x * image.width;
    final cy = o.y * image.height;
    final src = Rect.fromCenter(center: Offset(cx, cy), width: srcSize, height: srcSize);
    final visible = src.intersect(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
    if (visible.width > 0 && visible.height > 0) {
      final scale = size.width / srcSize;
      final dst = Rect.fromLTWH(
        (visible.left - src.left) * scale,
        (visible.top - src.top) * scale,
        visible.width * scale,
        visible.height * scale,
      );
      canvas.drawImageRect(
          image, visible, dst, Paint()..filterQuality = FilterQuality.medium);
    }

    Offset toLoupe(GeometryPoint p) => Offset(
          (p.x * image.width - src.left) / srcSize * size.width,
          (p.y * image.height - src.top) / srcSize * size.height,
        );
    if (path.isNotEmpty) {
      final line = Paint()
        ..color = StudioColors.selection.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final points = [for (final p in path) toLoupe(p)];
      for (var i = 1; i < points.length; i++) {
        canvas.drawLine(points[i - 1], points[i], line);
      }
      for (final p in points) {
        canvas.drawCircle(p, 3, Paint()..color = StudioColors.selection);
      }
    }
    final c = size.center(Offset.zero);
    final cross = Paint()
      ..color = StudioColors.error
      ..strokeWidth = 1.2;
    canvas.drawLine(c - const Offset(12, 0), c - const Offset(3, 0), cross);
    canvas.drawLine(c + const Offset(3, 0), c + const Offset(12, 0), cross);
    canvas.drawLine(c - const Offset(0, 12), c - const Offset(0, 3), cross);
    canvas.drawLine(c + const Offset(0, 3), c + const Offset(0, 12), cross);
  }

  @override
  bool shouldRepaint(covariant _LoupePainter old) =>
      old.target != target || old.path.length != path.length || old.image != image;
}

/// A polyline evidence path drawn over the page. [points] are oriented
/// normalized points; they are mapped to page space, then to the page canvas.
/// The stroke width is in PDF points and scaled by the canvas-to-page ratio, so
/// it stays the same document-space width at every zoom level.
class _PathOverlay extends StatelessWidget {
  const _PathOverlay({
    super.key,
    required this.points,
    required this.strokeWidthPt,
    required this.pageWidthPt,
    required this.canvasSize,
    required this.orientation,
    required this.color,
    this.selected = false,
    this.showVertices = false,
    this.tooltip,
    this.onTap,
  });

  final List<GeometryPoint> points;
  final double strokeWidthPt;
  final double pageWidthPt;
  final Size canvasSize;
  final DocumentOrientation orientation;
  final Color color;
  final bool selected;
  final bool showVertices;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pagePoints = [
      for (final p in points) orientation.orientedToPage(p.x, p.y),
    ];
    final offsets = [
      for (final p in pagePoints)
        Offset(p.x * canvasSize.width, p.y * canvasSize.height),
    ];
    final widthPx = strokeWidthToCanvasPx(strokeWidthPt, canvasSize.width, pageWidthPt);
    var minX = offsets.first.dx, maxX = minX, minY = offsets.first.dy, maxY = minY;
    for (final o in offsets) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    final pad = math.max(widthPx, 6.0);
    return Positioned.fill(
      child: Stack(
        children: [
          IgnorePointer(
            child: CustomPaint(
              size: canvasSize,
              painter: _PathPainter(
                offsets: offsets,
                widthPx: widthPx,
                color: color,
                selected: selected,
                showVertices: showVertices,
              ),
            ),
          ),
          if (onTap != null)
            Positioned(
              left: minX - pad,
              top: minY - pad,
              width: (maxX - minX) + 2 * pad,
              height: (maxY - minY) + 2 * pad,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onTap,
                child: Tooltip(message: tooltip ?? '', child: const SizedBox.expand()),
              ),
            ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.offsets,
    required this.widthPx,
    required this.color,
    required this.selected,
    required this.showVertices,
  });

  final List<Offset> offsets;
  final double widthPx;
  final Color color;
  final bool selected;
  final bool showVertices;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    // A hairline stays visible when zoomed far out; this only affects display.
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(widthPx, 1.5);
    canvas.drawPath(path, paint);
    if (selected) {
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
    if (showVertices) {
      for (final o in offsets) {
        canvas.drawCircle(o, 3, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) =>
      old.offsets != offsets ||
      old.widthPx != widthPx ||
      old.color != color ||
      old.selected != selected ||
      old.showVertices != showVertices;
}

extension on double? {
  double? get validOrNull {
    final v = this;
    return v == null || !v.isFinite || v <= 0 ? null : v;
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
      {required this.region,
      required this.canvasSize,
      required this.onTap,
      this.orientation = DocumentOrientation.deg0});

  final DocumentOrientation orientation;

  final EvidenceRegion region;
  final Size canvasSize;
  final VoidCallback onTap;

  Color get _color => switch (region.origin) {
        EvidenceOrigin.machine => StudioColors.warning,
        EvidenceOrigin.human => StudioColors.success,
        EvidenceOrigin.llm => StudioColors.selection,
        null => StudioColors.textSecondary,
      };

  String get _badge => switch (region.origin) {
        EvidenceOrigin.machine => 'machine',
        EvidenceOrigin.llm => 'llm',
        EvidenceOrigin.human =>
          region.status == EvidenceAnnotationStatus.verified
              ? 'human · verified'
              : 'human',
        null => 'unrecorded',
      };

  @override
  Widget build(BuildContext context) {
    final page = orientation.rectOrientedToPage(
        region.x, region.y, region.width, region.height);
    return Positioned(
      left: page.x * canvasSize.width,
      top: page.y * canvasSize.height,
      width: page.width * canvasSize.width,
      height: page.height * canvasSize.height,
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
    required this.draftFor,
    required this.onDraftChanged,
    required this.hasUnsavedChanges,
    required this.onSave,
    required this.selectedRegionId,
    required this.onSelect,
    required this.saveMessage,
    required this.saveFailed,
    required this.onDelete,
    required this.onNewRelationship,
    required this.canCreateRelationship,
  });

  final _AnnotationDraft Function(EvidenceRegion region) draftFor;
  final VoidCallback onDraftChanged;
  final bool hasUnsavedChanges;
  final VoidCallback onSave;
  final String? selectedRegionId;
  final ValueChanged<EvidenceRegion> onSelect;
  final String? saveMessage;
  final bool saveFailed;
  final TextEditingController annotatorController;
  final List<EvidenceRegion> annotations;
  final Future<ui.Image?> Function(int page) pageImageFor;
  final ValueChanged<EvidenceRegion> onJumpTo;
  final ValueChanged<EvidenceRegion> onDelete;
  final VoidCallback onNewRelationship;
  final bool canCreateRelationship;

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
                Row(
                  children: [
                    const Expanded(
                      child: Text('Annotations',
                          style: TextStyle(
                              color: StudioColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    FilledButton(
                      key: const ValueKey('save-annotation-changes'),
                      onPressed: hasUnsavedChanges ? onSave : null,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
                if (saveMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      key: const ValueKey('save-status'),
                      children: [
                        Icon(saveFailed ? Icons.error_outline : Icons.check_circle_outline,
                            size: 14, color: saveFailed ? StudioColors.error : StudioColors.success),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(saveMessage!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: saveFailed ? StudioColors.error : StudioColors.success)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: annotatorController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                      isDense: true, labelText: 'Annotator'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: canCreateRelationship ? onNewRelationship : null,
                  icon: const Icon(Icons.timeline, size: 16),
                  label: const Text('New Relationship'),
                ),
                if (!canCreateRelationship)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Classify at least two of your annotations to connect them.',
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
                      key: ValueKey('annotation-${annotations[index].id}'),
                      region: annotations[index],
                      draft: draftFor(annotations[index]),
                      onChanged: onDraftChanged,
                      pageImageFor: pageImageFor,
                      selected: annotations[index].id == selectedRegionId,
                      onJumpTo: () {
                        onSelect(annotations[index]);
                        onJumpTo(annotations[index]);
                      },
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
    super.key,
    required this.region,
    required this.draft,
    required this.onChanged,
    required this.pageImageFor,
    required this.onJumpTo,
    required this.onDelete,
    this.selected = false,
  });

  final bool selected;
  final EvidenceRegion region;
  final _AnnotationDraft draft;
  final VoidCallback onChanged;
  final Future<ui.Image?> Function(int page) pageImageFor;
  final VoidCallback onJumpTo;
  final VoidCallback onDelete;

  @override
  State<_AnnotationListItem> createState() => _AnnotationListItemState();
}

class _AnnotationListItemState extends State<_AnnotationListItem> {
  static const double _thumbSize = 88;

  late final _nameController = TextEditingController(text: widget.draft.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    final selectedType = widget.draft.type;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: StudioColors.surface,
      shape: widget.selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: StudioColors.selection, width: 1.5))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 1.5),
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
                            child: Text(
                                region.geometry is PolylineGeometry
                                    ? 'Page ${region.page} · Path'
                                    : 'Page ${region.page}',
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
                            DropdownMenuItem(
                                value: type, child: Text(type.label)),
                        ],
                        onChanged: (type) {
                          if (type == null) return;
                          widget.draft.type = type;
                          widget.onChanged();
                        },
                      ),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 11),
                        decoration: const InputDecoration(
                            isDense: true, hintText: 'Name (optional)'),
                        onChanged: (name) {
                          widget.draft.name = name;
                          widget.onChanged();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (region.geometry is PolylineGeometry)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _PathWidthField(
                  key: ValueKey('width-${region.id}'),
                  draft: widget.draft,
                  onChanged: widget.onChanged,
                ),
              ),
            // WP-INGEST-013: notes + open-ended properties, inline in the
            // non-modal panel (never a dialog per property).
            _AnnotationDetails(
              // Keyed by region id so switching which region a list slot
              // shows never reuses another region's text controllers.
              key: ValueKey('details-${region.id}'),
              region: region,
              draft: widget.draft,
              onChanged: widget.onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual width of a path annotation, in PDF points (zoom-independent). This
/// is how wide the evidence path is DRAWN, not a wire gauge or diameter.
class _PathWidthField extends StatefulWidget {
  const _PathWidthField({super.key, required this.draft, required this.onChanged});

  final _AnnotationDraft draft;
  final VoidCallback onChanged;

  @override
  State<_PathWidthField> createState() => _PathWidthFieldState();
}

class _PathWidthFieldState extends State<_PathWidthField> {
  late final _controller = TextEditingController(
      text: _format(widget.draft.strokeWidth ?? PolylineGeometry.defaultStrokeWidth));

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Width',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextField(
            key: const ValueKey('path-width-field'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 11, color: StudioColors.textPrimary),
            decoration: const InputDecoration(isDense: true),
            onChanged: (text) {
              widget.draft.strokeWidth = double.tryParse(text.trim()) ?? double.nan;
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(width: 4),
        const Text('pt',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

/// WP-INGEST-013: the expandable "Description / Notes" + "Properties"
/// section of one annotation. Edits commit on submit or when a field
/// loses focus (never per keystroke, so a key like "Part Number" can be
/// typed freely before being normalized to its stable `part_number`
/// form), and each commit updates the existing region in place -- it
/// never creates a region or a candidate.
class _AnnotationDetails extends StatefulWidget {
  const _AnnotationDetails({
    super.key,
    required this.region,
    required this.draft,
    required this.onChanged,
  });

  final EvidenceRegion region;
  final _AnnotationDraft draft;
  final VoidCallback onChanged;

  @override
  State<_AnnotationDetails> createState() => _AnnotationDetailsState();
}

class _AnnotationDetailsState extends State<_AnnotationDetails> {
  late final _notesController =
      TextEditingController(text: widget.draft.notes);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addProperty(AnnotationProperty property) {
    widget.draft.properties
        .add(_DraftProperty(_AnnotationDraft._nextUid++, property));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.draft.properties;
    final typeName = widget.draft.type?.name ??
        widget.region.annotation?.type ??
        classifiedTypeFromLabel(widget.region.label)?.name;
    final existingKeys = {for (final p in properties) p.property.key};
    final suggestions = [
      for (final key in observationPropertySuggestions[typeName] ?? const <String>[])
        if (!existingKeys.contains(key)) key,
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        maintainState: true,
        dense: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          properties.isEmpty
              ? 'Details'
              : 'Details (${properties.length} properties)',
          style: const TextStyle(
              color: StudioColors.textSecondary, fontSize: 11.5),
        ),
        children: [
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
                isDense: true, labelText: 'Description / Notes'),
            onChanged: (notes) {
              widget.draft.notes = notes;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Properties',
                style:
                    TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          ),
          for (var index = 0; index < properties.length; index++)
            _PropertyRow(
              // Content in the key: after a delete or a committed edit the
              // row rebuilds from the stored property, never from a stale
              // controller left at a shifted index.
              key: ValueKey('${widget.region.id}-prop-${properties[index].uid}'),
              property: properties[index].property,
              onChanged: (property) {
                properties[index].property = property;
                widget.onChanged();
              },
              onRemove: () {
                properties.removeAt(index);
                widget.onChanged();
              },
            ),
          if (suggestions.isNotEmpty)
            Wrap(
              spacing: 4,
              children: [
                for (final key in suggestions)
                  ActionChip(
                    key: ValueKey('suggest-property-$key'),
                    label: Text('+ $key', style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _addProperty(AnnotationProperty(key: key)),
                  ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addProperty(const AnnotationProperty(key: '')),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Property', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatefulWidget {
  const _PropertyRow(
      {super.key,
      required this.property,
      required this.onChanged,
      required this.onRemove});

  final AnnotationProperty property;
  final ValueChanged<AnnotationProperty> onChanged;
  final VoidCallback onRemove;

  @override
  State<_PropertyRow> createState() => _PropertyRowState();
}

class _PropertyRowState extends State<_PropertyRow> {
  late final _keyController = TextEditingController(text: widget.property.key);
  late final _valueController =
      TextEditingController(text: widget.property.value);
  late final _unitController =
      TextEditingController(text: widget.property.unit ?? '');

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _commit({String? valueType}) {
    final unit = _unitController.text.trim();
    final next = AnnotationProperty(
      key: _keyController.text,
      value: _valueController.text,
      valueType: valueType ?? widget.property.valueType,
      unit: unit.isEmpty ? null : unit,
    );
    if (next != widget.property) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11);
    Widget field(TextEditingController controller, String hint) => Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _commit();
          },
          child: TextField(
            controller: controller,
            style: style,
            decoration: InputDecoration(isDense: true, hintText: hint),
            onChanged: (_) => _commit(),
            onSubmitted: (_) => _commit(),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 4, child: field(_keyController, 'key')),
          const SizedBox(width: 4),
          Expanded(flex: 4, child: field(_valueController, 'value')),
          const SizedBox(width: 4),
          DropdownButton<String>(
            isDense: true,
            value: AnnotationProperty.valueTypes
                    .contains(widget.property.valueType)
                ? widget.property.valueType
                : AnnotationProperty.valueTypeText,
            style: const TextStyle(
                fontSize: 10.5, color: StudioColors.textPrimary),
            items: [
              for (final type in AnnotationProperty.valueTypes)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (type) {
              if (type != null) _commit(valueType: type);
            },
          ),
          const SizedBox(width: 4),
          SizedBox(width: 40, child: field(_unitController, 'unit')),
          InkWell(
            onTap: widget.onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close,
                  size: 14, color: StudioColors.textSecondary),
            ),
          ),
        ],
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
    // A path's crop is its bounding box plus padding (a straight wire has a
    // zero-height box); the path itself is drawn over the crop below.
    final geometry = region.geometry;
    var cropX = region.x, cropY = region.y;
    var cropW = region.width, cropH = region.height;
    if (geometry is PolylineGeometry) {
      final padX = math.max(cropW * 0.15, 0.03);
      final padY = math.max(cropH * 0.15, 0.03);
      final left = math.max(0.0, cropX - padX);
      final top = math.max(0.0, cropY - padY);
      final right = math.min(1.0, cropX + cropW + padX);
      final bottom = math.min(1.0, cropY + cropH + padY);
      cropX = left;
      cropY = top;
      cropW = right - left;
      cropH = bottom - top;
    }
    final regionWidthFraction = cropW <= 0 ? 1.0 : cropW;
    final regionHeightFraction = cropH <= 0 ? 1.0 : cropH;
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
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: displayedFullWidth,
                maxWidth: displayedFullWidth,
                minHeight: displayedFullHeight,
                maxHeight: displayedFullHeight,
                child: Transform.translate(
                  offset: Offset(-cropX * displayedFullWidth,
                      -cropY * displayedFullHeight),
                  child: RawImage(
                      image: image,
                      width: displayedFullWidth,
                      height: displayedFullHeight,
                      fit: BoxFit.fill),
                ),
              ),
            ),
          ),
          if (geometry is PolylineGeometry)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PathPainter(
                    offsets: [
                      for (final p in geometry.points)
                        Offset((p.x - cropX) / regionWidthFraction * boxWidth,
                            (p.y - cropY) / regionHeightFraction * boxHeight),
                    ],
                    // Thumbnails draw a fixed thin cue, not the document-space width.
                    widthPx: 1.5,
                    color: StudioColors.success,
                    selected: false,
                    showVertices: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
