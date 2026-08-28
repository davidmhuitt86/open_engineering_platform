import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/object_category.dart';

/// AP-OEP-FOUNDATION-BRIDGE-001 — maps Engine's [NodeCategory] (16
/// values, SDD-024) onto Foundation's [ObjectCategory] (6 values,
/// `oep_object_type_t`), for [StudioFoundationBridgePort.commitGraph].
///
/// A Dart `extension`, not a new member on [NodeCategory] itself:
/// `oep_engine` must stay Foundation-agnostic (the whole reason
/// [FoundationBridgePort] exists as an abstract interface rather than a
/// direct dependency), so this Foundation-aware mapping lives here in
/// `oep_studio` instead, alongside every other Foundation-facing type.
///
/// Same shape as the existing precedent for exactly this kind of gap —
/// `KnowledgeCandidateType.foundationCategory`
/// (`lib/knowledge/models/knowledge_candidate_type.dart`): nullable,
/// only categories with a genuine, unambiguous Foundation equivalent are
/// mapped. Everything else is `null` — excluded from commit with an
/// explicit warning by the caller, never guessed (e.g. `connector`/
/// `wire`/`relay`/`ground` are real, specific electrical concepts that
/// `ObjectCategory.component` would flatten and misrepresent).
extension NodeCategoryFoundationMapping on NodeCategory {
  ObjectCategory? get foundationCategory {
    switch (this) {
      case NodeCategory.component:
        return ObjectCategory.component;
      case NodeCategory.procedure:
        return ObjectCategory.procedure;
      case NodeCategory.connector:
      case NodeCategory.wire:
      case NodeCategory.circuit:
      case NodeCategory.harness:
      case NodeCategory.module:
      case NodeCategory.relay:
      case NodeCategory.fuse:
      case NodeCategory.switchNode:
      case NodeCategory.ground:
      case NodeCategory.sensor:
      case NodeCategory.actuator:
      case NodeCategory.measurementPoint:
      case NodeCategory.specification:
      case NodeCategory.unknown:
        return null;
    }
  }
}
