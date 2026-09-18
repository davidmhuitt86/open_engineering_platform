import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/foundation_bridge_exception.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/services/eke_lifecycle.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';

/// WP-EKE-010 — tests for TEST-EKE-010-001 through -010.
///
/// WP-EKE-009 tightened `EkeReadinessState.ready` to mean "the graph is
/// initialized"; this work package tightens it further to mean "the
/// graph is synchronized with the CURRENTLY OPEN Repository's actual
/// current content" — closing the gap where a post-open Repository
/// mutation (concretely: Exchange package installation via
/// `FoundationBridge.installPackage`) could leave `ekeReadiness.state ==
/// ready` true while the cached graph was actually stale. The fix is one
/// new public method, `FoundationRuntimeNotifier.repositoryMutationOccurred()`
/// (`lib/core/services/foundation_runtime_service.dart`), which reuses
/// the exact same `EkeLifecycle`/`_runEkeInitialization` lifecycle
/// WP-EKE-009 already established — see that method's own doc comment.
///
/// **These tests are explicitly split into three kinds, per this work
/// package's own requirement not to just re-test `EkeLifecycle.initialize()`
/// again (WP-EKE-009 already proved its mechanics in
/// `eke_lifecycle_test.dart`):**
///
/// 1. **Model/mechanics tests** (group "EkeLifecycle mechanics reused by
///    repositoryMutationOccurred") — directly exercise `EkeLifecycle.initialize`
///    with the exact `fullReload: true` shape `repositoryMutationOccurred()`
///    uses, with fake `loadGraph`/`buildGraph` closures. These prove the
///    load-then-build ordering and success/failure classification that
///    the mutation-sync path depends on — NOT proof that the wiring from
///    a mutation-owner into that lifecycle actually exists.
/// 2. **Consumer integration tests** (group "FoundationRuntimeNotifier.repositoryMutationOccurred
///    integration") — drive the REAL, unmodified
///    `FoundationRuntimeNotifier`/`ExchangeRuntimeNotifier`/
///    `package_manager_page` wiring through Riverpod. As documented in
///    `test/core/services/foundation_eke_readiness_test.dart`, this test
///    environment has no native `oep_foundation_bridge.dll` on its
///    search path, so `FoundationRuntimeNotifier._bridge` is always
///    `null` here — every call in this group necessarily exercises the
///    real "no Repository open" no-op branch of `repositoryMutationOccurred()`,
///    proving it is safe, idempotent, and never fabricates `ready` in
///    that branch. It does NOT prove the full mutation -> ready
///    transition, which requires a real Repository/Bridge — see (3).
/// 3. **Native Foundation integration** — `test/exchange_rc1_e2e_test.dart`
///    ("AC-01..11: the full RC1 vertical slice installs a real package
///    through Foundation") was extended by this work package with a
///    WP-EKE-010 assertion block proving the FULL
///    `ExchangeRuntimeNotifier.installPackage` -> `repositoryMutationOccurred`
///    -> `EkeLifecycle.initialize` -> real `loadEngineeringGraph`/
///    `buildKnowledgeGraph` FFI -> `ekeReadiness.state == ready` ->
///    query-sees-the-mutation flow, against the real, unmodified
///    `oep_foundation_bridge.dll` (skips, never fakes, if that DLL isn't
///    present in this environment — see that file's own doc comment).
///    This is the ONE piece of coverage this file's group (2) cannot
///    provide, reusing Exchange RC1's own existing real-Foundation
///    harness rather than inventing a second one.
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
  group('EkeLifecycle mechanics reused by repositoryMutationOccurred (model tests)', () {
    // TEST-EKE-010-003 (mechanics half): a mutation-triggered full
    // reload (loadGraph then buildGraph, both succeeding) reaches ready.
    test('003: fullReload success (load then build, both succeed) reaches ready', () {
      var loadCalled = false;
      var buildCalledAfterLoad = false;
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-mutated',
        loadGraph: () => loadCalled = true,
        buildGraph: () => buildCalledAfterLoad = loadCalled,
      );
      expect(result.state, EkeReadinessState.ready);
      expect(loadCalled, isTrue);
      expect(buildCalledAfterLoad, isTrue);
    });

    // TEST-EKE-010-004: a mutation followed by an Engineering Graph
    // Load failure lands on initializationFailed at the load stage —
    // build is never attempted.
    test('004: fullReload Engineering Graph Load failure => initializationFailed, build never attempted', () {
      var buildCalled = false;
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-mutated',
        loadGraph: () => throw FoundationBridgeException.fromResult(
          code: FoundationErrorCode.operationFailed,
          category: FoundationErrorCategory.io,
          technicalDetail: 'engineering graph load failed after mutation',
        ),
        buildGraph: () => buildCalled = true,
      );
      expect(result.state, EkeReadinessState.initializationFailed);
      expect(result.failedStage, EkeInitializationStage.engineeringGraphLoad);
      expect(result.causingException, isNotNull);
      expect(buildCalled, isFalse);
    });

    // TEST-EKE-010-005: a mutation followed by a Knowledge Graph Build
    // failure (after a successful load) lands on initializationFailed at
    // the build stage.
    test('005: fullReload Knowledge Graph Build failure (after a successful load) => initializationFailed', () {
      final result = EkeLifecycle.initialize(
        repositoryId: 'repo-mutated',
        loadGraph: () {},
        buildGraph: () => throw FoundationBridgeException.fromResult(
          code: FoundationErrorCode.operationFailed,
          category: FoundationErrorCategory.io,
          technicalDetail: 'knowledge graph build failed after mutation',
        ),
      );
      expect(result.state, EkeReadinessState.initializationFailed);
      expect(result.failedStage, EkeInitializationStage.knowledgeGraphBuild);
      expect(result.causingException, isNotNull);
    });

    // TEST-EKE-010-007 (mechanics half): a fresh initialize() call after
    // a prior failure (the shape ensureEkeReady()/a later
    // repositoryMutationOccurred() call reuses) can reach ready — nothing
    // about a prior failure poisons a later attempt.
    test('007: a fresh fullReload after a prior failure can reach ready (recovery)', () {
      final failed = EkeLifecycle.initialize(
        repositoryId: 'repo-mutated',
        loadGraph: () => throw FoundationBridgeException.fromResult(
          code: FoundationErrorCode.operationFailed,
          category: FoundationErrorCategory.io,
          technicalDetail: 'transient failure',
        ),
        buildGraph: () {},
      );
      expect(failed.hasFailed, isTrue);

      final recovered = EkeLifecycle.initialize(
        repositoryId: 'repo-mutated',
        loadGraph: () {},
        buildGraph: () {},
      );
      expect(recovered.state, EkeReadinessState.ready);
    });
  });

  group('FoundationRuntimeNotifier.repositoryMutationOccurred integration (degraded/no-Bridge environment)', () {
    // TEST-EKE-010-001 (consumer-integration half; the full
    // success-path half lives in the native integration test described
    // in this file's own top-level doc comment): repositoryMutationOccurred
    // is a real, callable, public entry point on the SAME notifier every
    // other EKE lifecycle trigger (openRepository/ensureEkeReady/
    // rebuildKnowledgeGraph/commitToFoundation) uses — not a second
    // service.
    testWidgets('001: repositoryMutationOccurred() is a safe, callable public entry point', (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      expect(() => notifier.repositoryMutationOccurred(), returnsNormally);
    });

    // TEST-EKE-010-002: calling repositoryMutationOccurred() never
    // fabricates a false `ready` — with no Repository open (this
    // environment's only reachable branch), readiness must stay exactly
    // what it already was (disconnected/error), never jump to ready
    // behind a mutation that hasn't actually been resynchronized.
    testWidgets('002: repositoryMutationOccurred() never leaves readiness falsely ready with no repository open',
        (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      final before = ref.read(foundationRuntimeServiceProvider).ekeReadiness;
      notifier.repositoryMutationOccurred();
      final after = ref.read(foundationRuntimeServiceProvider).ekeReadiness;
      expect(after.isReady, isFalse);
      expect(after.state, before.state);
    });

    // TEST-EKE-010-006 (safety half; the real-mutation half is native-
    // Foundation-only, see this file's top-level doc comment): calling
    // repositoryMutationOccurred() never closes, reopens, or otherwise
    // disturbs whatever Repository/connection state already existed —
    // it only ever touches ekeReadiness. The Repository stays whatever
    // it already was; this call is never a rollback trigger.
    testWidgets('006: repositoryMutationOccurred() does not touch repository/connection state, only ekeReadiness',
        (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      final before = ref.read(foundationRuntimeServiceProvider);
      notifier.repositoryMutationOccurred();
      final after = ref.read(foundationRuntimeServiceProvider);
      expect(after.phase, before.phase);
      expect(after.runtimeState, before.runtimeState);
      expect(after.repositoryStatus, before.repositoryStatus);
    });

    // TEST-EKE-010-007 (consumer-integration half): ensureEkeReady()
    // remains callable and safe immediately after a
    // repositoryMutationOccurred() call — the same recovery path every
    // other initializationFailed case already uses, with no new
    // mechanism needed for this trigger point.
    testWidgets('007: ensureEkeReady() remains safely callable after repositoryMutationOccurred()', (tester) async {
      final ref = await _pumpRef(tester);
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      notifier.repositoryMutationOccurred();
      expect(() => notifier.ensureEkeReady(), returnsNormally);
      expect(ref.read(foundationRuntimeServiceProvider).isEkeReady, isFalse);
    });
  });

  group('TEST-EKE-010-008: Exchange never reaches into Foundation internals directly (source inspection)', () {
    final repoRoot = _findRepoRoot();

    // Exchange's install orchestration must call ONLY the new public
    // `FoundationRuntimeNotifier.repositoryMutationOccurred()` method —
    // never `EkeLifecycle`, never `FoundationBridge`'s own graph methods,
    // never a private (`_`-prefixed) `FoundationRuntimeNotifier` member.
    for (final relativePath in [
      'lib/exchange/services/exchange_runtime_service.dart',
      'lib/exchange/services/exchange_install_bridge.dart',
      'lib/exchange/services/exchange_api_client.dart',
    ]) {
      test('$relativePath does not call EkeLifecycle/FoundationBridge graph methods or private notifier members',
          () {
        final file = File('${repoRoot.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}');
        expect(file.existsSync(), isTrue, reason: 'expected to find $relativePath relative to the oep_studio package root');
        final source = file.readAsStringSync();
        expect(source.contains('EkeLifecycle.initialize(') || source.contains('EkeLifecycle.rebuildKnowledgeGraphOnly('), isFalse,
            reason: 'Exchange must not call EkeLifecycle directly — only through FoundationRuntimeNotifier.repositoryMutationOccurred()');
        expect(source.contains('.loadEngineeringGraph('), isFalse,
            reason: 'Exchange must not call FoundationBridge.loadEngineeringGraph directly');
        expect(source.contains('.buildKnowledgeGraph('), isFalse,
            reason: 'Exchange must not call FoundationBridge.buildKnowledgeGraph directly');
        // No access to a private (`_`-prefixed) FoundationRuntimeNotifier
        // member — `.notifier)._` would be the shape of such a reach-in.
        expect(RegExp(r'foundationRuntimeServiceProvider\.notifier\)\._\w').hasMatch(source), isFalse,
            reason: 'Exchange must not access FoundationRuntimeNotifier private members');
      });
    }

    test('exchange_runtime_service.dart calls the new public repositoryMutationOccurred() after a successful install',
        () {
      final file = File(
          '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}exchange${Platform.pathSeparator}services${Platform.pathSeparator}exchange_runtime_service.dart');
      final source = file.readAsStringSync();
      expect(source.contains('repositoryMutationOccurred()'), isTrue);
      // Never named Exchange-specifically — it belongs to the
      // Repository/runtime boundary, not to Exchange.
      expect(source.contains('rebuildEkeBecauseExchangeInstalledPackage'), isFalse);
    });
  });

  group('TEST-EKE-010-009: commitToFoundation performs exactly one EKE synchronization (no duplicate trigger)', () {
    test('the commitToFoundation method body calls _runEkeInitialization exactly once', () {
      final repoRoot = _findRepoRoot();
      final file = File(
          '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}core${Platform.pathSeparator}services${Platform.pathSeparator}foundation_runtime_service.dart');
      final source = file.readAsStringSync();
      final methodStart = source.indexOf('Future<void> commitToFoundation()');
      expect(methodStart, greaterThan(-1));
      // The method body runs until the next top-level method at the
      // same indentation — approximated here by the next
      // "\n  Future<void>" or "\n  void " after the opening brace, which
      // is precise enough for this file's own consistent 2-space class
      // member formatting.
      final afterStart = source.substring(methodStart);
      final bodyEnd = RegExp(r'\n  (Future<void>|void|Map<String, String>) ').firstMatch(afterStart.substring(1));
      final body = bodyEnd == null ? afterStart : afterStart.substring(0, bodyEnd.start + 1);
      final occurrences = '_runEkeInitialization('.allMatches(body).length;
      expect(occurrences, 1,
          reason: 'commitToFoundation must call _runEkeInitialization exactly once on success — found $occurrences');
    });
  });

  group('TEST-EKE-010-010: Diagram Intelligence specialized refresh remains behaviorally intact', () {
    // WP-EKE-009's own AAR and WP-EKE-FOLLOWUP-001's audit both found
    // `DiagramIntelligenceService` has its own separate
    // loadEngineeringGraph/buildKnowledgeGraph calls, outside the
    // FoundationRuntimeNotifier lifecycle, deliberately left alone as
    // "not yet UI-wired." This work package's own audit re-verified that
    // finding still holds: `DiagramStudioController.intelligence` is
    // declared but never assigned/constructed anywhere in production
    // code, so `DiagramIntelligenceService` remains unreachable from any
    // UI — no readiness-consistency violation results from leaving it
    // untouched. This test proves both halves: the file was not modified
    // by this work package, and the controller field is still never
    // constructed.
    test('DiagramIntelligenceService.sync still performs its own load+build (unchanged) and is still unreachable from UI', () {
      final repoRoot = _findRepoRoot();
      final serviceFile = File(
          '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}diagram_studio${Platform.pathSeparator}intelligence${Platform.pathSeparator}diagram_intelligence_service.dart');
      final source = serviceFile.readAsStringSync();
      expect(source.contains('await Future(() => _bridge.loadEngineeringGraph());'), isTrue);
      expect(source.contains('await Future(() => _bridge.buildKnowledgeGraph());'), isTrue);

      final controllerFile = File(
          '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}diagram_studio${Platform.pathSeparator}controller${Platform.pathSeparator}diagram_studio_controller.dart');
      final controllerSource = controllerFile.readAsStringSync();
      expect(controllerSource.contains('DiagramIntelligenceService? intelligence;'), isTrue);
      // Never constructed/assigned anywhere in this file — confirms it
      // remains unreachable from the UI, exactly as before this work
      // package.
      expect(RegExp(r'intelligence\s*=\s*DiagramIntelligenceService').hasMatch(controllerSource), isFalse);
    });
  });
}

/// Locates the `oep_studio` package root (the directory containing this
/// package's `pubspec.yaml`) from the test runner's working directory,
/// so the source-inspection tests above work whether `flutter test` is
/// invoked from the package root or the repo root.
Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
        Directory('${dir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}exchange').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate the oep_studio package root from ${Directory.current.path}');
    }
    dir = parent;
  }
}
