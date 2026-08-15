import 'package:flutter/material.dart';

/// Engineering Object categories shown by the Repository Explorer
/// (STUDIO-TASK-000005) and Object Explorer (STUDIO-TASK-000006).
/// Mirrors `oep_object_type_t` (`oep_api.h`) 1:1, including numeric
/// values — this is Foundation's own taxonomy, not a Studio invention.
// Declaration order is the required display order (Components,
// Documents, Diagrams, Procedures, Images, Projects — SDD-008, Work
// Packages 003/004), independent of oep_object_type_t's own ordinal
// order, which nativeValue tracks separately.
enum ObjectCategory {
  component('Components', Icons.category_outlined, 2),
  document('Documents', Icons.description_outlined, 0),
  diagram('Diagrams', Icons.account_tree_outlined, 1),
  procedure('Procedures', Icons.checklist_outlined, 3),
  image('Images', Icons.image_outlined, 5),
  project('Projects', Icons.folder_special_outlined, 4);

  const ObjectCategory(this.label, this.icon, this.nativeValue);

  final String label;
  final IconData icon;

  /// The corresponding `oep_object_type_t` value.
  final int nativeValue;

  static ObjectCategory fromNative(int value) {
    return ObjectCategory.values.firstWhere(
      (category) => category.nativeValue == value,
      orElse: () => ObjectCategory.document,
    );
  }
}
