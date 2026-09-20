import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// WP-EKE-013 (Complete Authoritative Knowledge Runtime Boundary).
///
/// Layer A only: in-memory [KnowledgePackage] fixtures activated through
/// the production [KnowledgeRuntime]. Compiler/`runtime.json`
/// (`knowledge/reference_library/test/test_runtime_export.py`), `.oerp`
/// parsing (`oerp_reader_test.dart`) and the real compiled-package chain
/// (`tool/verify_oerp_reader.dart`) are verified separately.
KnowledgeObject _object(String id, {String provenanceId = 'prov.unit.volt'}) =>
    KnowledgeObject(
      id: id,
      objectType: 'Component',
      name: 'Object $id',
      shortName: id,
      version: '1.0.0',
      lifecycleState: 'Published',
      uuid: 'uuid-$id',
      domain: 'Electrical',
      tags: const ['passive'],
      provenanceId: provenanceId,
    );

KnowledgeRelationship _rel(
  String id,
  String source,
  String target, {
  String provenanceId = 'prov.unit.volt',
}) => KnowledgeRelationship(
  id: id,
  relationshipType: 'USES_EQUATION',
  sourceObjectId: source,
  targetObjectId: target,
  cardinality: 'many_to_one',
  lifecycle: 'Published',
  confidence: 'high',
  notes: 'n',
  provenanceId: provenanceId,
);

/// The fixture with any registry replaced.
KnowledgePackage _pkg({
  List<Dimension>? dimensions,
  List<Unit>? units,
  List<ComponentModel>? models,
  List<EngineeringLaw>? laws,
  List<Equation>? equations,
  List<ConstraintDefinition>? constraints,
  List<ProvenanceRecord>? provenance,
  List<KnowledgeObject> objects = const [],
  List<KnowledgeRelationship> relationships = const [],
}) {
  final base = buildElectricalCorePackage();
  return KnowledgePackage(
    manifest: base.manifest,
    dimensions: dimensions ?? base.dimensions,
    units: units ?? base.units,
    componentModels: models ?? base.componentModels,
    laws: laws ?? base.laws,
    equations: equations ?? base.equations,
    constraints: constraints ?? base.constraints,
    provenance: provenance ?? base.provenance,
    objects: objects,
    relationships: relationships,
    developmentModeUnsigned: true,
  );
}

KnowledgeRuntime _activate(KnowledgePackage p) =>
    KnowledgeRuntime.activate(p, allowUnsignedDevelopmentPackages: true);

Matcher _failsWith(KnowledgeRuntimeErrorCode code) => throwsA(
  isA<KnowledgeRuntimeException>().having((e) => e.code, 'code', code),
);

void main() {
  final base = buildElectricalCorePackage();

  group('Object registry', () {
    final objects = [_object('component.a'), _object('component.b')];

    test('1/3: valid lookup preserves canonical identity and fields', () {
      final o = _activate(_pkg(objects: objects)).getObject('component.a');
      expect(o.id, 'component.a');
      expect(o.objectType, 'Component');
      expect(o.name, 'Object component.a');
      expect(o.uuid, 'uuid-component.a');
      expect(o.tags, ['passive']);
    });

    test('2: a missing object is referenceNotFound, not a package error', () {
      final rt = _activate(_pkg(objects: objects));
      expect(
        () => rt.getObject('component.nope'),
        _failsWith(KnowledgeRuntimeErrorCode.referenceNotFound),
      );
    });

    test('4: object provenance is resolvable', () {
      final rt = _activate(_pkg(objects: objects));
      final prov = rt.getProvenance(rt.getObject('component.a').provenanceId);
      expect(prov.id, 'prov.unit.volt');
    });

    test('4b: an object with unknown provenance is rejected', () {
      expect(
        () => _activate(
          _pkg(objects: [_object('component.a', provenanceId: 'prov.nope')]),
        ),
        _failsWith(KnowledgeRuntimeErrorCode.invalidReference),
      );
    });

    test('5: duplicate object ids are rejected', () {
      expect(
        () => _activate(
          _pkg(objects: [_object('component.a'), _object('component.a')]),
        ),
        _failsWith(KnowledgeRuntimeErrorCode.duplicateAuthority),
      );
    });
  });

  group('Relationship registry', () {
    final objects = [_object('component.a'), _object('component.b')];
    final rels = [
      _rel('r2', 'component.b', 'component.a'),
      _rel('r1', 'component.a', 'component.b'),
    ];

    test('6/7: lookup preserves id, type, source and target', () {
      final r = _activate(
        _pkg(objects: objects, relationships: rels),
      ).getRelationship('r1');
      expect(r.relationshipType, 'USES_EQUATION');
      expect(r.sourceObjectId, 'component.a');
      expect(r.targetObjectId, 'component.b');
      expect(r.cardinality, 'many_to_one');
    });

    test('8: relationshipsForObject returns incident edges, sorted', () {
      final rt = _activate(_pkg(objects: objects, relationships: rels));
      expect(rt.relationshipsForObject('component.a').map((r) => r.id), [
        'r1',
        'r2',
      ]);
      expect(
        () => rt.relationshipsForObject('component.zzz'),
        _failsWith(KnowledgeRuntimeErrorCode.referenceNotFound),
      );
    });

    test('8b: an object with no relationships yields an empty list', () {
      final rt = _activate(
        _pkg(objects: [...objects, _object('component.c')], relationships: rels),
      );
      expect(rt.relationshipsForObject('component.c'), isEmpty);
    });

    test('9: a missing relationship is referenceNotFound', () {
      final rt = _activate(_pkg(objects: objects, relationships: rels));
      expect(
        () => rt.getRelationship('nope'),
        _failsWith(KnowledgeRuntimeErrorCode.referenceNotFound),
      );
    });

    test('10: duplicate relationship ids are rejected', () {
      expect(
        () => _activate(
          _pkg(
            objects: objects,
            relationships: [
              _rel('r1', 'component.a', 'component.b'),
              _rel('r1', 'component.b', 'component.a'),
            ],
          ),
        ),
        _failsWith(KnowledgeRuntimeErrorCode.duplicateAuthority),
      );
    });

    test('11: an unknown relationship source is rejected', () {
      expect(
        () => _activate(
          _pkg(
            objects: objects,
            relationships: [_rel('r1', 'component.ghost', 'component.b')],
          ),
        ),
        _failsWith(KnowledgeRuntimeErrorCode.invalidReference),
      );
    });

    test('12: an unknown relationship target is rejected', () {
      expect(
        () => _activate(
          _pkg(
            objects: objects,
            relationships: [_rel('r1', 'component.a', 'component.ghost')],
          ),
        ),
        _failsWith(KnowledgeRuntimeErrorCode.invalidReference),
      );
    });

    test('12b: a relationship with unknown provenance is rejected', () {
      expect(
        () => _activate(
          _pkg(
            objects: objects,
            relationships: [
              _rel('r1', 'component.a', 'component.b', provenanceId: 'prov.no'),
            ],
          ),
        ),
        _failsWith(KnowledgeRuntimeErrorCode.invalidReference),
      );
    });
  });

  group('Duplicate authority in existing registries', () {
    void rejects(String name, KnowledgePackage Function() build) => test(name, () {
      expect(
        () => _activate(build()),
        _failsWith(KnowledgeRuntimeErrorCode.duplicateAuthority),
      );
    });

    rejects('13: dimension', () => _pkg(dimensions: [...base.dimensions, base.dimensions.first]));
    rejects('14: unit', () => _pkg(units: [...base.units, base.units.first]));
    rejects('15: component model', () => _pkg(models: [...base.componentModels, base.componentModels.first]));
    rejects('16: law', () => _pkg(laws: [...base.laws, base.laws.first]));
    rejects('17: equation', () => _pkg(equations: [...base.equations, base.equations.first]));
    rejects('18: constraint', () => _pkg(constraints: [...base.constraints, base.constraints.first]));
    rejects('19: provenance', () => _pkg(provenance: [...base.provenance, base.provenance.first]));

    test('a duplicate never silently replaces the first definition', () {
      final first = base.units.first;
      final impostor = Unit(
        id: first.id,
        symbol: 'IMPOSTOR',
        dimensionId: first.dimensionId,
      );
      expect(
        () => _activate(_pkg(units: [first, impostor])),
        _failsWith(KnowledgeRuntimeErrorCode.duplicateAuthority),
      );
    });
  });

  group('Cross-reference validation', () {
    void rejects(String name, KnowledgePackage Function() build) => test(name, () {
      expect(
        () => _activate(build()),
        _failsWith(KnowledgeRuntimeErrorCode.invalidReference),
      );
    });

    final model = base.componentModels.first;
    ComponentModel model2({
      List<String>? equationRefs,
      List<String>? constraintRefs,
      String? provenanceId,
      List<ModelParameter>? parameters,
    }) => ComponentModel(
      id: model.id,
      version: model.version,
      domain: model.domain,
      terminals: model.terminals,
      parameters: parameters ?? model.parameters,
      equationRefs: equationRefs ?? model.equationRefs,
      constraintRefs: constraintRefs ?? model.constraintRefs,
      applicability: model.applicability,
      provenanceId: provenanceId ?? model.provenanceId,
    );
    List<ComponentModel> withModel(ComponentModel m) => [
      m,
      ...base.componentModels.skip(1),
    ];

    rejects(
      '20: unit -> dimension',
      () => _pkg(
        units: [
          Unit(id: 'unit.x', symbol: 'x', dimensionId: 'dimension.ghost'),
          ...base.units,
        ],
      ),
    );
    rejects('21: component -> equation', () => _pkg(models: withModel(model2(equationRefs: ['equation.ghost']))));
    rejects('22: component -> constraint', () => _pkg(models: withModel(model2(constraintRefs: ['constraint.ghost']))));
    rejects('25: component -> provenance', () => _pkg(models: withModel(model2(provenanceId: 'prov.ghost'))));
    rejects(
      'component parameter -> dimension',
      () => _pkg(
        models: withModel(
          model2(parameters: [const ModelParameter(name: 'p', dimensionId: 'dimension.ghost')]),
        ),
      ),
    );
    rejects(
      '23: law -> equation',
      () {
        final l = base.laws.first;
        return _pkg(
          laws: [
            EngineeringLaw(
              id: l.id,
              version: l.version,
              name: l.name,
              equationRefs: const ['equation.ghost'],
              applicability: l.applicability,
              provenanceId: l.provenanceId,
            ),
          ],
        );
      },
    );
    rejects(
      '24: equation -> provenance',
      () {
        final e = base.equations.first;
        return _pkg(
          equations: [
            Equation(
              id: e.id,
              version: e.version,
              expression: e.expression,
              variables: e.variables,
              dimensions: e.dimensions,
              applicability: e.applicability,
              provenanceId: 'prov.ghost',
            ),
            ...base.equations.skip(1),
          ],
        );
      },
    );
    rejects(
      'equation -> dimension',
      () {
        final e = base.equations.first;
        return _pkg(
          equations: [
            Equation(
              id: e.id,
              version: e.version,
              expression: e.expression,
              variables: e.variables,
              dimensions: const ['dimension.ghost'],
              applicability: e.applicability,
              provenanceId: e.provenanceId,
            ),
            ...base.equations.skip(1),
          ],
        );
      },
    );
    rejects(
      '26: constraint -> provenance',
      () {
        final c = base.constraints.first;
        return _pkg(
          constraints: [
            ConstraintDefinition(
              id: c.id,
              version: c.version,
              type: c.type,
              subject: c.subject,
              operator: c.operator,
              operand: c.operand,
              severity: c.severity,
              applicability: c.applicability,
              provenanceId: 'prov.ghost',
            ),
          ],
        );
      },
    );

    test('the unmodified fixture activates (references all resolve)', () {
      expect(() => _activate(_pkg()), returnsNormally);
    });

    test('provenance is resolvable from every provenance-bearing definition', () {
      final rt = _activate(_pkg());
      for (final m in base.componentModels) {
        expect(rt.getProvenance(rt.getComponentModel(m.id).provenanceId), isNotNull);
      }
      for (final e in base.equations) {
        expect(rt.getProvenance(rt.getEquation(e.id).provenanceId), isNotNull);
      }
    });
  });

  group('Runtime identity', () {
    test('27/28: runtime identity is distinct from, and not derived from, the package', () {
      final id = _activate(_pkg()).identity;
      expect(id.runtimeVersion, KnowledgeRuntime.runtimeVersion);
      expect(id.runtimeBuild, KnowledgeRuntime.runtimeBuild);
      expect(id.runtimeVersion, isNot(contains(id.packageId)));
      expect(id.runtimeVersion, isNot('${id.packageId}@${id.packageVersion}'));
      expect(id.packageId, 'electrical-core');
      expect(id.packageVersion, '1.0.0');
    });

    test('29: runtime identity is deterministic across activations', () {
      final a = _activate(_pkg()).identity;
      final b = _activate(_pkg()).identity;
      expect((a.runtimeVersion, a.runtimeBuild), (b.runtimeVersion, b.runtimeBuild));
    });

    test('a different package version does not change the runtime version', () {
      final p = _pkg();
      final other = KnowledgePackage(
        manifest: KnowledgePackageManifest(
          packageId: p.manifest.packageId,
          packageName: p.manifest.packageName,
          packageVersion: '9.9.9',
          schemaVersion: p.manifest.schemaVersion,
          sourceKnowledgeVersion: p.manifest.sourceKnowledgeVersion,
          compilerVersion: p.manifest.compilerVersion,
          createdUtc: p.manifest.createdUtc,
          publisherId: p.manifest.publisherId,
        ),
        dimensions: p.dimensions,
        units: p.units,
        componentModels: p.componentModels,
        laws: p.laws,
        equations: p.equations,
        constraints: p.constraints,
        provenance: p.provenance,
        developmentModeUnsigned: true,
      );
      final id = _activate(other).identity;
      expect(id.packageVersion, '9.9.9');
      expect(id.runtimeVersion, _activate(p).identity.runtimeVersion);
    });

    test('runtimeVersion mirrors oep_engine pubspec version', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1);
      expect(KnowledgeRuntime.runtimeVersion, version);
    });

    test('serialised identity round-trips, and a legacy identity has no build', () {
      final id = _activate(_pkg()).identity;
      expect(RuntimeIdentity.fromJson(id.toJson()).runtimeBuild, id.runtimeBuild);
      final legacy = {...id.toJson()}..remove('runtimeBuild');
      expect(RuntimeIdentity.fromJson(legacy).runtimeBuild, 'unrecorded');
    });
  });

  group('Capabilities', () {
    test('30: reflect the active package', () {
      final rt = _activate(
        _pkg(
          objects: [_object('component.a'), _object('component.b')],
          relationships: [_rel('r1', 'component.a', 'component.b')],
        ),
      );
      final c = rt.capabilities;
      expect(c.registryCounts['units'], base.units.length);
      expect(c.registryCounts['objects'], 2);
      expect(c.registryCounts['relationships'], 1);
      expect(c.has('objects'), isTrue);
      expect(c.unitIds, base.units.map((u) => u.id).toList()..sort());
      expect(c.domains, isNotEmpty);
      expect(c.availableRegistries, contains('relationships'));
    });

    test('31: an empty optional registry reports zero without failing', () {
      final rt = _activate(_pkg());
      expect(rt.capabilities.registryCounts['objects'], 0);
      expect(rt.capabilities.registryCounts['relationships'], 0);
      expect(rt.capabilities.has('objects'), isFalse);
      expect(rt.capabilities.availableRegistries, isNot(contains('objects')));
    });

    test('32: capability state cannot be mutated', () {
      final c = _activate(_pkg()).capabilities;
      expect(() => c.registryCounts['units'] = 0, throwsUnsupportedError);
      expect(() => c.unitIds.add('x'), throwsUnsupportedError);
      expect(() => c.domains.add('x'), throwsUnsupportedError);
    });
  });

  group('Immutability', () {
    test('33: the retained package and returned collections are unmodifiable', () {
      final source = _pkg(objects: [_object('component.a')]);
      final rt = _activate(source);
      expect(() => rt.package.units.add(base.units.first), throwsUnsupportedError);
      expect(() => rt.package.objects.clear(), throwsUnsupportedError);
      expect(() => rt.package.provenance.removeLast(), throwsUnsupportedError);
      expect(() => rt.relationshipsForObject('component.a').add(_rel('x', 'a', 'b')), throwsUnsupportedError);
    });

    test('34: mutating the source lists afterwards cannot alter an activated runtime', () {
      final units = [...base.units];
      final rt = _activate(_pkg(units: units));
      units.clear();
      expect(rt.getUnit('unit.volt').id, 'unit.volt');
      expect(rt.package.units, isNotEmpty);
    });
  });

  group('Package serialisation', () {
    test('objects and relationships round-trip and are covered by the content hash', () {
      final withGraph = _pkg(
        objects: [_object('component.a'), _object('component.b')],
        relationships: [_rel('r1', 'component.a', 'component.b')],
      );
      final restored = KnowledgePackage.fromJson(withGraph.toJson());
      expect(restored.objects.map((o) => o.id), ['component.a', 'component.b']);
      expect(restored.relationships.single.targetObjectId, 'component.b');
      expect(withGraph.computeContentHash(), restored.computeContentHash());
      expect(withGraph.computeContentHash(), isNot(_pkg().computeContentHash()));
    });

    test('a package JSON without objects/relationships loads as empty', () {
      final json = _pkg().toJson()..remove('objects')..remove('relationships');
      final restored = KnowledgePackage.fromJson(json);
      expect(restored.objects, isEmpty);
      expect(restored.relationships, isEmpty);
    });
  });
}
