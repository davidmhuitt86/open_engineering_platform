import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'title_block_storage.dart';

/// AP-DS-004: Title Block + Revision Management editor. Loads/saves via
/// [TitleBlockStorage], keyed by [diagramKey] (see that file's doc
/// comment for the persistence design decision). Follows
/// `PackageValidationDialog`'s visual convention (`AlertDialog` +
/// `StudioColors.surfaceRaised`, labeled rows).
class TitleBlockEditorDialog extends StatefulWidget {
  const TitleBlockEditorDialog({required this.diagramKey, super.key});

  final String diagramKey;

  static Future<void> show(BuildContext context, {required String diagramKey}) {
    return showDialog<void>(
      context: context,
      builder: (_) => TitleBlockEditorDialog(diagramKey: diagramKey),
    );
  }

  @override
  State<TitleBlockEditorDialog> createState() => _TitleBlockEditorDialogState();
}

class _TitleBlockEditorDialogState extends State<TitleBlockEditorDialog> {
  TitleBlock _block = TitleBlock.empty;
  bool _loading = true;
  final _customKeyCtrl = TextEditingController();
  final _customValueCtrl = TextEditingController();

  late final Map<String, TextEditingController> _controllers = {
    'company': TextEditingController(),
    'project': TextEditingController(),
    'drawingNumber': TextEditingController(),
    'revision': TextEditingController(),
    'engineer': TextEditingController(),
    'approver': TextEditingController(),
    'scale': TextEditingController(),
    'sheet': TextEditingController(),
    'classification': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    TitleBlockStorage.load(widget.diagramKey).then((block) {
      if (!mounted) return;
      setState(() {
        _block = block;
        _loading = false;
        _controllers['company']!.text = block.company;
        _controllers['project']!.text = block.project;
        _controllers['drawingNumber']!.text = block.drawingNumber;
        _controllers['revision']!.text = block.revision;
        _controllers['engineer']!.text = block.engineer;
        _controllers['approver']!.text = block.approver;
        _controllers['scale']!.text = block.scale;
        _controllers['sheet']!.text = block.sheet;
        _controllers['classification']!.text = block.classification;
      });
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _customKeyCtrl.dispose();
    _customValueCtrl.dispose();
    super.dispose();
  }

  TitleBlock _collect() => _block.copyWith(
        company: _controllers['company']!.text,
        project: _controllers['project']!.text,
        drawingNumber: _controllers['drawingNumber']!.text,
        revision: _controllers['revision']!.text,
        engineer: _controllers['engineer']!.text,
        approver: _controllers['approver']!.text,
        scale: _controllers['scale']!.text,
        sheet: _controllers['sheet']!.text,
        classification: _controllers['classification']!.text,
      );

  Future<void> _save() async {
    final block = _collect();
    await TitleBlockStorage.save(widget.diagramKey, block);
    if (mounted) Navigator.of(context).pop();
  }

  void _addCustomField() {
    final key = _customKeyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _block = _block.copyWith(customFields: {..._block.customFields, key: _customValueCtrl.text});
      _customKeyCtrl.clear();
      _customValueCtrl.clear();
    });
  }

  void _addRevision() {
    setState(() {
      _block = _block.copyWith(revisionHistory: [
        ..._block.revisionHistory,
        RevisionEntry(
          revisionNumber: 'R${_block.revisionHistory.length + 1}',
          description: '',
          author: _controllers['engineer']!.text,
          date: DateTime.now(),
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Title Block & Revisions', style: TextStyle(color: StudioColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 520,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: StudioColors.selection))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in const [
                      MapEntry('company', 'Company'),
                      MapEntry('project', 'Project'),
                      MapEntry('drawingNumber', 'Drawing Number'),
                      MapEntry('revision', 'Revision'),
                      MapEntry('engineer', 'Engineer'),
                      MapEntry('approver', 'Approver'),
                      MapEntry('scale', 'Scale'),
                      MapEntry('sheet', 'Sheet'),
                      MapEntry('classification', 'Classification'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 130, child: Text(entry.value, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11.5))),
                            Expanded(
                              child: TextField(
                                key: Key('titleblock_field_${entry.key}'),
                                controller: _controllers[entry.key],
                                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Text('Custom Fields', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    for (final field in _block.customFields.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text('${field.key}: ${field.value}', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12))),
                            IconButton(
                              iconSize: 16,
                              icon: const Icon(Icons.close, color: StudioColors.textDisabled),
                              onPressed: () => setState(() {
                                _block = _block.copyWith(
                                  customFields: {..._block.customFields}..remove(field.key),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('titleblock_custom_key'),
                            controller: _customKeyCtrl,
                            decoration: const InputDecoration(isDense: true, hintText: 'Field name'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _customValueCtrl,
                            decoration: const InputDecoration(isDense: true, hintText: 'Value'),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.add, size: 18), onPressed: _addCustomField),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Revision History', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        IconButton(
                          key: const Key('titleblock_add_revision'),
                          iconSize: 18,
                          tooltip: 'Add revision',
                          icon: const Icon(Icons.add_circle_outline, color: StudioColors.selection),
                          onPressed: _addRevision,
                        ),
                      ],
                    ),
                    for (var i = 0; i < _block.revisionHistory.length; i++) _RevisionRow(
                      entry: _block.revisionHistory[i],
                      onChanged: (updated) => setState(() {
                        final list = [..._block.revisionHistory];
                        list[i] = updated;
                        _block = _block.copyWith(revisionHistory: list);
                      }),
                      onDelete: () => setState(() {
                        final list = [..._block.revisionHistory]..removeAt(i);
                        _block = _block.copyWith(revisionHistory: list);
                      }),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(key: const Key('titleblock_save'), onPressed: _loading ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

class _RevisionRow extends StatefulWidget {
  const _RevisionRow({required this.entry, required this.onChanged, required this.onDelete});

  final RevisionEntry entry;
  final ValueChanged<RevisionEntry> onChanged;
  final VoidCallback onDelete;

  @override
  State<_RevisionRow> createState() => _RevisionRowState();
}

class _RevisionRowState extends State<_RevisionRow> {
  late final _numberCtrl = TextEditingController(text: widget.entry.revisionNumber);
  late final _descCtrl = TextEditingController(text: widget.entry.description);
  late final _notesCtrl = TextEditingController(text: widget.entry.notes);

  void _emit() {
    widget.onChanged(RevisionEntry(
      revisionNumber: _numberCtrl.text,
      description: _descCtrl.text,
      author: widget.entry.author,
      date: widget.entry.date,
      approvalStatus: widget.entry.approvalStatus,
      notes: _notesCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: TextField(controller: _numberCtrl, onChanged: (_) => _emit(), decoration: const InputDecoration(isDense: true)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(controller: _descCtrl, onChanged: (_) => _emit(), decoration: const InputDecoration(isDense: true, hintText: 'Description')),
          ),
          const SizedBox(width: 6),
          DropdownButton<RevisionApprovalStatus>(
            value: widget.entry.approvalStatus,
            underline: const SizedBox.shrink(),
            items: [
              for (final s in RevisionApprovalStatus.values)
                DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(fontSize: 11))),
            ],
            onChanged: (status) {
              if (status == null) return;
              widget.onChanged(RevisionEntry(
                revisionNumber: _numberCtrl.text,
                description: _descCtrl.text,
                author: widget.entry.author,
                date: widget.entry.date,
                approvalStatus: status,
                notes: _notesCtrl.text,
              ));
            },
          ),
          IconButton(iconSize: 16, icon: const Icon(Icons.close, color: StudioColors.textDisabled), onPressed: widget.onDelete),
        ],
      ),
    );
  }
}
