import '../../core/services/engineering_project_service.dart';

/// AP-OEP-DIAGRAM-COMPARE-001 — the Compare pane's own, fully independent
/// `EngineeringProjectState` (its own `EngineHost`/`EngineeringEngine`,
/// undo stack, selection, validation report).
///
/// This is not a new class — [EngineeringProjectNotifier]
/// (`core/services/engineering_project_service.dart`) is a plain,
/// stateless-construction notifier; nothing about it ties it to being
/// used by only one provider. A second, dedicated family key is
/// sufficient to get a second, fully-independent instance, with zero
/// changes to that file's own behavior. The Primary document's own
/// `engineeringProjectServiceProvider` is completely unaffected — every
/// cross-cutting Studio feature (Search, Validation, Project Explorer,
/// the Command Palette, AI context, Instruments/Simulation) keeps
/// reading that one, unaware this second provider exists.
///
/// AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — mechanical
/// compile-fix only, per that package's own explicit scope boundary
/// ("do not migrate Compare... unless the family conversion requires a
/// strictly mechanical change to compile"): [EngineeringProjectNotifier]
/// became a `FamilyNotifier<EngineeringProjectState, String>`, so this
/// provider must now go through [engineeringProjectServiceFamily] too —
/// bound to its own fixed, dedicated key (never a real
/// `WorkspaceTab.id`, which is always prefixed `workspace-tab-`, and
/// never [primaryDiagramInstanceId]) so it remains exactly what it
/// always was: one single, global, independent instance, unrelated to
/// any Workspace Diagram tab. No other change to Compare's behavior,
/// lifecycle, or architecture.
const _compareDiagramInstanceKey = '__compare_diagram_instance__';

final compareEngineeringProjectServiceProvider = engineeringProjectServiceFamily(_compareDiagramInstanceKey);
