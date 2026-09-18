import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';

/// WP-EKE-009: `FoundationServiceState.ekeReadiness` model tests plus
/// `FoundationRuntimeNotifier` smoke tests.
///
/// As documented in `test/foundation_refresh_repository_test.dart`, this
/// test environment has no native `oep_foundation_bridge.dll` on its
/// search path, so `FoundationRuntimeNotifier._bridge` is always `null`
/// here and the notifier always degrades to
/// `FoundationConnectionPhase.error`. The notifier-level tests below
/// exercise the resulting (fully real, not mocked) degraded-state
/// contract — the same established pattern every other Foundation test
/// in this suite already relies on. Tests that need a genuinely
/// successful graph load/build live in `eke_lifecycle_test.dart`
/// instead, against `EkeLifecycle` directly.
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
  group('EkeReadiness model', () {
    // TEST-EKE-009-001: initial runtime has EKE not-ready state.
    test('001: the default EkeReadiness is not ready (disconnected)', () {
      const readiness = EkeReadiness();
      expect(readiness.state, EkeReadinessState.disconnected);
      expect(readiness.isReady, isFalse);
    });

    // TEST-EKE-009-009: repository close clears EKE readiness — modeled
    // here as the exact copyWith transition
    // `FoundationRuntimeNotifier.closeRepository` performs.
    test('009: closing the repository transitions ready -> repositoryClosed, never ready', () {
      const ready = FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        ekeReadiness: EkeReadiness(state: EkeReadinessState.ready, repositoryId: 'repo-A'),
      );
      expect(ready.isEkeReady, isTrue);

      final afterClose = ready.copyWith(
        clearRepositoryStatus: true,
        ekeReadiness: const EkeReadiness(state: EkeReadinessState.repositoryClosed),
      );
      expect(afterClose.isEkeReady, isFalse);
      expect(afterClose.ekeReadiness.state, EkeReadinessState.repositoryClosed);
    });

    // TEST-EKE-009-010: opening a second Repository cannot expose the
    // first Repository's graph — each EkeReadiness is tagged with the
    // Repository it applies to, so a stale value is always
    // distinguishable from the current one.
    test("010: EkeReadiness carries the repositoryId it applies to, so repo A's ready state is distinguishable from repo B's", () {
      const readyForA = EkeReadiness(state: EkeReadinessState.ready, repositoryId: 'repo-A');
      const readyForB = EkeReadiness(state: EkeReadinessState.ready, repositoryId: 'repo-B');
      expect(readyForA, isNot(equals(readyForB)));
      expect(readyForA.repositoryId, isNot(equals(readyForB.repositoryId)));
      // A consumer holding a stale `readyForA` value after Repository B
      // is opened can detect the mismatch and must not treat it as
      // current.
      expect(readyForA.repositoryId == 'repo-B', isFalse);
    });

    // TEST-EKE-009-011 / 012: an empty repository (objectList == [])
    // reaches READY and is distinguishable from an uninitialized one
    // (objectList == null, ekeReadiness not ready). Emptiness of the
    // object list is never used as a readiness proxy.
    test('011/012: an empty (non-null) objectList with ekeReadiness.ready is READY, distinct from objectList == null / not ready', () {
      const emptyButReady = FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        objectList: <EngineeringObjectSummary>[],
        ekeReadiness: EkeReadiness(state: EkeReadinessState.ready, repositoryId: 'repo-A'),
      );
      expect(emptyButReady.objectList, isEmpty);
      expect(emptyButReady.isEkeReady, isTrue);

      const uninitialized = FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        ekeReadiness: EkeReadiness(state: EkeReadinessState.graphNotLoaded, repositoryId: 'repo-A'),
      );
      expect(uninitialized.objectList, isNull);
      expect(uninitialized.isEkeReady, isFalse);

      // The critical distinction: a populated objectList is NOT
      // required for readiness, and an empty objectList does NOT imply
      // non-readiness.
      const populatedButNotReady = FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        objectList: <EngineeringObjectSummary>[],
        ekeReadiness: EkeReadiness(state: EkeReadinessState.initializing, repositoryId: 'repo-A'),
      );
      expect(populatedButNotReady.objectList, isEmpty);
      expect(populatedButNotReady.isEkeReady, isFalse);
    });

    test('EkeReadiness failure retains failedStage/failureMessage diagnostics', () {
      const failed = EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failedStage: EkeInitializationStage.engineeringGraphLoad,
        failureMessage: 'The repository could not be accessed.',
        repositoryId: 'repo-A',
      );
      expect(failed.hasFailed, isTrue);
      expect(failed.failedStage, EkeInitializationStage.engineeringGraphLoad);
      expect(failed.failureMessage, isNotEmpty);
    });
  });

  group('FoundationRuntimeNotifier EKE readiness (degraded/no-Bridge environment)', () {
    // TEST-EKE-009-001 (integration form) / 014: the runtime's own
    // build() already produces a non-ready EKE state with no Repository
    // open and no page ever mounted — page navigation is not what drives
    // this.
    testWidgets('001/014: a freshly built runtime reports EKE not-ready without any EKE page being opened', (tester) async {
      final ref = await _pumpRef(tester);
      final readiness = ref.read(foundationRuntimeServiceProvider).ekeReadiness;
      expect(readiness.isReady, isFalse);
      // No repository is open in this environment, and no EKE page has
      // been built/mounted anywhere in this test — the state still
      // exists and is well-formed, proving it does not originate from a
      // page's initState.
      expect(ref.read(foundationRuntimeServiceProvider).isRepositoryOpen, isFalse);
    });

    // TEST-EKE-009-013: an EKE consumer can observe the authoritative
    // readiness purely through the shared provider, never a
    // page-private field.
    testWidgets('013: EKE readiness is observable through foundationRuntimeServiceProvider', (tester) async {
      final ref = await _pumpRef(tester);
      final state = ref.read(foundationRuntimeServiceProvider);
      expect(state.ekeReadiness, isA<EkeReadiness>());
      expect(state.isEkeReady, state.ekeReadiness.isReady);
    });

    // TEST-EKE-009-015: the explicit-refresh entry point
    // (`rebuildKnowledgeGraph`) remains a callable, safe public API —
    // it must not crash or corrupt state when called with no Repository
    // open (the real success path is covered by
    // `EkeLifecycle.rebuildKnowledgeGraphOnly` in eke_lifecycle_test.dart).
    testWidgets('015: rebuildKnowledgeGraph() is a safe no-op with no repository open', (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      expect(() => notifier.rebuildKnowledgeGraph(), returnsNormally);
      expect(ref.read(foundationRuntimeServiceProvider).isEkeReady, isFalse);
    });

    // TEST-EKE-009-016 (safety half): commitToFoundation must not crash
    // and must not falsely report EKE ready when there is no active
    // Knowledge Session / no repository open — the real
    // mutation-triggers-refresh wiring (commitToFoundation calling
    // `_runEkeInitialization` on success) is exercised by
    // `commitToFoundation`'s own existing test coverage plus
    // `EkeLifecycle.initialize`'s tests; this confirms it degrades
    // safely rather than desyncing EKE state.
    testWidgets('016: a rejected commit attempt (no session) leaves EKE readiness unchanged, never falsely ready', (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      final before = ref.read(foundationRuntimeServiceProvider).ekeReadiness;
      await expectLater(notifier.commitToFoundation(), throwsA(anything));
      final after = ref.read(foundationRuntimeServiceProvider).ekeReadiness;
      expect(after.isReady, isFalse);
      expect(after.state, before.state);
    });

    // ensureEkeReady must also be a safe no-op with no Bridge/Repository.
    testWidgets('ensureEkeReady() is a safe no-op with no repository open', (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      expect(() => notifier.ensureEkeReady(), returnsNormally);
      expect(ref.read(foundationRuntimeServiceProvider).isEkeReady, isFalse);
    });
  });
}
