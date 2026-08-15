import 'package:flutter/material.dart';

import '../models/knowledge_candidate_type.dart';

/// Bundles the text/selection state for the New/Edit Knowledge
/// Candidate dialog (`lib/knowledge/review/knowledge_candidate_form_dialog.dart`)
/// so both flows share one implementation instead of duplicating three
/// form fields.
class KnowledgeCandidateFormController {
  KnowledgeCandidateFormController({
    String name = '',
    KnowledgeCandidateType type = KnowledgeCandidateType.component,
    String description = '',
    String notes = '',
    String author = '',
    List<String> tags = const [],
  }) : nameController = TextEditingController(text: name),
       descriptionController = TextEditingController(text: description),
       notesController = TextEditingController(text: notes),
       authorController = TextEditingController(text: author),
       tagsController = TextEditingController(text: tags.join(', ')),
       typeNotifier = ValueNotifier(type);

  final TextEditingController nameController;
  final TextEditingController descriptionController;

  /// Work Package 010 STUDIO-TASK-000022: "Each Knowledge Candidate
  /// shall support: ... Notes".
  final TextEditingController notesController;

  /// Work Package 010: "... Author".
  final TextEditingController authorController;

  /// Work Package 010: "... Tags" — edited as one comma-separated
  /// field, split into a list on read; no work package Requirement asks
  /// for a dedicated chip-entry widget, and a single text field keeps
  /// this dialog consistent with every other field here.
  final TextEditingController tagsController;

  final ValueNotifier<KnowledgeCandidateType> typeNotifier;

  String get name => nameController.text;
  String get description => descriptionController.text;
  String get notes => notesController.text;
  String get author => authorController.text;
  List<String> get tags => tagsController.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();
  KnowledgeCandidateType get type => typeNotifier.value;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    authorController.dispose();
    tagsController.dispose();
    typeNotifier.dispose();
  }
}
