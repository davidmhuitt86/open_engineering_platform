import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/session/engineering_session.dart';
import 'package:oep_instruments_runtime/session/engineering_session_state.dart';

void main() {
  group('EngineeringSession', () {
    test('starts created and walks a real session lifecycle', () {
      final session = EngineeringSession(id: 's1', hostId: 'host1', owner: 'diagramStudio');
      expect(session.state, EngineeringSessionState.created);

      session.transitionTo(EngineeringSessionState.authenticated);
      session.transitionTo(EngineeringSessionState.initialized);
      session.transitionTo(EngineeringSessionState.running);
      expect(session.state, EngineeringSessionState.running);

      session.transitionTo(EngineeringSessionState.paused);
      session.transitionTo(EngineeringSessionState.resumed);
      session.transitionTo(EngineeringSessionState.completed);
      session.transitionTo(EngineeringSessionState.archived);
      expect(session.state, EngineeringSessionState.archived);
    });

    test('rejects an illegal transition', () {
      final session = EngineeringSession(id: 's1', hostId: 'host1', owner: 'diagramStudio');
      expect(() => session.transitionTo(EngineeringSessionState.running), throwsStateError);
    });

    test('clients may join and leave without affecting session state (§9)', () {
      final session = EngineeringSession(id: 's1', hostId: 'host1', owner: 'diagramStudio')
        ..transitionTo(EngineeringSessionState.authenticated)
        ..transitionTo(EngineeringSessionState.initialized)
        ..transitionTo(EngineeringSessionState.running);

      session.addClient('phone1');
      session.addClient('tablet1');
      expect(session.connectedClientIds, containsAll(['phone1', 'tablet1']));

      session.removeClient('phone1');
      expect(session.connectedClientIds, ['tablet1']);
      expect(session.state, EngineeringSessionState.running, reason: 'client churn never changes session state');
    });

    test('a session may host multiple instrument instances (§10)', () {
      final session = EngineeringSession(id: 's1', hostId: 'host1', owner: 'diagramStudio');
      session.addInstrument('dmm-1');
      session.addInstrument('dmm-2');
      session.addInstrument('scope-1');
      expect(session.connectedInstrumentIds, hasLength(3));
    });
  });
}
