import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/studio_detail_row.dart';
import '../../shared/widgets/studio_type_swatch.dart';

/// Package Validation (AP-DS-002, "Package Integration"): presents
/// `FoundationBridge.verifyPackage`'s result for one installed package.
///
/// A visual/structural sibling of `diagram_validation_panel.dart`
/// (same [StudioColors], same "clean vs N finding(s)" summary line
/// convention) but a different data source and a different scope: this
/// dialog validates package-level Foundation concerns (object/
/// relationship counts against the Package Registry, archive
/// availability, archive hash integrity) — it does not touch, and
/// deliberately does not duplicate, `DiagramValidationPanel`'s diagram
/// structural validation.
class PackageValidationDialog extends ConsumerStatefulWidget {
  const PackageValidationDialog({
    required this.packageId,
    required this.packageTitle,
    super.key,
  });

  final String packageId;
  final String packageTitle;

  @override
  ConsumerState<PackageValidationDialog> createState() => _PackageValidationDialogState();
}

class _PackageValidationDialogState extends ConsumerState<PackageValidationDialog> {
  PackageVerifyResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  void _verify() {
    setState(() => _loading = true);
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) {
      setState(() {
        _loading = false;
        _error = 'No repository connection available.';
      });
      return;
    }
    try {
      final result = bridge.verifyPackage(widget.packageId);
      setState(() {
        _result = result;
        _error = null;
        _loading = false;
      });
    } on FoundationBridgeException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(
        'Validate — ${widget.packageTitle}',
        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15),
      ),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: StudioColors.selection)),
              )
            : _error != null
                ? Text(_error!, style: const TextStyle(color: StudioColors.error, fontSize: 12.5))
                : _ResultBody(result: _result!),
      ),
      actions: [
        IconButton(
          tooltip: 'Revalidate',
          icon: const Icon(Icons.refresh, size: 18, color: StudioColors.textSecondary),
          onPressed: _loading ? null : _verify,
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result});

  final PackageVerifyResult result;

  @override
  Widget build(BuildContext context) {
    final findings = <String>[
      if (!result.archiveAvailable) 'Source archive is not available for re-verification.',
      if (result.archiveAvailable && !result.archiveHashMatches) 'Archive hash does not match the recorded package hash.',
      if (result.objectsPresent != result.objectsExpected)
        'Object count mismatch: expected ${result.objectsExpected}, found ${result.objectsPresent}.',
      if (result.relationshipsPresent != result.relationshipsExpected)
        'Relationship count mismatch: expected ${result.relationshipsExpected}, found ${result.relationshipsPresent}.',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.verified ? Icons.check_circle_outline : Icons.warning_amber_outlined,
              size: 18,
              color: result.verified ? StudioColors.success : StudioColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              result.verified ? 'Verified — clean' : '${findings.length} finding(s)',
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _row('Objects', '${result.objectsPresent} / ${result.objectsExpected} expected'),
        _row('Relationships', '${result.relationshipsPresent} / ${result.relationshipsExpected} expected'),
        _row('Archive available', result.archiveAvailable ? 'Yes' : 'No'),
        if (result.archiveAvailable) _row('Archive hash', result.archiveHashMatches ? 'Matches' : 'Mismatch'),
        if (findings.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (final finding in findings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudioTypeSwatch(color: StudioColors.warning, size: 5),
                  const SizedBox(width: 8),
                  Expanded(child: Text(finding, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12))),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) {
    return StudioDetailRow(label: label, value: value, labelWidth: 140);
  }
}
