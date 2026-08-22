import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagram_workspace_state.dart';
import 'workspace_state_storage.dart';

/// The non-widget owner of Diagram Studio's *workspace* persistence
/// (WAVE 2 STAGE D, AP-DIAGRAM-W2-D — see
/// `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` entries 49, 91–92 and
/// §29 item 9 for the hazard this closes).
///
/// **Why this exists.** Before Stage D, `DiagramStudioPage` was the only
/// thing that ever called `WorkspaceStateStorage.save`, and its
/// `dispose()` was the *final* opportunity to do so — but Riverpod marks
/// a `ConsumerStatefulElement` disposed before the framework calls the
/// `State`'s own `dispose()`, so `ref.read`/`ref.watch` throw a
/// `StateError` there. The page worked around that by mirroring the two
/// values `dispose()` needed (`_cachedDocumentPath`, `_cachedViewState`)
/// into plain fields on every `build()`, purely so `dispose()` would
/// have *something* to read without touching `ref`. That is a widget-
/// lifecycle workaround for a widget-lifecycle problem, and it is
/// exactly the dependency this stage removes: `DiagramStudioPage` no
/// longer calls `WorkspaceStateStorage` at all, in `dispose()` or
/// anywhere else — every mutating page operation calls [persist] on
/// this notifier instead, and the notifier is the one thing that ever
/// touches the storage layer.
///
/// **Scope, and why this scope.** App-wide, matching
/// `engineeringProjectServiceProvider`/`diagramStudioControllerProvider`
/// (Stage A) — there is exactly one Diagram Studio workspace per app
/// session, the same reasoning that put the Controller at this scope.
/// [build] loads the persisted `DiagramWorkspaceState` from disk exactly
/// once per app session (Riverpod only re-runs `AsyncNotifier.build()`
/// when the provider itself is invalidated, never merely because a
/// consuming widget mounts/remounts) — this is the "one authoritative
/// load lifecycle" Stage D calls for, replacing the page's former
/// per-mount `WorkspaceStateStorage.load()` re-read (a Stage A/B/C
/// deliberate, documented redundancy that this stage resolves rather
/// than carries forward: a widget remount now reads this provider's
/// already-loaded, already-current in-memory state instead of hitting
/// disk again).
///
/// **What this notifier does *not* own.** It holds a
/// `DiagramWorkspaceState` — UI/ambient-session state only (panel
/// visibility/widths, the last-open document *path* as a reference, and
/// `ViewState`) — never `DiagramDocument`/`EngineeringGraph`/
/// `DiagramLayoutState` content, and never a `TransformationController`
/// or `Matrix4`. Document persistence (`saveDocument`/`saveDocumentAs`/
/// `openDocument`/`newDocument`) is untouched and remains
/// `DiagramStudioController`'s job (Stage C); this notifier only
/// remembers which document path the workspace was last looking at, the
/// same reference `DiagramWorkspaceState.lastDocumentPath` always held.
class DiagramWorkspacePersistenceNotifier extends AsyncNotifier<DiagramWorkspaceState> {
  /// Chains every disk write after the previous one, so overlapping
  /// [persist] calls cannot land out of order and let an older save
  /// silently overwrite a newer one — `WorkspaceStateStorage.save` has
  /// no ordering guarantee of its own across independently-started
  /// writes, and this notifier is the only remaining caller, so it is
  /// the right (and only) place to add one. Not a new persistence
  /// engine: still exactly one file, one format, one writer — only the
  /// *scheduling* of that writer's calls is serialized.
  Future<void> _writeQueue = Future.value();

  @override
  Future<DiagramWorkspaceState> build() => WorkspaceStateStorage.load();

  /// Called from a `DiagramStudioPage` event handler after a mutating
  /// document/tab/panel operation — never from `dispose()`, and never
  /// automatically from a high-frequency interaction event (pointer/drag/
  /// resize/wire-edit/hover). [state] must be the full, already-merged
  /// `DiagramWorkspaceState` the caller wants persisted (mirroring the
  /// pre-Stage-D `_persistWorkspaceState` assembly, unchanged in shape).
  ///
  /// Updates the in-memory authoritative copy synchronously (so the very
  /// next `ref.read` — including from a widget that just remounted —
  /// sees it immediately, without waiting on disk I/O), then enqueues
  /// the write.
  void persist(DiagramWorkspaceState newState) {
    state = AsyncData(newState);
    _writeQueue = _writeQueue.then((_) => WorkspaceStateStorage.save(newState));
  }

  /// The last value handed to [persist] (or the value loaded at
  /// startup if [persist] was never called), for callers that need a
  /// synchronous read of "what would be persisted right now" — e.g. to
  /// merge in one changed field without clobbering the rest. `null`
  /// only during the brief window before [build]'s initial load
  /// resolves.
  DiagramWorkspaceState? get current => state.valueOrNull;

  /// Resolves once every write enqueued by a [persist] call made before
  /// this method was called has actually landed on disk — i.e. drains
  /// [_writeQueue]. No production caller needs this: eager persistence
  /// after every mutating operation, plus this notifier's own
  /// `ref.onDispose`-independent app-session lifetime, already make the
  /// write queue durable without anyone waiting on it. It exists for
  /// tests that must assert against the real file afterward (or, like
  /// this file's own tests, must restore the developer's real workspace
  /// to its original content in a `finally` block and need that
  /// restoring write to be provably the *last* one in the queue, not
  /// racing an earlier [persist] call's still-pending write).
  @visibleForTesting
  Future<void> flush() => _writeQueue;
}

final diagramWorkspacePersistenceProvider = AsyncNotifierProvider<DiagramWorkspacePersistenceNotifier, DiagramWorkspaceState>(
  DiagramWorkspacePersistenceNotifier.new,
);
