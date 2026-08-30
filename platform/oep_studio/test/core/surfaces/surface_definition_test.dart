import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/surfaces/surface_definition.dart';

/// AP-OEP-WORKSPACE-MULTI-INSTANCE-001 — [SurfaceDefinition.allowsMultipleInstances]
/// itself: purely declarative metadata, not yet consumed by
/// `WorkspaceTabsController` (a future caller's decision, § that
/// class's own doc comment). No existing Surface sets this to `true` in
/// this package.
void main() {
  SurfaceDefinition build({bool? allowsMultipleInstances}) {
    return SurfaceDefinition(
      id: 'test-surface',
      title: 'Test Surface',
      icon: Icons.abc,
      presentationTechnology: SurfacePresentationTechnology.native,
      build: (context) => const SizedBox(),
      allowsMultipleInstances: allowsMultipleInstances ?? false,
    );
  }

  test('allowsMultipleInstances defaults to false, preserving every existing Surface\'s singleton behavior', () {
    const surface = SurfaceDefinition(
      id: 'test-surface',
      title: 'Test Surface',
      icon: Icons.abc,
      presentationTechnology: SurfacePresentationTechnology.native,
      build: _dummyBuilder,
    );
    expect(surface.allowsMultipleInstances, isFalse);
  });

  test('allowsMultipleInstances can be explicitly opted into', () {
    final surface = build(allowsMultipleInstances: true);
    expect(surface.allowsMultipleInstances, isTrue);
  });
}

Widget _dummyBuilder(BuildContext context) => const SizedBox();
