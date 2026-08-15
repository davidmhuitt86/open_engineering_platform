import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/core/workspace/session_manager.dart';
import 'package:oep_studio/core/workspace/workspace_manager.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// Builds an [EngineeringProjectState] with just the `DiagramDocument`
/// field `WorkspaceManager` reads — mirrors `workspace_manager_test
/// .dart`'s own helper (test files in this codebase don't import each
/// other).
EngineeringProjectState _fakeState({String? path}) {
  final document = DiagramDocument()..path = path;
  return EngineeringProjectState(document: document);
}

/// A [KnowledgeSession] with only the fields these tests care about
/// filled in meaningfully.
KnowledgeSessionRecord _fakeSessionRecord(String id, String name, DateTime lastModified) {
  return KnowledgeSessionRecord(
    session: KnowledgeSession(
      id: id,
      name: name,
      repositoryName: 'demo-repo',
      author: 'test',
      createdTime: lastModified,
      lastModified: lastModified,
    ),
  );
}

/// Pumps a bare [ProviderScope] and hands back a live [WidgetRef] —
/// [SessionManager.listAll] takes one, matching every other Platform
/// service's own convention.
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

/// A no-op Knowledge Sessions loader — every test here injects one
/// (empty, or with deliberately fake sessions) rather than ever reading
/// the *real* `knowledge_sessions` directory, which holds genuine
/// project history (real Knowledge Curation Sessions from actual
/// engineering work, well over 100 MB) that this test suite must never
/// depend on the size or contents of.
Future<SessionBrowserListing> _emptyKnowledgeSessions() async =>
    const SessionBrowserListing(sessions: [], corruptedSessionIds: []);

void main() {
  group('SessionManager.listAll — read-only cross-Studio aggregation', () {
    testWidgets('every recent Diagram workspace appears, in WorkspaceManager\'s own order, as its own summary', (
      tester,
    ) async {
      final stateFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
          'wp029_session_manager_test_${DateTime.now().microsecondsSinceEpoch}.json');
      addTearDown(() async {
        if (stateFile.existsSync()) await stateFile.delete();
      });

      final workspaceManager = WorkspaceManager(file: stateFile);
      // Real dart:io writes (WorkspaceManager._persist) don't reliably
      // complete inside a bare testWidgets async body — the same class
      // of issue as a bare Future.delayed (WP-STUDIO-028's own test
      // notes). tester.runAsync() punches through to real event-loop
      // time for genuine I/O like this.
      await tester.runAsync(() async {
        await workspaceManager.initialize();
        await workspaceManager.handleProjectStateChange(_fakeState(path: 'first.json'));
        await workspaceManager.handleProjectStateChange(_fakeState(path: 'second.json'));
      });

      final ref = await _pumpRef(tester);
      final summaries = await SessionManager.listAll(
        ref,
        workspaceManager: workspaceManager,
        knowledgeSessionsLoader: _emptyKnowledgeSessions,
      );

      expect(summaries.map((s) => s.identifier).toList(), ['second.json', 'first.json']);
      expect(summaries.every((s) => s.destination == StudioDestination.diagram), isTrue);
      expect(summaries.every((s) => s.label == s.identifier), isTrue);
      expect(summaries.every((s) => s.lastModified == null), isTrue);
    });

    testWidgets('Knowledge sessions are listed before Diagram workspaces, sorted by lastModified descending', (
      tester,
    ) async {
      final stateFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
          'wp029_session_manager_test_order_${DateTime.now().microsecondsSinceEpoch}.json');
      addTearDown(() async {
        if (stateFile.existsSync()) await stateFile.delete();
      });

      final workspaceManager = WorkspaceManager(file: stateFile);
      await tester.runAsync(() async {
        await workspaceManager.initialize();
        await workspaceManager.handleProjectStateChange(_fakeState(path: 'only.json'));
      });

      final ref = await _pumpRef(tester);
      final summaries = await SessionManager.listAll(
        ref,
        workspaceManager: workspaceManager,
        knowledgeSessionsLoader: () async => SessionBrowserListing(
          sessions: [
            _fakeSessionRecord('older', 'Older Session', DateTime(2026, 1, 1)),
            _fakeSessionRecord('newer', 'Newer Session', DateTime(2026, 6, 1)),
          ],
          corruptedSessionIds: const [],
        ),
      );

      expect(summaries.map((s) => s.identifier).toList(), ['newer', 'older', 'only.json']);
      expect(summaries[0].destination, StudioDestination.knowledge);
      expect(summaries[1].destination, StudioDestination.knowledge);
      expect(summaries[2].destination, StudioDestination.diagram);
    });

    testWidgets('an empty recent-workspace list and no Knowledge sessions produce an empty result', (tester) async {
      final stateFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
          'wp029_session_manager_test_empty_${DateTime.now().microsecondsSinceEpoch}.json');
      addTearDown(() async {
        if (stateFile.existsSync()) await stateFile.delete();
      });

      final workspaceManager = WorkspaceManager(file: stateFile);
      await workspaceManager.initialize();

      final ref = await _pumpRef(tester);
      final summaries = await SessionManager.listAll(
        ref,
        workspaceManager: workspaceManager,
        knowledgeSessionsLoader: _emptyKnowledgeSessions,
      );

      expect(summaries, isEmpty);
    });
  });
}
