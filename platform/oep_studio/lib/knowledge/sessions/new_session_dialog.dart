import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controllers/session_form_controller.dart';
import '../models/knowledge_validation_exception.dart';

/// The "New Session" dialog (Work Package 007: "Create a new Knowledge
/// Curation Session. Name the session. Assign: Repository, Author,
/// Description."). Validation errors surface inline in the dialog
/// rather than as a separate dialog, since the form is still open and
/// the fix is local (Work Package 007 Error Handling: "Invalid session
/// names ... Missing repository ... Display professional validation
/// messages").
Future<void> showNewSessionDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _NewSessionDialog());
}

class _NewSessionDialog extends ConsumerStatefulWidget {
  const _NewSessionDialog();

  @override
  ConsumerState<_NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends ConsumerState<_NewSessionDialog> {
  // Owned by this State (not passed in and disposed via the dialog's
  // Future) so disposal happens exactly when Flutter tears down this
  // element — after the dialog's exit animation finishes, not the
  // instant `Navigator.pop()` is called. Disposing on the Future's
  // completion instead crashed the still-animating-out TextFields with
  // "Tried to build dirty widget in the wrong build scope".
  final _form = SessionFormController();
  String? _errorMessage;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _create() {
    try {
      ref
          .read(foundationRuntimeServiceProvider.notifier)
          .createKnowledgeSession(
            name: _form.nameController.text,
            repositoryName: _form.repositoryController.text,
            author: _form.authorController.text,
            description: _form.descriptionController.text,
          );
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('New Knowledge Curation Session'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _form.nameController,
              decoration: const InputDecoration(labelText: 'Session Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _form.repositoryController,
              decoration: const InputDecoration(labelText: 'Repository'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _form.authorController, decoration: const InputDecoration(labelText: 'Author')),
            const SizedBox(height: 12),
            TextField(
              controller: _form.descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _create, child: const Text('Create Session')),
      ],
    );
  }
}
