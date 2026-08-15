import 'package:flutter/material.dart';

/// Bundles the text state for the New Knowledge Curation Session
/// dialog (`lib/knowledge/sessions/new_session_dialog.dart`).
class SessionFormController {
  SessionFormController()
    : nameController = TextEditingController(),
      repositoryController = TextEditingController(),
      authorController = TextEditingController(),
      descriptionController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController repositoryController;
  final TextEditingController authorController;
  final TextEditingController descriptionController;

  void dispose() {
    nameController.dispose();
    repositoryController.dispose();
    authorController.dispose();
    descriptionController.dispose();
  }
}
