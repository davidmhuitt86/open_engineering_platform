import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/ai_request.dart';
import 'package:oep_studio/knowledge/services/mock_ai_provider.dart';

AiRequest _request({
  List<String> entityIds = const [],
  List<String> contextIds = const [],
  Map<String, String> labels = const {},
}) {
  return AiRequest(
    id: 'req-1',
    systemPrompt: 'system',
    userPrompt: 'user',
    sourceId: 's1',
    referencedEntityIds: entityIds,
    referencedContextIds: contextIds,
    evidenceLabels: labels,
    createdTime: DateTime(2026, 1, 1),
  );
}

void main() {
  group('MockAiProvider', () {
    test('makes no network activity and always succeeds', () async {
      final provider = MockAiProvider();
      final response = await provider.complete(_request());
      expect(response.success, isTrue);
      expect(response.providerId, 'mock');
    });

    test('produces zero suggestions for a request with no referenced evidence', () async {
      final provider = MockAiProvider();
      final response = await provider.complete(_request());
      final decoded = jsonDecode(response.rawText) as Map<String, dynamic>;
      expect(decoded['suggestions'], isEmpty);
    });

    test('produces one suggestion per referenced context when contexts are present', () async {
      final provider = MockAiProvider();
      final response = await provider.complete(
        _request(
          contextIds: const ['c1', 'c2'],
          entityIds: const ['e1'],
          labels: const {'c1': 'Torque Table', 'c2': 'Parts List', 'e1': '24 Nm'},
        ),
      );
      final decoded = jsonDecode(response.rawText) as Map<String, dynamic>;
      final suggestions = decoded['suggestions'] as List;
      expect(suggestions, hasLength(2));
    });

    test('falls back to one suggestion per referenced entity when there are no contexts', () async {
      final provider = MockAiProvider();
      final response = await provider.complete(
        _request(entityIds: const ['e1', 'e2'], labels: const {'e1': '24 Nm', 'e2': '35 ft-lb'}),
      );
      final decoded = jsonDecode(response.rawText) as Map<String, dynamic>;
      final suggestions = decoded['suggestions'] as List;
      expect(suggestions, hasLength(2));
    });

    test('every suggestion has all required fields with valid values', () async {
      final provider = MockAiProvider();
      final response = await provider.complete(_request(contextIds: const ['c1'], labels: const {'c1': 'Torque Table'}));
      final decoded = jsonDecode(response.rawText) as Map<String, dynamic>;
      final suggestion = (decoded['suggestions'] as List).first as Map<String, dynamic>;
      expect(suggestion['type'], isA<String>());
      expect(suggestion['name'], isA<String>());
      expect(suggestion['description'], isA<String>());
      expect(suggestion['confidence'], isA<num>());
      expect((suggestion['confidence'] as num).toDouble(), inInclusiveRange(0.0, 1.0));
      expect(suggestion['reasoning'], isA<String>());
      expect(suggestion['supportingContextIds'], ['c1']);
    });

    test('is deterministic: the same request always produces byte-identical output', () async {
      final provider = MockAiProvider();
      final request = _request(contextIds: const ['c1'], labels: const {'c1': 'Torque Table'});
      final first = await provider.complete(request);
      final second = await provider.complete(request);
      expect(first.rawText, second.rawText);
    });

    test('different evidence ids can produce different suggested types', () async {
      final provider = MockAiProvider();
      final response = await provider.complete(
        _request(
          contextIds: const ['context-alpha', 'context-beta', 'context-gamma', 'context-delta'],
          labels: const {
            'context-alpha': 'A',
            'context-beta': 'B',
            'context-gamma': 'C',
            'context-delta': 'D',
          },
        ),
      );
      final decoded = jsonDecode(response.rawText) as Map<String, dynamic>;
      final types = (decoded['suggestions'] as List).map((s) => (s as Map<String, dynamic>)['type']).toSet();
      expect(types.length, greaterThan(1), reason: 'a real mix of ids should not collapse to a single type');
    });
  });
}
