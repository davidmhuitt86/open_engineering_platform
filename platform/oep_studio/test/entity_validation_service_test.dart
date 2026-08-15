import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/candidate_validation_result.dart';
import 'package:oep_studio/knowledge/models/engineering_entity.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_status.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/services/entity_validation_service.dart';

const _box = OcrBoundingBox(x: 0, y: 0, width: 0.1, height: 0.1);

EngineeringEntity _entity({
  String id = 'e1',
  EngineeringEntityType type = EngineeringEntityType.torqueSpecification,
  String normalizedValue = '24 Nm',
  double confidence = 0.9,
  String sourceId = 's1',
  EngineeringEntityStatus status = EngineeringEntityStatus.pending,
}) {
  return EngineeringEntity(
    id: id,
    type: type,
    matchedPatternId: 'torque-metric',
    extractedText: '24Nm',
    normalizedValue: normalizedValue,
    sourceId: sourceId,
    page: 1,
    boundingBox: _box,
    confidence: confidence,
    characterStart: 0,
    characterEnd: 4,
    sourceFingerprint: 'fp',
    extractedTime: DateTime(2026, 1, 1),
    status: status,
  );
}

void main() {
  group('EntityValidationService.computeValidation', () {
    test('a clean, unique, high-confidence entity has no issues', () {
      final result = EntityValidationService.computeValidation(entities: [_entity()]);
      expect(result['e1']!.severity, ValidationSeverity.ok);
      expect(result['e1']!.issues, isEmpty);
    });

    test('two non-ignored entities with the same type/value/source are flagged as duplicates', () {
      final entities = [_entity(id: 'e1'), _entity(id: 'e2')];
      final result = EntityValidationService.computeValidation(entities: entities);
      expect(result['e1']!.severity, ValidationSeverity.warning);
      expect(result['e2']!.severity, ValidationSeverity.warning);
    });

    test('an ignored duplicate does not count toward the duplicate check', () {
      final entities = [
        _entity(id: 'e1', status: EngineeringEntityStatus.ignored),
        _entity(id: 'e2'),
      ];
      final result = EntityValidationService.computeValidation(entities: entities);
      expect(result['e2']!.severity, ValidationSeverity.ok);
    });

    test('an impossible torque value is flagged as an error', () {
      final result = EntityValidationService.computeValidation(entities: [_entity(normalizedValue: '5000 Nm')]);
      expect(result['e1']!.severity, ValidationSeverity.error);
    });

    test('a negative resistance is flagged as an error', () {
      final result = EntityValidationService.computeValidation(
        entities: [_entity(type: EngineeringEntityType.resistanceValue, normalizedValue: '-10 Ω')],
      );
      expect(result['e1']!.severity, ValidationSeverity.error);
    });

    test('a temperature below absolute zero is flagged as an error', () {
      final result = EntityValidationService.computeValidation(
        entities: [_entity(type: EngineeringEntityType.temperatureValue, normalizedValue: '-300 °C')],
      );
      expect(result['e1']!.severity, ValidationSeverity.error);
    });

    test('an empty normalized value is flagged as malformed', () {
      final result = EntityValidationService.computeValidation(entities: [_entity(normalizedValue: '')]);
      expect(result['e1']!.severity, ValidationSeverity.error);
    });

    test('low OCR confidence is flagged as a warning, not an error', () {
      final result = EntityValidationService.computeValidation(entities: [_entity(confidence: 0.3)]);
      expect(result['e1']!.severity, ValidationSeverity.warning);
    });

    test('non-numeric types (e.g. part numbers) are never flagged for an impossible value', () {
      final result = EntityValidationService.computeValidation(
        entities: [_entity(type: EngineeringEntityType.partNumber, normalizedValue: '90915-YZZD4')],
      );
      expect(result['e1']!.severity, ValidationSeverity.ok);
    });
  });
}
