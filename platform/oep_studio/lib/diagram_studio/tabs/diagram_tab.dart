import '../../core/context/engineering_interaction_context.dart';

/// (OEP Diagram Studio -- Phase 5, Part 2/Part 20.) One browser-style
/// tab: a reference to an open diagram document plus its own
/// independent mode. `path == null` means an unsaved/untitled document
/// (matches `DiagramDocument.path`'s own real nullability, not
/// invented).
///
/// **Architectural note (Part 1/Part 20)**: `EngineeringProjectState`
/// (`engineering_project_service.dart`) holds exactly ONE live
/// `DiagramDocument`/`EditingSession` -- confirmed by inspection, this
/// is deeply load-bearing (the shared DMM/Simulation runtime providers
/// Phase 2 established are themselves single-instance, scoped to that
/// one session). Building genuine concurrent multi-session editing
/// would mean redesigning `EngineeringProjectService` and the shared
/// runtime providers -- explicitly out of scope for this incremental
/// phase (Part 24/26). A `DiagramTab` is therefore a real, persisted
/// REFERENCE to a document (path/title/pin/mode); at most one tab is
/// "active" at a time, and its content is what the single shared
/// engine/session actually holds. Switching tabs goes through the
/// existing, unmodified Open/Save/Close/dirty-check pipeline
/// (`DiagramStudioPage._confirmDiscardChanges`,
/// `EngineeringProjectNotifier.openDocument`) -- never a second
/// document model.
class DiagramTab {
  const DiagramTab({
    required this.id,
    this.path,
    this.title = 'Untitled Diagram',
    this.pinned = false,
    this.mode = DiagramStudioMode.edit,
  });

  final String id;
  final String? path;
  final String title;
  final bool pinned;
  final DiagramStudioMode mode;

  DiagramTab copyWith({
    String? path,
    bool clearPath = false,
    String? title,
    bool? pinned,
    DiagramStudioMode? mode,
  }) =>
      DiagramTab(
        id: id,
        path: clearPath ? null : (path ?? this.path),
        title: title ?? this.title,
        pinned: pinned ?? this.pinned,
        mode: mode ?? this.mode,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'pinned': pinned,
        'mode': mode.name,
      };

  static DiagramTab? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String) return null;
    return DiagramTab(
      id: id,
      path: raw['path'] as String?,
      title: raw['title'] as String? ?? 'Untitled Diagram',
      pinned: raw['pinned'] as bool? ?? false,
      mode: DiagramStudioMode.values.firstWhere(
        (m) => m.name == raw['mode'],
        orElse: () => DiagramStudioMode.edit,
      ),
    );
  }
}
