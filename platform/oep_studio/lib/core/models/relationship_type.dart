import 'package:flutter/material.dart';

/// Relationship classifications. Mirrors `oep_relationship_type_t`
/// (`oep_api.h`, Work Package 013) 1:1, including numeric values —
/// Foundation's own taxonomy, not a Studio invention. Declaration order
/// matches `oep_relationship_type_t`'s declaration order, so no
/// reordering was needed when `nativeValue` was added in Work Package
/// 006 (it was already anticipated in Work Package 005, before this
/// enumeration existed).
enum RelationshipType {
  references('References', Icons.link, 0),
  contains('Contains', Icons.account_tree_outlined, 1),
  dependsOn('Depends On', Icons.arrow_forward, 2),
  connectedTo('Connected To', Icons.cable, 3),
  documents('Documents', Icons.description_outlined, 4),
  implements_('Implements', Icons.check_circle_outline, 5);

  const RelationshipType(this.label, this.icon, this.nativeValue);

  final String label;
  final IconData icon;

  /// The corresponding `oep_relationship_type_t` value.
  final int nativeValue;

  static RelationshipType fromNative(int value) {
    return RelationshipType.values.firstWhere(
      (type) => type.nativeValue == value,
      orElse: () => RelationshipType.references,
    );
  }
}
