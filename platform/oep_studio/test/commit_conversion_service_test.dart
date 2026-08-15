import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/services/commit_conversion_service.dart';

KnowledgeCandidate _candidate({
  KnowledgeCandidateType type = KnowledgeCandidateType.component,
  String description = '',
  String notes = '',
  String author = '',
  List<String> tags = const [],
}) {
  return KnowledgeCandidate(
    id: 'c1',
    type: type,
    name: 'Timing Cover',
    description: description,
    notes: notes,
    author: author,
    tags: tags,
    createdTime: DateTime(2026, 1, 1),
  );
}

void main() {
  group('toObjectCreateArgs', () {
    test('maps the candidate type to its Foundation ObjectCategory', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(type: KnowledgeCandidateType.procedure),
        sessionId: 's1',
        sessionAuthor: 'Session Author',
      );
      expect(args.category, ObjectCategory.procedure);
    });

    test('throws ArgumentError for a candidate type with no Foundation mapping', () {
      expect(
        () => CommitConversionService.toObjectCreateArgs(
          _candidate(type: KnowledgeCandidateType.tool),
          sessionId: 's1',
          sessionAuthor: 'Session Author',
        ),
        throwsArgumentError,
      );
    });

    test('appends the candidate and session provenance tags without dropping existing tags', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(tags: const ['existing-tag']),
        sessionId: 's1',
        sessionAuthor: 'Session Author',
      );
      expect(args.tags, containsAll(['existing-tag', 'knowledge-candidate:c1', 'knowledge-session:s1']));
    });

    test('falls back to the session author when the candidate has no author', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(author: ''),
        sessionId: 's1',
        sessionAuthor: 'Session Author',
      );
      expect(args.author, 'Session Author');
    });

    test('uses the candidate\'s own author when it is set', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(author: 'Candidate Author'),
        sessionId: 's1',
        sessionAuthor: 'Session Author',
      );
      expect(args.author, 'Candidate Author');
    });

    test('description passes through unchanged when there are no notes', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(description: 'A cover.'),
        sessionId: 's1',
        sessionAuthor: 'Author',
      );
      expect(args.description, 'A cover.');
    });

    test('notes are appended to a non-empty description', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(description: 'A cover.', notes: 'Torque to spec.'),
        sessionId: 's1',
        sessionAuthor: 'Author',
      );
      expect(args.description, 'A cover.\n\nNotes: Torque to spec.');
    });

    test('notes alone become the description when the description is empty', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(description: '', notes: 'Torque to spec.'),
        sessionId: 's1',
        sessionAuthor: 'Author',
      );
      expect(args.description, 'Notes: Torque to spec.');
    });

    test('an empty description and empty notes stay empty', () {
      final args = CommitConversionService.toObjectCreateArgs(
        _candidate(description: '', notes: ''),
        sessionId: 's1',
        sessionAuthor: 'Author',
      );
      expect(args.description, '');
    });
  });

  group('toRelationshipCreateArgs', () {
    test('carries through the resolved endpoint object ids, type, and description', () {
      final relationship = RelationshipCandidate(
        id: 'rel1',
        sourceCandidateId: 'c1',
        targetCandidateId: 'c2',
        type: RelationshipType.dependsOn,
        description: 'Depends on the gasket.',
        createdTime: DateTime(2026, 1, 1),
      );
      final args = CommitConversionService.toRelationshipCreateArgs(
        relationship,
        sourceObjectId: 'obj-1',
        targetObjectId: 'obj-2',
        sessionAuthor: 'Session Author',
      );
      expect(args.sourceObjectId, 'obj-1');
      expect(args.targetObjectId, 'obj-2');
      expect(args.type, RelationshipType.dependsOn);
      expect(args.description, 'Depends on the gasket.');
    });

    test('always uses the session author, since RelationshipCandidate has no author field', () {
      final relationship = RelationshipCandidate(
        id: 'rel1',
        sourceCandidateId: 'c1',
        targetCandidateId: 'c2',
        type: RelationshipType.references,
        createdTime: DateTime(2026, 1, 1),
      );
      final args = CommitConversionService.toRelationshipCreateArgs(
        relationship,
        sourceObjectId: 'obj-1',
        targetObjectId: 'obj-2',
        sessionAuthor: 'Session Author',
      );
      expect(args.author, 'Session Author');
    });
  });
}
