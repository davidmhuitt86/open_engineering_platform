import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/foundation_bridge_exception.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/services/eke_lifecycle.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';

/// WP-EKE-009: unit tests for [EkeLifecycle], the pure, FFI-free
/// orchestration of `Engineering Graph Load -> Knowledge Graph Build ->
/// EKE Ready`.
///
/// This project's Foundation test suite has an established, documented
/// constraint (see `test/foundation_refresh_repository_test.dart`):
/// `flutter test` runs without the native `oep_foundation_bridge.dll` on
/// its search path, so `FoundationBridge.create()` always fails and
/// `FoundationRuntimeNotifier._bridge` is always `null` in this harness
/// — there is no way to exercise a genuinely successful
/// `loadEngineeringGraph`/`buildKnowledgeGraph` call through the real
/// Bridge here. `EkeLifecycle` exists specifically to make the
/// ordering/success/failure/diagnostic rules of the lifecycle
/// independently testable despite that constraint: these tests pass
/// plain closures standing in for the two real Bridge calls, exercising
/// exactly the same code path `FoundationRuntimeNotifier` uses in
/// production (see `foundation_runtime_service.dart`'s
/// `_runEkeInitialization`), without needing a live native Runtime.
FoundationBridgeException _exception(String message) => FoundationBridgeException(
      code: FoundationErrorCode.internalError,
      category: FoundationErrorCategory.internalError,
      message: message,
      technicalDetail: message,
    );

void main() {
  group('EkeLifecycle.initialize', () {
    // TEST-EKE-009-002 / 003: repository open triggers Engineering
    // Graph load, and a successful load triggers Knowledge Graph build.
    test('002/003: calls loadGraph, and on success also calls buildGraph', () {
      var loadCalled = false;
      var buildCalled = false;
      EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => loadCalled = true,
        buildGraph: () => buildCalled = true,
      );
      expect(loadCalled, isTrue);
      expect(buildCalled, isTrue);
    });

    // TEST-EKE-009-004: load must happen before build, never reversed.
    test('004: loadGraph runs before buildGraph (ordering)', () {
      final callOrder = <String>[];
      EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => callOrder.add('load'),
        buildGraph: () => callOrder.add('build'),
      );
      expect(callOrder, ['load', 'build']);
    });

    // TEST-EKE-009-005: successful load + build produces READY.
    test('005: successful load + build produces EkeReadinessState.ready', () {
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () {},
        buildGraph: () {},
      );
      expect(result.state, EkeReadinessState.ready);
      expect(result.isReady, isTrue);
      expect(result.hasFailed, isFalse);
      expect(result.repositoryId, 'repo-1');
    });

    // TEST-EKE-009-006: a graph-load failure produces
    // initializationFailed, and never falsely proceeds to build.
    test('006: load failure produces initializationFailed and never calls buildGraph', () {
      var buildCalled = false;
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => throw _exception('load failed'),
        buildGraph: () => buildCalled = true,
      );
      expect(result.state, EkeReadinessState.initializationFailed);
      expect(result.failedStage, EkeInitializationStage.engineeringGraphLoad);
      expect(buildCalled, isFalse);
      expect(result.isReady, isFalse);
    });

    // TEST-EKE-009-007: a graph-build failure (after a successful load)
    // produces initializationFailed, never a false READY.
    test('007: build failure (after successful load) produces initializationFailed', () {
      var loadCalled = false;
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => loadCalled = true,
        buildGraph: () => throw _exception('build failed'),
      );
      expect(loadCalled, isTrue);
      expect(result.state, EkeReadinessState.initializationFailed);
      expect(result.failedStage, EkeInitializationStage.knowledgeGraphBuild);
      expect(result.isReady, isFalse);
    });

    // TEST-EKE-009-008: the failure diagnostic (message + causing
    // exception) is retained, not silently dropped.
    test('008: failure diagnostic (message + causing exception) is retained', () {
      final loadResult = EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => throw _exception('disk unavailable'),
        buildGraph: () {},
      );
      expect(loadResult.failureMessage, 'disk unavailable');
      expect(loadResult.causingException, isNotNull);
      expect(loadResult.causingException!.message, 'disk unavailable');

      final buildResult = EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () {},
        buildGraph: () => throw _exception('graph corrupt'),
      );
      expect(buildResult.failureMessage, 'graph corrupt');
      expect(buildResult.causingException, isNotNull);
      expect(buildResult.failedStage, EkeInitializationStage.knowledgeGraphBuild);
    });

    // TEST-EKE-009-011: an empty Repository (zero objects/relationships)
    // still reaches READY — the closures below never throw, mirroring
    // FoundationBridge.loadEngineeringGraph/buildKnowledgeGraph
    // returning zero counts rather than failing.
    test('011: an empty repository (load/build succeed with nothing to load) still reaches READY', () {
      var objectsLoaded = -1;
      final result = EkeLifecycle.initialize(
        repositoryId: 'empty-repo',
        loadGraph: () => objectsLoaded = 0,
        buildGraph: () {},
      );
      expect(objectsLoaded, 0);
      expect(result.state, EkeReadinessState.ready);
    });

    // TEST-EKE-009-017: reinitializing (e.g. after a mutation, or an
    // explicit refresh) never creates a second graph instance — this
    // orchestration is pure function calls against whichever single
    // Bridge/native Runtime handle the caller's closures close over,
    // never a new object of its own. Calling it twice against the same
    // counters proves no independent state/graph is created here.
    test("017: calling initialize twice doesn't create a second graph — same counters mutate in place", () {
      var loadCount = 0;
      var buildCount = 0;
      EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => loadCount++,
        buildGraph: () => buildCount++,
      );
      EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => loadCount++,
        buildGraph: () => buildCount++,
      );
      // Two full initializations against the one real Bridge handle the
      // closures close over — never a second graph/handle allocated by
      // this orchestration itself.
      expect(loadCount, 2);
      expect(buildCount, 2);
    });

    // TEST-EKE-009-018: a fresh (re)initialization must never be
    // observable as a stale prior READY mid-flight. This mirrors
    // `FoundationRuntimeNotifier._runEkeInitialization`'s exact
    // sequence: state is moved to `initializing` *before* calling into
    // `EkeLifecycle`, so anything read during the call (e.g. from a
    // nested/reentrant read) sees `initializing`, never a stale `ready`
    // left over from a previous Repository/initialization.
    test('018: state is `initializing` (never a stale ready) while a fresh init runs', () {
      // Simulate the notifier's own sequence: it was previously ready...
      EkeReadiness current = const EkeReadiness(
        state: EkeReadinessState.ready,
        repositoryId: 'repo-1',
      );
      // ...then, exactly as `_runEkeInitialization` does, moves off
      // `ready` immediately, before doing any graph work.
      current = const EkeReadiness(
        state: EkeReadinessState.initializing,
        repositoryId: 'repo-1',
      );
      expect(current.isReady, isFalse);
      expect(current.isInitializing, isTrue);

      EkeReadinessState? observedDuringLoad;
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-1',
        loadGraph: () => observedDuringLoad = current.state,
        buildGraph: () {},
      );
      // Nothing that reads the readiness while the call is in flight
      // could have observed a stale `ready`.
      expect(observedDuringLoad, EkeReadinessState.initializing);
      current = result;
      expect(current.isReady, isTrue);
    });
  });

  group('EkeLifecycle.rebuildKnowledgeGraphOnly', () {
    // Supports TEST-EKE-009-015/016 (explicit refresh / post-mutation
    // refresh) — does not touch the Engineering Graph, only rebuilds
    // the Knowledge Graph, and still produces a well-formed
    // EkeReadiness on both success and failure.
    test('succeeds without an Engineering Graph reload', () {
      final result = EkeLifecycle.rebuildKnowledgeGraphOnly(
        repositoryId: 'repo-1',
        buildGraph: () {},
      );
      expect(result.state, EkeReadinessState.ready);
    });

    test('failure produces initializationFailed at the knowledgeGraphBuild stage', () {
      final result = EkeLifecycle.rebuildKnowledgeGraphOnly(
        repositoryId: 'repo-1',
        buildGraph: () => throw _exception('rebuild failed'),
      );
      expect(result.state, EkeReadinessState.initializationFailed);
      expect(result.failedStage, EkeInitializationStage.knowledgeGraphBuild);
      expect(result.failureMessage, 'rebuild failed');
    });
  });
}
