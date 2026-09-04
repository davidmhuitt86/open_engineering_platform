import 'dart:convert';

import '../graph/models/engineering_graph.dart';
import '../knowledge/knowledge_runtime.dart';
import '../knowledge/knowledge_runtime_errors.dart';
import '../knowledge/models/knowledge_definitions.dart';
import '../knowledge/models/knowledge_package.dart' show sha256Hex;
import '../knowledge/models/quantity.dart';
import '../shared/ids.dart';
import 'linear_system.dart';
import 'models/analysis_request.dart';
import 'models/analysis_result.dart';
import 'models/electrical_topology.dart';
import 'topology_extractor.dart';

/// Knowledge identities the first vertical slice's solver knows how to
/// stamp/evaluate. Referencing these by id (rather than a `switch` on
/// free-form strings scattered through the solver) keeps the mapping
/// from "component model" to "algorithmic behavior" in one place —
/// AP-EK-020 Phase 3: "It is acceptable for the solver to have
/// algorithmic implementation of the selected equation/model. It is NOT
/// acceptable for the knowledge identity to disappear into code."
class ElectricalCoreIds {
  static const resistorModel = 'component.passive.resistor';
  static const voltageSourceModel = 'component.source.voltage_ideal';
  static const referenceNodeModel = 'component.reference_node';
  static const ohmsLawLaw = 'law.ohms_law';

  /// A single equation object per law/relationship concept — matching
  /// how `oep_reference_library` actually authors equations (one
  /// `equation.ohms_law` object with `classification.aliases: ["V = IR"]`,
  /// not one authored object per algebraic rearrangement). The solver
  /// still records which unknown was solved for on the derivation step's
  /// description text; the equation *identity* stays the single
  /// authored id regardless of which variable it was rearranged for.
  static const ohmsLawEquation = 'equation.ohms_law';
  static const powerEquation = 'equation.power';
  static const resistancePositiveConstraint = 'constraint.resistance_positive';
  static const solverVersion = 'mna-gaussian-elimination-1.0.0';
}

/// Orchestrates AP-EK-020 §17: topology extraction → component/parameter
/// resolution → equation/law resolution → system construction →
/// deterministic solve → constraint evaluation → derivation →
/// provenance → [AnalysisResult]. No stage reads Diagram Studio UI
/// state; the only inputs are the [EngineeringGraph], the
/// [AnalysisRequest], and the [KnowledgeRuntime].
class AnalysisEngine {
  final TopologyExtractor _extractor;

  const AnalysisEngine({
    TopologyExtractor extractor = const TopologyExtractor(),
  }) : _extractor = extractor;

  AnalysisResult analyze({
    required AnalysisRequest request,
    required EngineeringGraph graph,
    required KnowledgeRuntime runtime,
  }) {
    final createdUtc = DateTime.now().toUtc().toIso8601String();
    final analysisId = EngineIds.generate('analysis');

    AnalysisResult failure(
      AnalysisStatus status,
      String code,
      String message, {
      ElectricalTopology? topology,
    }) {
      return AnalysisResult(
        analysisId: analysisId,
        requestId: request.requestId,
        documentId: request.documentId,
        documentVersion: request.documentVersion,
        status: status,
        runtimeIdentity: runtime.identity,
        topology: topology,
        diagnostics: [
          Diagnostic(
            severity: DiagnosticSeverity.error,
            code: code,
            message: message,
          ),
        ],
        createdUtc: createdUtc,
      );
    }

    ElectricalTopology topology;
    try {
      topology = _extractor.extract(graph);
    } on TopologyExtractionFailure catch (e) {
      final status = e.kind == TopologyFailureKind.missingReferenceNode
          ? AnalysisStatus.invalidInput
          : AnalysisStatus.unsupported;
      return failure(status, 'TOPOLOGY_${e.kind.name.toUpperCase()}', e.reason);
    }

    // Reference-node model resolution (Phase 6: "Reference Node Instance
    // → Reference Node Model" — resolution failure is a hard failure,
    // never a silent generic substitution).
    final referenceEngNode = topology.nodes.firstWhere((n) => n.isReference);
    final referenceModelId =
        graph
                .nodes[referenceEngNode.sourceObjectId]
                ?.metadata['componentModelId']
            as String?;
    if (referenceModelId == null ||
        !runtime.hasComponentModel(referenceModelId)) {
      return failure(
        AnalysisStatus.unsupported,
        'MODEL_RESOLUTION_FAILED',
        'Reference node "${referenceEngNode.sourceObjectId}" does not resolve to a known component model.',
        topology: topology,
      );
    }

    // Component model resolution (Phase 6).
    final resolvedModels = <String, ComponentModel>{};
    for (final component in topology.components) {
      if (component.componentModelId.isEmpty ||
          !runtime.hasComponentModel(component.componentModelId)) {
        return failure(
          AnalysisStatus.unsupported,
          'MODEL_RESOLUTION_FAILED',
          'Component instance "${component.id}" (from "${component.sourceObjectId}") does not resolve '
              'to a known component model ("${component.componentModelId}").',
          topology: topology,
        );
      }
      final model = runtime.getComponentModel(component.componentModelId);
      if (model.id != ElectricalCoreIds.resistorModel &&
          model.id != ElectricalCoreIds.voltageSourceModel) {
        return failure(
          AnalysisStatus.unsupported,
          'UNSUPPORTED_COMPONENT_MODEL',
          'Component model "${model.id}" is not supported by the linear DC solver.',
          topology: topology,
        );
      }
      resolvedModels[component.id] = model;
    }

    // Parameter resolution (Phase 7): typed Quantity extraction + dimensional validation.
    final resolvedComponents = <String, ComponentInstance>{};
    for (final component in topology.components) {
      final model = resolvedModels[component.id]!;
      final engNode = graph.nodes[component.sourceObjectId]!;
      final parameters = <String, Quantity>{};
      for (final paramDef in model.parameters) {
        final raw = engNode.properties[paramDef.name];
        if (raw == null) {
          if (!paramDef.required) {
            // Optional parameter (e.g. a resistor's maximum_voltage
            // rating) genuinely absent from this instance — not an
            // analysis failure, just nothing to resolve for it.
            continue;
          }
          return failure(
            AnalysisStatus.insufficientData,
            'MISSING_PARAMETER',
            'Component "${component.sourceObjectId}" is missing required parameter "${paramDef.name}".',
            topology: topology,
          );
        }
        final rawMap = raw as Map;
        final value = (rawMap['value'] as num).toDouble();
        final unitId = rawMap['unit'] as String;
        late final Unit unit;
        try {
          unit = runtime.getUnit(unitId);
        } on KnowledgeRuntimeException {
          return failure(
            AnalysisStatus.invalidInput,
            'UNKNOWN_UNIT',
            'Component "${component.sourceObjectId}" parameter "${paramDef.name}" references unknown unit "$unitId".',
            topology: topology,
          );
        }
        if (unit.dimensionId != paramDef.dimensionId) {
          return failure(
            AnalysisStatus.invalidInput,
            'DIMENSION_MISMATCH',
            'Component "${component.sourceObjectId}" parameter "${paramDef.name}" expects dimension '
                '"${paramDef.dimensionId}" but unit "$unitId" has dimension "${unit.dimensionId}".',
            topology: topology,
          );
        }
        parameters[paramDef.name] = runtime.quantity(value, unitId);
      }
      resolvedComponents[component.id] = ComponentInstance(
        id: component.id,
        sourceObjectId: component.sourceObjectId,
        componentModelId: component.componentModelId,
        parameters: parameters,
      );
    }

    // Resistance must be strictly positive to invert (R == 0 is a hard
    // singular-system condition, distinct from the R > 0 *constraint*
    // evaluated below against already-solved evidence).
    for (final component in resolvedComponents.values) {
      if (component.componentModelId == ElectricalCoreIds.resistorModel) {
        final r = component.parameters['resistance']!.baseValue;
        if (r == 0) {
          return failure(
            AnalysisStatus.singular,
            'ZERO_RESISTANCE',
            'Resistor "${component.sourceObjectId}" has zero resistance; the linear system is singular.',
            topology: topology,
          );
        }
      }
    }

    // System construction (Phase 8) — general MNA stamping, not a
    // "voltage divided by resistance" special case.
    final nodeUnknownIds =
        topology.nodes.where((n) => !n.isReference).map((n) => n.id).toList()
          ..sort();
    final voltageSourceComponentIds =
        resolvedComponents.values
            .where(
              (c) => c.componentModelId == ElectricalCoreIds.voltageSourceModel,
            )
            .map((c) => c.id)
            .toList()
          ..sort();
    final size = nodeUnknownIds.length + voltageSourceComponentIds.length;

    int? nodeIndex(String nodeId) {
      if (nodeId == topology.referenceNodeId) return null;
      final idx = nodeUnknownIds.indexOf(nodeId);
      return idx == -1 ? null : idx;
    }

    int auxIndex(String componentId) =>
        nodeUnknownIds.length + voltageSourceComponentIds.indexOf(componentId);

    final a = List.generate(size, (_) => List<double>.filled(size, 0));
    final b = List<double>.filled(size, 0);

    for (final branch in topology.branches) {
      final component = resolvedComponents[branch.componentInstanceId]!;
      final fromIdx = nodeIndex(branch.fromNodeId);
      final toIdx = nodeIndex(branch.toNodeId);

      if (component.componentModelId == ElectricalCoreIds.resistorModel) {
        final g = 1.0 / component.parameters['resistance']!.baseValue;
        if (fromIdx != null) a[fromIdx][fromIdx] += g;
        if (toIdx != null) a[toIdx][toIdx] += g;
        if (fromIdx != null && toIdx != null) {
          a[fromIdx][toIdx] -= g;
          a[toIdx][fromIdx] -= g;
        }
      } else {
        // voltageSourceModel — fromNode is '-', toNode is '+'.
        final k = auxIndex(component.id);
        if (fromIdx != null) a[fromIdx][k] += 1;
        if (toIdx != null) a[toIdx][k] -= 1;
        if (toIdx != null) a[k][toIdx] += 1;
        if (fromIdx != null) a[k][fromIdx] -= 1;
        b[k] = component.parameters['voltage']!.baseValue;
      }
    }

    List<double> solution;
    try {
      solution = solveLinearSystem(a, b);
    } on SingularSystemException catch (e) {
      return failure(
        AnalysisStatus.singular,
        'SINGULAR_SYSTEM',
        e.message,
        topology: topology,
      );
    }

    final nodeVoltages = <String, double>{topology.referenceNodeId: 0.0};
    for (var i = 0; i < nodeUnknownIds.length; i++) {
      nodeVoltages[nodeUnknownIds[i]] = solution[i];
    }
    final branchCurrents = <String, double>{};
    for (final branch in topology.branches) {
      final component = resolvedComponents[branch.componentInstanceId]!;
      if (component.componentModelId == ElectricalCoreIds.resistorModel) {
        final r = component.parameters['resistance']!.baseValue;
        branchCurrents[branch.id] =
            (nodeVoltages[branch.fromNodeId]! -
                nodeVoltages[branch.toNodeId]!) /
            r;
      } else {
        branchCurrents[branch.id] = solution[auxIndex(component.id)];
      }
    }

    // Equation resolution + evidence (Phase 3/15): re-derive the
    // resistor's current through the resolved Ohm's Law equation
    // (rather than only trusting the MNA numeric result) so the
    // recorded EquationResult/derivation genuinely comes from resolved
    // knowledge, and cross-check it agrees with the solved system.
    final resistorComponent = resolvedComponents.values.firstWhere(
      (c) => c.componentModelId == ElectricalCoreIds.resistorModel,
    );
    final resistorBranch = topology.branches.firstWhere(
      (br) => br.componentInstanceId == resistorComponent.id,
    );
    final sourceComponent = resolvedComponents.values.firstWhere(
      (c) => c.componentModelId == ElectricalCoreIds.voltageSourceModel,
    );

    final vQuantity = sourceComponent.parameters['voltage']!;
    final rQuantity = resistorComponent.parameters['resistance']!;
    final ohmsLawEquation = runtime.getEquation(
      ElectricalCoreIds.ohmsLawEquation,
    );
    final currentFromEquation = runtime.quantity(
      vQuantity.baseValue / rQuantity.baseValue,
      'unit.ampere',
    );

    final mnaCurrent = branchCurrents[resistorBranch.id]!.abs();
    final diagnostics = <Diagnostic>[];
    if ((currentFromEquation.value - mnaCurrent).abs() > 1e-9) {
      diagnostics.add(
        Diagnostic(
          severity: DiagnosticSeverity.error,
          code: 'SOLVER_EQUATION_MISMATCH',
          message:
              'MNA solve ($mnaCurrent A) and Ohm\'s Law equation evaluation '
              '(${currentFromEquation.value} A) disagree beyond tolerance.',
        ),
      );
    }

    final powerEquation = runtime.getEquation(ElectricalCoreIds.powerEquation);
    final powerQuantity = runtime.quantity(
      vQuantity.baseValue * currentFromEquation.baseValue,
      'unit.watt',
    );

    // Power balance (Phase 10 / §22).
    final sourceBranch = topology.branches.firstWhere(
      (br) => br.componentInstanceId == sourceComponent.id,
    );
    final sourceCurrent = branchCurrents[sourceBranch.id]!;
    final powerSuppliedBySource = vQuantity.baseValue * sourceCurrent;
    final powerAbsorbedByResistor = powerQuantity.value;
    final powerBalanceResidual =
        powerSuppliedBySource - powerAbsorbedByResistor;
    diagnostics.add(
      Diagnostic(
        severity: powerBalanceResidual.abs() > 1e-6
            ? DiagnosticSeverity.warning
            : DiagnosticSeverity.info,
        code: 'POWER_BALANCE_CHECK',
        message:
            'Source supplies ${powerSuppliedBySource}W; resistor absorbs ${powerAbsorbedByResistor}W; '
            'residual ${powerBalanceResidual}W.',
      ),
    );

    // Constraint evaluation (Phase 10 / §21).
    final constraintDef = runtime.getConstraint(
      ElectricalCoreIds.resistancePositiveConstraint,
    );
    final constraintSatisfied = _evaluateConstraint(
      constraintDef,
      rQuantity.value,
    );
    final constraintResults = [
      ConstraintResult(
        constraintId: constraintDef.id,
        satisfied: constraintSatisfied,
        subject: constraintDef.subject,
        observedValue: rQuantity.value,
        message: constraintSatisfied
            ? 'resistance (${rQuantity.value} ${rQuantity.unit.symbol}) > 0 — SATISFIED'
            : 'resistance (${rQuantity.value} ${rQuantity.unit.symbol}) does not satisfy R > 0',
      ),
    ];

    // Derivation (Phase 11 / §23) — structured steps, not prose.
    final derivation = <DerivationStep>[
      DerivationStep(
        stepNumber: 1,
        description: 'Resolve source voltage.',
        inputs: const {},
        output: {
          'name': 'V',
          'value': vQuantity.value,
          'unitId': vQuantity.unit.id,
        },
      ),
      DerivationStep(
        stepNumber: 2,
        description: 'Resolve resistance.',
        inputs: const {},
        output: {
          'name': 'R',
          'value': rQuantity.value,
          'unitId': rQuantity.unit.id,
        },
      ),
      DerivationStep(
        stepNumber: 3,
        description: "Apply Ohm's Law.",
        equationId: ohmsLawEquation.id,
        equationVersion: ohmsLawEquation.version,
        equationExpression: ohmsLawEquation.expression,
        inputs: {'V': vQuantity.value, 'R': rQuantity.value},
      ),
      DerivationStep(
        stepNumber: 4,
        description: 'Evaluate.',
        equationId: ohmsLawEquation.id,
        equationVersion: ohmsLawEquation.version,
        equationExpression: ohmsLawEquation.expression,
        inputs: {'V': vQuantity.value, 'R': rQuantity.value},
        output: {
          'name': 'I',
          'value': currentFromEquation.value,
          'unitId': currentFromEquation.unit.id,
        },
      ),
      DerivationStep(
        stepNumber: 5,
        description: 'Apply power equation.',
        equationId: powerEquation.id,
        equationVersion: powerEquation.version,
        equationExpression: powerEquation.expression,
        inputs: {'V': vQuantity.value, 'I': currentFromEquation.value},
      ),
      DerivationStep(
        stepNumber: 6,
        description: 'Evaluate.',
        equationId: powerEquation.id,
        equationVersion: powerEquation.version,
        equationExpression: powerEquation.expression,
        inputs: {'V': vQuantity.value, 'I': currentFromEquation.value},
        output: {
          'name': 'P',
          'value': powerQuantity.value,
          'unitId': powerQuantity.unit.id,
        },
      ),
    ];

    // Provenance (Phase 12 / §24).
    final sourceModel = resolvedModels[sourceComponent.id]!;
    final resistorModel = resolvedModels[resistorComponent.id]!;
    final lawDef = runtime.getLaw(ElectricalCoreIds.ohmsLawLaw);
    final provenance = <AnalysisProvenanceEntry>[
      AnalysisProvenanceEntry(
        subject: 'V (source voltage)',
        sourceObjectId: sourceComponent.sourceObjectId,
        componentModelId: sourceModel.id,
        componentModelVersion: sourceModel.version,
        runtimeVersion: runtime.identity.runtimeVersion,
        knowledgePackageId: runtime.identity.packageId,
        knowledgePackageVersion: runtime.identity.packageVersion,
      ),
      AnalysisProvenanceEntry(
        subject: 'R (resistance)',
        sourceObjectId: resistorComponent.sourceObjectId,
        componentModelId: resistorModel.id,
        componentModelVersion: resistorModel.version,
        runtimeVersion: runtime.identity.runtimeVersion,
        knowledgePackageId: runtime.identity.packageId,
        knowledgePackageVersion: runtime.identity.packageVersion,
      ),
      AnalysisProvenanceEntry(
        subject: 'I (current)',
        lawId: lawDef.id,
        lawVersion: lawDef.version,
        equationId: ohmsLawEquation.id,
        equationVersion: ohmsLawEquation.version,
        runtimeVersion: runtime.identity.runtimeVersion,
        knowledgePackageId: runtime.identity.packageId,
        knowledgePackageVersion: runtime.identity.packageVersion,
      ),
      AnalysisProvenanceEntry(
        subject: 'P (resistor power)',
        equationId: powerEquation.id,
        equationVersion: powerEquation.version,
        runtimeVersion: runtime.identity.runtimeVersion,
        knowledgePackageId: runtime.identity.packageId,
        knowledgePackageVersion: runtime.identity.packageVersion,
      ),
    ];

    final componentResults = [
      ComponentResult(
        componentInstanceId: sourceComponent.id,
        sourceObjectId: sourceComponent.sourceObjectId,
        quantities: {
          'voltage': vQuantity.value,
          'current': sourceCurrent.abs(),
        },
        quantityUnitIds: {
          'voltage': vQuantity.unit.id,
          'current': 'unit.ampere',
        },
      ),
      ComponentResult(
        componentInstanceId: resistorComponent.id,
        sourceObjectId: resistorComponent.sourceObjectId,
        quantities: {
          'resistance': rQuantity.value,
          'current': currentFromEquation.value,
          'power': powerQuantity.value,
        },
        quantityUnitIds: {
          'resistance': rQuantity.unit.id,
          'current': 'unit.ampere',
          'power': 'unit.watt',
        },
      ),
    ];

    final nodeResults =
        nodeVoltages.entries
            .map((e) => NodeResult(nodeId: e.key, voltage: e.value))
            .toList()
          ..sort((x, y) => x.nodeId.compareTo(y.nodeId));
    final branchResults =
        branchCurrents.entries
            .map((e) => BranchResult(branchId: e.key, current: e.value))
            .toList()
          ..sort((x, y) => x.branchId.compareTo(y.branchId));

    final documentHash = sha256Hex(utf8.encode(jsonEncode(graph.toJson())));
    final status = constraintSatisfied
        ? AnalysisStatus.success
        : AnalysisStatus.failed;

    return AnalysisResult(
      analysisId: analysisId,
      requestId: request.requestId,
      documentId: request.documentId,
      documentVersion: request.documentVersion,
      status: status,
      runtimeIdentity: runtime.identity,
      topology: topology,
      componentResults: componentResults,
      nodeResults: nodeResults,
      branchResults: branchResults,
      equationResults: [
        EquationResult(
          equationId: ohmsLawEquation.id,
          equationVersion: ohmsLawEquation.version,
          inputs: {'V': vQuantity.value, 'R': rQuantity.value},
          outputValue: currentFromEquation.value,
          outputUnitId: currentFromEquation.unit.id,
        ),
        EquationResult(
          equationId: powerEquation.id,
          equationVersion: powerEquation.version,
          inputs: {'V': vQuantity.value, 'I': currentFromEquation.value},
          outputValue: powerQuantity.value,
          outputUnitId: powerQuantity.unit.id,
        ),
      ],
      constraintResults: constraintResults,
      diagnostics: diagnostics,
      derivation: derivation,
      provenance: provenance,
      reproducibility: ReproducibilityDescriptor(
        documentId: request.documentId,
        documentVersion: request.documentVersion,
        documentHash: documentHash,
        knowledgePackageId: runtime.identity.packageId,
        knowledgePackageVersion: runtime.identity.packageVersion,
        knowledgePackageHash: runtime.identity.contentHash,
        runtimeVersion: runtime.identity.runtimeVersion,
        compilerVersion: runtime.identity.compilerVersion,
        solverVersion: ElectricalCoreIds.solverVersion,
        numericPolicy: request.numericPolicy,
        analysisMode: request.analysisMode.name,
      ),
      createdUtc: createdUtc,
    );
  }

  bool _evaluateConstraint(ConstraintDefinition def, double observed) {
    switch (def.operator) {
      case ConstraintOperator.greaterThan:
        return observed > def.operand;
      case ConstraintOperator.greaterThanOrEqual:
        return observed >= def.operand;
      case ConstraintOperator.lessThan:
        return observed < def.operand;
      case ConstraintOperator.lessThanOrEqual:
        return observed <= def.operand;
      case ConstraintOperator.equal:
        return observed == def.operand;
      case ConstraintOperator.notEqual:
        return observed != def.operand;
    }
  }
}
