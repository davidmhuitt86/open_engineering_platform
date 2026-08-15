import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';

import '../../core/foundation/foundation_bridge.dart';
import '../../core/foundation/oep_api_types.dart';
import '../repository/diagram_repository_service.dart';

/// AP-DS-003: the single point of contact between Diagram Studio and the
/// Engineering Intelligence Platform (EIP). Per the governing spec's own
/// Architectural Principles -- "Diagram Studio shall never duplicate
/// engineering logic" / "All engineering intelligence shall be consumed
/// through the Engineering Intelligence Platform" -- this class contains
/// NO validation, analysis, reasoning, or recommendation logic of its
/// own. It does exactly three things:
///
/// 1. **Keeps a Foundation-backed shadow copy of the live canvas graph in
///    sync** (via [DiagramRepositoryService.syncForIntelligence], not
///    [DiagramRepositoryService.saveDiagram] -- live feedback while
///    authoring cannot wait for the user's own explicit Save/Save As,
///    which AP-DS-002 left as a real, disclosed, still-open UX gap; see
///    that phase's `IMPLEMENTATION_STATUS.md` entry).
/// 2. **Owns one Engineering Intelligence Platform Knowledge Session**
///    for the lifetime of the open diagram, created once
///    ([ensureSessionReady]) and reused across every validate/analyze/
///    reason/recommend/query/inspect call -- "the user shall never
///    manually coordinate multiple engines" (the spec's own words) means
///    this class does that coordination, not the user, and not by
///    re-deriving results itself.
/// 3. **Translates between the two id spaces**: canvas
///    `EngineeringNode.id` and Foundation `object_id`. Every EIP call is
///    keyed by Foundation object id; every canvas selection/highlight
///    operation is keyed by node id. [nodeIdFor]/[objectIdFor] are the
///    only place that translation happens, backed by the mapping
///    [DiagramRepositoryService.syncForIntelligence] returns on every
///    sync.
///
/// **Asynchrony**: every public method here returns a `Future`, and
/// none are called synchronously from a build method or gesture
/// callback -- callers (the canvas overlay, panels) are expected to
/// `await` or listen to [busy] and render a loading/pending state
/// meanwhile, per the spec's "editor shall remain responsive during
/// analysis" requirement. Honest disclosure: the underlying FFI calls
/// themselves still execute synchronously on the calling isolate (this
/// codebase has no precedent anywhere for cross-isolate `dart:ffi`
/// dispatch, and introducing one is a materially larger architectural
/// change than this phase's own scope permits) -- responsiveness here
/// comes from debouncing (edits are batched into infrequent sync calls,
/// not one per keystroke) and from every call being wrapped in
/// `Future(() => ...)`/`scheduleMicrotask`-friendly async methods so the
/// current frame is never blocked mid-build waiting on a slow call. Real
/// interactive-scale (100,000-object) EIP latency has not been
/// benchmarked in this phase — see `PERFORMANCE_REPORT.md`'s own
/// disclosed headless-proxy limitation, which applies here too.
class DiagramIntelligenceService {
  DiagramIntelligenceService({required FoundationBridge bridge, required DiagramRepositoryService repository})
    : _bridge = bridge,
      _repository = repository;

  final FoundationBridge _bridge;
  final DiagramRepositoryService _repository;

  String? _diagramObjectId;
  String? _sessionId;
  Map<String, String> _nodeToObjectId = const {};
  Map<String, String> _objectToNodeId = const {};
  bool _graphLoaded = false;

  Timer? _debounce;

  /// True while a sync or EIP call is in flight — panels/overlays should
  /// show a pending/stale-data indicator rather than block on this.
  bool busy = false;

  /// The Foundation object id EIP calls are currently scoped to
  /// (`null` until the first successful [sync]).
  String? get diagramObjectId => _diagramObjectId;

  /// Translates a canvas `EngineeringNode.id` to the Foundation
  /// `object_id` EIP results reference, or `null` if that node hasn't
  /// been synced yet (e.g. added since the last debounced sync).
  String? objectIdFor(String nodeId) => _nodeToObjectId[nodeId];

  /// The inverse of [objectIdFor] — translates an EIP-returned Foundation
  /// `object_id` back to the canvas node it corresponds to, or `null` if
  /// the id refers to something other than a decomposed diagram node
  /// (e.g. the Diagram object itself, or an object from a different
  /// diagram/package the query happened to touch).
  String? nodeIdFor(String objectId) => _objectToNodeId[objectId];

  /// Debounced sync entry point — call this from the same place
  /// `DiagramStudioPage` already calls `_markDirty()` (every mutating
  /// Engine Command). Coalesces bursts of edits into one sync
  /// [duration] after the last one, rather than syncing on every single
  /// command, so a rapid drag or multi-step edit doesn't trigger a sync
  /// (and therefore a full graph rebuild + potential live-validation
  /// pass) per intermediate frame.
  void scheduleSync({
    required String title,
    required EngineeringGraph graph,
    required DiagramLayoutState layout,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    _debounce?.cancel();
    _debounce = Timer(duration, () {
      unawaited(sync(title: title, graph: graph, layout: layout));
    });
  }

  /// Immediately syncs [graph]/[layout] to the Foundation-backed shadow
  /// diagram and rebuilds the Engineering/Knowledge Graph so subsequent
  /// EIP calls see current state. Safe to call directly (bypassing
  /// [scheduleSync]'s debounce) when the caller needs a guaranteed-fresh
  /// view before a specific action (e.g. a manual "Validate Now").
  Future<void> sync({required String title, required EngineeringGraph graph, required DiagramLayoutState layout}) async {
    busy = true;
    try {
      final result = await Future(
        () => _repository.syncForIntelligence(
          diagramObjectId: _diagramObjectId,
          title: title,
          graph: graph,
          layout: layout,
        ),
      );
      _diagramObjectId = result.diagramObjectId;
      _nodeToObjectId = result.nodeObjectIds;
      _objectToNodeId = {for (final entry in result.nodeObjectIds.entries) entry.value: entry.key};

      // Foundation caches the Engineering/Knowledge Graph on the Runtime
      // handle, not the repository (see loadEngineeringGraph's own doc
      // comment) -- it must be rebuilt after every mutating sync for
      // EIP calls to see the new state, per eipQuery's documented
      // "graph-readiness precondition."
      await Future(() => _bridge.loadEngineeringGraph());
      await Future(() => _bridge.buildKnowledgeGraph());
      _graphLoaded = true;
      await ensureSessionReady();
    } finally {
      busy = false;
    }
  }

  /// Creates the one Knowledge Session this diagram's EIP calls share,
  /// if it doesn't already exist. Called automatically at the end of
  /// [sync]; exposed separately for callers (e.g. the Knowledge Sessions
  /// panel) that need the session id before any sync has happened yet
  /// (e.g. to show "no session yet" rather than crash).
  Future<void> ensureSessionReady() async {
    if (_sessionId != null) return;
    _sessionId = await Future(() => _bridge.createEipSession());
  }

  String get _requireSession {
    final sessionId = _sessionId;
    if (sessionId == null) {
      throw StateError('DiagramIntelligenceService: no Knowledge Session yet — call sync() or ensureSessionReady() first.');
    }
    return sessionId;
  }

  String get _requireDiagram {
    final id = _diagramObjectId;
    if (id == null) {
      throw StateError('DiagramIntelligenceService: diagram has not been synced to the repository yet — call sync() first.');
    }
    return id;
  }

  bool get isReady => _graphLoaded && _sessionId != null && _diagramObjectId != null;

  /// Live Validation. [profile] defaults to [ValidationProfile.complete]
  /// (every rule category) — callers wanting a narrower/faster pass
  /// (e.g. only Connectivity during a wire-drag) may pass a different
  /// profile. Validates the whole synced diagram (scoped to
  /// [_requireDiagram], not an individual node) since most validation
  /// rules are inherently graph-wide (e.g. "no isolated objects").
  Future<({OepWorkflowResult result, List<String> objectIds})> validate({
    ValidationProfile profile = ValidationProfile.complete,
  }) {
    return Future(() => _bridge.eipValidate(_requireSession, _requireDiagram, profile));
  }

  /// Live Analysis (Dependency/Impact/Reachability/Root-Cause, per the
  /// spec) for the node identified by [nodeId] — translated to its
  /// Foundation object id internally; throws [ArgumentError] if [nodeId]
  /// hasn't been synced (added since the last [sync]).
  Future<({OepWorkflowResult result, List<String> objectIds})> analyzeNode(String nodeId) {
    final objectId = objectIdFor(nodeId);
    if (objectId == null) {
      throw ArgumentError.value(nodeId, 'nodeId', 'not yet synced to the repository — call sync() first');
    }
    return Future(() => _bridge.eipAnalyze(_requireSession, objectId));
  }

  /// Live Reasoning. [startingNodeIds] are translated to Foundation
  /// object ids (any not yet synced are silently dropped, matching
  /// [analyzeNode]'s ArgumentError-on-unknown-id treated more leniently
  /// here since Reasoning already tolerates an empty starting set).
  Future<({OepWorkflowResult result, List<String> objectIds})> reason({
    String objective = '',
    List<String> startingNodeIds = const [],
  }) {
    final startingObjectIds = startingNodeIds.map(objectIdFor).whereType<String>().toList();
    return Future(() => _bridge.eipReason(_requireSession, objective, startingObjectIds));
  }

  /// Engineering Recommendations for the node identified by [nodeId].
  Future<({OepWorkflowResult result, List<String> objectIds})> recommendForNode(String nodeId) {
    final objectId = objectIdFor(nodeId);
    if (objectId == null) {
      throw ArgumentError.value(nodeId, 'nodeId', 'not yet synced to the repository — call sync() first');
    }
    return Future(() => _bridge.eipRecommend(_requireSession, objectId));
  }

  /// Engineering Query Console entry point — [primaryObjectId], if
  /// given as a node id, is translated to its Foundation object id;
  /// pass a raw Foundation object id directly (e.g. from the Engineering
  /// Explorer or Knowledge Graph viewer, which operate in Foundation's
  /// id space already) by setting [isNodeId] to false.
  Future<({OepWorkflowResult result, List<String> objectIds})> query(
    QueryCategory category,
    String primaryObjectId, {
    bool isNodeId = true,
  }) {
    final resolvedId = isNodeId ? (objectIdFor(primaryObjectId) ?? primaryObjectId) : primaryObjectId;
    return Future(() => _bridge.eipQuery(_requireSession, category, resolvedId));
  }

  /// Inspects a single Engineering Object/Package/Context — see
  /// `foundation_bridge.dart`'s `eipInspect` for [kind] semantics.
  Future<({OepWorkflowResult result, List<String> objectIds})> inspect(InspectionTargetKind kind, String targetId) {
    return Future(() => _bridge.eipInspect(_requireSession, kind, targetId));
  }

  /// Releases the debounce timer. Does not close the Knowledge Session
  /// (Foundation sessions are process-local and cleaned up with the
  /// Runtime handle itself, per every prior EIP work package's own
  /// documented "in-memory-only sessions" limitation) — this is
  /// deliberate, not an oversight: closing here would race a pending
  /// [scheduleSync] callback that fires after dispose.
  void dispose() {
    _debounce?.cancel();
  }
}
