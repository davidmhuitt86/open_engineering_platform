import '../models/knowledge_definitions.dart';
import '../models/knowledge_package.dart';
import '../models/quantity.dart';

/// A hand-built, in-memory stand-in for the compiled `electrical-core`
/// Knowledge Package — **retained only as an isolated-unit-test
/// fixture**, no longer the production/canonical authority.
///
/// **AP-EK-020 completion (Part A):** the real authority chain is now
/// wired end-to-end: `knowledge/reference_library/packages/core_reference/`
/// (11 authored objects, including the six AP-EK-020 added — the ideal
/// voltage source, reference node, power equation, and the ampere/ohm/
/// watt units) → the Python Reference Compiler
/// (`knowledge/reference_library/compiler/`, extended with
/// `runtime_export.py`) → a real `.oerp` archive → this package's own
/// [OerpReader] (`lib/core/knowledge/oerp/`) → [KnowledgePackage]. That
/// path is what `tool/verify_oerp_reader.dart` exercises against a
/// genuinely-compiled package (id/version/every unit/model/equation/
/// constraint match this fixture's ids exactly, by construction — see
/// `runtime_export.py`'s derivation rules), and what
/// `test/knowledge/oerp_reader_test.dart` unit-tests the reader against.
///
/// This fixture still exists, deliberately, for tests that want a
/// [KnowledgePackage] without incurring a Python compiler invocation or
/// a real `.oerp` file (which SDD-R010 §16 forbids committing to the
/// repository) — e.g. `test/knowledge/knowledge_runtime_test.dart`'s
/// registry-lookup tests. It is kept byte-for-byte *shape*-compatible
/// with the compiled package (same ids, same `expression` text) so a
/// test written against one produces the same assertions against the
/// other; it is not read by any production code path.
KnowledgePackage buildElectricalCorePackage() {
  const packageId = 'electrical-core';
  const packageVersion = '1.0.0';
  const compilerVersion = 'ap-ek-020-fixture-0.1.0';
  const sourceKnowledgeVersion = 'core_reference@1.0.0';

  final provenance = <ProvenanceRecord>[
    const ProvenanceRecord(
      id: 'prov.unit.volt',
      sourceObjectId: 'unit.volt',
      sourceReference:
          'knowledge/reference_library/packages/core_reference/unit.volt/object.yaml',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.unit.ampere',
      sourceObjectId: 'unit.ampere',
      sourceReference:
          'AP-EK-020 §6 (SI base unit; not yet authored in oep_reference_library)',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.unit.ohm',
      sourceObjectId: 'unit.ohm',
      sourceReference:
          'AP-EK-020 §6 (SI derived unit; not yet authored in oep_reference_library)',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.unit.watt',
      sourceObjectId: 'unit.watt',
      sourceReference:
          'AP-EK-020 §6 (SI derived unit; not yet authored in oep_reference_library)',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.component.passive.resistor',
      sourceObjectId: 'component.passive.resistor',
      sourceReference:
          'knowledge/reference_library/packages/core_reference/component.passive.resistor/object.yaml',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.component.source.voltage_ideal',
      sourceObjectId: 'component.source.voltage_ideal',
      sourceReference:
          'AP-EK-020 §6 (not yet authored in oep_reference_library)',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.component.reference_node',
      sourceObjectId: 'component.reference_node',
      sourceReference:
          'AP-EK-020 §6 (not yet authored in oep_reference_library)',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.equation.ohms_law',
      sourceObjectId: 'equation.ohms_law',
      sourceReference:
          'knowledge/reference_library/packages/core_reference/equation.ohms_law/object.yaml',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.equation.power',
      sourceObjectId: 'equation.power',
      sourceReference:
          'AP-EK-020 §16 (not yet authored in oep_reference_library)',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.law.ohms_law',
      sourceObjectId: 'law.ohms_law',
      sourceReference:
          'knowledge/reference_library/packages/core_reference/equation.ohms_law/object.yaml#authority',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
    const ProvenanceRecord(
      id: 'prov.constraint.resistance_positive',
      sourceObjectId: 'constraint.resistance_positive',
      sourceReference:
          'knowledge/reference_library/packages/core_reference/component.passive.resistor/validation.yaml',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
    ),
  ];

  const dimensions = [
    Dimension(
      id: 'dimension.voltage',
      name: 'Voltage',
      exponents: DimensionExponents(kg: 1, m: 2, s: -3, a: -1),
    ),
    Dimension(
      id: 'dimension.current',
      name: 'Current',
      exponents: DimensionExponents(a: 1),
    ),
    Dimension(
      id: 'dimension.resistance',
      name: 'Resistance',
      exponents: DimensionExponents(kg: 1, m: 2, s: -3, a: -2),
    ),
    Dimension(
      id: 'dimension.power',
      name: 'Power',
      exponents: DimensionExponents(kg: 1, m: 2, s: -3),
    ),
  ];

  const units = [
    Unit(
      id: 'unit.volt',
      symbol: 'V',
      dimensionId: 'dimension.voltage',
      aliases: ['volt', 'volts'],
    ),
    Unit(
      id: 'unit.ampere',
      symbol: 'A',
      dimensionId: 'dimension.current',
      aliases: ['ampere', 'amp', 'amps'],
    ),
    Unit(
      id: 'unit.ohm',
      symbol: 'Ω',
      dimensionId: 'dimension.resistance',
      aliases: ['ohm', 'ohms'],
    ),
    Unit(
      id: 'unit.watt',
      symbol: 'W',
      dimensionId: 'dimension.power',
      aliases: ['watt', 'watts'],
    ),
  ];

  const equations = [
    // A single equation object per law/relationship concept, matching
    // how oep_reference_library actually authors equations (one
    // `equation.ohms_law` object, not one per algebraic rearrangement —
    // see ElectricalCoreIds' doc comment in analysis_engine.dart).
    Equation(
      id: 'equation.ohms_law',
      version: '1.0.0',
      expression: 'V = I × R',
      variables: ['V', 'I', 'R'],
      dimensions: [
        'dimension.voltage',
        'dimension.current',
        'dimension.resistance',
      ],
      applicability: 'linear_dc',
      provenanceId: 'prov.equation.ohms_law',
    ),
    Equation(
      id: 'equation.power',
      version: '1.0.0',
      expression: 'P = V × I',
      variables: ['P', 'V', 'I'],
      dimensions: ['dimension.power', 'dimension.voltage', 'dimension.current'],
      applicability: 'linear_dc',
      provenanceId: 'prov.equation.power',
    ),
  ];

  const laws = [
    EngineeringLaw(
      id: 'law.ohms_law',
      version: '1.0.0',
      name: "Ohm's Law",
      equationRefs: ['equation.ohms_law'],
      applicability: 'linear_dc',
      provenanceId: 'prov.law.ohms_law',
    ),
  ];

  const componentModels = [
    ComponentModel(
      id: 'component.passive.resistor',
      version: '1.0.0',
      domain: 'Electrical',
      terminals: [
        ModelTerminal(id: 't1', name: 'Terminal 1'),
        ModelTerminal(id: 't2', name: 'Terminal 2'),
      ],
      parameters: [
        ModelParameter(name: 'resistance', dimensionId: 'dimension.resistance'),
      ],
      equationRefs: ['equation.ohms_law'],
      constraintRefs: ['constraint.resistance_positive'],
      applicability: 'linear_dc',
      provenanceId: 'prov.component.passive.resistor',
    ),
    ComponentModel(
      id: 'component.source.voltage_ideal',
      version: '1.0.0',
      domain: 'Electrical',
      terminals: [
        ModelTerminal(id: 'positive', name: 'Positive'),
        ModelTerminal(id: 'negative', name: 'Negative'),
      ],
      parameters: [
        ModelParameter(name: 'voltage', dimensionId: 'dimension.voltage'),
      ],
      equationRefs: [],
      constraintRefs: [],
      applicability: 'linear_dc',
      provenanceId: 'prov.component.source.voltage_ideal',
    ),
    ComponentModel(
      id: 'component.reference_node',
      version: '1.0.0',
      domain: 'Electrical',
      terminals: [ModelTerminal(id: 'ground', name: 'Ground')],
      parameters: [],
      equationRefs: [],
      constraintRefs: [],
      applicability: 'linear_dc',
      provenanceId: 'prov.component.reference_node',
    ),
  ];

  const constraints = [
    ConstraintDefinition(
      id: 'constraint.resistance_positive',
      version: '1.0.0',
      type: 'parameter_bound',
      subject: 'resistance',
      operator: ConstraintOperator.greaterThan,
      operand: 0.0,
      severity: 'error',
      applicability: 'linear_dc',
      provenanceId: 'prov.constraint.resistance_positive',
    ),
  ];

  return KnowledgePackage(
    manifest: const KnowledgePackageManifest(
      packageId: packageId,
      packageName: 'OEP Electrical Core (Vertical Slice)',
      packageVersion: packageVersion,
      schemaVersion: '1.0.0',
      sourceKnowledgeVersion: sourceKnowledgeVersion,
      compilerVersion: compilerVersion,
      createdUtc: '2026-07-17T00:00:00Z',
      publisherId: 'Divad Technology Group, LLC.',
    ),
    dimensions: dimensions,
    units: units,
    componentModels: componentModels,
    laws: laws,
    equations: equations,
    constraints: constraints,
    provenance: provenance,
    developmentModeUnsigned: true,
  );
}
