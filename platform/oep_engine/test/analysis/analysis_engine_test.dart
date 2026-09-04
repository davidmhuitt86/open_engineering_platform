import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

KnowledgeRuntime _activate() => KnowledgeRuntime.activate(
  buildElectricalCorePackage(),
  allowUnsignedDevelopmentPackages: true,
);

AnalysisRequest _request({String documentVersion = 'v1'}) => AnalysisRequest(
  requestId: 'req-1',
  documentId: 'doc-circuit-12v-10ohm',
  documentVersion: documentVersion,
  knowledgePackageId: 'electrical-core',
);

void main() {
  group('Topology', () {
    test('correct node extraction: one internal node + reference node', () {
      final graph = buildCanonicalCircuitGraph();
      final topology = const TopologyExtractor().extract(graph);
      expect(topology.nodes.map((n) => n.id).toSet(), {'n1', 'gnd'});
      expect(topology.nodes.singleWhere((n) => n.isReference).id, 'gnd');
    });

    test('correct branch extraction', () {
      final graph = buildCanonicalCircuitGraph();
      final topology = const TopologyExtractor().extract(graph);
      expect(topology.branches, hasLength(2));
    });

    test('deterministic ordering across repeated extraction', () {
      final graph = buildCanonicalCircuitGraph();
      final a = const TopologyExtractor().extract(graph);
      final b = const TopologyExtractor().extract(graph);
      expect(
        a.nodes.map((n) => n.id).toList(),
        b.nodes.map((n) => n.id).toList(),
      );
      expect(
        a.branches.map((br) => br.id).toList(),
        b.branches.map((br) => br.id).toList(),
      );
    });

    test('missing reference node fails extraction', () {
      final builder = GraphBuilder(id: 'g')
        ..addNode(
          id: 'source-1',
          category: NodeCategory.component,
          displayName: 'Source',
        )
        ..addNode(
          id: 'resistor-1',
          category: NodeCategory.component,
          displayName: 'Resistor',
        )
        ..connect('source-1', 'resistor-1');
      expect(
        () => const TopologyExtractor().extract(builder.build()),
        throwsA(
          isA<TopologyExtractionFailure>().having(
            (e) => e.kind,
            'kind',
            TopologyFailureKind.missingReferenceNode,
          ),
        ),
      );
    });
  });

  group('Solver', () {
    late KnowledgeRuntime runtime;
    setUp(() => runtime = _activate());

    test('12 V / 10 Ω produces 1.2 A current', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      expect(result.status, AnalysisStatus.success);
      expect(result.current, closeTo(1.2, 1e-9));
    });

    test('resistor power = 14.4 W', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      expect(result.power, closeTo(14.4, 1e-9));
    });

    test(
      'correct sign convention: source supplies, resistor absorbs, balanced',
      () {
        final result = const AnalysisEngine().analyze(
          request: _request(),
          graph: buildCanonicalCircuitGraph(),
          runtime: runtime,
        );
        final balance = result.diagnostics.singleWhere(
          (d) => d.code == 'POWER_BALANCE_CHECK',
        );
        expect(balance.severity, DiagnosticSeverity.info);
      },
    );

    test('node voltages: n1 = 12 V, gnd = 0 V', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      final n1 = result.nodeResults.singleWhere((n) => n.nodeId == 'n1');
      final gnd = result.nodeResults.singleWhere((n) => n.nodeId == 'gnd');
      expect(n1.voltage, closeTo(12.0, 1e-9));
      expect(gnd.voltage, 0.0);
    });
  });

  group('Knowledge resolution', () {
    late KnowledgeRuntime runtime;
    setUp(() => runtime = _activate());

    test("Ohm's Law resolved from runtime and recorded on the derivation", () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      final step = result.derivation.singleWhere(
        (s) => s.description == "Apply Ohm's Law.",
      );
      expect(step.equationId, 'equation.ohms_law');
      expect(step.equationVersion, '1.0.0');
    });

    test('power equation resolved from runtime', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      final eq = result.equationResults.singleWhere(
        (e) => e.equationId == 'equation.power',
      );
      expect(eq.outputValue, closeTo(14.4, 1e-9));
    });

    test(
      'resistor model resolved from runtime (present in componentResults)',
      () {
        final result = const AnalysisEngine().analyze(
          request: _request(),
          graph: buildCanonicalCircuitGraph(),
          runtime: runtime,
        );
        expect(
          result.componentResults.map((c) => c.sourceObjectId),
          contains('resistor-1'),
        );
      },
    );
  });

  group('Evidence', () {
    late KnowledgeRuntime runtime;
    setUp(() => runtime = _activate());

    test('derivation contains 6 structured steps', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      expect(result.derivation, hasLength(6));
      expect(result.derivation.map((s) => s.stepNumber).toList(), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('provenance retains source lineage for every input/result', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      final voltageProvenance = result.provenance.singleWhere(
        (p) => p.subject == 'V (source voltage)',
      );
      expect(voltageProvenance.sourceObjectId, 'source-1');
      expect(
        voltageProvenance.componentModelId,
        'component.source.voltage_ideal',
      );
      final currentProvenance = result.provenance.singleWhere(
        (p) => p.subject == 'I (current)',
      );
      expect(currentProvenance.lawId, 'law.ohms_law');
      expect(currentProvenance.equationId, 'equation.ohms_law');
      expect(currentProvenance.knowledgePackageId, 'electrical-core');
    });

    test('constraint R > 0 is SATISFIED for the canonical circuit', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      final constraint = result.constraintResults.single;
      expect(constraint.constraintId, 'constraint.resistance_positive');
      expect(constraint.satisfied, isTrue);
    });

    test('reproducibility descriptor is complete', () {
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: buildCanonicalCircuitGraph(),
        runtime: runtime,
      );
      expect(result.reproducibility!.complete, isTrue);
      expect(
        result.reproducibility!.knowledgePackageHash,
        runtime.identity.contentHash,
      );
    });
  });

  group('Failures', () {
    late KnowledgeRuntime runtime;
    setUp(() => runtime = _activate());

    test('missing resistance -> INSUFFICIENT_DATA', () {
      final builder = GraphBuilder(id: 'g')
        ..addNode(
          id: 'source-1',
          category: NodeCategory.component,
          displayName: 'Source',
          metadata: const {
            'componentModelId': ElectricalCoreIds.voltageSourceModel,
          },
          properties: const {
            'voltage': {'value': 12.0, 'unit': 'unit.volt'},
          },
        )
        ..addNode(
          id: 'resistor-1',
          category: NodeCategory.component,
          displayName: 'Resistor',
          metadata: const {'componentModelId': ElectricalCoreIds.resistorModel},
        )
        ..addNode(
          id: 'ground-1',
          category: NodeCategory.ground,
          displayName: 'Ground',
          metadata: const {
            'componentModelId': ElectricalCoreIds.referenceNodeModel,
          },
        )
        ..connect('source-1', 'resistor-1')
        ..connect('resistor-1', 'ground-1');
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: builder.build(),
        runtime: runtime,
      );
      expect(result.status, AnalysisStatus.insufficientData);
    });

    test('invalid resistance unit (R = 10 V) -> INVALID_INPUT', () {
      final builder = GraphBuilder(id: 'g')
        ..addNode(
          id: 'source-1',
          category: NodeCategory.component,
          displayName: 'Source',
          metadata: const {
            'componentModelId': ElectricalCoreIds.voltageSourceModel,
          },
          properties: const {
            'voltage': {'value': 12.0, 'unit': 'unit.volt'},
          },
        )
        ..addNode(
          id: 'resistor-1',
          category: NodeCategory.component,
          displayName: 'Resistor',
          metadata: const {'componentModelId': ElectricalCoreIds.resistorModel},
          properties: const {
            'resistance': {'value': 10.0, 'unit': 'unit.volt'},
          },
        )
        ..addNode(
          id: 'ground-1',
          category: NodeCategory.ground,
          displayName: 'Ground',
          metadata: const {
            'componentModelId': ElectricalCoreIds.referenceNodeModel,
          },
        )
        ..connect('source-1', 'resistor-1')
        ..connect('resistor-1', 'ground-1');
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: builder.build(),
        runtime: runtime,
      );
      expect(result.status, AnalysisStatus.invalidInput);
    });

    test('missing reference node -> INVALID_INPUT', () {
      final builder = GraphBuilder(id: 'g')
        ..addNode(
          id: 'source-1',
          category: NodeCategory.component,
          displayName: 'Source',
          metadata: const {
            'componentModelId': ElectricalCoreIds.voltageSourceModel,
          },
          properties: const {
            'voltage': {'value': 12.0, 'unit': 'unit.volt'},
          },
        )
        ..addNode(
          id: 'resistor-1',
          category: NodeCategory.component,
          displayName: 'Resistor',
          metadata: const {'componentModelId': ElectricalCoreIds.resistorModel},
          properties: const {
            'resistance': {'value': 10.0, 'unit': 'unit.ohm'},
          },
        )
        ..connect('source-1', 'resistor-1');
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: builder.build(),
        runtime: runtime,
      );
      expect(result.status, AnalysisStatus.invalidInput);
    });

    test('unsupported component model -> UNSUPPORTED', () {
      final builder = GraphBuilder(id: 'g')
        ..addNode(
          id: 'source-1',
          category: NodeCategory.component,
          displayName: 'Source',
          metadata: const {
            'componentModelId': ElectricalCoreIds.voltageSourceModel,
          },
          properties: const {
            'voltage': {'value': 12.0, 'unit': 'unit.volt'},
          },
        )
        ..addNode(
          id: 'diode-1',
          category: NodeCategory.component,
          displayName: 'Diode',
          metadata: const {'componentModelId': 'component.nonlinear.diode'},
        )
        ..addNode(
          id: 'ground-1',
          category: NodeCategory.ground,
          displayName: 'Ground',
          metadata: const {
            'componentModelId': ElectricalCoreIds.referenceNodeModel,
          },
        )
        ..connect('source-1', 'diode-1')
        ..connect('diode-1', 'ground-1');
      final result = const AnalysisEngine().analyze(
        request: _request(),
        graph: builder.build(),
        runtime: runtime,
      );
      expect(result.status, AnalysisStatus.unsupported);
    });

    test('invalid knowledge package -> activation failure, never analyzed', () {
      final badPackage = KnowledgePackage(
        manifest: buildElectricalCorePackage().manifest,
        dimensions: const [],
        units: const [],
        componentModels: const [],
        laws: const [],
        equations: const [],
        constraints: const [],
        provenance: const [],
        developmentModeUnsigned: true,
      );
      expect(
        () => KnowledgeRuntime.activate(
          badPackage,
          allowUnsignedDevelopmentPackages: true,
        ),
        throwsA(isA<KnowledgeRuntimeException>()),
      );
    });
  });
}
