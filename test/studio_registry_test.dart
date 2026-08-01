import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/routing/studio_registry.dart';

Widget _fakePageBuilder(BuildContext context, GoRouterState state) => const SizedBox.shrink();

void main() {
  group('StudioRegistry.defaultRegistry — capability metadata (WP-STUDIO-022)', () {
    test('validateCapabilities reports no issues for the real, seeded registry', () {
      expect(StudioRegistry.defaultRegistry.validateCapabilities(), isEmpty);
    });

    test('Knowledge, Diagram, Acquisition, and Exchange each register at least one capability', () {
      final registry = StudioRegistry.defaultRegistry;
      expect(registry.capabilitiesFor(StudioDestination.knowledge), isNotEmpty);
      expect(registry.capabilitiesFor(StudioDestination.diagram), isNotEmpty);
      expect(registry.capabilitiesFor(StudioDestination.acquisition), isNotEmpty);
      expect(registry.capabilitiesFor(StudioDestination.exchange), isNotEmpty);
    });

    test('a core Platform page (no Studio) has no capabilities', () {
      expect(StudioRegistry.defaultRegistry.capabilitiesFor(StudioDestination.dashboard), isEmpty);
      expect(StudioRegistry.defaultRegistry.capabilitiesFor(StudioDestination.settings), isEmpty);
    });

    test('allCapabilities flattens every Studio\'s capabilities in registration order', () {
      final registry = StudioRegistry.defaultRegistry;
      final expectedCount = registry.capabilitiesFor(StudioDestination.knowledge).length +
          registry.capabilitiesFor(StudioDestination.diagram).length +
          registry.capabilitiesFor(StudioDestination.acquisition).length +
          registry.capabilitiesFor(StudioDestination.exchange).length +
          registry.capabilitiesFor(StudioDestination.engineeringIntelligence).length;
      expect(registry.allCapabilities.length, expectedCount);
      // Knowledge is registered before Diagram, before Acquisition, before
      // Engineering Intelligence, before Exchange — their capabilities
      // must appear in that same relative order (Engineering Intelligence
      // is registered right after Packages, before Exchange — see
      // `StudioRegistry.defaultRegistry`).
      final ids = registry.allCapabilities.map((c) => c.id).toList();
      final knowledgeIndex = ids.indexWhere((id) => id.startsWith('knowledge.'));
      final diagramIndex = ids.indexWhere((id) => id.startsWith('diagram.'));
      final acquisitionIndex = ids.indexWhere((id) => id.startsWith('acquisition.'));
      final engineeringIntelligenceIndex = ids.indexWhere((id) => id.startsWith('engineeringIntelligence.'));
      final exchangeIndex = ids.indexWhere((id) => id.startsWith('exchange.'));
      expect(knowledgeIndex, lessThan(diagramIndex));
      expect(diagramIndex, lessThan(acquisitionIndex));
      expect(acquisitionIndex, lessThan(engineeringIntelligenceIndex));
      expect(engineeringIntelligenceIndex, lessThan(exchangeIndex));
    });

    test('findCapability resolves a known id and returns null for an unknown one', () {
      final registry = StudioRegistry.defaultRegistry;
      final found = registry.findCapability('acquisition.vaultPublishing');
      expect(found, isNotNull);
      expect(found!.label, 'Reference Vault Publishing');
      expect(registry.findCapability('no.such.capability'), isNull);
    });

    test('ownerOf resolves the registering Studio and returns null for an unknown id', () {
      final registry = StudioRegistry.defaultRegistry;
      expect(registry.ownerOf('knowledge.review'), StudioDestination.knowledge);
      expect(registry.ownerOf('diagram.validation'), StudioDestination.diagram);
      expect(registry.ownerOf('no.such.capability'), isNull);
    });

    test('every registered capability id is unique across the whole registry', () {
      final ids = StudioRegistry.defaultRegistry.allCapabilities.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('Exchange (WP-EXC-010) registers browse/install/library capabilities', () {
      final registry = StudioRegistry.defaultRegistry;
      final ids = registry.capabilitiesFor(StudioDestination.exchange).map((c) => c.id).toSet();
      expect(ids, {'exchange.browse', 'exchange.install', 'exchange.library'});
    });

    test('Exchange has a settings provider and a search provider (WP-EXC-010)', () {
      final registry = StudioRegistry.defaultRegistry;
      expect(registry.descriptorFor(StudioDestination.exchange)!.settingsProvider, isNotNull);
      expect(registry.descriptorFor(StudioDestination.exchange)!.searchProvider, isNotNull);
    });
  });

  group('StudioRegistry.validateCapabilities — catches inconsistent metadata', () {
    test('flags a blank capability id', () {
      final registry = StudioRegistry([
        const StudioDescriptor(
          destination: StudioDestination.dashboard,
          pageBuilder: _fakePageBuilder,
          capabilities: [CapabilityDescriptor(id: '', label: 'Something', description: 'Does something.')],
        ),
      ]);
      expect(registry.validateCapabilities(), isNotEmpty);
    });

    test('flags a blank label and a blank description independently', () {
      final registry = StudioRegistry([
        const StudioDescriptor(
          destination: StudioDestination.dashboard,
          pageBuilder: _fakePageBuilder,
          capabilities: [
            CapabilityDescriptor(id: 'fake.one', label: '', description: 'Has a description.'),
            CapabilityDescriptor(id: 'fake.two', label: 'Has a label', description: ''),
          ],
        ),
      ]);
      final issues = registry.validateCapabilities();
      expect(issues.length, 2);
    });

    test('flags a capability id duplicated across two different Studios', () {
      final registry = StudioRegistry([
        const StudioDescriptor(
          destination: StudioDestination.dashboard,
          pageBuilder: _fakePageBuilder,
          capabilities: [CapabilityDescriptor(id: 'duplicate.id', label: 'One', description: 'First.')],
        ),
        const StudioDescriptor(
          destination: StudioDestination.knowledge,
          pageBuilder: _fakePageBuilder,
          capabilities: [CapabilityDescriptor(id: 'duplicate.id', label: 'Two', description: 'Second.')],
        ),
      ]);
      final issues = registry.validateCapabilities();
      expect(issues, hasLength(1));
      expect(issues.single, contains('duplicate.id'));
    });

    test('a registry with no capabilities at all is trivially valid', () {
      final registry = StudioRegistry([
        const StudioDescriptor(destination: StudioDestination.dashboard, pageBuilder: _fakePageBuilder),
      ]);
      expect(registry.validateCapabilities(), isEmpty);
    });
  });
}
