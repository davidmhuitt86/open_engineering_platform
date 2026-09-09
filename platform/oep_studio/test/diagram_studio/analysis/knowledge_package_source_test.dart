import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/analysis/analysis_controller.dart';
import 'package:oep_studio/diagram_studio/analysis/knowledge_package_source.dart';

/// AP-EK-020 (packaging finalization) — the production package-loading
/// boundary: [AssetKnowledgePackageSource] reads the real, compiled
/// `.oerp` (staged by `tool/generate_knowledge_asset.dart` — run before
/// this suite, same as any other test relying on a real Flutter asset;
/// § `test/widget_test.dart`'s own precedent for `rootBundle` resolving
/// real on-disk assets under `flutter test`), and [electricalCoreRuntimeProvider]
/// activates it via the real [OerpReader]/[KnowledgeRuntime] path — never
/// `buildElectricalCorePackage()` (the Dart fixture).
class _FixtureKnowledgePackageSource implements KnowledgePackageSource {
  const _FixtureKnowledgePackageSource();

  @override
  Future<KnowledgePackage> loadElectricalCorePackage() async =>
      buildElectricalCorePackage();
}

void main() {
  // `rootBundle.load` (ServicesBinding) needs a real Flutter binding —
  // these are plain `test()` blocks, not `testWidgets()`, so nothing
  // else initializes one.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetKnowledgePackageSource', () {
    test('loads the real compiled .oerp asset and preserves its identity',
        () async {
      const source = AssetKnowledgePackageSource();
      final package = await source.loadElectricalCorePackage();

      expect(package.manifest.packageId, 'core_reference');
      expect(package.manifest.schemaVersion, '1.0.0');
      expect(package.manifest.compilerVersion, isNotEmpty);
      // Confirms this is the genuinely-compiled package, not the Dart
      // fixture (whose packageId is 'electrical-core', not
      // 'core_reference' — see electrical_core_package.dart).
      expect(package.manifest.packageId, isNot('electrical-core'));
    });

    test('resolving unit/component/equation ids the canonical circuit needs',
        () async {
      const source = AssetKnowledgePackageSource();
      final package = await source.loadElectricalCorePackage();
      final runtime = KnowledgeRuntime.activate(package,
          allowUnsignedDevelopmentPackages: true);

      for (final unitId in [
        'unit.volt',
        'unit.ampere',
        'unit.ohm',
        'unit.watt'
      ]) {
        expect(runtime.getUnit(unitId).id, unitId);
      }
      for (final modelId in [
        'component.passive.resistor',
        'component.source.voltage_ideal',
        'component.reference_node',
      ]) {
        expect(runtime.getComponentModel(modelId).id, modelId);
      }
      expect(runtime.getEquation('equation.ohms_law').id, 'equation.ohms_law');
      expect(runtime.getEquation('equation.power').id, 'equation.power');
    });

    test(
        'the canonical 12V/10Ω circuit still analyzes to 1.2 A / 14.4 W '
        'through the bundled compiled package', () async {
      const source = AssetKnowledgePackageSource();
      final package = await source.loadElectricalCorePackage();
      final runtime = KnowledgeRuntime.activate(package,
          allowUnsignedDevelopmentPackages: true);
      final graph = buildCanonicalCircuitGraph();

      final result = const AnalysisEngine().analyze(
        request: const AnalysisRequest(
          requestId: 'req-packaging-test',
          documentId: 'doc-packaging-test',
          documentVersion: 'v1',
          knowledgePackageId: 'electrical-core',
        ),
        graph: graph,
        runtime: runtime,
      );

      expect(result.status, AnalysisStatus.success);
      expect(result.current, closeTo(1.2, 1e-9));
      expect(result.power, closeTo(14.4, 1e-9));
    });

    test(
        'a missing asset fails explicitly with KnowledgeRuntimeException, '
        'never silently falling back to anything', () async {
      const source = AssetKnowledgePackageSource(
          assetPath: 'assets/knowledge/does-not-exist.oerp');
      await expectLater(
        source.loadElectricalCorePackage(),
        throwsA(isA<KnowledgeRuntimeException>().having(
          (e) => e.code,
          'code',
          KnowledgeRuntimeErrorCode.packageNotFound,
        )),
      );
    });
  });

  group('electricalCoreRuntimeProvider', () {
    test(
        'activates whatever KnowledgePackageSource is provided — the '
        'production default is AssetKnowledgePackageSource, never the '
        'Dart fixture', () async {
      final container = ProviderContainer(overrides: [
        knowledgePackageSourceProvider
            .overrideWithValue(const _FixtureKnowledgePackageSource()),
      ]);
      addTearDown(container.dispose);

      final runtime =
          await container.read(electricalCoreRuntimeProvider.future);
      // The override above proves the provider genuinely reads through
      // `knowledgePackageSourceProvider` (this test's fixture source,
      // packageId 'electrical-core') rather than hardcoding
      // `AssetKnowledgePackageSource` or `buildElectricalCorePackage()`
      // directly inside its own body.
      expect(runtime.identity.packageId, 'electrical-core');
    });

    test(
        'the unconfigured provider (production default) resolves to '
        'AssetKnowledgePackageSource', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(knowledgePackageSourceProvider),
          isA<AssetKnowledgePackageSource>());
    });

    test(
        'a source that throws surfaces as a real AsyncError, not a '
        'silently-substituted fixture package', () async {
      final container = ProviderContainer(overrides: [
        knowledgePackageSourceProvider.overrideWithValue(
            const AssetKnowledgePackageSource(
                assetPath: 'assets/knowledge/does-not-exist.oerp')),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(electricalCoreRuntimeProvider.future),
        throwsA(isA<KnowledgeRuntimeException>()),
      );
    });
  });
}
