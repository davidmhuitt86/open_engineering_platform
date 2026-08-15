import 'package:flutter/material.dart';

import '../../core/models/object_category.dart';

/// Knowledge Candidate types the Engineering Review panel's manual
/// authoring workflow supports (Work Package 007/008, expanded to ten
/// types by Work Package 010 STUDIO-TASK-000022). Mirrors SDD-015's
/// Layer 3 Engineering Objects and SDD-021's Evidence Object examples —
/// the subset this workspace's manual (non-AI) workflow covers.
enum KnowledgeCandidateType {
  component('Component', Icons.category_outlined, ObjectCategory.component),
  procedure('Procedure', Icons.checklist_outlined, ObjectCategory.procedure),
  specification('Specification', Icons.rule_outlined, null),
  tool('Tool', Icons.build_outlined, null),
  material('Material', Icons.layers_outlined, null),
  fluid('Fluid', Icons.water_drop_outlined, null),
  warning('Warning', Icons.warning_amber_outlined, null),
  measurement('Measurement', Icons.straighten_outlined, null),
  image('Image', Icons.image_outlined, ObjectCategory.image),
  document('Document', Icons.description_outlined, ObjectCategory.document);

  const KnowledgeCandidateType(this.label, this.icon, this.foundationCategory);

  final String label;
  final IconData icon;

  /// The `ObjectCategory` (and therefore `oep_object_type_t`) this
  /// candidate type becomes on Repository Commit (Work Package 012
  /// STUDIO-TASK-000031: "Convert Knowledge Candidate → Foundation
  /// Engineering Object") — `null` for the six types Foundation's fixed,
  /// six-value `oep_object_type_t` has no corresponding entry for
  /// (Specification, Tool, Material, Fluid, Warning, Measurement).
  ///
  /// This gap was first flagged as an architectural observation in Work
  /// Package 008 (`docs/KNOWLEDGE_SESSION_FORMAT.md`), restated in Work
  /// Package 010 when Specification/Tool/Material/Fluid/Warning/
  /// Measurement were added to this enum, and is now load-bearing: a
  /// candidate whose `foundationCategory` is `null` cannot be converted
  /// to a real Engineering Object without either modifying Foundation's
  /// `oep_object_type_t` (forbidden — "Do not modify OEP Foundation")
  /// or guessing an unprincipled substitute mapping (e.g. Tool →
  /// Component) that would misrepresent what the candidate actually is.
  /// `CommitPlanService` therefore excludes these six types from "New
  /// Engineering Objects" with an explicit validation error rather than
  /// silently reinterpreting them — see `docs/REPOSITORY_COMMIT.md` §
  /// Architectural Observations.
  final ObjectCategory? foundationCategory;
}
