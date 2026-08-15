import 'package:flutter/material.dart';

import '../../core/models/relationship_type.dart';

/// Bundles the selection/text state for the New/Edit Relationship
/// Candidate dialog
/// (`lib/knowledge/review/relationship_candidate_form_dialog.dart`).
class RelationshipCandidateFormController {
  RelationshipCandidateFormController({
    String? sourceCandidateId,
    String? targetCandidateId,
    RelationshipType type = RelationshipType.references,
    String description = '',
  }) : sourceCandidateIdNotifier = ValueNotifier(sourceCandidateId),
       targetCandidateIdNotifier = ValueNotifier(targetCandidateId),
       typeNotifier = ValueNotifier(type),
       descriptionController = TextEditingController(text: description);

  final ValueNotifier<String?> sourceCandidateIdNotifier;
  final ValueNotifier<String?> targetCandidateIdNotifier;
  final ValueNotifier<RelationshipType> typeNotifier;
  final TextEditingController descriptionController;

  String? get sourceCandidateId => sourceCandidateIdNotifier.value;
  String? get targetCandidateId => targetCandidateIdNotifier.value;
  RelationshipType get type => typeNotifier.value;
  String get description => descriptionController.text;

  void dispose() {
    sourceCandidateIdNotifier.dispose();
    targetCandidateIdNotifier.dispose();
    typeNotifier.dispose();
    descriptionController.dispose();
  }
}
