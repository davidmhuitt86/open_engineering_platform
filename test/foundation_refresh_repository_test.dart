import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';

/// `FoundationRuntimeNotifier.refreshRepository()` (WP-EXC-010) -- the
/// new public entry point Exchange's Repository Integration calls after
/// an install, added alongside `openRepository`/`closeRepository` rather
/// than reaching into the previously-private `_refreshRepositoryData`.
/// Mirrors `command_registry_test.dart`'s `_pumpRef` helper for getting a
/// live `WidgetRef` outside a full widget tree.
Future<WidgetRef> _pumpRef(WidgetTester tester) async {
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return capturedRef;
}

void main() {
  testWidgets('refreshRepository is a no-op when no repository is open '
      '(this test environment has no Foundation Bridge DLL, so the '
      'notifier degrades to an error/closed phase on its own)', (tester) async {
    final ref = await _pumpRef(tester);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    expect(ref.read(foundationRuntimeServiceProvider).isRepositoryOpen, isFalse);

    // Must not throw even though no repository is open.
    notifier.refreshRepository();

    expect(ref.read(foundationRuntimeServiceProvider).isRepositoryOpen, isFalse);
  });
}
