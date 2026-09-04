import '../../knowledge/knowledge_runtime.dart';
import '../../knowledge/models/quantity.dart';
import 'electrical_topology.dart';

/// AP-EK-020 §19–§25, §20 — the immutable evidence artifact produced by
/// one analysis run, and its constituent structured-evidence types.

/// AP-EK-020 §20 minimum result statuses.
enum AnalysisStatus {
  success,
  partial,
  invalidInput,
  unsupported,
  nonConvergent,
  singular,
  inconsistent,
  insufficientData,
  failed,
  stale,
}

enum DiagnosticSeverity { info, warning, error }

class Diagnostic {
  final DiagnosticSeverity severity;
  final String code;
  final String message;

  const Diagnostic({
    required this.severity,
    required this.code,
    required this.message,
  });

  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'code': code,
    'message': message,
  };

  factory Diagnostic.fromJson(Map<String, Object?> json) => Diagnostic(
    severity: DiagnosticSeverity.values.firstWhere(
      (s) => s.name == json['severity'],
    ),
    code: json['code'] as String,
    message: json['message'] as String,
  );
}

/// One structured derivation step (AP-EK-020 §23) — data first, not a
/// pre-formatted paragraph. `explanation_service.dart` turns these into
/// prose without recomputing anything.
class DerivationStep {
  final int stepNumber;
  final String description;
  final String? equationId;
  final String? equationVersion;

  /// The equation's human-readable form (e.g. `"I = V / R"`), copied
  /// verbatim from the resolved `Equation.expression` at derivation-
  /// assembly time — retained as data on the step so the Explanation
  /// Service can render it without depending on the Knowledge Runtime
  /// (it consumes [AnalysisResult] only).
  final String? equationExpression;
  final Map<String, Object?> inputs;
  final Map<String, Object?>? output;

  const DerivationStep({
    required this.stepNumber,
    required this.description,
    this.equationId,
    this.equationVersion,
    this.equationExpression,
    this.inputs = const {},
    this.output,
  });

  Map<String, Object?> toJson() => {
    'stepNumber': stepNumber,
    'description': description,
    'equationId': equationId,
    'equationVersion': equationVersion,
    'equationExpression': equationExpression,
    'inputs': inputs,
    'output': output,
  };

  factory DerivationStep.fromJson(Map<String, Object?> json) => DerivationStep(
    stepNumber: (json['stepNumber'] as num).toInt(),
    description: json['description'] as String,
    equationId: json['equationId'] as String?,
    equationVersion: json['equationVersion'] as String?,
    equationExpression: json['equationExpression'] as String?,
    inputs: Map<String, Object?>.from(json['inputs'] as Map? ?? const {}),
    output: json['output'] == null
        ? null
        : Map<String, Object?>.from(json['output'] as Map),
  );
}

/// One provenance entry (AP-EK-020 §24): answers "where did this value
/// come from, and which knowledge/runtime version produced it?".
class AnalysisProvenanceEntry {
  final String subject;
  final String? sourceObjectId;
  final String? componentModelId;
  final String? componentModelVersion;
  final String? lawId;
  final String? lawVersion;
  final String? equationId;
  final String? equationVersion;
  final String runtimeVersion;
  final String knowledgePackageId;
  final String knowledgePackageVersion;

  const AnalysisProvenanceEntry({
    required this.subject,
    this.sourceObjectId,
    this.componentModelId,
    this.componentModelVersion,
    this.lawId,
    this.lawVersion,
    this.equationId,
    this.equationVersion,
    required this.runtimeVersion,
    required this.knowledgePackageId,
    required this.knowledgePackageVersion,
  });

  Map<String, Object?> toJson() => {
    'subject': subject,
    'sourceObjectId': sourceObjectId,
    'componentModelId': componentModelId,
    'componentModelVersion': componentModelVersion,
    'lawId': lawId,
    'lawVersion': lawVersion,
    'equationId': equationId,
    'equationVersion': equationVersion,
    'runtimeVersion': runtimeVersion,
    'knowledgePackageId': knowledgePackageId,
    'knowledgePackageVersion': knowledgePackageVersion,
  };

  factory AnalysisProvenanceEntry.fromJson(Map<String, Object?> json) =>
      AnalysisProvenanceEntry(
        subject: json['subject'] as String,
        sourceObjectId: json['sourceObjectId'] as String?,
        componentModelId: json['componentModelId'] as String?,
        componentModelVersion: json['componentModelVersion'] as String?,
        lawId: json['lawId'] as String?,
        lawVersion: json['lawVersion'] as String?,
        equationId: json['equationId'] as String?,
        equationVersion: json['equationVersion'] as String?,
        runtimeVersion: json['runtimeVersion'] as String,
        knowledgePackageId: json['knowledgePackageId'] as String,
        knowledgePackageVersion: json['knowledgePackageVersion'] as String,
      );
}

class ConstraintResult {
  final String constraintId;
  final bool satisfied;
  final String subject;
  final double observedValue;
  final String message;

  const ConstraintResult({
    required this.constraintId,
    required this.satisfied,
    required this.subject,
    required this.observedValue,
    required this.message,
  });

  Map<String, Object?> toJson() => {
    'constraintId': constraintId,
    'satisfied': satisfied,
    'subject': subject,
    'observedValue': observedValue,
    'message': message,
  };

  factory ConstraintResult.fromJson(Map<String, Object?> json) =>
      ConstraintResult(
        constraintId: json['constraintId'] as String,
        satisfied: json['satisfied'] as bool,
        subject: json['subject'] as String,
        observedValue: (json['observedValue'] as num).toDouble(),
        message: json['message'] as String,
      );
}

class EquationResult {
  final String equationId;
  final String equationVersion;
  final Map<String, double> inputs;
  final double outputValue;
  final String outputUnitId;

  const EquationResult({
    required this.equationId,
    required this.equationVersion,
    required this.inputs,
    required this.outputValue,
    required this.outputUnitId,
  });

  Map<String, Object?> toJson() => {
    'equationId': equationId,
    'equationVersion': equationVersion,
    'inputs': inputs,
    'outputValue': outputValue,
    'outputUnitId': outputUnitId,
  };

  factory EquationResult.fromJson(Map<String, Object?> json) => EquationResult(
    equationId: json['equationId'] as String,
    equationVersion: json['equationVersion'] as String,
    inputs: Map<String, double>.from(
      (json['inputs'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
    ),
    outputValue: (json['outputValue'] as num).toDouble(),
    outputUnitId: json['outputUnitId'] as String,
  );
}

class ComponentResult {
  final String componentInstanceId;
  final String sourceObjectId;
  final Map<String, double> quantities;
  final Map<String, String> quantityUnitIds;

  const ComponentResult({
    required this.componentInstanceId,
    required this.sourceObjectId,
    required this.quantities,
    required this.quantityUnitIds,
  });

  Map<String, Object?> toJson() => {
    'componentInstanceId': componentInstanceId,
    'sourceObjectId': sourceObjectId,
    'quantities': quantities,
    'quantityUnitIds': quantityUnitIds,
  };

  factory ComponentResult.fromJson(Map<String, Object?> json) =>
      ComponentResult(
        componentInstanceId: json['componentInstanceId'] as String,
        sourceObjectId: json['sourceObjectId'] as String,
        quantities: Map<String, double>.from(
          (json['quantities'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        ),
        quantityUnitIds: Map<String, String>.from(
          json['quantityUnitIds'] as Map,
        ),
      );
}

class NodeResult {
  final String nodeId;
  final double voltage;

  const NodeResult({required this.nodeId, required this.voltage});

  Map<String, Object?> toJson() => {'nodeId': nodeId, 'voltage': voltage};

  factory NodeResult.fromJson(Map<String, Object?> json) => NodeResult(
    nodeId: json['nodeId'] as String,
    voltage: (json['voltage'] as num).toDouble(),
  );
}

class BranchResult {
  final String branchId;
  final double current;

  const BranchResult({required this.branchId, required this.current});

  Map<String, Object?> toJson() => {'branchId': branchId, 'current': current};

  factory BranchResult.fromJson(Map<String, Object?> json) => BranchResult(
    branchId: json['branchId'] as String,
    current: (json['current'] as num).toDouble(),
  );
}

/// AP-EK-020 §25 — sufficient identity to reproduce the analysis. If any
/// required identity could not be recorded, [complete] is false and
/// [missing] names what's absent — reduced reproducibility is reported
/// explicitly rather than silently claimed.
class ReproducibilityDescriptor {
  final String documentId;
  final String documentVersion;
  final String documentHash;
  final String knowledgePackageId;
  final String knowledgePackageVersion;
  final String knowledgePackageHash;
  final String runtimeVersion;
  final String compilerVersion;
  final String solverVersion;
  final String numericPolicy;
  final String analysisMode;
  final bool complete;
  final List<String> missing;

  const ReproducibilityDescriptor({
    required this.documentId,
    required this.documentVersion,
    required this.documentHash,
    required this.knowledgePackageId,
    required this.knowledgePackageVersion,
    required this.knowledgePackageHash,
    required this.runtimeVersion,
    required this.compilerVersion,
    required this.solverVersion,
    required this.numericPolicy,
    required this.analysisMode,
    this.complete = true,
    this.missing = const [],
  });

  Map<String, Object?> toJson() => {
    'documentId': documentId,
    'documentVersion': documentVersion,
    'documentHash': documentHash,
    'knowledgePackageId': knowledgePackageId,
    'knowledgePackageVersion': knowledgePackageVersion,
    'knowledgePackageHash': knowledgePackageHash,
    'runtimeVersion': runtimeVersion,
    'compilerVersion': compilerVersion,
    'solverVersion': solverVersion,
    'numericPolicy': numericPolicy,
    'analysisMode': analysisMode,
    'complete': complete,
    'missing': missing,
  };

  factory ReproducibilityDescriptor.fromJson(Map<String, Object?> json) =>
      ReproducibilityDescriptor(
        documentId: json['documentId'] as String,
        documentVersion: json['documentVersion'] as String,
        documentHash: json['documentHash'] as String,
        knowledgePackageId: json['knowledgePackageId'] as String,
        knowledgePackageVersion: json['knowledgePackageVersion'] as String,
        knowledgePackageHash: json['knowledgePackageHash'] as String,
        runtimeVersion: json['runtimeVersion'] as String,
        compilerVersion: json['compilerVersion'] as String,
        solverVersion: json['solverVersion'] as String,
        numericPolicy: json['numericPolicy'] as String,
        analysisMode: json['analysisMode'] as String,
        complete: json['complete'] as bool? ?? true,
        missing: (json['missing'] as List? ?? const []).cast<String>(),
      );
}

/// AP-EK-020 §19 — the immutable AnalysisResult. Constructing one does
/// not imply persistence; see `analysis_persistence.dart`.
class AnalysisResult {
  final String analysisId;
  final String requestId;
  final String documentId;
  final String documentVersion;
  final AnalysisStatus status;
  final RuntimeIdentity runtimeIdentity;
  final ElectricalTopology? topology;
  final List<ComponentResult> componentResults;
  final List<NodeResult> nodeResults;
  final List<BranchResult> branchResults;
  final List<EquationResult> equationResults;
  final List<ConstraintResult> constraintResults;
  final List<Diagnostic> diagnostics;
  final List<DerivationStep> derivation;
  final List<AnalysisProvenanceEntry> provenance;
  final ReproducibilityDescriptor? reproducibility;
  final String createdUtc;

  const AnalysisResult({
    required this.analysisId,
    required this.requestId,
    required this.documentId,
    required this.documentVersion,
    required this.status,
    required this.runtimeIdentity,
    this.topology,
    this.componentResults = const [],
    this.nodeResults = const [],
    this.branchResults = const [],
    this.equationResults = const [],
    this.constraintResults = const [],
    this.diagnostics = const [],
    this.derivation = const [],
    this.provenance = const [],
    this.reproducibility,
    required this.createdUtc,
  });

  /// Convenience accessor: the resistor's current, in amperes, when
  /// present in [componentResults] — used by callers (Studio,
  /// explanation) that don't want to re-derive the topology shape.
  double? get current {
    for (final c in componentResults) {
      final value = c.quantities['current'];
      if (value != null) return value;
    }
    return null;
  }

  double? get power {
    for (final c in componentResults) {
      final value = c.quantities['power'];
      if (value != null) return value;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'analysisId': analysisId,
    'requestId': requestId,
    'documentId': documentId,
    'documentVersion': documentVersion,
    'status': status.name,
    'runtimeIdentity': runtimeIdentity.toJson(),
    'topology': topology?.toJson(),
    'componentResults': componentResults.map((c) => c.toJson()).toList(),
    'nodeResults': nodeResults.map((n) => n.toJson()).toList(),
    'branchResults': branchResults.map((b) => b.toJson()).toList(),
    'equationResults': equationResults.map((e) => e.toJson()).toList(),
    'constraintResults': constraintResults.map((c) => c.toJson()).toList(),
    'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
    'derivation': derivation.map((d) => d.toJson()).toList(),
    'provenance': provenance.map((p) => p.toJson()).toList(),
    'reproducibility': reproducibility?.toJson(),
    'createdUtc': createdUtc,
  };

  /// [runtime] must be the same (or a runtime-identity-compatible)
  /// snapshot the analysis was originally produced with, so stored
  /// `unitId`s inside [topology] resolve back to the same typed
  /// [Quantity]s — pass `null` to skip topology reconstruction when the
  /// caller only needs the scalar results/evidence.
  factory AnalysisResult.fromJson(
    Map<String, Object?> json, {
    KnowledgeRuntime? runtime,
  }) => AnalysisResult(
    analysisId: json['analysisId'] as String,
    requestId: json['requestId'] as String,
    documentId: json['documentId'] as String,
    documentVersion: json['documentVersion'] as String,
    status: AnalysisStatus.values.firstWhere((s) => s.name == json['status']),
    runtimeIdentity: RuntimeIdentity.fromJson(
      Map<String, Object?>.from(json['runtimeIdentity'] as Map),
    ),
    topology: (json['topology'] == null || runtime == null)
        ? null
        : ElectricalTopology.fromJson(
            Map<String, Object?>.from(json['topology'] as Map),
            runtime,
          ),
    componentResults: (json['componentResults'] as List? ?? const [])
        .map(
          (c) => ComponentResult.fromJson(Map<String, Object?>.from(c as Map)),
        )
        .toList(),
    nodeResults: (json['nodeResults'] as List? ?? const [])
        .map((n) => NodeResult.fromJson(Map<String, Object?>.from(n as Map)))
        .toList(),
    branchResults: (json['branchResults'] as List? ?? const [])
        .map((b) => BranchResult.fromJson(Map<String, Object?>.from(b as Map)))
        .toList(),
    equationResults: (json['equationResults'] as List? ?? const [])
        .map(
          (e) => EquationResult.fromJson(Map<String, Object?>.from(e as Map)),
        )
        .toList(),
    constraintResults: (json['constraintResults'] as List? ?? const [])
        .map(
          (c) => ConstraintResult.fromJson(Map<String, Object?>.from(c as Map)),
        )
        .toList(),
    diagnostics: (json['diagnostics'] as List? ?? const [])
        .map((d) => Diagnostic.fromJson(Map<String, Object?>.from(d as Map)))
        .toList(),
    derivation: (json['derivation'] as List? ?? const [])
        .map(
          (d) => DerivationStep.fromJson(Map<String, Object?>.from(d as Map)),
        )
        .toList(),
    provenance: (json['provenance'] as List? ?? const [])
        .map(
          (p) => AnalysisProvenanceEntry.fromJson(
            Map<String, Object?>.from(p as Map),
          ),
        )
        .toList(),
    reproducibility: json['reproducibility'] == null
        ? null
        : ReproducibilityDescriptor.fromJson(
            Map<String, Object?>.from(json['reproducibility'] as Map),
          ),
    createdUtc: json['createdUtc'] as String,
  );
}
