import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
// Internal — see note in graph_service_test.dart.
import 'package:engineering_engine/core/events/engine_event_bus.dart';

class _AddOneCommand implements EditingCommand {
  @override
  String get description => 'add one';

  @override
  EditingSession apply(EditingSession session) {
    final graph = session.graph;
    final count = (graph.metadata['count'] as int? ?? 0) + 1;
    return session.copyWith(graph: graph.copyWith(metadata: {'count': count}));
  }

  @override
  EditingSession revert(EditingSession session) {
    final graph = session.graph;
    final count = (graph.metadata['count'] as int? ?? 0) - 1;
    return session.copyWith(graph: graph.copyWith(metadata: {'count': count}));
  }
}

void main() {
  group('CommandHistory', () {
    late EditingSession session;
    late CommandHistory history;

    setUp(() {
      session = EditingSession.initial(EngineeringGraph.empty('g'));
      history = CommandHistory();
    });

    test('execute applies the command and enables undo', () {
      session = history.execute(_AddOneCommand(), session);
      expect(session.graph.metadata['count'], 1);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('undo reverts and enables redo', () {
      session = history.execute(_AddOneCommand(), session);
      session = history.undo(session);
      expect(session.graph.metadata['count'], 0);
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);
    });

    test('redo re-applies', () {
      session = history.execute(_AddOneCommand(), session);
      session = history.undo(session);
      session = history.redo(session);
      expect(session.graph.metadata['count'], 1);
      expect(history.canRedo, isFalse);
    });

    test('a new execute after undo clears the redo stack', () {
      session = history.execute(_AddOneCommand(), session);
      session = history.undo(session);
      session = history.execute(_AddOneCommand(), session);
      expect(history.canRedo, isFalse);
    });

    test('multiple undo/redo round-trips are deterministic', () {
      session = history.execute(_AddOneCommand(), session);
      session = history.execute(_AddOneCommand(), session);
      session = history.execute(_AddOneCommand(), session);
      expect(session.graph.metadata['count'], 3);

      session = history.undo(session);
      session = history.undo(session);
      expect(session.graph.metadata['count'], 1);

      session = history.redo(session);
      session = history.redo(session);
      expect(session.graph.metadata['count'], 3);
    });

    test('recentDescriptions lists the undo stack most-recent-first (WORK_PACKAGE_023)', () {
      session = history.execute(_AddOneCommand(), session);
      session = history.execute(_AddOneCommand(), session);
      expect(history.recentDescriptions, ['add one', 'add one']);

      session = history.undo(session);
      expect(
        history.recentDescriptions,
        ['add one'],
        reason: 'undo pops the stack recentDescriptions reads from',
      );
    });
  });

  group('EditingService', () {
    test('execute/undo/redo drive the session stream', () async {
      final events = EngineEventBus();
      final service = EditingService(
        initialSession: EditingSession.initial(EngineeringGraph.empty('g')),
        events: events,
      );
      final emissions = <int>[];
      final sub = service.sessionChanges.listen((s) {
        emissions.add(s.graph.metadata['count'] as int? ?? 0);
      });

      service.execute(_AddOneCommand());
      service.execute(_AddOneCommand());
      service.undo();

      await Future<void>.delayed(Duration.zero);
      expect(emissions, [1, 2, 1]);
      expect(service.session.graph.metadata['count'], 1);

      await sub.cancel();
      await service.dispose();
    });
  });
}
