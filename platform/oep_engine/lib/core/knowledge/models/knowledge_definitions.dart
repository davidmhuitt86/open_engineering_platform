/// Component Model, Engineering Law, Equation, Constraint, and Provenance
/// definitions carried inside a compiled [KnowledgePackage] and exposed
/// through the Knowledge Runtime's typed registries (AP-EK-013 §21–25).
///
/// These are immutable, id/version-addressed definitions. None of them
/// contain executable behavior — evaluation of an [Equation] is performed
/// by the analysis layer's `EquationEvaluator` (`lib/core/analysis/`),
/// dispatched by `equationId` so that the equation's *identity* never
/// disappears into code (AP-EK-020 Phase 3), while the arithmetic itself
/// stays out of the knowledge model.
library;

/// Immutable source-lineage record for one authoritative knowledge item
/// (AP-EK-009 / AP-EK-013 §25).
class ProvenanceRecord {
  final String id;
  final String sourceObjectId;
  final String sourceReference;
  final String sourceKnowledgeVersion;
  final String compilerVersion;
  final String? contentHash;

  const ProvenanceRecord({
    required this.id,
    required this.sourceObjectId,
    required this.sourceReference,
    required this.sourceKnowledgeVersion,
    required this.compilerVersion,
    this.contentHash,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceObjectId': sourceObjectId,
    'sourceReference': sourceReference,
    'sourceKnowledgeVersion': sourceKnowledgeVersion,
    'compilerVersion': compilerVersion,
    'contentHash': contentHash,
  };

  factory ProvenanceRecord.fromJson(Map<String, Object?> json) =>
      ProvenanceRecord(
        id: json['id'] as String,
        sourceObjectId: json['sourceObjectId'] as String,
        sourceReference: json['sourceReference'] as String,
        sourceKnowledgeVersion: json['sourceKnowledgeVersion'] as String,
        compilerVersion: json['compilerVersion'] as String,
        contentHash: json['contentHash'] as String?,
      );
}

/// A named engineering equation (AP-EK-013 §21). `expression` is retained
/// as human-readable structured data only — it is not executed; the
/// analysis layer resolves `id` to a Dart evaluator function and records
/// `id`+`version` on every derivation step that uses it.
class Equation {
  final String id;
  final String version;
  final String expression;
  final List<String> variables;
  final List<String> dimensions;
  final String applicability;
  final String provenanceId;

  const Equation({
    required this.id,
    required this.version,
    required this.expression,
    required this.variables,
    required this.dimensions,
    required this.applicability,
    required this.provenanceId,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'expression': expression,
    'variables': variables,
    'dimensions': dimensions,
    'applicability': applicability,
    'provenanceId': provenanceId,
  };

  factory Equation.fromJson(Map<String, Object?> json) => Equation(
    id: json['id'] as String,
    version: json['version'] as String,
    expression: json['expression'] as String,
    variables: (json['variables'] as List).cast<String>(),
    dimensions: (json['dimensions'] as List).cast<String>(),
    applicability: json['applicability'] as String,
    provenanceId: json['provenanceId'] as String,
  );
}

/// A named engineering law (AP-EK-013 §22) — a law is not executable code;
/// it references the [Equation]s that express it.
class EngineeringLaw {
  final String id;
  final String version;
  final String name;
  final List<String> equationRefs;
  final String applicability;
  final String provenanceId;

  const EngineeringLaw({
    required this.id,
    required this.version,
    required this.name,
    required this.equationRefs,
    required this.applicability,
    required this.provenanceId,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'name': name,
    'equationRefs': equationRefs,
    'applicability': applicability,
    'provenanceId': provenanceId,
  };

  factory EngineeringLaw.fromJson(Map<String, Object?> json) => EngineeringLaw(
    id: json['id'] as String,
    version: json['version'] as String,
    name: json['name'] as String,
    equationRefs: (json['equationRefs'] as List).cast<String>(),
    applicability: json['applicability'] as String,
    provenanceId: json['provenanceId'] as String,
  );
}

/// A component terminal declared by a [ComponentModel].
class ModelTerminal {
  final String id;
  final String name;

  const ModelTerminal({required this.id, required this.name});

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory ModelTerminal.fromJson(Map<String, Object?> json) =>
      ModelTerminal(id: json['id'] as String, name: json['name'] as String);
}

/// A component's required parameter declaration — a name plus the
/// dimension its value must resolve to (AP-EK-013 §23 `parameters`).
class ModelParameter {
  final String name;
  final String dimensionId;
  final bool required;

  const ModelParameter({
    required this.name,
    required this.dimensionId,
    this.required = true,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'dimensionId': dimensionId,
    'required': required,
  };

  factory ModelParameter.fromJson(Map<String, Object?> json) => ModelParameter(
    name: json['name'] as String,
    dimensionId: json['dimensionId'] as String,
    required: json['required'] as bool? ?? true,
  );
}

/// A runtime Component Model (AP-EK-013 §23 / AP-EK-006). Component
/// *instances* in the Engineering Graph resolve to one of these by
/// `metadata['componentModelId']` (AP-EK-020 Phase 6) — resolution
/// failure is a hard analysis failure, never a silent generic fallback.
class ComponentModel {
  final String id;
  final String version;
  final String domain;
  final List<ModelTerminal> terminals;
  final List<ModelParameter> parameters;
  final List<String> equationRefs;
  final List<String> constraintRefs;
  final String applicability;
  final String provenanceId;

  const ComponentModel({
    required this.id,
    required this.version,
    required this.domain,
    required this.terminals,
    required this.parameters,
    required this.equationRefs,
    required this.constraintRefs,
    required this.applicability,
    required this.provenanceId,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'domain': domain,
    'terminals': terminals.map((t) => t.toJson()).toList(),
    'parameters': parameters.map((p) => p.toJson()).toList(),
    'equationRefs': equationRefs,
    'constraintRefs': constraintRefs,
    'applicability': applicability,
    'provenanceId': provenanceId,
  };

  factory ComponentModel.fromJson(Map<String, Object?> json) => ComponentModel(
    id: json['id'] as String,
    version: json['version'] as String,
    domain: json['domain'] as String,
    terminals: (json['terminals'] as List)
        .map((t) => ModelTerminal.fromJson(Map<String, Object?>.from(t as Map)))
        .toList(),
    parameters: (json['parameters'] as List)
        .map(
          (p) => ModelParameter.fromJson(Map<String, Object?>.from(p as Map)),
        )
        .toList(),
    equationRefs: (json['equationRefs'] as List).cast<String>(),
    constraintRefs: (json['constraintRefs'] as List? ?? const [])
        .cast<String>(),
    applicability: json['applicability'] as String,
    provenanceId: json['provenanceId'] as String,
  );
}

/// Constraint comparison operators (AP-EK-013 §24 `condition`).
enum ConstraintOperator {
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  equal,
  notEqual,
}

/// A structured engineering constraint (AP-EK-013 §24). `subject` names
/// the parameter being checked (e.g. `resistance`); evaluation is
/// performed by the analysis layer against the resolved [Quantity],
/// never by re-deriving the value.
class ConstraintDefinition {
  final String id;
  final String version;
  final String type;
  final String subject;
  final ConstraintOperator operator;
  final double operand;
  final String severity;
  final String applicability;
  final String provenanceId;

  const ConstraintDefinition({
    required this.id,
    required this.version,
    required this.type,
    required this.subject,
    required this.operator,
    required this.operand,
    required this.severity,
    required this.applicability,
    required this.provenanceId,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'type': type,
    'subject': subject,
    'operator': operator.name,
    'operand': operand,
    'severity': severity,
    'applicability': applicability,
    'provenanceId': provenanceId,
  };

  factory ConstraintDefinition.fromJson(Map<String, Object?> json) =>
      ConstraintDefinition(
        id: json['id'] as String,
        version: json['version'] as String,
        type: json['type'] as String,
        subject: json['subject'] as String,
        operator: ConstraintOperator.values.firstWhere(
          (o) => o.name == json['operator'],
        ),
        operand: (json['operand'] as num).toDouble(),
        severity: json['severity'] as String,
        applicability: json['applicability'] as String,
        provenanceId: json['provenanceId'] as String,
      );
}
