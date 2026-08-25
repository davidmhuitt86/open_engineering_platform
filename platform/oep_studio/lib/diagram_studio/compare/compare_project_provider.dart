import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart';

/// AP-OEP-DIAGRAM-COMPARE-001 — the Compare pane's own, fully independent
/// `EngineeringProjectState` (its own `EngineHost`/`EngineeringEngine`,
/// undo stack, selection, validation report).
///
/// This is not a new class — [EngineeringProjectNotifier]
/// (`core/services/engineering_project_service.dart`) is a plain,
/// stateless-construction `Notifier`; nothing about it ties it to being
/// used by only one provider. A second provider declaration is
/// sufficient to get a second, fully-independent instance, with zero
/// changes to that file. The Primary document's own
/// `engineeringProjectServiceProvider` is completely unaffected — every
/// cross-cutting Studio feature (Search, Validation, Project Explorer,
/// the Command Palette, AI context, Instruments/Simulation) keeps
/// reading that one, unaware this second provider exists.
final compareEngineeringProjectServiceProvider =
    NotifierProvider<EngineeringProjectNotifier, EngineeringProjectState>(
  EngineeringProjectNotifier.new,
);
