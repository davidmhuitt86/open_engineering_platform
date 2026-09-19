import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/studio_colors.dart';
import '../../models/official_source.dart';
import '../../services/acquisition_runtime_service.dart';
import '../acquisition_wizard_controller.dart';

/// Wizard Step 2 -- either lists real Official Sources (`GET /sources`,
/// lets the engineer search them, and create a new one without leaving
/// the wizard by calling the same real `POST /sources` the classic
/// Sources panel uses), or -- WP-EAM-005 -- lets the engineer select a
/// local file (e.g. a PDF wiring diagram) directly, entering the same
/// downstream pipeline as a User-Provided Artifact rather than one
/// acquired from a registered Source.
class WizardStepOfficialSource extends ConsumerStatefulWidget {
  const WizardStepOfficialSource({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  ConsumerState<WizardStepOfficialSource> createState() => _WizardStepOfficialSourceState();
}

class _WizardStepOfficialSourceState extends ConsumerState<WizardStepOfficialSource> {
  final _searchController = TextEditingController();
  bool _creating = false;
  bool _picking = false;
  String? _pickError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickLocalFile() async {
    setState(() {
      _picking = true;
      _pickError = null;
    });
    try {
      final picked = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Engineering Documents', extensions: ['pdf']),
        ],
      );
      if (picked == null) return;
      final sizeBytes = await picked.length();
      widget.controller.setLocalFile(path: picked.path, name: picked.name, sizeBytes: sizeBytes);
    } catch (error) {
      setState(() => _pickError = 'Could not read the selected file: $error');
    }
    if (mounted) setState(() => _picking = false);
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(acquisitionRuntimeServiceProvider).sources;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? sources
        : sources.where((s) => s.name.toLowerCase().contains(query) || s.baseUrl.toLowerCase().contains(query)).toList();
    final isLocal = widget.controller.sourceType == AcquisitionSourceType.localDocument;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Where is this coming from?',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Every acquisition traces back either to an Official Source -- a trusted publisher OEP already '
            'knows about, or a new one you register here -- or to a document you provide directly. This is '
            'the root of Engineering Chain of Custody: it is the answer to "where did this come from, and '
            'can we trust it?"',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          SegmentedButton<AcquisitionSourceType>(
            segments: const [
              ButtonSegment(
                value: AcquisitionSourceType.officialSource,
                label: Text('Official Source'),
                icon: Icon(Icons.public, size: 16),
              ),
              ButtonSegment(
                value: AcquisitionSourceType.localDocument,
                label: Text('Local Document'),
                icon: Icon(Icons.description_outlined, size: 16),
              ),
            ],
            selected: {widget.controller.sourceType},
            onSelectionChanged: (selection) => widget.controller.setSourceType(selection.first),
          ),
          const SizedBox(height: 16),
          if (isLocal) ...[
            OutlinedButton.icon(
              onPressed: _picking ? null : _pickLocalFile,
              icon: _picking
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_open_outlined, size: 16),
              label: const Text('Browse Files…'),
            ),
            const SizedBox(height: 12),
            if (_pickError != null)
              Text(_pickError!, style: const TextStyle(color: StudioColors.error, fontSize: 11.5)),
            if (widget.controller.localFilePath != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StudioColors.surfaceRaised,
                  border: Border.all(color: StudioColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 20, color: StudioColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected:', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                          Text(widget.controller.localFileName ?? '',
                              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _formatBytes(widget.controller.localFileSizeBytes ?? 0),
                            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text('No file selected yet.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          ] else ...[
            _buildOfficialSourcePicker(filtered),
          ],
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildOfficialSourcePicker(List<OfficialSource> filtered) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search sources…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _creating ? null : () => setState(() => _creating = true),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Source'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_creating)
            _NewSourceForm(
              onCancel: () => setState(() => _creating = false),
              onCreated: (source) {
                widget.controller.setSource(source.id, source.name);
                setState(() => _creating = false);
              },
            ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No sources match.', style: TextStyle(color: StudioColors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final source = filtered[index];
                      final selected = widget.controller.sourceId == source.id;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: StudioColors.selection.withValues(alpha: 0.12),
                        leading: Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18,
                          color: selected ? StudioColors.selection : StudioColors.textSecondary,
                        ),
                        title: Text(source.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
                        subtitle: Text(source.baseUrl,
                            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                        trailing: Text('Trust ${source.trustLevel}',
                            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                        onTap: () => widget.controller.setSource(source.id, source.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewSourceForm extends ConsumerStatefulWidget {
  const _NewSourceForm({required this.onCancel, required this.onCreated});

  final VoidCallback onCancel;
  final ValueChanged<OfficialSource> onCreated;

  @override
  ConsumerState<_NewSourceForm> createState() => _NewSourceFormState();
}

class _NewSourceFormState extends ConsumerState<_NewSourceForm> {
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  int _trustLevel = 3;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _baseUrl.text.trim().isEmpty) {
      setState(() => _error = 'Name and base URL are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(acquisitionRuntimeServiceProvider.notifier).createSourceReturning({
        'name': _name.text.trim(),
        'base_url': _baseUrl.text.trim(),
        'trust_level': _trustLevel,
        'status': 'active',
      });
      widget.onCreated(OfficialSource.fromJson(result));
    } catch (error) {
      setState(() => _error = 'Could not create the source: $error');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised,
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(isDense: true, labelText: 'Source Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(isDense: true, labelText: 'Base URL', hintText: 'https://...'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Trust Level', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _trustLevel.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  label: '$_trustLevel',
                  onChanged: (v) => setState(() => _trustLevel = v.round()),
                ),
              ),
            ],
          ),
          if (_error != null) Text(_error!, style: const TextStyle(color: StudioColors.error, fontSize: 11.5)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _saving ? null : widget.onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
