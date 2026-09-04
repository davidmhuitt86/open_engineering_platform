import 'knowledge_runtime_errors.dart';
import 'models/knowledge_definitions.dart';
import 'models/knowledge_package.dart';
import 'models/quantity.dart';

/// Stable identity of one activated runtime snapshot (AP-EK-013 §6–7).
/// An [AnalysisResult] records this — never a mutable "current runtime"
/// pointer — so historical evidence stays bound to the exact snapshot
/// that produced it even after a newer package is later activated
/// (AP-EK-020 §8, §38).
class RuntimeIdentity {
  final String runtimeVersion;
  final String packageId;
  final String packageVersion;
  final String schemaVersion;
  final String compilerVersion;
  final String sourceKnowledgeVersion;
  final String contentHash;
  final PackageTrustState trustState;
  final bool developmentModeUnsigned;

  const RuntimeIdentity({
    required this.runtimeVersion,
    required this.packageId,
    required this.packageVersion,
    required this.schemaVersion,
    required this.compilerVersion,
    required this.sourceKnowledgeVersion,
    required this.contentHash,
    required this.trustState,
    required this.developmentModeUnsigned,
  });

  Map<String, Object?> toJson() => {
    'runtimeVersion': runtimeVersion,
    'packageId': packageId,
    'packageVersion': packageVersion,
    'schemaVersion': schemaVersion,
    'compilerVersion': compilerVersion,
    'sourceKnowledgeVersion': sourceKnowledgeVersion,
    'contentHash': contentHash,
    'trustState': trustState.name,
    'developmentModeUnsigned': developmentModeUnsigned,
  };

  factory RuntimeIdentity.fromJson(Map<String, Object?> json) =>
      RuntimeIdentity(
        runtimeVersion: json['runtimeVersion'] as String,
        packageId: json['packageId'] as String,
        packageVersion: json['packageVersion'] as String,
        schemaVersion: json['schemaVersion'] as String,
        compilerVersion: json['compilerVersion'] as String,
        sourceKnowledgeVersion: json['sourceKnowledgeVersion'] as String,
        contentHash: json['contentHash'] as String,
        trustState: PackageTrustState.values.firstWhere(
          (t) => t.name == json['trustState'],
        ),
        developmentModeUnsigned: json['developmentModeUnsigned'] as bool,
      );
}

/// An immutable, activated Knowledge Runtime snapshot (AP-EK-013 §11,
/// §16, §40). Every `getX(id)` lookup is a typed registry lookup over
/// pre-built, immutable indexes — the analysis layer never reads raw
/// package files directly (AP-EK-013 §44).
///
/// Each successful activation produces a brand-new `KnowledgeRuntime`
/// instance; activating a newer package never mutates an existing one
/// (AP-EK-013 §11 "Immutable Active Runtime"), so any code still holding
/// an older instance (e.g. a persisted [RuntimeIdentity] used to explain
/// historical evidence) is unaffected by a later activation.
class KnowledgeRuntime {
  final RuntimeIdentity identity;
  final KnowledgePackage package;

  final Map<String, Dimension> _dimensions;
  final Map<String, Unit> _units;
  final Map<String, ComponentModel> _componentModels;
  final Map<String, EngineeringLaw> _laws;
  final Map<String, Equation> _equations;
  final Map<String, ConstraintDefinition> _constraints;
  final Map<String, ProvenanceRecord> _provenance;

  KnowledgeRuntime._({
    required this.identity,
    required this.package,
    required Map<String, Dimension> dimensions,
    required Map<String, Unit> units,
    required Map<String, ComponentModel> componentModels,
    required Map<String, EngineeringLaw> laws,
    required Map<String, Equation> equations,
    required Map<String, ConstraintDefinition> constraints,
    required Map<String, ProvenanceRecord> provenance,
  }) : _dimensions = dimensions,
       _units = units,
       _componentModels = componentModels,
       _laws = laws,
       _equations = equations,
       _constraints = constraints,
       _provenance = provenance;

  Dimension getDimension(String id) => _lookup(_dimensions, id, 'dimension');
  Unit getUnit(String id) => _lookup(_units, id, 'unit');
  ComponentModel getComponentModel(String id) =>
      _lookup(_componentModels, id, 'componentModel');
  EngineeringLaw getLaw(String id) => _lookup(_laws, id, 'law');
  Equation getEquation(String id) => _lookup(_equations, id, 'equation');
  ConstraintDefinition getConstraint(String id) =>
      _lookup(_constraints, id, 'constraint');
  ProvenanceRecord getProvenance(String id) =>
      _lookup(_provenance, id, 'provenance');

  bool hasComponentModel(String id) => _componentModels.containsKey(id);

  /// Constructs a typed [Quantity] by resolving `unitId` and its
  /// dimension through this runtime's registries — the only sanctioned
  /// way a raw numeric value becomes a dimensionally-meaningful quantity
  /// (AP-EK-020 §13).
  Quantity quantity(double value, String unitId) {
    final unit = getUnit(unitId);
    final dimension = getDimension(unit.dimensionId);
    return Quantity(value, unit, dimension);
  }

  T _lookup<T>(Map<String, T> registry, String id, String kind) {
    final value = registry[id];
    if (value == null) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.referenceNotFound,
        'No $kind registered with id "$id" in runtime $identity.runtimeVersion.',
      );
    }
    return value;
  }

  /// AP-EK-013 §8/§9/§10: Load → Parse → Validate → Verify Integrity →
  /// Verify Signature/Trust → Build Immutable Registries → Activate.
  /// Failure at any stage prevents activation — no partially-built
  /// runtime is ever returned.
  ///
  /// [allowUnsignedDevelopmentPackages] permits an explicit, visible
  /// development-mode exception for unsigned packages (§43); the
  /// resulting [RuntimeIdentity.developmentModeUnsigned] flag makes that
  /// exception impossible to mistake for a production trust decision.
  static KnowledgeRuntime activate(
    KnowledgePackage package, {
    bool allowUnsignedDevelopmentPackages = false,
  }) {
    _validate(package);

    final computedHash = package.computeContentHash();
    final declaredHash = package.manifest.contentHash;
    if (declaredHash != null && declaredHash != computedHash) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageHashMismatch,
        'Package "${package.manifest.packageId}" declared contentHash '
        '$declaredHash but canonical content hashes to $computedHash.',
      );
    }

    var trustState = PackageTrustState.hashVerified;
    if (package.manifest.signature != null) {
      // Signature *verification* (Ed25519, AP-EK-013 §29) requires a
      // trusted publisher key store, which does not exist in this
      // repository yet — tracked as a disclosed gap in the AP-EK-020
      // final report, not silently assumed valid.
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageSignatureInvalid,
        'Package "${package.manifest.packageId}" declares a signature but '
        'no signature-verification trust store is implemented; refusing '
        'to activate a package this runtime cannot actually verify.',
      );
    } else if (!package.developmentModeUnsigned ||
        !allowUnsignedDevelopmentPackages) {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageSignatureInvalid,
        'Package "${package.manifest.packageId}" is unsigned and '
        'allowUnsignedDevelopmentPackages was not explicitly set — an '
        'untrusted package must not silently become an authoritative '
        'runtime snapshot (AP-EK-013 §30, §43).',
      );
    }
    trustState = PackageTrustState.validated;

    final dimensions = <String, Dimension>{};
    for (final d in package.dimensions) {
      if (dimensions.containsKey(d.id)) {
        throw KnowledgeRuntimeException(
          KnowledgeRuntimeErrorCode.duplicateAuthority,
          'Duplicate dimension id "${d.id}".',
        );
      }
      dimensions[d.id] = d;
    }
    final units = <String, Unit>{};
    for (final u in package.units) {
      if (units.containsKey(u.id)) {
        throw KnowledgeRuntimeException(
          KnowledgeRuntimeErrorCode.duplicateAuthority,
          'Duplicate unit id "${u.id}".',
        );
      }
      if (!dimensions.containsKey(u.dimensionId)) {
        throw KnowledgeRuntimeException(
          KnowledgeRuntimeErrorCode.invalidReference,
          'Unit "${u.id}" references unknown dimension "${u.dimensionId}".',
        );
      }
      units[u.id] = u;
    }
    final models = {for (final m in package.componentModels) m.id: m};
    final laws = {for (final l in package.laws) l.id: l};
    final equations = {for (final e in package.equations) e.id: e};
    final constraints = {for (final c in package.constraints) c.id: c};
    final provenance = {for (final p in package.provenance) p.id: p};

    trustState = PackageTrustState.active;

    return KnowledgeRuntime._(
      identity: RuntimeIdentity(
        runtimeVersion:
            '${package.manifest.packageId}@${package.manifest.packageVersion}',
        packageId: package.manifest.packageId,
        packageVersion: package.manifest.packageVersion,
        schemaVersion: package.manifest.schemaVersion,
        compilerVersion: package.manifest.compilerVersion,
        sourceKnowledgeVersion: package.manifest.sourceKnowledgeVersion,
        contentHash: computedHash,
        trustState: trustState,
        developmentModeUnsigned: package.developmentModeUnsigned,
      ),
      package: package,
      dimensions: dimensions,
      units: units,
      componentModels: models,
      laws: laws,
      equations: equations,
      constraints: constraints,
      provenance: provenance,
    );
  }

  static void _validate(KnowledgePackage package) {
    if (package.manifest.packageId.isEmpty) {
      throw const KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageInvalid,
        'Package manifest is missing a packageId.',
      );
    }
    if (package.manifest.schemaVersion != '1.0.0') {
      throw KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.schemaUnsupported,
        'Unsupported schemaVersion "${package.manifest.schemaVersion}" '
        '(runtime supports 1.0.0).',
      );
    }
    if (package.dimensions.isEmpty || package.units.isEmpty) {
      throw const KnowledgeRuntimeException(
        KnowledgeRuntimeErrorCode.packageInvalid,
        'Package declares no dimensions/units.',
      );
    }
  }
}
