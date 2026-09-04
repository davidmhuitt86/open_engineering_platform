// ignore_for_file: avoid_print
//
// Manual/CI verification script (AP-EK-020 Part A/C evidence) — not a
// `flutter test`, since it depends on a `.oerp` produced by the Python
// Reference Compiler, which SDD-R010 §16 forbids committing to git
// (`knowledge/reference_library/.gitignore`: "/dist/", "*.oerp" —
// "Compiler output shall never be submitted"). Run:
//
//   cd knowledge/reference_library && python -m compiler.cli core_reference
//   cd ../../platform/oep_engine && dart run tool/verify_oerp_reader.dart
//
// This proves the real Reference Library -> Compiler -> .oerp ->
// OerpReader -> KnowledgeRuntime -> AnalysisEngine chain end-to-end
// against genuinely compiled content, not the Dart fixture.
import 'dart:io';

import 'package:engineering_engine/core/analysis/analysis_engine.dart';
import 'package:engineering_engine/core/analysis/analysis_persistence.dart';
import 'package:engineering_engine/core/analysis/explanation_service.dart';
import 'package:engineering_engine/core/analysis/fixtures/canonical_circuit_fixture.dart';
import 'package:engineering_engine/core/analysis/models/analysis_request.dart';
import 'package:engineering_engine/core/analysis/models/analysis_result.dart';
import 'package:engineering_engine/core/knowledge/knowledge_runtime.dart';
import 'package:engineering_engine/core/knowledge/oerp/oerp_reader.dart';

Future<void> main() async {
  final oerpPath =
      '${Directory.current.path}${Platform.pathSeparator}'
      '..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'knowledge${Platform.pathSeparator}reference_library${Platform.pathSeparator}'
      'dist${Platform.pathSeparator}core_reference_v1.oerp';
  final file = File(oerpPath);
  if (!file.existsSync()) {
    stderr.writeln('No compiled package at $oerpPath.');
    stderr.writeln(
      'Run: cd knowledge/reference_library && python -m compiler.cli core_reference',
    );
    exit(1);
  }

  final package = const OerpReader().readFile(file);
  print(
    'Read package: ${package.manifest.packageId}@${package.manifest.packageVersion}',
  );
  print('Units: ${package.units.map((u) => u.id).join(", ")}');
  print(
    'Component models: ${package.componentModels.map((m) => m.id).join(", ")}',
  );
  print(
    'Equations: ${package.equations.map((e) => "${e.id} (${e.expression})").join(", ")}',
  );
  print('Constraints: ${package.constraints.map((c) => c.id).join(", ")}');

  final runtime = KnowledgeRuntime.activate(
    package,
    allowUnsignedDevelopmentPackages: true,
  );
  print(
    'Activated runtime: ${runtime.identity.runtimeVersion}, trust=${runtime.identity.trustState.name}, '
    'contentHash=${runtime.identity.contentHash}',
  );

  final graph = buildCanonicalCircuitGraph();
  final request = AnalysisRequest(
    requestId: 'req-verify',
    documentId: 'doc-verify',
    documentVersion: 'v1',
    knowledgePackageId: 'electrical-core',
  );
  final result = const AnalysisEngine().analyze(
    request: request,
    graph: graph,
    runtime: runtime,
  );

  print('Analysis status: ${result.status.name}');
  print('Current: ${result.current} A (expected 1.2)');
  print('Power: ${result.power} W (expected 14.4)');

  final current = result.current;
  final power = result.power;
  if (result.status != AnalysisStatus.success ||
      current == null ||
      power == null ||
      (current - 1.2).abs() > 1e-9 ||
      (power - 14.4).abs() > 1e-9) {
    stderr.writeln('VERIFICATION FAILED (initial analysis).');
    exit(1);
  }
  print('Analysis A (v1, 10 Ω): current=$current power=$power');

  // Persistence: save, then reload from disk.
  final tempDir = Directory.systemTemp.createTempSync('ap-ek-020-oerp-verify-');
  final store = AnalysisPersistenceStore(tempDir);
  await store.save(result);
  final reloaded = await store.byId(
    result.documentId,
    result.analysisId,
    runtime: runtime,
  );
  if (reloaded == null || (reloaded.current! - 1.2).abs() > 1e-9) {
    stderr.writeln('VERIFICATION FAILED (persistence/reload).');
    exit(1);
  }
  print('Persisted and reloaded: current=${reloaded.current} (unchanged)');

  // Explanation from the reloaded (real-compiled-package-derived) result.
  final explanation = const ExplanationService().explain(reloaded);
  print('Explanation:\n${explanation.text}');
  if (!explanation.text.contains('1.2') || !explanation.text.contains('14.4')) {
    stderr.writeln(
      'VERIFICATION FAILED (explanation missing canonical values).',
    );
    exit(1);
  }

  // Document mutation: 10 Ω -> 20 Ω, staleness, re-analysis.
  final graphV2 = buildCanonicalCircuitGraph(resistanceOhms: 20.0);
  final requestB = AnalysisRequest(
    requestId: 'req-verify-b',
    documentId: 'doc-verify',
    documentVersion: 'v2',
    knowledgePackageId: 'electrical-core',
  );
  final resultB = const AnalysisEngine().analyze(
    request: requestB,
    graph: graphV2,
    runtime: runtime,
  );
  await store.save(resultB);
  if (resultB.status != AnalysisStatus.success ||
      (resultB.current! - 0.6).abs() > 1e-9) {
    stderr.writeln('VERIFICATION FAILED (re-analysis after mutation).');
    exit(1);
  }
  print('Analysis B (v2, 20 Ω): current=${resultB.current} (expected 0.6)');

  final stillCurrentForV1 = await store.current(
    'doc-verify',
    'v1',
    runtime: runtime,
  );
  final currentForV2 = await store.current(
    'doc-verify',
    'v2',
    runtime: runtime,
  );
  if (stillCurrentForV1?.analysisId != result.analysisId ||
      currentForV2?.analysisId != resultB.analysisId) {
    stderr.writeln('VERIFICATION FAILED (staleness/history bookkeeping).');
    exit(1);
  }
  print(
    'Analysis A remains historical for v1; Analysis B is current for v2. Analysis A unmutated.',
  );

  tempDir.deleteSync(recursive: true);
  print('');
  print(
    'VERIFICATION PASSED: Reference Library -> Compiler -> .oerp -> OerpReader -> KnowledgeRuntime -> '
    'AnalysisEngine -> AnalysisResult -> Persistence -> Explanation, all against the genuinely compiled '
    'package, produced 1.2 A / 14.4 W (v1) and 0.6 A (v2) with historical Analysis A unchanged.',
  );
}
