import 'dart:io';
import 'dart:typed_data';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/theme/studio_colors.dart';
import '../intelligence/diagram_intelligence_service.dart';
import 'engineering_summary.dart';
import 'exchange_checklist.dart';
import 'intelligence_reports.dart';
import 'package_manifest.dart';
import 'tabular_report_dialog.dart';
import 'title_block_editor_dialog.dart';
import 'title_block_storage.dart';

/// AP-DS-004: the single entry point for Engineering Publishing &
/// Deliverables — the one dialog `diagram_studio_page.dart` opens (its
/// own minimal wiring addition is documented at that call site). Ties
/// together: Title Block editing, the 6 tabular reports, Validation/
/// Reasoning reports (via [DiagramIntelligenceService] only — never
/// computed here), Engineering Summary, Package Manifest, and Exchange
/// Readiness/Publishing Checklist. Printing (Print Preview) is reachable
/// from the "Print" tab, backed by `oep_engine`'s `PdfExportProvider` —
/// see `_printTab`'s own doc comment for what's built (single-sheet
/// preview) vs. deliberately deferred (Page Setup, Multiple Sheets/
/// Entire Project/Entire Package printing).
class PublishingCenterDialog extends StatefulWidget {
  const PublishingCenterDialog({
    required this.diagramKey,
    required this.graph,
    required this.layout,
    required this.intelligence,
    super.key,
  });

  final String diagramKey;
  final EngineeringGraph graph;
  final DiagramLayoutState layout;

  /// Nullable so this dialog is constructible/testable without a live
  /// Foundation runtime — Validation/Reasoning actions are disabled
  /// (with an honest message) when null, per this codebase's disclosed
  /// "not testable under `flutter test`" limitation for
  /// `DiagramIntelligenceService`-dependent code.
  final DiagramIntelligenceService? intelligence;

  static Future<void> show(
    BuildContext context, {
    required String diagramKey,
    required EngineeringGraph graph,
    required DiagramLayoutState layout,
    required DiagramIntelligenceService? intelligence,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PublishingCenterDialog(diagramKey: diagramKey, graph: graph, layout: layout, intelligence: intelligence),
    );
  }

  @override
  State<PublishingCenterDialog> createState() => _PublishingCenterDialogState();
}

class _PublishingCenterDialogState extends State<PublishingCenterDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);
  TitleBlock _titleBlock = TitleBlock.empty;
  bool _validationRun = false;
  bool _validationPassed = false;
  String? _lastReportMarkdown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    TitleBlockStorage.load(widget.diagramKey).then((tb) {
      if (mounted) setState(() => _titleBlock = tb);
    });
  }

  Future<void> _openTitleBlockEditor() async {
    await TitleBlockEditorDialog.show(context, diagramKey: widget.diagramKey);
    final tb = await TitleBlockStorage.load(widget.diagramKey);
    if (mounted) setState(() => _titleBlock = tb);
  }

  Future<void> _runValidation() async {
    final intel = widget.intelligence;
    if (intel == null) return;
    setState(() => _busy = true);
    final outcome = await intel.validate();
    setState(() {
      _busy = false;
      _validationRun = true;
      _validationPassed = outcome.result.success;
      _lastReportMarkdown = IntelligenceReportRenderer.renderValidationMarkdown(
        result: outcome.result,
        objectIds: outcome.objectIds,
      );
    });
  }

  Future<void> _runReasoning() async {
    final intel = widget.intelligence;
    if (intel == null) return;
    setState(() => _busy = true);
    final outcome = await intel.reason(objective: 'Publishing: engineering reasoning report');
    setState(() {
      _busy = false;
      _lastReportMarkdown = IntelligenceReportRenderer.renderReasoningMarkdown(
        result: outcome.result,
        objectIds: outcome.objectIds,
      );
    });
  }

  Future<void> _saveMarkdownReport(String content, String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [XTypeGroup(label: 'Markdown', extensions: ['md'])],
    );
    if (location == null) return;
    await File(location.path).writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${location.path}')));
  }

  Future<void> _exportManifest() async {
    final bom = BillOfMaterialsGenerator.generate(widget.graph);
    final manifest = PackageManifest(
      diagramTitle: widget.diagramKey,
      generatedAt: DateTime.now(),
      includedReports: const [
        'Bill of Materials',
        'Wire List',
        'Connector Report',
        'Harness Report',
        'Relationship Report',
        'Engineering Object Report',
      ],
      titleBlockSnapshot: _titleBlock,
    );
    await _saveMarkdownReport(manifest.toMarkdown(), 'package_manifest.md');
    // Row count read purely for the manifest's own future use; not stored.
    // (bom used below by the checklist tab too, kept local here.)
    // ignore: unnecessary_statements
    bom.rows.length;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Engineering Publishing', style: TextStyle(color: StudioColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 760,
        height: 600,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: StudioColors.selection,
              unselectedLabelColor: StudioColors.textSecondary,
              tabs: const [
                Tab(text: 'Title Block'),
                Tab(text: 'Print'),
                Tab(text: 'Reports'),
                Tab(text: 'Intelligence Reports'),
                Tab(text: 'Summary'),
                Tab(text: 'Exchange'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _titleBlockTab(),
                  _printTab(),
                  _reportsTab(),
                  _intelligenceTab(),
                  _summaryTab(),
                  _exchangeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  Widget _titleBlockTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_titleBlock.company.isEmpty ? "(no company)" : _titleBlock.company} — Drawing ${_titleBlock.drawingNumber.isEmpty ? "(unset)" : _titleBlock.drawingNumber} rev ${_titleBlock.revision.isEmpty ? "(unset)" : _titleBlock.revision}',
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 8),
          Text('Revisions: ${_titleBlock.revisionHistory.length}', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(key: const Key('open_title_block_editor'), onPressed: _openTitleBlockEditor, child: const Text('Edit Title Block & Revisions')),
        ],
      ),
    );
  }

  /// AP-DS-004: closes the reconciliation point named in this class's own
  /// doc comment ("Printing... once the parallel PDF export provider
  /// lands") — the PDF diagram exporter landed in `oep_engine` after this
  /// dialog was first built, but `DiagramPrintPreviewDialog` (already
  /// implemented and tested standalone) was never actually wired to a
  /// reachable call site. This tab closes that gap: single-sheet print
  /// preview via a real `PdfExportProvider`. "Multiple Sheets"/"Entire
  /// Project"/"Entire Package" printing remain unimplemented — this
  /// platform has no multi-sheet document model to print across (the
  /// same disclosed limitation `ENGINEERING_MAPPING.md`/`DOCUMENT_MODEL.md`
  /// already record), and "Entire Package" printing was not attempted in
  /// this pass.
  Widget _printTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Print Preview for the current diagram sheet (vector PDF, title block included if set).',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('open_print_preview'),
            onPressed: () => DiagramPrintPreviewDialog.show(
              context,
              exportProvider: PdfExportProvider(),
              graph: widget.graph,
              layout: widget.layout,
            ),
            child: const Text('Print Preview (Single Sheet)'),
          ),
        ],
      ),
    );
  }

  Widget _reportsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bill of Materials / Wire List / Connector / Harness / Relationship / Engineering Object reports.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('open_tabular_reports'),
            onPressed: () => TabularReportDialog.show(context, graph: widget.graph, layout: widget.layout),
            child: const Text('Generate / Preview / Export Reports'),
          ),
        ],
      ),
    );
  }

  Widget _intelligenceTab() {
    final intel = widget.intelligence;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intel == null)
            const Text('No Engineering Intelligence connection available in this context.', style: TextStyle(color: StudioColors.textDisabled, fontSize: 12)),
          Row(
            children: [
              ElevatedButton(
                key: const Key('run_validation_report'),
                onPressed: intel == null || _busy ? null : _runValidation,
                child: const Text('Validation Report'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('run_reasoning_report'),
                onPressed: intel == null || _busy ? null : _runReasoning,
                child: const Text('Reasoning Report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(minHeight: 2, color: StudioColors.selection),
          if (_lastReportMarkdown != null) ...[
            Expanded(
              child: SingleChildScrollView(
                child: Text(_lastReportMarkdown!, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5, fontFamily: 'monospace')),
              ),
            ),
            TextButton(
              key: const Key('save_intelligence_report'),
              onPressed: () => _saveMarkdownReport(_lastReportMarkdown!, 'intelligence_report.md'),
              child: const Text('Save as Markdown'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryTab() {
    final summary = EngineeringSummary.build(widget.graph, widget.layout);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(summary.toMarkdown(), style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
            ),
          ),
          Row(
            children: [
              TextButton(key: const Key('save_engineering_summary'), onPressed: () => _saveMarkdownReport(summary.toMarkdown(), 'engineering_summary.md'), child: const Text('Save as Markdown')),
              TextButton(key: const Key('save_package_manifest'), onPressed: _exportManifest, child: const Text('Save Package Manifest')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exchangeTab() {
    final bomRows = BillOfMaterialsGenerator.generate(widget.graph).rows.length;
    final items = ExchangeChecklist.build(
      titleBlock: _titleBlock,
      validationPassed: _validationPassed,
      validationRun: _validationRun,
      bomRowCount: bomRows,
      nodeCount: widget.graph.nodes.length,
    );
    final ready = ExchangeChecklist.ready(items);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ready ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: ready ? StudioColors.success : StudioColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(ready ? 'Exchange Ready' : 'Not Ready', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.complete ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: item.complete ? StudioColors.success : StudioColors.textDisabled),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                        Text(item.detail, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text('No networking. No upload. This tab only checks local readiness.', style: TextStyle(color: StudioColors.textDisabled, fontSize: 10.5, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// Print Preview for the diagram drawing itself (as opposed to a tabular
/// report, which `TabularReportDialog` already previews). Reconciliation
/// point with the parallel PDF export provider work: this calls
/// `ExportProvider.export(ExportRequest(formatId: 'pdf', graph: ...,
/// layout: ...))` and feeds the resulting bytes to `PdfPreview` — if the
/// PDF diagram exporter has not landed in `oep_engine` yet when this runs,
/// `export` returns `ExportResult.failure`, which is rendered as a
/// disclosed "PDF diagram export is not yet available" message rather
/// than a crash or a fabricated page.
class DiagramPrintPreviewDialog extends StatelessWidget {
  const DiagramPrintPreviewDialog({required this.exportProvider, required this.graph, required this.layout, super.key});

  final ExportProvider exportProvider;
  final EngineeringGraph graph;
  final DiagramLayoutState layout;

  static Future<void> show(BuildContext context, {required ExportProvider exportProvider, required EngineeringGraph graph, required DiagramLayoutState layout}) {
    return showDialog<void>(
      context: context,
      builder: (_) => DiagramPrintPreviewDialog(exportProvider: exportProvider, graph: graph, layout: layout),
    );
  }

  Future<Uint8List> _buildPdfBytes(PdfPageFormat format) async {
    final result = await exportProvider.export(ExportRequest(formatId: 'pdf', graph: graph, layout: layout));
    if (!result.success || result.bytes == null) {
      throw StateError(result.errorMessage ?? 'PDF diagram export is not yet available.');
    }
    return Uint8List.fromList(result.bytes!);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: StudioColors.surfaceRaised,
      child: SizedBox(
        width: 800,
        height: 850,
        child: PdfPreview(
          build: _buildPdfBytes,
          canChangePageFormat: true,
          allowSharing: false,
        ),
      ),
    );
  }
}
