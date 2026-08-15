import '../models/candidate_validation_result.dart';
import '../models/engineering_entity.dart';
import '../models/engineering_entity_type.dart';
import '../models/entity_validation_result.dart';

/// Entity Validation (Work Package 014 STUDIO-TASK-000041): "Detect:
/// Duplicate entities, Invalid units, Impossible values, Malformed
/// specifications, OCR uncertainty. Display validation warnings. No
/// automatic correction." Pure — reads a list of already-extracted
/// entities, returns findings; never mutates an entity, never fixes
/// anything it finds wrong.
abstract final class EntityValidationService {
  /// Below this confidence, an entity is flagged for manual
  /// verification rather than trusted outright — "OCR uncertainty."
  /// Chosen the same way `OcrPageResult`'s own confidence thresholds
  /// were: a judgment call with no spec-given number, set low enough
  /// that a clean, well-scanned page's real matches don't trigger it,
  /// but a plausible garbled-OCR misread does.
  static const lowConfidenceThreshold = 0.6;

  static Map<String, EntityValidationResult> computeValidation({required List<EngineeringEntity> entities}) {
    final duplicateCounts = <String, int>{};
    for (final entity in entities) {
      if (entity.isIgnored) continue;
      final key = _duplicateKey(entity);
      duplicateCounts[key] = (duplicateCounts[key] ?? 0) + 1;
    }

    final results = <String, EntityValidationResult>{};
    for (final entity in entities) {
      final issues = <String>[];
      var severity = ValidationSeverity.ok;
      void flag(String message, ValidationSeverity level) {
        issues.add(message);
        if (level.index > severity.index) severity = level;
      }

      if (!entity.isIgnored && (duplicateCounts[_duplicateKey(entity)] ?? 0) > 1) {
        flag(
          'Duplicate of another ${entity.type.label} with the same normalized value on this source.',
          ValidationSeverity.warning,
        );
      }

      final malformedOrInvalidUnit = _malformedOrInvalidUnit(entity);
      if (malformedOrInvalidUnit != null) {
        flag(malformedOrInvalidUnit, ValidationSeverity.error);
      }

      final impossibleValue = _impossibleValue(entity);
      if (impossibleValue != null) {
        flag(impossibleValue, ValidationSeverity.error);
      }

      if (entity.confidence < lowConfidenceThreshold) {
        flag(
          'Low OCR confidence (${(entity.confidence * 100).round()}%) — verify against the source manually.',
          ValidationSeverity.warning,
        );
      }

      results[entity.id] = EntityValidationResult(entityId: entity.id, severity: severity, issues: issues);
    }
    return results;
  }

  static String _duplicateKey(EngineeringEntity entity) => '${entity.sourceId}|${entity.type.name}|${entity.normalizedValue}';

  /// "Invalid units, Malformed specifications" — in practice, every
  /// pattern in `EngineeringPatternLibrary` is anchored to a known unit
  /// and only normalizes text it successfully matched, so this mostly
  /// cannot fire through the normal extraction path. Kept as an
  /// explicit, defensive check (an empty normalized value, or a numeric
  /// type whose normalized text carries no parseable leading number)
  /// rather than assumed impossible — this work package's own
  /// Requirements name both findings explicitly.
  static String? _malformedOrInvalidUnit(EngineeringEntity entity) {
    if (entity.normalizedValue.trim().isEmpty) {
      return 'This entity could not be normalized into a usable value.';
    }
    if (_isNumericType(entity.type) && _leadingNumber(entity.normalizedValue) == null) {
      return 'This entity\'s normalized value has no recognizable numeric value or unit.';
    }
    return null;
  }

  static String? _impossibleValue(EngineeringEntity entity) {
    final value = _leadingNumber(entity.normalizedValue);
    if (value == null) return null;
    switch (entity.type) {
      case EngineeringEntityType.torqueSpecification:
        if (value <= 0 || value > 1000) return 'Torque value ($value) is outside a plausible range (0-1000).';
      case EngineeringEntityType.voltageValue:
        if (value.abs() > 100000) return 'Voltage value ($value) is outside a plausible range.';
      case EngineeringEntityType.resistanceValue:
        if (value < 0) return 'Resistance cannot be negative ($value).';
      case EngineeringEntityType.pressureValue:
        if (value < 0) return 'Pressure cannot be negative ($value).';
      case EngineeringEntityType.temperatureValue:
        final isCelsius = entity.normalizedValue.contains('°C');
        final absoluteZero = isCelsius ? -273.15 : -459.67;
        if (value < absoluteZero) return 'Temperature ($value) is below absolute zero.';
      case EngineeringEntityType.wireGauge:
        if (value < 0 || value > 40) return 'Wire gauge ($value AWG) is outside a plausible range (0-40).';
      case EngineeringEntityType.fuseRating:
        if (value <= 0 || value > 600) return 'Fuse rating ($value A) is outside a plausible range.';
      case EngineeringEntityType.dimension:
        if (value < 0) return 'A dimension cannot be negative ($value).';
      case EngineeringEntityType.fastenerSize:
      case EngineeringEntityType.partNumber:
      case EngineeringEntityType.toolReference:
      case EngineeringEntityType.fluidSpecification:
      case EngineeringEntityType.connectorIdentifier:
      case EngineeringEntityType.wireColor:
        return null;
    }
    return null;
  }

  static bool _isNumericType(EngineeringEntityType type) => switch (type) {
    EngineeringEntityType.torqueSpecification ||
    EngineeringEntityType.voltageValue ||
    EngineeringEntityType.resistanceValue ||
    EngineeringEntityType.pressureValue ||
    EngineeringEntityType.temperatureValue ||
    EngineeringEntityType.dimension ||
    EngineeringEntityType.wireGauge ||
    EngineeringEntityType.fuseRating => true,
    EngineeringEntityType.fastenerSize ||
    EngineeringEntityType.partNumber ||
    EngineeringEntityType.toolReference ||
    EngineeringEntityType.fluidSpecification ||
    EngineeringEntityType.connectorIdentifier ||
    EngineeringEntityType.wireColor => false,
  };

  static double? _leadingNumber(String text) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }
}
