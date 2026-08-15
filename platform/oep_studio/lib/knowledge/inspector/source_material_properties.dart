import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/ocr_page_result.dart';
import '../models/ocr_processing_status.dart';
import '../models/source_material.dart';
import '../review/knowledge_candidate_form_dialog.dart';

/// Property Inspector's Source Material mode (Work Package 008
/// STUDIO-TASK-000016 Property Inspector: "Display: ... Source
/// Material"; Work Package 009: "Source Metadata" extended with the
/// Evidence Region count and selected pages this source now carries;
/// Work Package 010: each selected page gets its own "Create Knowledge
/// Candidate from Page Selection" action; Work Package 013: "Extend
/// support for: OCR metadata, Confidence, OCR statistics").
class SourceMaterialProperties extends StatelessWidget {
  const SourceMaterialProperties({
    required this.source,
    this.evidenceRegionCount = 0,
    this.selectedPages = const [],
    this.ocrStatus = OcrProcessingStatus.notProcessed,
    this.ocrResults = const [],
    this.ocrAverageConfidence = 0,
    super.key,
  });

  final SourceMaterial source;

  /// How many Evidence Regions belong to this source (Work Package 009
  /// STUDIO-TASK-000020).
  final int evidenceRegionCount;

  /// Page Selections belonging to this source (Work Package 009
  /// STUDIO-TASK-000019 § Selection), sorted ascending.
  final List<int> selectedPages;

  /// This source's current OCR processing state (Work Package 013).
  final OcrProcessingStatus ocrStatus;

  /// This source's cached OCR results, one per page (Work Package 013).
  final List<OcrPageResult> ocrResults;

  /// The mean confidence across every successfully-OCR'd page (Work
  /// Package 013 Property Inspector: "Confidence").
  final double ocrAverageConfidence;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Source ID', value: source.id, monospace: true),
        PropertyField(label: 'File Name', value: source.originalFileName),
        PropertyField(label: 'Type', value: source.type.label),
        PropertyField(label: 'Size', value: formatFileSize(source.sizeBytes)),
        PropertyField(label: 'Date Added', value: formatDateTime(source.importDate)),
        PropertyField(label: 'Added By', value: source.addedBy),
        PropertyField(label: 'Evidence Regions', value: '$evidenceRegionCount'),
        const Text('Selected Pages', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        if (selectedPages.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('—', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
          )
        else
          for (final page in selectedPages)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Page $page', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                  ),
                  IconButton(
                    tooltip: 'Create Knowledge Candidate from Page Selection',
                    icon: const Icon(Icons.add_box_outlined, size: 15),
                    onPressed: () => showKnowledgeCandidateFormDialog(
                      context,
                      initialName: '${source.originalFileName} — Page $page',
                      initialDescription: 'Created from Page Selection (page $page) of "${source.originalFileName}".',
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 10),
        PropertyField(label: 'Local Path', value: source.localPath, monospace: true),
        _OcrSection(status: ocrStatus, results: ocrResults, averageConfidence: ocrAverageConfidence),
      ],
    );
  }
}

/// OCR metadata/confidence/statistics (Work Package 013 Property
/// Inspector: "Extend support for: OCR metadata, Confidence, OCR
/// statistics").
class _OcrSection extends StatelessWidget {
  const _OcrSection({required this.status, required this.results, required this.averageConfidence});

  final OcrProcessingStatus status;
  final List<OcrPageResult> results;
  final double averageConfidence;

  @override
  Widget build(BuildContext context) {
    final successfulPages = results.where((result) => result.success).length;
    final engineVersion = results.isEmpty ? '—' : results.first.engineVersion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('OCR', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'OCR Status', value: status.label),
        PropertyField(label: 'Pages OCR\'d', value: '$successfulPages'),
        PropertyField(
          label: 'Confidence',
          value: successfulPages == 0 ? '—' : '${(averageConfidence * 100).toStringAsFixed(0)}%',
        ),
        PropertyField(label: 'OCR Engine', value: engineVersion),
      ],
    );
  }
}

extension on OcrProcessingStatus {
  String get label => switch (this) {
    OcrProcessingStatus.notProcessed => 'Not Processed',
    OcrProcessingStatus.processing => 'Processing…',
    OcrProcessingStatus.completed => 'Completed',
    OcrProcessingStatus.failed => 'Failed',
  };
}
