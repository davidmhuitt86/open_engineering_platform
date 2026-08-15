import 'package:flutter/material.dart';

import 'knowledge_candidate_type.dart';

/// The engineering entity kinds Work Package 014's deterministic
/// pattern matching recognizes (STUDIO-TASK-000038 "Detect: Support
/// recognition of..."). Purely a Studio-side detection taxonomy — not
/// an Engineering Object type, not a Foundation concept.
enum EngineeringEntityType {
  torqueSpecification('Torque Specification', Icons.rotate_right, KnowledgeCandidateType.specification),
  voltageValue('Voltage Value', Icons.bolt_outlined, KnowledgeCandidateType.specification),
  resistanceValue('Resistance Value', Icons.waves_outlined, KnowledgeCandidateType.specification),
  pressureValue('Pressure Value', Icons.speed_outlined, KnowledgeCandidateType.specification),
  temperatureValue('Temperature Value', Icons.thermostat_outlined, KnowledgeCandidateType.specification),
  dimension('Dimension', Icons.straighten_outlined, KnowledgeCandidateType.specification),
  fastenerSize('Fastener Size', Icons.hardware_outlined, KnowledgeCandidateType.specification),
  partNumber('Part Number', Icons.qr_code_outlined, KnowledgeCandidateType.component),
  toolReference('Tool Reference', Icons.build_outlined, KnowledgeCandidateType.tool),
  fluidSpecification('Fluid Specification', Icons.water_drop_outlined, KnowledgeCandidateType.fluid),
  fuseRating('Fuse Rating', Icons.electric_bolt_outlined, KnowledgeCandidateType.specification),
  connectorIdentifier('Connector Identifier', Icons.cable_outlined, KnowledgeCandidateType.component),
  wireColor('Wire Color', Icons.palette_outlined, KnowledgeCandidateType.specification),
  wireGauge('Wire Gauge', Icons.linear_scale_outlined, KnowledgeCandidateType.specification);

  const EngineeringEntityType(this.label, this.icon, this.defaultCandidateType);

  final String label;
  final IconData icon;

  /// Which [KnowledgeCandidateType] an accepted entity of this kind
  /// becomes by default (STUDIO-TASK-000039: "Acceptance shall create a
  /// Knowledge Candidate"). Grounded in SDD-015's own Specification
  /// Model ("Torque, Voltage, Resistance, Pressure, Temperature,
  /// Clearance" are named Specification examples) and Component Model
  /// ("Components may possess: Part Numbers") — this mapping reuses
  /// that vocabulary rather than inventing a parallel one. Part
  /// Numbers and Connector Identifiers identify physical Components;
  /// Tool References and Fluid Specifications map directly onto the
  /// existing `tool`/`fluid` candidate types; everything else
  /// (measurement-like values and attributes) maps to `specification`.
  /// The engineer may still change the type before saving the created
  /// candidate — this is only the sensible starting default, not a
  /// restriction.
  final KnowledgeCandidateType defaultCandidateType;
}
