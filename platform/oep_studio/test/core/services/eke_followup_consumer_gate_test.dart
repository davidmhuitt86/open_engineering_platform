import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/eke_consumer_gate.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';

/// WP-EKE-FOLLOWUP-001: proves the actual EKE consumer *execution gate*
/// behavior — not merely that [EkeReadiness]'s enum/model holds the
/// right value (that is what `foundation_eke_readiness_test.dart` and
/// `eke_lifecycle_test.dart` already cover, from WP-EKE-009).
///
/// The defect this work package corrects: several consumer pages
/// (`analysis_dashboard_page.dart`, `engineering_explorer_page.dart`,
/// `query_console_page.dart`, `reasoning_dashboard_page.dart`,
/// `recommendation_panel_page.dart`, `validation_dashboard_page.dart`,
/// and `knowledge_graph_explorer_page.dart`'s rebuild path) called
/// `FoundationRuntimeNotifier.ensureEkeReady()`, checked
/// `EkeReadiness.hasFailed` to *display* an error, and then invoked
/// their EKE operation (`engineeringHealth`/`analyzeDependencies`/
/// `planQuery`/`executeQuery`/`createReasoningSession`/
/// `executeReasoning`/`engineeringRecommendations`/`validateContext`/
/// `validateObject`/`knowledgeGraphStatistics`/etc.) regardless of the
/// actual readiness state.
///
/// This test environment has no native `oep_foundation_bridge.dll` on
/// its search path (see `foundation_eke_readiness_test.dart`'s own
/// doc comment) — `FoundationRuntimeNotifier._bridge` is always `null`
/// under `flutter test`, so a real widget test can never reach the
/// EKE-gated code paths at all (every page's own `bridge == null`
/// early-return fires first, before any readiness check would matter).
/// Faking a successful native Runtime merely for coverage is exactly
/// what the work order forbids.
///
/// Instead, per the work order's own guidance, this file:
///
/// 1. Directly unit-tests [EkeConsumerGate.allows] — the single, shared
///    predicate every one of the seven consumer pages' own
///    `_ensureGraphReady()` gate now calls — against every
///    [EkeReadinessState] value (TEST-EKE-FU-001 through 007/009).
/// 2. Drives [_ConsumerGateHarness], a small object that reproduces —
///    verbatim in shape — the exact "if (!_ensureGraphReady()) return;
///    (invoke EKE operation)" call-site pattern every one of those
///    pages was edited to use in this work package (see e.g.
///    `analysis_dashboard_page.dart`'s `_run`/`_loadHealth`,
///    `query_console_page.dart`'s `_runPlan`/`_execute`,
///    `validation_dashboard_page.dart`'s `_validateContext`/
///    `_validateObject`). This is the "operation invoked or not"
///    proof the work order's §10 calls out as the most important test
///    (TEST-EKE-FU-011/012).
/// 3. Reads each real page's source text and asserts the call-site
///    shape is actually present there — so this file is not merely
///    testing an isolated harness that happens to agree with the
///    pages in prose, but confirms the production files themselves
///    contain the gate.
void main() {
  group('EkeConsumerGate.allows — model-level state coverage', () {
    // TEST-EKE-FU-001: ready permits.
    test('001: ready permits', () {
      expect(EkeConsumerGate.allows(const EkeReadiness(state: EkeReadinessState.ready)), isTrue);
    });

    // TEST-EKE-FU-002: disconnected blocks.
    test('002: disconnected blocks', () {
      expect(EkeConsumerGate.allows(const EkeReadiness(state: EkeReadinessState.disconnected)), isFalse);
    });

    // TEST-EKE-FU-003: repositoryClosed blocks.
    test('003: repositoryClosed blocks', () {
      expect(EkeConsumerGate.allows(const EkeReadiness(state: EkeReadinessState.repositoryClosed)), isFalse);
    });

    // TEST-EKE-FU-004: graphNotLoaded blocks.
    test('004: graphNotLoaded blocks', () {
      expect(EkeConsumerGate.allows(const EkeReadiness(state: EkeReadinessState.graphNotLoaded)), isFalse);
    });

    // TEST-EKE-FU-005: initializing blocks (the core of the actual bug —
    // initializing must never be treated as ready even though a fresh
    // initialization is actively in flight).
    test('005: initializing blocks', () {
      expect(EkeConsumerGate.allows(const EkeReadiness(state: EkeReadinessState.initializing)), isFalse);
    });

    // TEST-EKE-FU-006: engineeringGraphLoaded blocks (Engineering Graph
    // loaded, Knowledge Graph not yet built — still not queryable).
    test('006: engineeringGraphLoaded blocks', () {
      expect(EkeConsumerGate.allows(const EkeReadiness(state: EkeReadinessState.engineeringGraphLoaded)), isFalse);
    });

    // TEST-EKE-FU-007: initializationFailed blocks.
    test('007: initializationFailed blocks', () {
      expect(
        EkeConsumerGate.allows(const EkeReadiness(
          state: EkeReadinessState.initializationFailed,
          failedStage: EkeInitializationStage.knowledgeGraphBuild,
          failureMessage: 'Knowledge Graph build failed: duplicate object id.',
        )),
        isFalse,
      );
    });

    // TEST-EKE-FU-008: initializationFailed preserves/surfaces
    // failureMessage rather than falling back to the generic message —
    // and only falls back when no diagnostic was recorded.
    test('008: blockedMessage preserves the real diagnostic, only falls back when null', () {
      const withDiagnostic = EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failedStage: EkeInitializationStage.engineeringGraphLoad,
        failureMessage: 'The repository could not be accessed.',
      );
      expect(EkeConsumerGate.blockedMessage(withDiagnostic), 'The repository could not be accessed.');

      const withoutDiagnostic = EkeReadiness(state: EkeReadinessState.disconnected);
      expect(EkeConsumerGate.blockedMessage(withoutDiagnostic), 'Engineering Knowledge Engine is not ready.');
    });

    // TEST-EKE-FU-009: an empty (non-null) repository with ekeReadiness
    // == ready still permits execution — objectList emptiness is never
    // consulted by the gate at all (it isn't even a parameter).
    test('009: ready permits execution regardless of repository emptiness', () {
      // The gate's signature itself proves this: EkeConsumerGate.allows
      // takes only an EkeReadiness, never an object list, so there is no
      // way for list emptiness to influence the result. Exercised
      // explicitly against the exact "empty repository" EkeReadiness an
      // empty-but-successfully-initialized repository produces.
      const emptyRepoReady = EkeReadiness(state: EkeReadinessState.ready, repositoryId: 'repo-empty');
      expect(EkeConsumerGate.allows(emptyRepoReady), isTrue);
    });
  });

  group('Consumer gate behavior — operation invoked or not (TEST-EKE-FU-011/012)', () {
    // TEST-EKE-FU-011: a non-ready readiness blocks the harness from
    // invoking its EKE operation at all — the harness reproduces the
    // exact `if (!_ensureGraphReady()) return; <operation>()` shape used
    // by every consumer page's call sites after this work package's fix.
    for (final state in EkeReadinessState.values.where((s) => s != EkeReadinessState.ready)) {
      test('011: readiness=$state blocks the operation (not invoked)', () {
        final harness = _ConsumerGateHarness(EkeReadiness(
          state: state,
          failureMessage: state == EkeReadinessState.initializationFailed ? 'diagnostic' : null,
        ));
        harness.runOperation();
        expect(harness.operationCallCount, 0, reason: 'readiness=$state must block the EKE operation');
      });
    }

    // TEST-EKE-FU-012: readiness == ready permits the harness to invoke
    // its EKE operation.
    test('012: readiness=ready permits the operation (invoked)', () {
      final harness = _ConsumerGateHarness(const EkeReadiness(state: EkeReadinessState.ready));
      harness.runOperation();
      expect(harness.operationCallCount, 1);
    });

    test('a blocked call sets the harness error message, a permitted call does not', () {
      final blocked = _ConsumerGateHarness(const EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failureMessage: 'boom',
      ));
      blocked.runOperation();
      expect(blocked.error, 'boom');

      final permitted = _ConsumerGateHarness(const EkeReadiness(state: EkeReadinessState.ready));
      permitted.runOperation();
      expect(permitted.error, isNull);
    });
  });

  group('Production source verification — the real pages actually contain the gate', () {
    String readPage(String relativePath) {
      final file = File(
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}engineering_intelligence${Platform.pathSeparator}pages${Platform.pathSeparator}$relativePath',
      );
      expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
      return file.readAsStringSync();
    }

    // TEST-EKE-FU-011/012 (production-file half): every non-rebuild EKE
    // consumer page defines a boolean `_ensureGraphReady()` gate and
    // every one of its EKE-operation call sites checks it before
    // proceeding.
    for (final entry in const {
      'analysis_dashboard_page.dart': ['bridge.engineeringHealth()', 'bridge.analyzeDependencies'],
      'engineering_explorer_page.dart': ['bridge.engineRelatedObjects'],
      'query_console_page.dart': ['bridge.planQuery', 'bridge.executeQuery'],
      'reasoning_dashboard_page.dart': ['bridge.createReasoningSession', 'bridge.executeReasoning'],
      'recommendation_panel_page.dart': ['bridge.engineeringRecommendations', 'bridge.createReasoningSession'],
      'validation_dashboard_page.dart': ['bridge.validateContext', 'bridge.validateObject'],
    }.entries) {
      test('${entry.key} defines and uses a bool _ensureGraphReady() gate', () {
        final source = readPage(entry.key);
        expect(source, contains('bool _ensureGraphReady()'));
        expect(source, contains('if (!_ensureGraphReady())'));
        for (final operation in entry.value) {
          expect(source, contains(operation), reason: '$operation must still be called from ${entry.key}');
        }
      });
    }

    // TEST-EKE-FU-010: Knowledge Graph Explorer's "Rebuild Graph" button
    // remains routed through FoundationRuntimeNotifier.rebuildKnowledgeGraph()
    // — never `bridge.buildKnowledgeGraph()` directly — and its own
    // success/failure path is checked with EkeConsumerGate before any
    // further Knowledge Graph query is allowed to run.
    test('010: knowledge_graph_explorer_page.dart routes rebuild through notifier.rebuildKnowledgeGraph()', () {
      final source = readPage('knowledge_graph_explorer_page.dart');
      expect(source, contains('notifier.rebuildKnowledgeGraph()'));
      expect(source, isNot(contains('bridge.buildKnowledgeGraph()')));
      expect(source, isNot(contains('bridge.loadEngineeringGraph()')));
      // The explicit-refresh button itself must remain callable
      // regardless of prior readiness (it is the recovery path out of a
      // non-ready state) — it is gated only on `_building`, never on
      // `ekeReadiness.isReady`.
      expect(source, contains('onPressed: _building ? null : _build'));
      // But once rebuild returns, further Knowledge Graph queries
      // (knowledgeGraphStatistics/connectedComponents/knowledgeGraphSubgraph)
      // must still be blocked if the rebuild did not reach ready.
      expect(source, contains('EkeConsumerGate.allows(readiness)'));
    });
  });
}

/// Test-only harness reproducing the exact gate + call-site shape every
/// consumer page uses after this work package's fix:
/// ```dart
/// bool _ensureGraphReady() {
///   ...
///   if (!EkeConsumerGate.allows(readiness)) {
///     setState(() => _error = EkeConsumerGate.blockedMessage(readiness));
///     return false;
///   }
///   return true;
/// }
///
/// Future<void> _someAction() async {
///   ...
///   if (!_ensureGraphReady()) return;
///   <invoke EKE operation>
/// }
/// ```
/// Not a production redesign — a minimal seam so the gate's actual
/// blocking/permitting behavior (does the operation run or not) is
/// directly testable without a live native Foundation Runtime.
class _ConsumerGateHarness {
  _ConsumerGateHarness(this.readiness);

  final EkeReadiness readiness;
  int operationCallCount = 0;
  String? error;

  bool _ensureGraphReady() {
    if (!EkeConsumerGate.allows(readiness)) {
      error = EkeConsumerGate.blockedMessage(readiness);
      return false;
    }
    return true;
  }

  /// Mirrors a page's `_run`/`_execute`/`_load`/`_validateContext`/etc.
  void runOperation() {
    if (!_ensureGraphReady()) return;
    operationCallCount++;
  }
}
