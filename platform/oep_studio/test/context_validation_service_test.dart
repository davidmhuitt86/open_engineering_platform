import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/candidate_validation_result.dart';
import 'package:oep_studio/knowledge/models/engineering_context.dart';
import 'package:oep_studio/knowledge/models/engineering_context_status.dart';
import 'package:oep_studio/knowledge/models/engineering_context_type.dart';
import 'package:oep_studio/knowledge/models/engineering_entity.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_status.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/services/context_validation_service.dart';

const _box = OcrBoundingBox(x: 0, y: 0, width: 0.1, height: 0.1);

EngineeringContext _context({
  String id = 'c1',
  EngineeringContextType type = EngineeringContextType.torqueTable,
  String title = 'Torque Specifications',
  int pageStart = 1,
  int pageEnd = 1,
  List<String> childEntityIds = const [],
  EngineeringContextStatus status = EngineeringContextStatus.pending,
  String? parentContextId,
  String sourceId = 's1',
}) {
  return EngineeringContext(
    id: id,
    type: type,
    title: title,
    sourceId: sourceId,
    pageStart: pageStart,
    pageEnd: pageEnd,
    boundingRegion: _box,
    childEntityIds: childEntityIds,
    confidence: 0.9,
    sourceFingerprint: 'fp',
    detectedTime: DateTime(2026, 1, 1),
    status: status,
    parentContextId: parentContextId,
  );
}

EngineeringEntity _entity({String id = 'e1', int page = 1}) {
  return EngineeringEntity(
    id: id,
    type: EngineeringEntityType.torqueSpecification,
    matchedPatternId: 'torque-metric',
    extractedText: '24Nm',
    normalizedValue: '24 Nm',
    sourceId: 's1',
    page: page,
    boundingBox: _box,
    confidence: 0.9,
    characterStart: 0,
    characterEnd: 4,
    sourceFingerprint: 'fp',
    extractedTime: DateTime(2026, 1, 1),
    status: EngineeringEntityStatus.pending,
  );
}

void main() {
  group('ContextValidationService.computeValidation', () {
    test('a context with child entities and no conflicts is clean', () {
      final result = ContextValidationService.computeValidation(
        contexts: [_context(childEntityIds: const ['e1'])],
        entities: [_entity()],
      );
      expect(result['c1']!.severity, ValidationSeverity.ok);
    });

    test('a context with no child entities is flagged as empty (warning)', () {
      final result = ContextValidationService.computeValidation(contexts: [_context()], entities: const []);
      expect(result['c1']!.severity, ValidationSeverity.warning);
    });

    test('two non-ignored contexts with the same type/title/range are flagged as duplicates', () {
      final contexts = [_context(id: 'c1', childEntityIds: const ['e1']), _context(id: 'c2', childEntityIds: const ['e1'])];
      final result = ContextValidationService.computeValidation(contexts: contexts, entities: [_entity()]);
      expect(result['c1']!.severity, ValidationSeverity.warning);
      expect(result['c2']!.severity, ValidationSeverity.warning);
    });

    test('an ignored duplicate does not count toward the duplicate check', () {
      final contexts = [
        _context(id: 'c1', childEntityIds: const ['e1'], status: EngineeringContextStatus.ignored),
        _context(id: 'c2', childEntityIds: const ['e1']),
      ];
      final result = ContextValidationService.computeValidation(contexts: contexts, entities: [_entity()]);
      expect(result['c2']!.severity, ValidationSeverity.ok);
    });

    test('two non-ignored, non-parent-child contexts with overlapping page ranges are flagged', () {
      final contexts = [
        _context(id: 'c1', pageStart: 1, pageEnd: 3, childEntityIds: const ['e1']),
        _context(id: 'c2', title: 'Parts List', type: EngineeringContextType.partsList, pageStart: 2, pageEnd: 4, childEntityIds: const ['e1']),
      ];
      final result = ContextValidationService.computeValidation(contexts: contexts, entities: [_entity()]);
      expect(result['c1']!.severity, ValidationSeverity.warning);
      expect(result['c2']!.severity, ValidationSeverity.warning);
    });

    test('a parent and its nested child do not count as an invalid overlap', () {
      final contexts = [
        _context(id: 'parent', pageStart: 1, pageEnd: 5, childEntityIds: const ['e1']),
        _context(
          id: 'child',
          title: 'Warning',
          type: EngineeringContextType.warning,
          pageStart: 2,
          pageEnd: 2,
          parentContextId: 'parent',
          childEntityIds: const ['e1'],
        ),
      ];
      final result = ContextValidationService.computeValidation(contexts: contexts, entities: [_entity()]);
      expect(result['parent']!.severity, ValidationSeverity.ok);
      expect(result['child']!.severity, ValidationSeverity.ok);
    });

    test('a context whose parent no longer exists is an invalid-hierarchy error', () {
      final result = ContextValidationService.computeValidation(
        contexts: [_context(childEntityIds: const ['e1'], parentContextId: 'does-not-exist')],
        entities: [_entity()],
      );
      expect(result['c1']!.severity, ValidationSeverity.error);
    });

    test('a context whose page range falls outside its parent\'s is an invalid-hierarchy error', () {
      final contexts = [
        _context(id: 'parent', pageStart: 1, pageEnd: 2, childEntityIds: const ['e1']),
        _context(
          id: 'child',
          title: 'Warning',
          type: EngineeringContextType.warning,
          pageStart: 3,
          pageEnd: 3,
          parentContextId: 'parent',
          childEntityIds: const ['e1'],
        ),
      ];
      final result = ContextValidationService.computeValidation(contexts: contexts, entities: [_entity()]);
      expect(result['child']!.severity, ValidationSeverity.error);
    });

    test('a two-context parent cycle is an invalid-hierarchy error', () {
      final contexts = [
        _context(id: 'a', pageStart: 1, pageEnd: 5, parentContextId: 'b', childEntityIds: const ['e1']),
        _context(id: 'b', pageStart: 1, pageEnd: 5, parentContextId: 'a', childEntityIds: const ['e1']),
      ];
      final result = ContextValidationService.computeValidation(contexts: contexts, entities: [_entity()]);
      expect(result['a']!.severity, ValidationSeverity.error);
      expect(result['b']!.severity, ValidationSeverity.error);
    });
  });

  group('ContextValidationService.computeOrphanedEntityIds', () {
    test('an entity claimed by no context is orphaned', () {
      final orphaned = ContextValidationService.computeOrphanedEntityIds(
        contexts: [_context(childEntityIds: const [])],
        entities: [_entity(id: 'e1')],
      );
      expect(orphaned, {'e1'});
    });

    test('an entity claimed by an ignored context is still not orphaned', () {
      final orphaned = ContextValidationService.computeOrphanedEntityIds(
        contexts: [_context(childEntityIds: const ['e1'], status: EngineeringContextStatus.ignored)],
        entities: [_entity(id: 'e1')],
      );
      expect(orphaned, isEmpty);
    });
  });
}
