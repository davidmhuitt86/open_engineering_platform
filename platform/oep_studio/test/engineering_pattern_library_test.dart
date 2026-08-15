import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/services/engineering_pattern_library.dart';

/// Finds the first pattern of [type] whose regex matches [text] and
/// returns its normalized value — the same "does any pattern of this
/// type recognize this text" question `EngineeringEntityExtractionService`
/// effectively asks per line, just without the OCR-word bookkeeping.
String? _firstMatchNormalized(EngineeringEntityType type, String text) {
  for (final pattern in EngineeringPatternLibrary.patternsFor(type)) {
    final match = pattern.regex.firstMatch(text);
    if (match != null) return pattern.normalize(match.group(0)!);
  }
  return null;
}

void main() {
  group('EngineeringPatternLibrary', () {
    test('every entity type has at least one pattern (STUDIO-TASK-000038 Detect list)', () {
      for (final type in EngineeringEntityType.values) {
        expect(EngineeringPatternLibrary.patternsFor(type), isNotEmpty, reason: 'missing pattern for ${type.name}');
      }
    });

    test('byId resolves a known pattern and returns null for an unknown one', () {
      expect(EngineeringPatternLibrary.byId('torque-metric'), isNotNull);
      expect(EngineeringPatternLibrary.byId('does-not-exist'), isNull);
    });

    test('torque metric', () {
      expect(_firstMatchNormalized(EngineeringEntityType.torqueSpecification, 'Torque: 24Nm'), '24 Nm');
    });

    test('torque imperial', () {
      expect(_firstMatchNormalized(EngineeringEntityType.torqueSpecification, 'Torque to 35 ft-lb'), '35 ft-lb');
    });

    test('voltage', () {
      expect(_firstMatchNormalized(EngineeringEntityType.voltageValue, 'Supply: 12V'), '12 V');
      expect(_firstMatchNormalized(EngineeringEntityType.voltageValue, '3.3V logic'), '3.3 V');
    });

    test('resistance', () {
      expect(_firstMatchNormalized(EngineeringEntityType.resistanceValue, 'R1 = 4.7kΩ'), '4.7 kΩ');
      expect(_firstMatchNormalized(EngineeringEntityType.resistanceValue, '10 ohms'), '10 Ω');
    });

    test('pressure', () {
      expect(_firstMatchNormalized(EngineeringEntityType.pressureValue, 'Inflate to 35 psi'), '35 psi');
      expect(_firstMatchNormalized(EngineeringEntityType.pressureValue, '2.5 bar'), '2.5 bar');
    });

    test('temperature', () {
      expect(_firstMatchNormalized(EngineeringEntityType.temperatureValue, 'Operating range: 82°C'), '82 °C');
      expect(_firstMatchNormalized(EngineeringEntityType.temperatureValue, '-40 C minimum'), '-40 °C');
    });

    test('dimension metric and imperial', () {
      expect(_firstMatchNormalized(EngineeringEntityType.dimension, 'Gap: 25.4mm'), '25.4 mm');
      expect(_firstMatchNormalized(EngineeringEntityType.dimension, 'Clearance 3/4 in'), '3/4 in');
    });

    test('fastener metric and SAE', () {
      expect(_firstMatchNormalized(EngineeringEntityType.fastenerSize, 'Bolt: M10x1.5'), 'M10X1.5');
      expect(_firstMatchNormalized(EngineeringEntityType.fastenerSize, 'Use 3/8-16 UNC'), '3/8-16 UNC');
    });

    test('part number', () {
      expect(_firstMatchNormalized(EngineeringEntityType.partNumber, 'Part 90915-YZZD4 required'), '90915-YZZD4');
    });

    test('tool torx and socket', () {
      expect(_firstMatchNormalized(EngineeringEntityType.toolReference, 'Use a T25 driver'), 'T25');
      expect(_firstMatchNormalized(EngineeringEntityType.toolReference, 'Use a 10mm Socket'), '10mm Socket');
    });

    test('fluid SAE, DOT, ATF', () {
      expect(_firstMatchNormalized(EngineeringEntityType.fluidSpecification, 'Fill with SAE 5W-30'), 'SAE 5W-30');
      expect(_firstMatchNormalized(EngineeringEntityType.fluidSpecification, 'Use DOT 3 fluid'), 'DOT 3');
      expect(_firstMatchNormalized(EngineeringEntityType.fluidSpecification, 'ATF Type IV'), 'ATF TYPE IV');
    });

    test('fuse rating', () {
      expect(_firstMatchNormalized(EngineeringEntityType.fuseRating, 'Replace with a 15A fuse'), '15 A');
    });

    test('connector code and pin', () {
      expect(_firstMatchNormalized(EngineeringEntityType.connectorIdentifier, 'Connector C102'), 'C102');
      expect(_firstMatchNormalized(EngineeringEntityType.connectorIdentifier, 'See Pin 12'), 'Pin 12');
    });

    test('wire color full name and abbreviation', () {
      expect(_firstMatchNormalized(EngineeringEntityType.wireColor, 'Red wire to ground'), 'Red');
      expect(_firstMatchNormalized(EngineeringEntityType.wireColor, 'BLK wire'), 'Black');
    });

    test('wire gauge', () {
      expect(_firstMatchNormalized(EngineeringEntityType.wireGauge, 'Use 14 AWG wire'), '14 AWG');
      expect(_firstMatchNormalized(EngineeringEntityType.wireGauge, '10GA wire'), '10 GA');
    });

    test('matching is deterministic - the same text always produces the same match', () {
      final first = _firstMatchNormalized(EngineeringEntityType.torqueSpecification, 'Torque: 24Nm');
      final second = _firstMatchNormalized(EngineeringEntityType.torqueSpecification, 'Torque: 24Nm');
      expect(first, second);
    });
  });
}
