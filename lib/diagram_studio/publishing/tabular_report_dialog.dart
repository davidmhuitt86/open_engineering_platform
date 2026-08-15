import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/studio_colors.dart';
import 'tabular_report_kind.dart';

/// AP-DS-004: generate/preview/export UI for the 6 tabular Engineering
/// Deliverables (§5 of the task spec). Grouping/Sorting/Filtering/Custom
/// Columns are the spec's own named BOM affordances, applied here to all
/// six report kinds via `TabularReport`'s own methods — the UI never
/// recomputes rows itself, only calls `groupedBy`/`sortedBy`/`filtered`/
/// `withCustomColumn`.
class TabularReportDialog extends StatefulWidget {
  const TabularReportDialog({required this.graph, required this.layout, super.key});

  final EngineeringGraph graph;
  final DiagramLayoutState layout;

  static Future<void> show(BuildContext context, {required EngineeringGraph graph, required DiagramLayoutState layout}) {
    return showDialog<void>(context: context, builder: (_) => TabularReportDialog(graph: graph, layout: layout));
  }

  @override
  State<TabularReportDialog> createState() => _TabularReportDialogState();
}

class _TabularReportDialogState extends State<TabularReportDialog> {
  TabularReportKind _kind = TabularReportKind.billOfMaterials;
  String? _sortColumn;
  bool _sortDescending = false;
  String? _groupColumn;
  String _filterText = '';
  final List<(String, String)> _customColumns = []; // (label, source column to echo — simple "custom column" demo)

  TabularReport get _report {
    var report = _kind.generate(widget.graph, widget.layout);
    for (final custom in _customColumns) {
      final (label, sourceColumn) = custom;
      report = report.withCustomColumn(
        'custom_${label.toLowerCase().replaceAll(' ', '_')}',
        label,
        (row) => row[sourceColumn],
      );
    }
    if (_filterText.trim().isNotEmpty) {
      final needle = _filterText.trim().toLowerCase();
      report = report.filtered((row) => row.values.any((v) => (v ?? '').toString().toLowerCase().contains(needle)));
    }
    if (_sortColumn != null) {
      report = report.sortedBy(_sortColumn!, descending: _sortDescending);
    }
    return report;
  }

  Future<void> _exportCsv() => _exportText(TabularReportRenderer.toCsv(_report), 'csv');
  Future<void> _exportMarkdown() => _exportText(TabularReportRenderer.toMarkdown(_report), 'md');

  Future<void> _exportText(String content, String extension) async {
    final location = await getSaveLocation(
      suggestedName: '${_kind.name}.$extension',
      acceptedTypeGroups: [XTypeGroup(label: extension.toUpperCase(), extensions: [extension])],
    );
    if (location == null) return;
    await File(location.path).writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${_kind.label} to ${location.path}')));
  }

  Future<void> _exportPdf() async {
    final doc = TabularReportPdfRenderer.render(_report);
    final location = await getSaveLocation(
      suggestedName: '${_kind.name}.pdf',
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (location == null) return;
    await File(location.path).writeAsBytes(await doc.save());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${_kind.label} to ${location.path}')));
  }

  void _previewPdf() {
    final doc = TabularReportPdfRenderer.render(_report);
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: StudioColors.surfaceRaised,
        child: SizedBox(
          width: 700,
          height: 800,
          child: PdfPreview(build: (format) => doc.save(), canChangePageFormat: false, allowSharing: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Engineering Reports', style: TextStyle(color: StudioColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 700,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<TabularReportKind>(
                  key: const Key('report_kind_dropdown'),
                  value: _kind,
                  items: [for (final k in TabularReportKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
                  onChanged: (k) => setState(() {
                    _kind = k!;
                    _sortColumn = null;
                    _groupColumn = null;
                  }),
                ),
                DropdownButton<String?>(
                  key: const Key('report_sort_dropdown'),
                  value: _sortColumn,
                  hint: const Text('Sort by…'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No sort')),
                    for (final c in report.columns) DropdownMenuItem(value: c, child: Text(report.labelFor(c))),
                  ],
                  onChanged: (c) => setState(() => _sortColumn = c),
                ),
                IconButton(
                  tooltip: _sortDescending ? 'Descending' : 'Ascending',
                  icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  onPressed: () => setState(() => _sortDescending = !_sortDescending),
                ),
                DropdownButton<String?>(
                  key: const Key('report_group_dropdown'),
                  value: _groupColumn,
                  hint: const Text('Group by…'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No grouping')),
                    for (final c in report.columns) DropdownMenuItem(value: c, child: Text(report.labelFor(c))),
                  ],
                  onChanged: (c) => setState(() => _groupColumn = c),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('report_filter_field'),
                    decoration: const InputDecoration(isDense: true, hintText: 'Filter…'),
                    onChanged: (v) => setState(() => _filterText = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${report.rows.length} row(s)', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 8),
            Expanded(child: _TableView(report: report, groupColumn: _groupColumn)),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('report_export_csv'), onPressed: _exportCsv, child: const Text('Export CSV')),
        TextButton(key: const Key('report_export_md'), onPressed: _exportMarkdown, child: const Text('Export Markdown')),
        TextButton(key: const Key('report_export_pdf'), onPressed: _exportPdf, child: const Text('Export PDF')),
        TextButton(key: const Key('report_preview_pdf'), onPressed: _previewPdf, child: const Text('Print Preview')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.report, required this.groupColumn});

  final TabularReport report;
  final String? groupColumn;

  @override
  Widget build(BuildContext context) {
    final groups = report.groupedBy(groupColumn);
    return ListView(
      children: [
        for (final group in groups) ...[
          if (groupColumn != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(group.key.isEmpty ? '(blank)' : group.key,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          Table(
            border: TableBorder.all(color: StudioColors.border, width: 0.5),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: StudioColors.surfaceSunken),
                children: [
                  for (final c in report.columns)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(report.labelFor(c), style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              for (final row in group.value)
                TableRow(
                  children: [
                    for (final c in report.columns)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text((row[c] ?? '').toString(), style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
