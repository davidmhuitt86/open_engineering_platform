import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/core/models/relationship_summary.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/core/objects/engineering_object_runtime.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';

const _widget = EngineeringObjectSummary(
  objectId: 'obj-1',
  category: ObjectCategory.component,
  name: 'Widget',
  author: 'alice',
  version: '1.0',
);

const _gadget = EngineeringObjectSummary(
  objectId: 'obj-2',
  category: ObjectCategory.document,
  name: 'Gadget',
  author: 'bob',
  version: '2.0',
);

const _relationship = RelationshipSummary(
  relationshipId: 'rel-1',
  sourceObjectId: 'obj-1',
  targetObjectId: 'obj-2',
  sourceObjectName: 'Widget',
  targetObjectName: 'Gadget',
  type: RelationshipType.references,
  author: 'alice',
);

FoundationServiceState _state({
  List<EngineeringObjectSummary>? objectList,
  List<RelationshipSummary>? relationshipList,
}) =>
    FoundationServiceState(
      phase: FoundationConnectionPhase.connected,
      objectList: objectList,
      relationshipList: relationshipList,
    );

void main() {
  group('EngineeringObjectRuntime', () {
    late PlatformEventBus bus;
    late EngineeringObjectRuntime runtime;

    setUp(() {
      bus = PlatformEventBus();
      runtime = EngineeringObjectRuntime(eventBus: bus);
    });

    tearDown(() {
      runtime.dispose();
      bus.dispose();
    });

    test('starts empty before any state has been supplied', () {
      expect(runtime.objects, isEmpty);
      expect(runtime.relationships, isEmpty);
      expect(runtime.objectById('obj-1'), isNull);
      expect(runtime.hasObject('obj-1'), isFalse);
    });

    test('updateFromFoundationState populates the object/relationship cache', () {
      runtime.updateFromFoundationState(_state(objectList: const [_widget, _gadget], relationshipList: const [_relationship]));

      expect(runtime.objects, [_widget, _gadget]);
      expect(runtime.relationships, [_relationship]);
      expect(runtime.objectById('obj-1'), _widget);
      expect(runtime.hasObject('obj-2'), isTrue);
      expect(runtime.hasObject('no-such-object'), isFalse);
      expect(runtime.relationshipById('rel-1'), _relationship);
      expect(runtime.relationshipById('no-such-relationship'), isNull);
    });

    test('a null objectList/relationshipList (not yet loaded) is treated as empty, not left stale', () {
      runtime.updateFromFoundationState(_state(objectList: const [_widget], relationshipList: const [_relationship]));
      runtime.updateFromFoundationState(_state());

      expect(runtime.objects, isEmpty);
      expect(runtime.relationships, isEmpty);
      expect(runtime.objectById('obj-1'), isNull);
    });

    test('objectsInCategory filters by category', () {
      runtime.updateFromFoundationState(_state(objectList: const [_widget, _gadget]));

      expect(runtime.objectsInCategory(ObjectCategory.component), [_widget]);
      expect(runtime.objectsInCategory(ObjectCategory.document), [_gadget]);
      expect(runtime.objectsInCategory(ObjectCategory.diagram), isEmpty);
    });

    test('relationshipsInvolving returns relationships where the object is source or target', () {
      runtime.updateFromFoundationState(_state(relationshipList: const [_relationship]));

      expect(runtime.relationshipsInvolving('obj-1'), [_relationship]);
      expect(runtime.relationshipsInvolving('obj-2'), [_relationship]);
      expect(runtime.relationshipsInvolving('obj-3'), isEmpty);
    });

    test('a relationship where source == target is only listed once', () {
      const selfRelationship = RelationshipSummary(
        relationshipId: 'rel-self',
        sourceObjectId: 'obj-1',
        targetObjectId: 'obj-1',
        sourceObjectName: 'Widget',
        targetObjectName: 'Widget',
        type: RelationshipType.contains,
        author: 'alice',
      );
      runtime.updateFromFoundationState(_state(relationshipList: const [selfRelationship]));

      expect(runtime.relationshipsInvolving('obj-1'), [selfRelationship]);
    });

    test('calling with the same object/relationship list by reference is a no-op (lightweight caching)', () async {
      final objectList = [_widget];
      var changeCount = 0;
      final subscription = runtime.changes.listen((_) => changeCount++);
      addTearDown(subscription.cancel);

      final firstState = _state(objectList: objectList);
      runtime.updateFromFoundationState(firstState);
      // A different FoundationServiceState instance (as every ref.listenManual
      // delivery is), but carrying the exact same objectList/relationshipList
      // references — e.g. an unrelated field (AI suggestions, OCR status)
      // changed elsewhere in Foundation state.
      final secondState = FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        objectList: objectList,
        searchQuery: 'unrelated change',
      );
      runtime.updateFromFoundationState(secondState);
      await Future<void>.delayed(Duration.zero);

      expect(changeCount, 1, reason: 'the second call must not rebuild the cache or fire changes again');
    });

    test('changes fires after the cache has already been rebuilt (read-after-write)', () async {
      var countWhenFired = -1;
      final subscription = runtime.changes.listen((_) {
        countWhenFired = runtime.objects.length;
      });
      addTearDown(subscription.cancel);

      runtime.updateFromFoundationState(_state(objectList: const [_widget, _gadget]));
      await Future<void>.delayed(Duration.zero);

      expect(countWhenFired, 2);
    });

    test('publishes an EngineeringObjectEvent with the new counts whenever the cache changes', () async {
      final received = <EngineeringObjectEvent>[];
      final subscription = bus.on<EngineeringObjectEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      runtime.updateFromFoundationState(_state(objectList: const [_widget, _gadget], relationshipList: const [_relationship]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.objectCount, 2);
      expect(received.single.relationshipCount, 1);
    });

    test('publishes a 0/0 EngineeringObjectEvent when the repository is closed (cache cleared)', () async {
      runtime.updateFromFoundationState(_state(objectList: const [_widget]));

      final received = <EngineeringObjectEvent>[];
      final subscription = bus.on<EngineeringObjectEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      runtime.updateFromFoundationState(_state());
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.objectCount, 0);
      expect(received.single.relationshipCount, 0);
    });

    test('EngineeringObjectRuntime.instance is a shared singleton', () {
      expect(EngineeringObjectRuntime.instance, same(EngineeringObjectRuntime.instance));
    });
  });
}
