import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/ai_analysis_exception.dart';
import 'package:oep_studio/knowledge/services/ai_suggestion_parser.dart';

String _validResponse() => jsonEncode({
  'suggestions': [
    {
      'type': 'component',
      'name': 'Oil Filter',
      'description': 'A replaceable oil filter.',
      'confidence': 0.75,
      'reasoning': 'Referenced by part number entity.',
      'supportingEntityIds': ['e1'],
      'supportingContextIds': <String>[],
    },
  ],
});

void main() {
  group('AiSuggestionParser.parse', () {
    test('parses a well-formed response into an AiSuggestion', () {
      final suggestions = AiSuggestionParser.parse(
        _validResponse(),
        sourceId: 's1',
        providerId: 'mock',
        modelId: 'mock-deterministic-v1',
        sourceFingerprint: 'fp-1',
      );
      expect(suggestions, hasLength(1));
      final suggestion = suggestions.first;
      expect(suggestion.suggestedName, 'Oil Filter');
      expect(suggestion.confidence, 0.75);
      expect(suggestion.supportingEntityIds, ['e1']);
      expect(suggestion.sourceId, 's1');
      expect(suggestion.providerId, 'mock');
      expect(suggestion.sourceFingerprint, 'fp-1');
      expect(suggestion.isPending, isTrue);
    });

    test('throws on non-JSON text', () {
      expect(
        () => AiSuggestionParser.parse('not json at all', sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('throws when the top level is not a JSON object', () {
      expect(
        () => AiSuggestionParser.parse('[1,2,3]', sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('throws when "suggestions" is missing', () {
      expect(
        () => AiSuggestionParser.parse(jsonEncode({'foo': 'bar'}), sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('throws when a suggestion is missing its type', () {
      final malformed = jsonEncode({
        'suggestions': [
          {'name': 'X', 'description': '', 'confidence': 0.5, 'reasoning': 'why'},
        ],
      });
      expect(
        () => AiSuggestionParser.parse(malformed, sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('throws on an unrecognized candidate type', () {
      final malformed = jsonEncode({
        'suggestions': [
          {'type': 'not-a-real-type', 'name': 'X', 'description': '', 'confidence': 0.5, 'reasoning': 'why'},
        ],
      });
      expect(
        () => AiSuggestionParser.parse(malformed, sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('throws when confidence is missing or not numeric', () {
      final malformed = jsonEncode({
        'suggestions': [
          {'type': 'component', 'name': 'X', 'description': '', 'reasoning': 'why'},
        ],
      });
      expect(
        () => AiSuggestionParser.parse(malformed, sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('throws when reasoning is missing', () {
      final malformed = jsonEncode({
        'suggestions': [
          {'type': 'component', 'name': 'X', 'description': '', 'confidence': 0.5},
        ],
      });
      expect(
        () => AiSuggestionParser.parse(malformed, sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp'),
        throwsA(isA<AiAnalysisException>()),
      );
    });

    test('an empty suggestions list parses to an empty list, not an error', () {
      final suggestions = AiSuggestionParser.parse(
        jsonEncode({'suggestions': <dynamic>[]}),
        sourceId: 's1',
        providerId: 'p',
        modelId: 'm',
        sourceFingerprint: 'fp',
      );
      expect(suggestions, isEmpty);
    });

    test('clamps an out-of-range confidence into 0.0-1.0', () {
      final malformed = jsonEncode({
        'suggestions': [
          {'type': 'component', 'name': 'X', 'description': '', 'confidence': 5.0, 'reasoning': 'why'},
        ],
      });
      final suggestions = AiSuggestionParser.parse(malformed, sourceId: 's1', providerId: 'p', modelId: 'm', sourceFingerprint: 'fp');
      expect(suggestions.first.confidence, 1.0);
    });
  });
}
