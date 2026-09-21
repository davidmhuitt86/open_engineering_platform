import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/studio_colors.dart';
import '../../../knowledge/models/document_orientation.dart';
import '../acquisition_wizard_controller.dart';

/// Document Orientation (WP-INGEST-014): the persistent Extraction Orientation
/// applied before OCR. The preview shows page 1 of the real local file rotated
/// by the same transform extraction will use; official-source acquisitions have
/// no file yet, so no preview is shown.
class WizardOrientationSelector extends StatelessWidget {
  const WizardOrientationSelector({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    final orientation = controller.extractionOrientation;
    final path = controller.localFilePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Document Orientation',
            style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Choose the rotation that makes the document upright. It is applied before extraction, so OCR, '
          'evidence regions and thumbnails all use the upright page. The original artifact in the Reference '
          'Vault is never modified.',
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 10),
        SegmentedButton<DocumentOrientation>(
          key: const ValueKey('extraction-orientation-selector'),
          showSelectedIcon: false,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? Colors.white : StudioColors.textPrimary),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? StudioColors.selection.withValues(alpha: 0.45) : null),
          ),
          segments: [
            for (final value in DocumentOrientation.values)
              ButtonSegment(value: value, label: Text('${value.degrees}°')),
          ],
          selected: {orientation},
          onSelectionChanged: (selection) => controller.setExtractionOrientation(selection.first),
        ),
        const SizedBox(height: 12),
        if (path != null && File(path).existsSync())
          Container(
            key: const ValueKey('extraction-orientation-preview'),
            height: 220,
            alignment: Alignment.centerLeft,
            child: RotatedBox(quarterTurns: orientation.quarterTurns, child: _preview(path)),
          )
        else
          const Text(
            'No preview: the file is retrieved from the official source when acquisition runs. The selected '
            'orientation will still be applied.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _preview(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return PdfDocumentViewBuilder.file(
        path,
        builder: (context, document) => document == null
            ? const SizedBox(width: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : PdfPageView(document: document, pageNumber: 1),
      );
    }
    return Image.file(File(path));
  }
}
