/// An Engineering Project (WORK_PACKAGE_025, ENGINE-TASK-000118) — the
/// parent object coordinating everything an engineer works on for one
/// piece of engineering work: Knowledge (a `KnowledgeSession`), a
/// Diagram (a `DiagramDocument` file path), an Engineering Graph (owned
/// by whichever diagram document is open), Evidence, AI Sessions,
/// Validation Results, and future Simulation Sessions.
///
/// A Project coordinates existing systems — it never duplicates
/// repository, Knowledge, or Engineering Graph data. Every field below
/// is a reference (an id or a file path), not a copy: `knowledgeSessionId`
/// points at a `KnowledgeSession` already persisted by
/// `KnowledgeSessionStorage`; `diagramDocumentPath` points at a file
/// `DiagramDocument` already knows how to open; `repositoryPath` points
/// at whichever Foundation repository is open (or was last open) —
/// exactly like `KnowledgeSession.repositoryName` today, a name/path
/// only, never a live Foundation handle, since a Project may exist
/// without any repository open at all.
///
/// Deliberately implemented in `oep_studio`, not `oep_engine` or
/// `oep_foundation` — see `docs/ENGINEERING_PROJECT.md` for the full
/// ownership rationale.
class EngineeringProject {
  const EngineeringProject({
    required this.id,
    required this.name,
    this.repositoryPath,
    this.knowledgeSessionId,
    this.diagramDocumentPath,
    required this.createdTime,
    required this.lastModified,
  });

  final String id;
  final String name;

  /// The Foundation repository this project is associated with, if any
  /// — a path only, mirroring `KnowledgeSession.repositoryName`'s own
  /// "name only, not a live reference" precedent. `null` until an
  /// engineer opens or assigns one.
  final String? repositoryPath;

  /// The active `KnowledgeSession.id` for this project, if Knowledge
  /// has been added to it yet.
  final String? knowledgeSessionId;

  /// The active diagram document's file path, if a diagram has been
  /// created or opened for this project yet.
  final String? diagramDocumentPath;

  final DateTime createdTime;
  final DateTime lastModified;

  EngineeringProject copyWith({
    String? name,
    String? repositoryPath,
    bool clearRepositoryPath = false,
    String? knowledgeSessionId,
    bool clearKnowledgeSessionId = false,
    String? diagramDocumentPath,
    bool clearDiagramDocumentPath = false,
    DateTime? lastModified,
  }) {
    return EngineeringProject(
      id: id,
      name: name ?? this.name,
      repositoryPath: clearRepositoryPath ? null : (repositoryPath ?? this.repositoryPath),
      knowledgeSessionId:
          clearKnowledgeSessionId ? null : (knowledgeSessionId ?? this.knowledgeSessionId),
      diagramDocumentPath:
          clearDiagramDocumentPath ? null : (diagramDocumentPath ?? this.diagramDocumentPath),
      createdTime: createdTime,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'repositoryPath': repositoryPath,
        'knowledgeSessionId': knowledgeSessionId,
        'diagramDocumentPath': diagramDocumentPath,
        'createdTime': createdTime.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
      };

  factory EngineeringProject.fromJson(Map<String, dynamic> json) {
    return EngineeringProject(
      id: json['id'] as String,
      name: json['name'] as String,
      repositoryPath: json['repositoryPath'] as String?,
      knowledgeSessionId: json['knowledgeSessionId'] as String?,
      diagramDocumentPath: json['diagramDocumentPath'] as String?,
      createdTime: DateTime.parse(json['createdTime'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }
}
