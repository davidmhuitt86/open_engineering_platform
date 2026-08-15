import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('PowerDistributionCalculator', () {
    test('partitions devices into powered/unpowered and finds fuse/relay paths', () {
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {
          'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
          'fuse': const EngineeringNode(id: 'fuse', category: NodeCategory.fuse, displayName: 'Fuse'),
          'relay': const EngineeringNode(id: 'relay', category: NodeCategory.relay, displayName: 'Relay'),
          'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp'),
          'orphan': const EngineeringNode(id: 'orphan', category: NodeCategory.component, displayName: 'Orphan'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'fuse'),
          'r2': const EngineeringRelationship(id: 'r2', relationshipType: RelationshipType.connectedTo, sourceNode: 'fuse', targetNode: 'relay'),
          'r3': const EngineeringRelationship(id: 'r3', relationshipType: RelationshipType.connectedTo, sourceNode: 'relay', targetNode: 'lamp'),
        },
      );

      final view = const PowerDistributionCalculator().compute(graph, FaultOverlay());
      expect(view.poweredDeviceIds, containsAll(['fuse', 'relay', 'lamp']));
      expect(view.unpoweredDeviceIds, contains('orphan'));
      expect(view.fusePaths, isNotEmpty);
      expect(view.relayPaths, isNotEmpty);
      expect(view.powerDomains.expand((d) => d), containsAll(['fuse', 'relay', 'lamp']));
    });

    test('inactive paths are relationships where neither endpoint is powered', () {
      final graph = EngineeringGraph(
        id: 'g2',
        nodes: {
          'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A'),
          'b': const EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.connectedTo, sourceNode: 'a', targetNode: 'b'),
        },
      );
      final view = const PowerDistributionCalculator().compute(graph, FaultOverlay());
      expect(view.inactivePathRelationshipIds, contains('r1'));
    });
  });
}
