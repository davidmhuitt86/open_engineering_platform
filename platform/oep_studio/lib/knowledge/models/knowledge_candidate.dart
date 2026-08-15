import 'knowledge_candidate_status.dart';
import 'knowledge_candidate_type.dart';

/// A manually-created Engineering Object candidate within a Knowledge
/// Curation Session (Work Package 007 STUDIO-TASK-000014, Work Package
/// 008 STUDIO-TASK-000015).
///
/// Named "Knowledge Candidate" rather than "Proposal" — Work Package
/// 008's internal-naming direction ("begin transitioning internal
/// naming from 'Proposal' toward 'Knowledge Candidate'"), matching
/// [RelationshipCandidate]'s naming (`relationship_candidate.dart`) so
/// both "things awaiting engineering review" share one vocabulary.
///
/// SDD-018's "Draft" lifecycle state ("Created during an active
/// Knowledge Curation Session. Not yet committed. Visible only within
/// the session.") until persisted (Work Package 008), after which it
/// survives restart but is still pre-commit — SDD-018's "Draft" state
/// covers both. Carries no AI confidence/evidence/repository-match
/// fields yet — no AI or repository-matching workflow exists in this
/// or the prior work package; those fields belong to the fuller
/// candidate model SDD-016/SDD-020 describe once that workflow exists.
class KnowledgeCandidate {
  const KnowledgeCandidate({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.notes = '',
    this.author = '',
    this.tags = const [],
    this.status = KnowledgeCandidateStatus.pending,
    required this.createdTime,
    this.modifiedTime,
    this.committedObjectId,
    this.committedTime,
  });

  final String id;
  final KnowledgeCandidateType type;
  final String name;
  final String description;

  /// Free-form engineering notes, separate from [description] (Work
  /// Package 010 STUDIO-TASK-000022: "Each Knowledge Candidate shall
  /// support: ... Notes").
  final String notes;

  /// Who authored this candidate — distinct from [KnowledgeSession.author]
  /// (the session owner), since a session may accumulate candidates
  /// contributed by more than one engineer.
  final String author;

  /// Free-form labels (Work Package 010: "Each Knowledge Candidate shall
  /// support: ... Tags").
  final List<String> tags;

  final KnowledgeCandidateStatus status;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  /// The Foundation `object_id` this candidate became on Repository
  /// Commit (Work Package 012 STUDIO-TASK-000031), `null` until
  /// committed. "Knowledge Candidates remain in the Knowledge Session
  /// after Commit" (this work package's own text) — this field is how
  /// the session remembers a candidate was already committed, so a
  /// later commit of the same session never creates a duplicate
  /// Foundation object for it. Once set, nothing in this work package
  /// ever clears it — Commit is one-way.
  final String? committedObjectId;

  /// When [committedObjectId] was set, `null` iff [committedObjectId]
  /// is `null`.
  final DateTime? committedTime;

  /// Whether this candidate has already been committed to Foundation.
  bool get isCommitted => committedObjectId != null;

  KnowledgeCandidate copyWith({
    KnowledgeCandidateType? type,
    String? name,
    String? description,
    String? notes,
    String? author,
    List<String>? tags,
    KnowledgeCandidateStatus? status,
    DateTime? modifiedTime,
    String? committedObjectId,
    DateTime? committedTime,
  }) {
    return KnowledgeCandidate(
      id: id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      committedObjectId: committedObjectId ?? this.committedObjectId,
      committedTime: committedTime ?? this.committedTime,
    );
  }

  /// Serializes to the shape `docs/KNOWLEDGE_SESSION_FORMAT.md`
  /// documents for `session.json`'s `candidates` array.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'description': description,
    'notes': notes,
    'author': author,
    'tags': tags,
    'status': status.name,
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime?.toIso8601String(),
    'committedObjectId': committedObjectId,
    'committedTime': committedTime?.toIso8601String(),
  };

  /// Deserializes a `candidates` array entry. Throws [FormatException]
  /// (caught and translated by `KnowledgeSessionStorage`) if a required
  /// field is missing or an enum value is unrecognized — surfaced to
  /// the engineer as "Corrupted session files" (Work Package 008 Error
  /// Handling), never a raw stack trace. [notes]/[author]/[tags] default
  /// when absent so a pre-Work-Package-010 session file still loads
  /// (Work Package 009 established this same backward-compatibility
  /// pattern for its own new fields).
  factory KnowledgeCandidate.fromJson(Map<String, dynamic> json) {
    return KnowledgeCandidate(
      id: json['id'] as String,
      type: KnowledgeCandidateType.values.byName(json['type'] as String),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      author: json['author'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((tag) => tag as String).toList() ?? const [],
      status: KnowledgeCandidateStatus.values.byName(json['status'] as String),
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null ? null : DateTime.parse(json['modifiedTime'] as String),
      committedObjectId: json['committedObjectId'] as String?,
      committedTime: json['committedTime'] == null ? null : DateTime.parse(json['committedTime'] as String),
    );
  }
}
