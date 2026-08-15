import 'session_status.dart';

/// A Knowledge Curation Session (Work Package 007 STUDIO-TASK-000014;
/// Work Package 008 STUDIO-TASK-000015; SDD-017). Persisted locally by
/// Studio as of Work Package 008 — "Sessions shall survive application
/// restart" — see `docs/KNOWLEDGE_SESSION_FORMAT.md`. No repository
/// commit occurs in this or the prior work package.
class KnowledgeSession {
  const KnowledgeSession({
    required this.id,
    required this.name,
    required this.repositoryName,
    required this.author,
    this.description = '',
    required this.createdTime,
    required this.lastModified,
    this.status = SessionStatus.created,
    this.archived = false,
  });

  final String id;
  final String name;

  /// The repository this session curates knowledge for — a name only,
  /// not a live `RepositoryStatus` reference. Work Package 007 requires
  /// "Assign: Repository" without requiring it to be the Foundation
  /// repository currently open elsewhere in Studio.
  final String repositoryName;
  final String author;
  final String description;
  final DateTime createdTime;

  /// Updated on every mutation to this session's candidates,
  /// relationship candidates, sources, or status (Work Package 008:
  /// "Persist: ... Last Modified").
  final DateTime lastModified;
  final SessionStatus status;

  /// Whether this session is archived (Work Package 008 Session
  /// Browser: "Support: ... Archive"). Independent of [status] — a
  /// session's curation-workflow stage (SDD-017) and whether it has
  /// been archived out of the Session Browser's active view are
  /// separate lifecycle dimensions; SDD-018 archives Engineering
  /// Objects the same way ("Archive does not imply deletion. Archived
  /// knowledge remains searchable") and this mirrors that for sessions.
  final bool archived;

  KnowledgeSession copyWith({
    String? name,
    String? repositoryName,
    String? author,
    String? description,
    DateTime? lastModified,
    SessionStatus? status,
    bool? archived,
  }) {
    return KnowledgeSession(
      id: id,
      name: name ?? this.name,
      repositoryName: repositoryName ?? this.repositoryName,
      author: author ?? this.author,
      description: description ?? this.description,
      createdTime: createdTime,
      lastModified: lastModified ?? this.lastModified,
      status: status ?? this.status,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'repositoryName': repositoryName,
    'author': author,
    'description': description,
    'createdTime': createdTime.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    'status': status.name,
    'archived': archived,
  };

  factory KnowledgeSession.fromJson(Map<String, dynamic> json) {
    return KnowledgeSession(
      id: json['id'] as String,
      name: json['name'] as String,
      repositoryName: json['repositoryName'] as String,
      author: json['author'] as String,
      description: json['description'] as String? ?? '',
      createdTime: DateTime.parse(json['createdTime'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      status: SessionStatus.values.byName(json['status'] as String),
      archived: json['archived'] as bool? ?? false,
    );
  }
}
