import 'package:flutter/material.dart';

/// The engineering context kinds Work Package 015's deterministic
/// context detection recognizes (STUDIO-TASK-000042 "Detect: Support
/// contexts including..."). Purely a Studio-side organizational
/// taxonomy — not an Engineering Object type, not a Foundation
/// concept, and not a Knowledge Candidate type (`KnowledgeCandidateType`
/// is a separate, unrelated enum — a Context is never converted into
/// one; see `docs/ENGINEERING_CONTEXT.md` § Architectural Observations).
enum EngineeringContextType {
  procedure('Procedure', Icons.list_alt_outlined),
  component('Component', Icons.settings_outlined),
  connector('Connector', Icons.cable_outlined),
  circuit('Circuit', Icons.memory_outlined),
  wiringSection('Wiring Section', Icons.electrical_services_outlined),
  torqueTable('Torque Table', Icons.rotate_right),
  specificationTable('Specification Table', Icons.table_chart_outlined),
  warning('Warning', Icons.warning_amber_outlined),
  note('Note', Icons.sticky_note_2_outlined),
  figure('Figure', Icons.image_outlined),
  diagram('Diagram', Icons.schema_outlined),
  partsList('Parts List', Icons.qr_code_outlined);

  const EngineeringContextType(this.label, this.icon);

  final String label;
  final IconData icon;
}
