import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/eke_consumer_gate.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';

/// WP-EKE-011 — tests for TEST-EKE-011-003 through -012.
///
/// AP-EKE-012-F2 found a hazard in `FoundationRuntimeNotifier.openRepository()`:
/// when Repository A is open and a switch to Repository B fails, the
/// method's `catch` block only recorded `lastError` — it left `state`
/// (repository status, object/relationship lists, and crucially
/// `ekeReadiness`) representing Repository A as still open and possibly
/// still `ready`, even though the Runtime itself no longer has A open
/// (it was closed first, per `openRepository`'s own documented "if a
/// different repository is already open, it is closed first"
/// contract). This file proves the fix: on a failed open/switch, `state`
/// is resynchronized from `FoundationBridge.state` — the Runtime's own
/// ground truth — and `ekeReadiness` is never left `ready`.
///
/// **Test kinds in this file, stated explicitly per this work package's
/// own requirement:**
///
/// - Every `test(...)` in the "real native Repository switch" group
///   below drives the REAL, unmodified `FoundationRuntimeNotifier`
///   against the REAL, unmodified `oep_foundation_bridge.dll` (via
///   `FoundationBridge.create()`/`openRepository()`/`closeRepository()`
///   over real temp-directory Repositories) — real native Foundation
///   integration, not a mock. A genuine open failure is induced by
///   pointing at a directory with no `repository.json` (Foundation's
///   real installer/runtime rejects this the same way it would reject
///   any missing/invalid Repository on disk), exactly the same
///   `FoundationBridgeException` shape production code already handles
///   — no fake/seam is introduced. Skips (never fakes) if
///   `oep_foundation_bridge.dll` is not present in this environment,
///   mirroring `test/exchange_rc1_e2e_test.dart`'s own
///   `setUpRealStack` skip/fail classification so a stale/incompatible
///   DLL still fails loudly rather than skipping silently.
/// - The "EkeConsumerGate re-verification" group is a pure/unit test —
///   no Bridge, no Riverpod — directly exercising
///   `EkeConsumerGate.allows`/`blockedMessage` against every
///   `EkeReadinessState` value.
/// - The "source inspection" group re-confirms (does not re-derive) the
///   WP-EKE-010 invariants that Exchange never reaches into EKE
///   internals and that `commitToFoundation` synchronizes exactly once,
///   in this work package's own numbering — it does not re-implement
///   `eke_010_repository_mutation_sync_test.dart`'s own coverage, it
///   corroborates it still holds after this work package's changes.
void main() {
  Directory writeValidRepo(String repositoryId, String name) {
    final dir = Directory.systemTemp.createTempSync('oep_eke011_${name}_');
    File('${dir.path}${Platform.pathSeparator}repository.json').writeAsStringSync(
      '{"repositoryId":"$repositoryId",'
      '"repositoryName":"$name",'
      '"repositoryVersion":"1.0.0",'
      '"foundationVersion":"0.1.0",'
      '"templateVersion":"1.0",'
      '"createdUtc":"2026-01-01T00:00:00Z",'
      '"lastModifiedUtc":"2026-01-01T00:00:00Z"}',
    );
    return dir;
  }

  /// A path guaranteed to make `FoundationBridge.openRepository` fail —
  /// a freshly created-then-deleted temp directory, i.e. a path that
  /// does not exist on disk at all. Foundation's real runtime rejects
  /// this with a real `FoundationBridgeException` (`notFound`/`io`),
  /// exactly as proved by this file's own exploratory probe against the
  /// real DLL before this test was written.
  String bogusRepositoryPath(String tag) {
    final dir = Directory.systemTemp.createTempSync('oep_eke011_missing_${tag}_');
    dir.deleteSync();
    return dir.path;
  }

  group('WP-EKE-011 real native Repository switch (AP-EKE-012-F2)', () {
    late Directory dirA;
    late Directory dirC;
    late List<Directory> cleanupDirs;

    setUp(() {
      cleanupDirs = [];
    });

    tearDown(() {
      for (final dir in cleanupDirs) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    /// Sets up a real `ProviderContainer` with the production
    /// `FoundationRuntimeNotifier`, skipping (via `markTestSkipped`) if
    /// `oep_foundation_bridge.dll` cannot be loaded in this environment,
    /// and failing loudly (never skipping) if it loads but is stale —
    /// the same classification `exchange_rc1_e2e_test.dart` already
    /// uses.
    ProviderContainer? setUpContainer() {
      final container = ProviderContainer();
      final foundationState = container.read(foundationRuntimeServiceProvider);
      if (foundationState.phase == FoundationConnectionPhase.error) {
        final detail = foundationState.lastError?.technicalDetail ?? '';
        if (detail.contains('Failed to lookup symbol')) {
          fail(
            'oep_foundation_bridge.dll loaded but is stale/incompatible with the current Foundation API '
            '($detail). Run `flutter build windows --debug` then `dart run '
            'tool/sync_foundation_bridge_dll.dart`.',
          );
        }
        container.dispose();
        markTestSkipped(
          'oep_foundation_bridge.dll is not present in this environment (Foundation was not built here).',
        );
        return null;
      }
      return container;
    }

    // TEST-EKE-011-003: Repository A open and EKE ready -> a Repository
    // B switch fails -> ekeReadiness must not remain (or become) ready.
    testWidgets('003: a failed Repository switch cannot leave EKE ready', (tester) async {
      final container = setUpContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      dirA = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a1', 'switch_a');
      cleanupDirs.add(dirA);
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);

      notifier.openRepository(dirA.path);
      final readyState = container.read(foundationRuntimeServiceProvider);
      expect(readyState.isRepositoryOpen, isTrue);
      expect(readyState.ekeReadiness.state, EkeReadinessState.ready,
          reason: readyState.ekeReadiness.failureMessage);

      final bogusPath = bogusRepositoryPath('003');
      expect(() => notifier.openRepository(bogusPath), throwsA(isA<Object>()));

      final afterFailure = container.read(foundationRuntimeServiceProvider);
      expect(afterFailure.ekeReadiness.state, isNot(EkeReadinessState.ready));
      expect(afterFailure.ekeReadiness.isReady, isFalse);
    });

    // TEST-EKE-011-004: the failed switch clears/invalidates stale
    // Repository A state -- repositoryStatus/object/relationship lists
    // must not keep presenting Repository A's identity or content as
    // current.
    testWidgets('004: a failed Repository switch clears stale Repository A state', (tester) async {
      final container = setUpContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      dirA = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a2', 'switch_a2');
      cleanupDirs.add(dirA);
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);

      notifier.openRepository(dirA.path);
      final openState = container.read(foundationRuntimeServiceProvider);
      expect(openState.repositoryStatus, isNotNull);

      final bogusPath = bogusRepositoryPath('004');
      expect(() => notifier.openRepository(bogusPath), throwsA(isA<Object>()));

      final afterFailure = container.read(foundationRuntimeServiceProvider);
      // Repository A was closed by openRepository()'s own pre-close step
      // before B's open was even attempted -- state must reflect that,
      // not continue reporting A's status/lists as current.
      expect(afterFailure.isRepositoryOpen, isFalse);
      expect(afterFailure.repositoryStatus, isNull);
      expect(afterFailure.objectList, isNull);
      expect(afterFailure.relationshipList, isNull);
      expect(afterFailure.repositoryStatistics, isNull);
    });

    // TEST-EKE-011-005: after a failed switch, the Foundation runtime
    // itself (the Bridge/connection, not just a particular Repository)
    // remains usable -- the failure is recoverable, not a poisoned
    // connection.
    testWidgets('005: a failed Repository switch leaves the Foundation runtime connection recoverable',
        (tester) async {
      final container = setUpContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      dirA = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a3', 'switch_a3');
      cleanupDirs.add(dirA);
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);

      notifier.openRepository(dirA.path);
      final bogusPath = bogusRepositoryPath('005');
      expect(() => notifier.openRepository(bogusPath), throwsA(isA<Object>()));

      final afterFailure = container.read(foundationRuntimeServiceProvider);
      // Connected to Foundation, just no Repository open -- never
      // degraded to the error phase by a Repository-level failure.
      expect(afterFailure.phase, FoundationConnectionPhase.connected);
      expect(notifier.bridge, isNotNull);
      // A harmless no-op call must not throw against the now-Repository-
      // less runtime -- proves the connection itself is still alive.
      expect(() => notifier.closeRepository(), returnsNormally);
    });

    // TEST-EKE-011-006: a subsequent VALID Repository open after a
    // failed switch reaches EKE ready again -- the failure does not
    // block future initialization.
    testWidgets('006: a subsequent valid Repository open after a failed switch reaches EKE ready', (tester) async {
      final container = setUpContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      dirA = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a4', 'switch_a4');
      cleanupDirs.add(dirA);
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);

      notifier.openRepository(dirA.path);
      final bogusPath = bogusRepositoryPath('006');
      expect(() => notifier.openRepository(bogusPath), throwsA(isA<Object>()));

      dirC = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a5', 'switch_c');
      cleanupDirs.add(dirC);
      notifier.openRepository(dirC.path);

      final recovered = container.read(foundationRuntimeServiceProvider);
      expect(recovered.isRepositoryOpen, isTrue);
      expect(recovered.repositoryStatus?.repositoryId, '2c8f3a10-1111-4222-8333-0000000000a5');
      expect(recovered.ekeReadiness.state, EkeReadinessState.ready, reason: recovered.ekeReadiness.failureMessage);
    });

    // TEST-EKE-011-007: a SUCCESSFUL Repository switch (A ready -> B
    // opens successfully) still reaches a fresh EKE ready for B -- a
    // successful switch is not a "failure" case, but this proves the
    // fix above did not regress the ordinary switch path, and that
    // readiness is genuinely re-derived for B, not carried over from A.
    testWidgets('007: a successful Repository switch reaches a fresh EKE ready for the new Repository',
        (tester) async {
      final container = setUpContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      dirA = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a6', 'switch_a6');
      cleanupDirs.add(dirA);
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);

      notifier.openRepository(dirA.path);
      final afterA = container.read(foundationRuntimeServiceProvider);
      expect(afterA.ekeReadiness.state, EkeReadinessState.ready);
      expect(afterA.repositoryStatus?.repositoryId, '2c8f3a10-1111-4222-8333-0000000000a6');

      dirC = writeValidRepo('2c8f3a10-1111-4222-8333-0000000000a7', 'switch_b_ok');
      cleanupDirs.add(dirC);
      notifier.openRepository(dirC.path);

      final afterB = container.read(foundationRuntimeServiceProvider);
      expect(afterB.isRepositoryOpen, isTrue);
      expect(afterB.repositoryStatus?.repositoryId, '2c8f3a10-1111-4222-8333-0000000000a7');
      expect(afterB.ekeReadiness.state, EkeReadinessState.ready, reason: afterB.ekeReadiness.failureMessage);
      expect(afterB.ekeReadiness.repositoryId, '2c8f3a10-1111-4222-8333-0000000000a7');
    });
  });

  group('WP-EKE-011 EkeConsumerGate re-verification (TEST-EKE-011-012, pure/unit)', () {
    // Re-verifies WP-EKE-FOLLOWUP-001's execution gate still blocks
    // every state except `ready`, in this work package's own context —
    // an EKE operation must be blocked, not merely display an error,
    // whenever the graph is not genuinely ready.
    test('012: only EkeReadinessState.ready allows an EKE operation to execute', () {
      for (final state in EkeReadinessState.values) {
        final readiness = EkeReadiness(state: state);
        final allowed = EkeConsumerGate.allows(readiness);
        if (state == EkeReadinessState.ready) {
          expect(allowed, isTrue, reason: '$state must allow execution');
        } else {
          expect(allowed, isFalse, reason: '$state must block execution');
        }
      }
    });

    test('012: blockedMessage surfaces the real failure diagnostic when one was recorded', () {
      const readiness = EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failureMessage: 'engineering graph load failed: disk error',
      );
      expect(EkeConsumerGate.blockedMessage(readiness), 'engineering graph load failed: disk error');
    });

    test('012: blockedMessage falls back to a generic message with no recorded diagnostic', () {
      const readiness = EkeReadiness(state: EkeReadinessState.graphNotLoaded);
      expect(EkeConsumerGate.blockedMessage(readiness), 'Engineering Knowledge Engine is not ready.');
    });
  });

  group('WP-EKE-011 source-inspection re-verification (TEST-EKE-011-009/010/011)', () {
    final repoRoot = _findRepoRoot();

    // TEST-EKE-011-009: commitToFoundation still performs exactly one
    // EKE synchronization on success -- re-verified in this work
    // package's own context (unchanged by the WP-EKE-011 F2 fix, which
    // only touches openRepository's catch block).
    test('009: commitToFoundation still calls _runEkeInitialization exactly once', () {
      final file = File(
        '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}core${Platform.pathSeparator}services${Platform.pathSeparator}foundation_runtime_service.dart',
      );
      final source = file.readAsStringSync();
      final methodStart = source.indexOf('Future<void> commitToFoundation()');
      expect(methodStart, greaterThan(-1));
      final afterStart = source.substring(methodStart);
      final bodyEnd = RegExp(r'\n  (Future<void>|void|Map<String, String>) ').firstMatch(afterStart.substring(1));
      final body = bodyEnd == null ? afterStart : afterStart.substring(0, bodyEnd.start + 1);
      final occurrences = '_runEkeInitialization('.allMatches(body).length;
      expect(occurrences, 1,
          reason: 'commitToFoundation must call _runEkeInitialization exactly once on success — found $occurrences');
    });

    // TEST-EKE-011-010: Exchange still never reaches into EKE
    // lifecycle/readiness internals directly -- re-verified in this
    // work package's own context.
    for (final relativePath in [
      'lib/exchange/services/exchange_runtime_service.dart',
      'lib/exchange/services/exchange_install_bridge.dart',
      'lib/exchange/services/exchange_api_client.dart',
    ]) {
      test('010: $relativePath still does not touch EkeLifecycle/FoundationBridge graph methods directly', () {
        final file = File(
            '${repoRoot.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}');
        expect(file.existsSync(), isTrue, reason: 'expected to find $relativePath relative to the oep_studio package root');
        final source = file.readAsStringSync();
        expect(source.contains('EkeLifecycle.initialize(') || source.contains('EkeLifecycle.rebuildKnowledgeGraphOnly('),
            isFalse);
        expect(source.contains('.loadEngineeringGraph('), isFalse);
        expect(source.contains('.buildKnowledgeGraph('), isFalse);
        expect(RegExp(r'foundationRuntimeServiceProvider\.notifier\)\._\w').hasMatch(source), isFalse);
      });
    }

    // TEST-EKE-011-011: the Repository-mutation entry point Exchange
    // uses is still the single public repositoryMutationOccurred()
    // method -- no second/duplicate sync trigger was introduced by this
    // work package.
    test('011: exchange_runtime_service.dart still calls the single public repositoryMutationOccurred()', () {
      final file = File(
          '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}exchange${Platform.pathSeparator}services${Platform.pathSeparator}exchange_runtime_service.dart');
      final source = file.readAsStringSync();
      expect(source.contains('repositoryMutationOccurred()'), isTrue);
      expect('repositoryMutationOccurred()'.allMatches(source).length, 1,
          reason: 'expected exactly one call site for repositoryMutationOccurred() in this file');
    });
  });
}

/// Locates the `oep_studio` package root (the directory containing this
/// package's `pubspec.yaml`) from the test runner's working directory —
/// mirrors `eke_010_repository_mutation_sync_test.dart`'s own helper.
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
