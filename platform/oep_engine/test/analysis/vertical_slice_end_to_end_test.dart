import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// AP-EK-020 §36/§47 — the mandatory end-to-end acceptance test: load
/// package → activate runtime → analyze the canonical 12 V / 10 Ω
/// circuit → persist → reload → explain → mutate the document → observe
/// staleness → re-analyze → verify the new result, all while the
/// original analysis remains untouched.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ap-ek-020-analysis-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'full vertical slice: package -> runtime -> analysis -> persistence -> explanation -> mutation -> staleness',
    () async {
      // 1-3. Load, verify, activate.
      final package = buildElectricalCorePackage();
      final runtime = KnowledgeRuntime.activate(
        package,
        allowUnsignedDevelopmentPackages: true,
      );
      expect(runtime.identity.trustState, PackageTrustState.active);

      // 4-13. Load canonical document, submit AnalysisRequest, resolve
      // topology/models/equations, solve, evaluate constraints, produce
      // derivation/provenance/AnalysisResult.
      final documentV1 = buildCanonicalCircuitGraph(resistanceOhms: 10.0);
      final requestA = AnalysisRequest(
        requestId: 'req-a',
        documentId: 'doc-circuit-12v-10ohm',
        documentVersion: 'v1',
        knowledgePackageId: 'electrical-core',
      );
      final analysisA = const AnalysisEngine().analyze(
        request: requestA,
        graph: documentV1,
        runtime: runtime,
      );

      expect(analysisA.status, AnalysisStatus.success);
      expect(analysisA.current, closeTo(1.2, 1e-9));
      expect(analysisA.power, closeTo(14.4, 1e-9));
      expect(analysisA.derivation, isNotEmpty);
      expect(analysisA.provenance, isNotEmpty);

      // 14-15. Persist and reload.
      final store = AnalysisPersistenceStore(tempDir);
      await store.save(analysisA);
      final reloaded = await store.byId(
        analysisA.documentId,
        analysisA.analysisId,
        runtime: runtime,
      );
      expect(reloaded, isNotNull);
      expect(reloaded!.current, closeTo(1.2, 1e-9));
      expect(reloaded.power, closeTo(14.4, 1e-9));
      expect(reloaded.derivation.length, analysisA.derivation.length);
      expect(reloaded.provenance.length, analysisA.provenance.length);
      expect(
        reloaded.runtimeIdentity.contentHash,
        analysisA.runtimeIdentity.contentHash,
      );

      // 16-17. Explanation from the reloaded result; verify canonical values.
      final explanation = const ExplanationService().explain(reloaded);
      expect(explanation.text, contains('1.2'));
      expect(explanation.text, contains('14.4'));
      expect(explanation.lines.any((l) => l.contains('V = I × R')), isTrue);

      // 18. Modify the document: 10 Ω -> 20 Ω, producing v2.
      final documentV2 = buildCanonicalCircuitGraph(resistanceOhms: 20.0);
      final requestB = AnalysisRequest(
        requestId: 'req-b',
        documentId: 'doc-circuit-12v-10ohm',
        documentVersion: 'v2',
        knowledgePackageId: 'electrical-core',
      );

      // 19. Previous analysis is stale for v2 (not current for v2's version).
      final currentForV2BeforeReanalysis = await store.current(
        'doc-circuit-12v-10ohm',
        'v2',
        runtime: runtime,
      );
      expect(currentForV2BeforeReanalysis, isNull);
      final currentForV1 = await store.current(
        'doc-circuit-12v-10ohm',
        'v1',
        runtime: runtime,
      );
      expect(currentForV1!.analysisId, analysisA.analysisId);

      // 20. Re-analyze.
      final analysisB = const AnalysisEngine().analyze(
        request: requestB,
        graph: documentV2,
        runtime: runtime,
      );
      await store.save(analysisB);

      // 21. New current = 0.6 A.
      expect(analysisB.status, AnalysisStatus.success);
      expect(analysisB.current, closeTo(0.6, 1e-9));

      // 22. Historical Analysis A remains unchanged.
      final analysisAAfterB = await store.byId(
        'doc-circuit-12v-10ohm',
        analysisA.analysisId,
        runtime: runtime,
      );
      expect(analysisAAfterB!.current, closeTo(1.2, 1e-9));
      expect(analysisAAfterB.documentVersion, 'v1');
      expect(analysisB.analysisId, isNot(analysisA.analysisId));

      final currentForV2 = await store.current(
        'doc-circuit-12v-10ohm',
        'v2',
        runtime: runtime,
      );
      expect(currentForV2!.analysisId, analysisB.analysisId);

      final fullHistory = await store.history(
        'doc-circuit-12v-10ohm',
        runtime: runtime,
      );
      expect(fullHistory, hasLength(2));
    },
  );

  group('Reproducibility', () {
    test('same inputs -> same engineering result, twice', () {
      final runtime = KnowledgeRuntime.activate(
        buildElectricalCorePackage(),
        allowUnsignedDevelopmentPackages: true,
      );
      final graph = buildCanonicalCircuitGraph();
      final request = AnalysisRequest(
        requestId: 'req-repro',
        documentId: 'doc-circuit-12v-10ohm',
        documentVersion: 'v1',
        knowledgePackageId: 'electrical-core',
      );

      final resultA = const AnalysisEngine().analyze(
        request: request,
        graph: graph,
        runtime: runtime,
      );
      final resultB = const AnalysisEngine().analyze(
        request: request,
        graph: graph,
        runtime: runtime,
      );

      expect(resultA.current, resultB.current);
      expect(resultA.power, resultB.power);
      expect(resultA.topology!.toJson(), resultB.topology!.toJson());
      expect(
        resultA.constraintResults.map((c) => c.toJson()).toList(),
        resultB.constraintResults.map((c) => c.toJson()).toList(),
      );
      expect(
        resultA.derivation.map((d) => d.toJson()).toList(),
        resultB.derivation.map((d) => d.toJson()).toList(),
      );
      expect(
        resultA.reproducibility!.documentHash,
        resultB.reproducibility!.documentHash,
      );
    });
  });

  group('Runtime upgrade', () {
    test(
      'historical analysis remains bound to the runtime it was produced with',
      () async {
        final tempDir2 = Directory.systemTemp.createTempSync(
          'ap-ek-020-upgrade-',
        );
        addTearDown(() => tempDir2.deleteSync(recursive: true));
        final store = AnalysisPersistenceStore(tempDir2);

        final runtimeV1 = KnowledgeRuntime.activate(
          buildElectricalCorePackage(),
          allowUnsignedDevelopmentPackages: true,
        );
        final graph = buildCanonicalCircuitGraph();
        final analysisA = const AnalysisEngine().analyze(
          request: AnalysisRequest(
            requestId: 'req-upgrade-a',
            documentId: 'doc-upgrade',
            documentVersion: 'v1',
            knowledgePackageId: 'electrical-core',
          ),
          graph: graph,
          runtime: runtimeV1,
        );
        await store.save(analysisA);

        // Activate a "newer" package (bumped compilerVersion) — a brand
        // new KnowledgeRuntime instance; runtimeV1 is untouched.
        final upgradedManifest = buildElectricalCorePackage();
        final packageV2 = KnowledgePackage(
          manifest: KnowledgePackageManifest(
            packageId: upgradedManifest.manifest.packageId,
            packageName: upgradedManifest.manifest.packageName,
            packageVersion: '1.1.0',
            schemaVersion: upgradedManifest.manifest.schemaVersion,
            sourceKnowledgeVersion:
                upgradedManifest.manifest.sourceKnowledgeVersion,
            compilerVersion: upgradedManifest.manifest.compilerVersion,
            createdUtc: upgradedManifest.manifest.createdUtc,
            publisherId: upgradedManifest.manifest.publisherId,
          ),
          dimensions: upgradedManifest.dimensions,
          units: upgradedManifest.units,
          componentModels: upgradedManifest.componentModels,
          laws: upgradedManifest.laws,
          equations: upgradedManifest.equations,
          constraints: upgradedManifest.constraints,
          provenance: upgradedManifest.provenance,
          developmentModeUnsigned: true,
        );
        final runtimeV2 = KnowledgeRuntime.activate(
          packageV2,
          allowUnsignedDevelopmentPackages: true,
        );

        expect(runtimeV1.identity.packageVersion, '1.0.0');
        expect(runtimeV2.identity.packageVersion, '1.1.0');

        // The historical analysis, reloaded, still reports its original runtime identity.
        final reloadedA = await store.byId(
          'doc-upgrade',
          analysisA.analysisId,
          runtime: runtimeV1,
        );
        expect(reloadedA!.runtimeIdentity.packageVersion, '1.0.0');

        // A new analysis against runtimeV2 uses the new identity.
        final analysisB = const AnalysisEngine().analyze(
          request: AnalysisRequest(
            requestId: 'req-upgrade-b',
            documentId: 'doc-upgrade',
            documentVersion: 'v1',
            knowledgePackageId: 'electrical-core',
          ),
          graph: graph,
          runtime: runtimeV2,
        );
        expect(analysisB.runtimeIdentity.packageVersion, '1.1.0');
      },
    );
  });

  group('Diagram Studio contract', () {
    test(
      'DS receives AnalysisResult through AnalysisRequest without performing the calculation itself',
      () {
        final runtime = KnowledgeRuntime.activate(
          buildElectricalCorePackage(),
          allowUnsignedDevelopmentPackages: true,
        );
        final graph = buildCanonicalCircuitGraph();

        // Simulates the Engine <-> Studio in-process boundary
        // (`engineering_engine: path: ../oep_engine`): Studio only ever
        // constructs a request and reads back typed result fields — no
        // `/` or `*` operator appears on this side of the boundary.
        AnalysisResult studioRequestsAnalysis(
          String documentId,
          String documentVersion,
        ) {
          final request = AnalysisRequest(
            requestId: 'req-studio',
            documentId: documentId,
            documentVersion: documentVersion,
            knowledgePackageId: 'electrical-core',
          );
          return const AnalysisEngine().analyze(
            request: request,
            graph: graph,
            runtime: runtime,
          );
        }

        final result = studioRequestsAnalysis('doc-studio', 'v1');
        expect(result.status, AnalysisStatus.success);
        expect(result.current, closeTo(1.2, 1e-9));
        expect(result.power, closeTo(14.4, 1e-9));
        // Component-level traceability (§31): every componentResult traces
        // back to its Engineering Object id.
        expect(
          result.componentResults.map((c) => c.sourceObjectId),
          containsAll(['source-1', 'resistor-1']),
        );
      },
    );
  });
}
