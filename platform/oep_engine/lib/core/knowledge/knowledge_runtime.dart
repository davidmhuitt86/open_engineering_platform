import 'knowledge_runtime_errors.dart';
import 'models/knowledge_definitions.dart';
import 'models/knowledge_package.dart';
import 'models/quantity.dart';

/// Stable identity of one activated runtime snapshot (AP-EK-013 §6–7).
/// An [AnalysisResult] records this — never a mutable "current runtime"
/// pointer — so historical evidence stays bound to the exact snapshot
/// that produced it even after a newer package is later activated
/// (AP-EK-020 §8, §38).
///
/// WP-EKE-013: the *package* (engineering knowledge content: [packageId],
/// [packageVersion], [schemaVersion], [compilerVersion], [contentHash])
/// and the *runtime* (the software that interprets it: [runtimeVersion],
/// [runtimeBuild]) are separate identities (AP-EK-013 §7). [runtimeVersion]
/// is never derived from the package.
class RuntimeIdentity {
  final String runtimeVersion;
  final String runtimeBuild;
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
    required this.runtimeBuild,
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
    'runtimeBuild': runtimeBuild,
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
        // Identities persisted before WP-EKE-013 carry no build.
        runtimeBuild: json['runtimeBuild'] as String? ?? 'unrecorded',
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

/// Deterministic capability report of one activated runtime (AP-EK-013
/// §33): derived directly from the immutable package — never dynamic or
/// heuristic. Every collection is unmodifiable.
class KnowledgeRuntimeCapabilities {
  /// Registry name -> number of authoritative entries (0 for an empty
  /// optional registry). Keys: dimensions, units, objects, relationships,
  /// componentModels, laws, equations, constraints, provenance.
  final Map<String, int> registryCounts;

  /// Distinct component-model domains, sorted.
  final List<String> domains;
  final List<String> unitIds;
  final List<String> lawIds;
  final List<String> equationIds;
  final List<String> componentModelIds;
  final List<String> constraintIds;

  const KnowledgeRuntimeCapabilities._({
    required this.registryCounts,
    required this.domains,
    required this.unitIds,
    required this.lawIds,
    required this.equationIds,
    required this.componentModelIds,
    required this.constraintIds,
  });

  /// Registries that hold at least one entry, sorted.
  List<String> get availableRegistries =>
      registryCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList()
        ..sort();

  bool has(String registry) => (registryCounts[registry] ?? 0) > 0;
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
///
/// WP-EKE-013: activation additionally rejects duplicate authoritative
/// ids in every registry and any dangling cross-reference, exposes the
/// Object and Relationship registries, and separates runtime identity
/// from package identity. All registries and the retained [package] are
/// unmodifiable.
class KnowledgeRuntime {
  /// Identity of this runtime *software* (AP-EK-013 §6-7), independent of
  /// any package. Mirrors `oep_engine`'s `pubspec.yaml` `version` (a test
  /// asserts they agree); [runtimeBuild] is bumped when runtime semantics
  /// change without a version bump.
  static const String runtimeVersion = '0.1.0';
  static const String runtimeBuild = '1';

  final RuntimeIdentity identity;
  final KnowledgePackage package;
  final KnowledgeRuntimeCapabilities capabilities;

  final Map<String, Dimension> _dimensions;
  final Map<String, Unit> _units;
  final Map<String, KnowledgeObject> _objects;
  final Map<String, KnowledgeRelationship> _relationships;
  final Map<String, List<KnowledgeRelationship>> _relationshipsByObject;
  final Map<String, ComponentModel> _componentModels;
  final Map<String, EngineeringLaw> _laws;
  final Map<String, Equation> _equations;
  final Map<String, ConstraintDefinition> _constraints;
  final Map<String, ProvenanceRecord> _provenance;

  KnowledgeRuntime._({
    required this.identity,
    required this.package,
    required this.capabilities,
    required Map<String, Dimension> dimensions,
    required Map<String, Unit> units,
    required Map<String, KnowledgeObject> objects,
    required Map<String, KnowledgeRelationship> relationships,
    required Map<String, List<KnowledgeRelationship>> relationshipsByObject,
    required Map<String, ComponentModel> componentModels,
    required Map<String, EngineeringLaw> laws,
    required Map<String, Equation> equations,
    required Map<String, ConstraintDefinition> constraints,
    required Map<String, ProvenanceRecord> provenance,
  }) : _dimensions = dimensions,
       _units = units,
       _objects = objects,
       _relationships = relationships,
       _relationshipsByObject = relationshipsByObject,
       _componentModels = componentModels,
       _laws = laws,
       _equations = equations,
       _constraints = constraints,
       _provenance = provenance;

  Dimension getDimension(String id) => _lookup(_dimensions, id, 'dimension');
  Unit getUnit(String id) => _lookup(_units, id, 'unit');
  KnowledgeObject getObject(String id) => _lookup(_objects, id, 'object');
  KnowledgeRelationship getRelationship(String id) =>
      _lookup(_relationships, id, 'relationship');

  /// Every relationship whose source or target is [objectId], sorted by
  /// relationship id. Throws `referenceNotFound` for an unknown object;
  /// an object with no relationships returns an empty list.
  List<KnowledgeRelationship> relationshipsForObject(String objectId) {
    getObject(objectId);
    return _relationshipsByObject[objectId] ?? const [];
  }

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
        'No $kind registered with id "$id" in runtime '
        '${identity.runtimeVersion} (package ${identity.packageId}'
        '@${identity.packageVersion}).',
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

    // AP-EK-013 §9 step 6: construct registries. Every registry rejects a
    // duplicate id explicitly; none relies on Map construction, which
    // would silently keep the last definition.
    final dimensions = _registry(package.dimensions, (d) => d.id, 'dimension');
    final units = _registry(package.units, (u) => u.id, 'unit');
    final objects = _registry(package.objects, (o) => o.id, 'object');
    final relationships = _registry(
      package.relationships,
      (r) => r.id,
      'relationship',
    );
    final models = _registry(
      package.componentModels,
      (m) => m.id,
      'componentModel',
    );
    final laws = _registry(package.laws, (l) => l.id, 'law');
    final equations = _registry(package.equations, (e) => e.id, 'equation');
    final constraints = _registry(
      package.constraints,
      (c) => c.id,
      'constraint',
    );
    final provenance = _registry(package.provenance, (p) => p.id, 'provenance');

    // AP-EK-013 §9 step 7: validate registry cross-references.
    _validateReferences(
      dimensions: dimensions,
      units: units,
      objects: objects,
      relationships: relationships,
      models: models,
      laws: laws,
      equations: equations,
      constraints: constraints,
      provenance: provenance,
    );

    final byObject = <String, List<KnowledgeRelationship>>{};
    for (final r in relationships.values) {
      byObject.putIfAbsent(r.sourceObjectId, () => []).add(r);
      if (r.targetObjectId != r.sourceObjectId) {
        byObject.putIfAbsent(r.targetObjectId, () => []).add(r);
      }
    }
    for (final list in byObject.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    trustState = PackageTrustState.active;

    return KnowledgeRuntime._(
      identity: RuntimeIdentity(
        runtimeVersion: runtimeVersion,
        runtimeBuild: runtimeBuild,
        packageId: package.manifest.packageId,
        packageVersion: package.manifest.packageVersion,
        schemaVersion: package.manifest.schemaVersion,
        compilerVersion: package.manifest.compilerVersion,
        sourceKnowledgeVersion: package.manifest.sourceKnowledgeVersion,
        contentHash: computedHash,
        trustState: trustState,
        developmentModeUnsigned: package.developmentModeUnsigned,
      ),
      package: package.frozenCopy(),
      capabilities: _capabilitiesFor(
        dimensions: dimensions,
        units: units,
        objects: objects,
        relationships: relationships,
        models: models,
        laws: laws,
        equations: equations,
        constraints: constraints,
        provenance: provenance,
      ),
      dimensions: dimensions,
      units: units,
      objects: objects,
      relationships: relationships,
      relationshipsByObject:
          Map<String, List<KnowledgeRelationship>>.unmodifiable({
            for (final e in byObject.entries)
              e.key: List<KnowledgeRelationship>.unmodifiable(e.value),
          }),
      componentModels: models,
      laws: laws,
      equations: equations,
      constraints: constraints,
      provenance: provenance,
    );
  }

  /// Builds one unmodifiable id -> definition registry, throwing
  /// `duplicateAuthority` the first time an id repeats.
  static Map<String, T> _registry<T>(
    List<T> items,
    String Function(T) idOf,
    String kind,
  ) {
    final registry = <String, T>{};
    for (final item in items) {
      final id = idOf(item);
      if (registry.containsKey(id)) {
        throw KnowledgeRuntimeException(
          KnowledgeRuntimeErrorCode.duplicateAuthority,
          'Duplicate $kind id "$id".',
        );
      }
      registry[id] = item;
    }
    return Map.unmodifiable(registry);
  }

  /// Validates every reference the current package schema actually
  /// carries; nothing is checked that the schema does not define.
  static void _validateReferences({
    required Map<String, Dimension> dimensions,
    required Map<String, Unit> units,
    required Map<String, KnowledgeObject> objects,
    required Map<String, KnowledgeRelationship> relationships,
    required Map<String, ComponentModel> models,
    required Map<String, EngineeringLaw> laws,
    required Map<String, Equation> equations,
    required Map<String, ConstraintDefinition> constraints,
    required Map<String, ProvenanceRecord> provenance,
  }) {
    void need(
      Map<String, Object?> registry,
      String id,
      String owner,
      String field,
      String kind,
    ) {
      if (!registry.containsKey(id)) {
        throw KnowledgeRuntimeException(
          KnowledgeRuntimeErrorCode.invalidReference,
          '$owner references unknown $kind "$id" in $field.',
        );
      }
    }

    for (final u in units.values) {
      need(dimensions, u.dimensionId, 'Unit "${u.id}"', 'dimensionId', 'dimension');
    }
    for (final e in equations.values) {
      final owner = 'Equation "${e.id}"';
      need(provenance, e.provenanceId, owner, 'provenanceId', 'provenance');
      for (final d in e.dimensions) {
        need(dimensions, d, owner, 'dimensions', 'dimension');
      }
    }
    for (final l in laws.values) {
      final owner = 'Law "${l.id}"';
      need(provenance, l.provenanceId, owner, 'provenanceId', 'provenance');
      for (final ref in l.equationRefs) {
        need(equations, ref, owner, 'equationRefs', 'equation');
      }
    }
    for (final c in constraints.values) {
      need(provenance, c.provenanceId, 'Constraint "${c.id}"', 'provenanceId', 'provenance');
    }
    for (final m in models.values) {
      final owner = 'ComponentModel "${m.id}"';
      need(provenance, m.provenanceId, owner, 'provenanceId', 'provenance');
      for (final ref in m.equationRefs) {
        need(equations, ref, owner, 'equationRefs', 'equation');
      }
      for (final ref in m.constraintRefs) {
        need(constraints, ref, owner, 'constraintRefs', 'constraint');
      }
      for (final p in m.parameters) {
        need(dimensions, p.dimensionId, owner, 'parameters', 'dimension');
      }
    }
    for (final o in objects.values) {
      need(provenance, o.provenanceId, 'Object "${o.id}"', 'provenanceId', 'provenance');
    }
    for (final r in relationships.values) {
      final owner = 'Relationship "${r.id}"';
      need(objects, r.sourceObjectId, owner, 'sourceObjectId', 'object');
      need(objects, r.targetObjectId, owner, 'targetObjectId', 'object');
      need(provenance, r.provenanceId, owner, 'provenanceId', 'provenance');
    }
  }

  static KnowledgeRuntimeCapabilities _capabilitiesFor({
    required Map<String, Dimension> dimensions,
    required Map<String, Unit> units,
    required Map<String, KnowledgeObject> objects,
    required Map<String, KnowledgeRelationship> relationships,
    required Map<String, ComponentModel> models,
    required Map<String, EngineeringLaw> laws,
    required Map<String, Equation> equations,
    required Map<String, ConstraintDefinition> constraints,
    required Map<String, ProvenanceRecord> provenance,
  }) {
    List<String> sortedIds(Iterable<String> ids) =>
        List.unmodifiable(ids.toList()..sort());
    return KnowledgeRuntimeCapabilities._(
      registryCounts: Map.unmodifiable({
        'dimensions': dimensions.length,
        'units': units.length,
        'objects': objects.length,
        'relationships': relationships.length,
        'componentModels': models.length,
        'laws': laws.length,
        'equations': equations.length,
        'constraints': constraints.length,
        'provenance': provenance.length,
      }),
      domains: sortedIds(models.values.map((m) => m.domain).toSet()),
      unitIds: sortedIds(units.keys),
      lawIds: sortedIds(laws.keys),
      equationIds: sortedIds(equations.keys),
      componentModelIds: sortedIds(models.keys),
      constraintIds: sortedIds(constraints.keys),
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
