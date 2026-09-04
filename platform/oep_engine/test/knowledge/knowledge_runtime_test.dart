import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('Package', () {
    test('valid package loads and activates', () {
      final package = buildElectricalCorePackage();
      final runtime = KnowledgeRuntime.activate(
        package,
        allowUnsignedDevelopmentPackages: true,
      );
      expect(runtime.identity.packageId, 'electrical-core');
      expect(runtime.identity.trustState, PackageTrustState.active);
      expect(runtime.identity.developmentModeUnsigned, isTrue);
    });

    test('invalid package (missing schema-required content) is rejected', () {
      final package = buildElectricalCorePackage();
      final invalid = KnowledgePackage(
        manifest: package.manifest,
        dimensions: const [],
        units: const [],
        componentModels: package.componentModels,
        laws: package.laws,
        equations: package.equations,
        constraints: package.constraints,
        provenance: package.provenance,
        developmentModeUnsigned: true,
      );
      expect(
        () => KnowledgeRuntime.activate(
          invalid,
          allowUnsignedDevelopmentPackages: true,
        ),
        throwsA(
          isA<KnowledgeRuntimeException>().having(
            (e) => e.code,
            'code',
            KnowledgeRuntimeErrorCode.packageInvalid,
          ),
        ),
      );
    });

    test('hash mismatch is rejected', () {
      final package = buildElectricalCorePackage();
      final tampered = KnowledgePackage(
        manifest: KnowledgePackageManifest(
          packageId: package.manifest.packageId,
          packageName: package.manifest.packageName,
          packageVersion: package.manifest.packageVersion,
          schemaVersion: package.manifest.schemaVersion,
          sourceKnowledgeVersion: package.manifest.sourceKnowledgeVersion,
          compilerVersion: package.manifest.compilerVersion,
          createdUtc: package.manifest.createdUtc,
          publisherId: package.manifest.publisherId,
          contentHash: 'not-the-real-hash',
        ),
        dimensions: package.dimensions,
        units: package.units,
        componentModels: package.componentModels,
        laws: package.laws,
        equations: package.equations,
        constraints: package.constraints,
        provenance: package.provenance,
        developmentModeUnsigned: true,
      );
      expect(
        () => KnowledgeRuntime.activate(
          tampered,
          allowUnsignedDevelopmentPackages: true,
        ),
        throwsA(
          isA<KnowledgeRuntimeException>().having(
            (e) => e.code,
            'code',
            KnowledgeRuntimeErrorCode.packageHashMismatch,
          ),
        ),
      );
    });

    test(
      'trust failure (unsigned, dev mode not explicitly allowed) is rejected',
      () {
        final package = buildElectricalCorePackage();
        expect(
          () => KnowledgeRuntime.activate(package),
          throwsA(
            isA<KnowledgeRuntimeException>().having(
              (e) => e.code,
              'code',
              KnowledgeRuntimeErrorCode.packageSignatureInvalid,
            ),
          ),
        );
      },
    );

    test('a declared-but-unverifiable signature is rejected, not trusted', () {
      final package = buildElectricalCorePackage();
      final signed = KnowledgePackage(
        manifest: KnowledgePackageManifest(
          packageId: package.manifest.packageId,
          packageName: package.manifest.packageName,
          packageVersion: package.manifest.packageVersion,
          schemaVersion: package.manifest.schemaVersion,
          sourceKnowledgeVersion: package.manifest.sourceKnowledgeVersion,
          compilerVersion: package.manifest.compilerVersion,
          createdUtc: package.manifest.createdUtc,
          publisherId: package.manifest.publisherId,
          signature: 'ed25519:deadbeef',
        ),
        dimensions: package.dimensions,
        units: package.units,
        componentModels: package.componentModels,
        laws: package.laws,
        equations: package.equations,
        constraints: package.constraints,
        provenance: package.provenance,
      );
      expect(
        () => KnowledgeRuntime.activate(
          signed,
          allowUnsignedDevelopmentPackages: true,
        ),
        throwsA(
          isA<KnowledgeRuntimeException>().having(
            (e) => e.code,
            'code',
            KnowledgeRuntimeErrorCode.packageSignatureInvalid,
          ),
        ),
      );
    });
  });

  group('Runtime / Registry', () {
    late KnowledgeRuntime runtime;
    setUp(() {
      runtime = KnowledgeRuntime.activate(
        buildElectricalCorePackage(),
        allowUnsignedDevelopmentPackages: true,
      );
    });

    test(
      'activation produces an immutable snapshot with a stable identity',
      () {
        final runtime2 = KnowledgeRuntime.activate(
          buildElectricalCorePackage(),
          allowUnsignedDevelopmentPackages: true,
        );
        expect(runtime.identity.contentHash, runtime2.identity.contentHash);
        expect(identical(runtime, runtime2), isFalse);
      },
    );

    test('unit lookup', () {
      final volt = runtime.getUnit('unit.volt');
      expect(volt.symbol, 'V');
      expect(volt.dimensionId, 'dimension.voltage');
    });

    test('component model lookup', () {
      final resistor = runtime.getComponentModel('component.passive.resistor');
      expect(resistor.parameters.single.name, 'resistance');
    });

    test('law lookup', () {
      final law = runtime.getLaw('law.ohms_law');
      expect(law.name, "Ohm's Law");
      expect(law.equationRefs, contains('equation.ohms_law'));
    });

    test('equation lookup', () {
      final equation = runtime.getEquation('equation.ohms_law');
      expect(equation.expression, 'V = I × R');
    });

    test('package identity retained on the runtime identity', () {
      expect(runtime.identity.packageId, 'electrical-core');
      expect(runtime.identity.packageVersion, '1.0.0');
    });

    test('unresolvable id throws REFERENCE_NOT_FOUND', () {
      expect(
        () => runtime.getUnit('unit.does_not_exist'),
        throwsA(
          isA<KnowledgeRuntimeException>().having(
            (e) => e.code,
            'code',
            KnowledgeRuntimeErrorCode.referenceNotFound,
          ),
        ),
      );
    });
  });

  group('Quantity', () {
    late KnowledgeRuntime runtime;
    setUp(() {
      runtime = KnowledgeRuntime.activate(
        buildElectricalCorePackage(),
        allowUnsignedDevelopmentPackages: true,
      );
    });

    test('V / Ω dimension composes to A', () {
      final v = runtime.getDimension('dimension.voltage').exponents;
      final r = runtime.getDimension('dimension.resistance').exponents;
      final a = runtime.getDimension('dimension.current').exponents;
      expect(v / r, a);
    });

    test('V × A dimension composes to W', () {
      final v = runtime.getDimension('dimension.voltage').exponents;
      final a = runtime.getDimension('dimension.current').exponents;
      final w = runtime.getDimension('dimension.power').exponents;
      expect(v * a, w);
    });

    test('quantity() resolves a typed value through the runtime', () {
      final q = runtime.quantity(12, 'unit.volt');
      expect(q.value, 12);
      expect(q.unit.symbol, 'V');
      expect(q.dimension.id, 'dimension.voltage');
    });
  });
}
