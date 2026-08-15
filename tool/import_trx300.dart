// OEP Diagram Studio -- Phase 14 (UI Layout Ratification): a one-off,
// re-runnable conversion of the real `legacy_wiring_sim_v2` reference
// tool's TRX300 sample diagram into OEP's own real formats, using the
// real Dart model classes' own `toJson()` (never a hand-typed JSON
// guess) -- guarantees the output is byte-for-byte what
// `DiagramDocument.open()`/`DomainProfile.fromJson` actually expect.
//
// Run with: dart run tool/import_trx300.dart
//
// Produces two files Diagram Studio can open directly:
//   trx300.json          -- via File > Open (a real EngineeringGraph + layout)
//   trx300_profile.json  -- via "Load Operating Profile..." (a real DomainProfile)
import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';

void main() {
  final graph = _buildGraph();
  final layout = _buildLayout();
  final profile = _buildProfile();

  final diagramEnvelope = {
    'schemaVersion': 1,
    'graph': graph.toJson(),
    'layout': layout.toJson(),
  };
  File('trx300.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(diagramEnvelope));

  File('trx300_profile.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(profile.toJson()));

  // ignore: avoid_print
  print('Wrote trx300.json (${graph.nodes.length} nodes, ${graph.relationships.length} relationships) '
      'and trx300_profile.json (${profile.operatingStates.length} operating states, ${profile.inputStates.length} inputs).');
}

// --- Module -> NodeCategory (a real, disclosed conversion rule -- the
// reference tool's own ad hoc string categories have no OEP equivalent
// to look up, so this is a considered one-time mapping, not fabricated
// per-node data) --------------------------------------------------------
const Map<String, NodeCategory> _categoryByModuleId = {
  'indicator-lights': NodeCategory.component,
  'cdi-unit': NodeCategory.component,
  'alarm-unit': NodeCategory.component,
  'ignition-switch': NodeCategory.switchNode,
  'dc-consent-jack': NodeCategory.connector,
  'rectifier-diode': NodeCategory.component,
  'regulator-rectifier': NodeCategory.component,
  'left-handlebar-switch': NodeCategory.switchNode,
  'chassis-ground': NodeCategory.ground,
  'ignition-coil': NodeCategory.component,
  'spark-plug': NodeCategory.component,
  'reverse-switch': NodeCategory.switchNode,
  'neutral-switch': NodeCategory.switchNode,
  'oil-temp-switch': NodeCategory.switchNode,
  'pulser-coil': NodeCategory.sensor,
  'alternator-stator': NodeCategory.component,
  'starter-motor': NodeCategory.actuator,
  'starter-relay': NodeCategory.relay,
  'battery-fuses': NodeCategory.component,
  'rh-headlight': NodeCategory.actuator,
  'lh-headlight': NodeCategory.actuator,
  'tail-light': NodeCategory.actuator,
};

const Map<String, ({String label, String sublabel, String exit, List<String> terminals})> _modules = {
  'indicator-lights': (label: 'Indicator Lights', sublabel: 'Oil/Rev/Neutral', exit: 'down', terminals: ['OIL', 'REV', 'NEU']),
  'cdi-unit': (label: 'CDI Unit', sublabel: 'DC-CDI Igniter', exit: 'down', terminals: ['P1', 'P2', 'P3', 'P4', 'P5', 'P6']),
  'alarm-unit': (label: 'Alarm Unit', sublabel: 'Rev/Oil Buzzer', exit: 'down', terminals: ['A1', 'A2', 'A3', 'A5', 'A6']),
  'ignition-switch': (label: 'Ignition Switch', sublabel: 'Key Cylinder', exit: 'down', terminals: ['BAT1', 'BAT2', 'IG1', 'BAT3']),
  'dc-consent-jack': (label: 'DC Consent', sublabel: 'Accessory Jack', exit: 'down', terminals: ['+12V', 'GND']),
  'rectifier-diode': (label: 'Rectifier', sublabel: 'Diode', exit: 'down', terminals: ['A', 'K']),
  'regulator-rectifier': (label: 'Reg/Rect', sublabel: 'Charge Regulator', exit: 'down', terminals: ['GND', 'B+', 'REG', 'AC1', 'AC2', 'AC3']),
  'left-handlebar-switch': (label: 'LH Handlebar Sw', sublabel: 'Light/Stop/Start', exit: 'up', terminals: ['BAT2', 'IG1', 'TL', 'ST', 'IG2', 'LO', 'HI']),
  'chassis-ground': (label: 'Chassis GND', sublabel: 'Engine Bolt', exit: 'up', terminals: ['A', 'B']),
  'ignition-coil': (label: 'Ignition Coil', sublabel: 'Primary', exit: 'up', terminals: ['PRI+', 'GND']),
  'spark-plug': (label: 'Spark Plug', sublabel: 'HT Lead', exit: 'up', terminals: ['HT']),
  'reverse-switch': (label: 'Reverse Switch', sublabel: 'Gear Position', exit: 'up', terminals: ['OUT', 'BODY']),
  'neutral-switch': (label: 'Neutral Switch', sublabel: 'Gear Position', exit: 'up', terminals: ['OUT', 'BODY']),
  'oil-temp-switch': (label: 'Oil Temp Switch', sublabel: 'Thermo Switch', exit: 'up', terminals: ['OUT', 'BODY']),
  'pulser-coil': (label: 'Pulser Coil', sublabel: 'Timing Pickup', exit: 'up', terminals: ['OUT', 'BODY']),
  'alternator-stator': (label: 'Stator/Alt', sublabel: 'Charging', exit: 'up', terminals: ['GND', 'LIT', 'AC1', 'AC2', 'AC3']),
  'starter-motor': (label: 'Starter Motor', sublabel: 'DC Motor', exit: 'up', terminals: ['B+', 'BODY']),
  'starter-relay': (label: 'Starter Relay', sublabel: 'Solenoid', exit: 'up', terminals: ['C+', 'C-', 'MB+', 'MO']),
  'battery-fuses': (label: 'Battery + Fuses', sublabel: '12V', exit: 'up', terminals: ['B+(R)', 'B+(PW)', 'MB+', 'B-']),
  'rh-headlight': (label: 'RH Headlight', sublabel: '12V 25/25W', exit: 'right', terminals: ['HI', 'LO', 'GND']),
  'lh-headlight': (label: 'LH Headlight', sublabel: '12V 25/25W', exit: 'right', terminals: ['HI', 'LO', 'GND']),
  'tail-light': (label: 'Tail Light', sublabel: '12V 5W', exit: 'left', terminals: ['P/W', 'R']),
};

// --- Wires: (id, color, label, description, fromModule, fromTerminal,
// toModule, toTerminal) -- transcribed directly from the reference's
// own wires.json. -------------------------------------------------------
final List<({
  String id,
  String color,
  String label,
  String description,
  String fromModule,
  String fromTerminal,
  String toModule,
  String toTerminal,
})> _wires = [
  (id: 'stator-ac1', color: 'Y', label: 'Stator Ph1', description: 'Stator AC phase 1 -> regulator', fromModule: 'alternator-stator', fromTerminal: 'AC1', toModule: 'regulator-rectifier', toTerminal: 'AC1'),
  (id: 'stator-ac2', color: 'Y', label: 'Stator Ph2', description: 'Stator AC phase 2 -> regulator', fromModule: 'alternator-stator', fromTerminal: 'AC2', toModule: 'regulator-rectifier', toTerminal: 'AC2'),
  (id: 'stator-ac3', color: 'Y', label: 'Stator Ph3', description: 'Stator AC phase 3 -> regulator', fromModule: 'alternator-stator', fromTerminal: 'AC3', toModule: 'regulator-rectifier', toTerminal: 'AC3'),
  (id: 'stator-gnd', color: 'G', label: 'Stator GND', description: 'Stator ground -> regulator', fromModule: 'alternator-stator', fromTerminal: 'GND', toModule: 'regulator-rectifier', toTerminal: 'REG'),
  (id: 'reg-bat', color: 'R', label: 'Charge Out', description: 'Regulated DC charge -> battery', fromModule: 'regulator-rectifier', fromTerminal: 'B+', toModule: 'battery-fuses', toTerminal: 'B+(R)'),
  (id: 'pulser-cdi', color: 'Blu/Y', label: 'Pulser Signal', description: 'Timing pulse -> CDI', fromModule: 'pulser-coil', fromTerminal: 'OUT', toModule: 'cdi-unit', toTerminal: 'P3'),
  (id: 'pulser-gnd', color: 'G', label: 'Pulser GND', description: 'Pulser body ground', fromModule: 'pulser-coil', fromTerminal: 'BODY', toModule: 'chassis-ground', toTerminal: 'A'),
  (id: 'cdi-coil', color: 'Bl/Y', label: 'CDI->Ign Coil', description: 'CDI primary drive -> ignition coil', fromModule: 'cdi-unit', fromTerminal: 'P1', toModule: 'ignition-coil', toTerminal: 'PRI+'),
  (id: 'coil-gnd', color: 'G', label: 'Coil GND', description: 'Ignition coil primary ground', fromModule: 'ignition-coil', fromTerminal: 'GND', toModule: 'chassis-ground', toTerminal: 'A'),
  (id: 'cdi-gnd', color: 'G', label: 'CDI GND', description: 'CDI unit ground', fromModule: 'cdi-unit', fromTerminal: 'P2', toModule: 'chassis-ground', toTerminal: 'B'),
  (id: 'oil-alarm', color: 'Br/R', label: 'Oil Temp Sig', description: 'Oil temp indicator -> alarm unit', fromModule: 'indicator-lights', fromTerminal: 'OIL', toModule: 'alarm-unit', toTerminal: 'A1'),
  (id: 'rev-ind', color: 'Gr', label: 'Reverse Signal', description: 'Reverse switch -> indicator lamp', fromModule: 'reverse-switch', fromTerminal: 'OUT', toModule: 'indicator-lights', toTerminal: 'REV'),
  (id: 'rev-gnd', color: 'G', label: 'Rev SW GND', description: 'Reverse switch body ground', fromModule: 'reverse-switch', fromTerminal: 'BODY', toModule: 'chassis-ground', toTerminal: 'A'),
  (id: 'neu-gnd', color: 'G', label: 'Neu SW GND', description: 'Neutral switch body ground', fromModule: 'neutral-switch', fromTerminal: 'BODY', toModule: 'chassis-ground', toTerminal: 'A'),
  (id: 'oilsw-gnd', color: 'G', label: 'Oil SW GND', description: 'Oil temp switch body ground', fromModule: 'oil-temp-switch', fromTerminal: 'BODY', toModule: 'chassis-ground', toTerminal: 'A'),
  (id: 'neu-ind', color: 'Lg/R', label: 'Neutral Feed', description: 'Neutral indicator -> rectifier diode', fromModule: 'indicator-lights', fromTerminal: 'NEU', toModule: 'rectifier-diode', toTerminal: 'A'),
  (id: 'bat-ign-r', color: 'R', label: 'Batt to Ign R', description: 'Battery B+ -> ignition switch (Red)', fromModule: 'battery-fuses', fromTerminal: 'B+(R)', toModule: 'ignition-switch', toTerminal: 'BAT1'),
  (id: 'bat-ign-pw', color: 'P/W', label: 'Batt to Ign PW', description: 'Battery B+ -> ignition switch (Pink/White)', fromModule: 'battery-fuses', fromTerminal: 'B+(PW)', toModule: 'ignition-switch', toTerminal: 'BAT3'),
  (id: 'ign-consent', color: 'P', label: 'Ign to DC Jack', description: 'Switched +12V -> accessory jack', fromModule: 'ignition-switch', fromTerminal: 'IG1', toModule: 'dc-consent-jack', toTerminal: '+12V'),
  (id: 'ign-alarm', color: 'P', label: 'Ign to Alarm', description: 'Switched +12V -> alarm unit', fromModule: 'ignition-switch', fromTerminal: 'IG1', toModule: 'alarm-unit', toTerminal: 'A5'),
  (id: 'jack-gnd', color: 'G', label: 'Jack GND', description: 'DC jack ground', fromModule: 'dc-consent-jack', fromTerminal: 'GND', toModule: 'chassis-ground', toTerminal: 'A'),
  (id: 'kill-cdi', color: 'Bl/W', label: 'Kill to CDI', description: 'Kill switch -> CDI unit', fromModule: 'left-handlebar-switch', fromTerminal: 'IG2', toModule: 'cdi-unit', toTerminal: 'P5'),
  (id: 'start-relay', color: 'Y/R', label: 'Start Button', description: 'Start button -> relay coil positive', fromModule: 'left-handlebar-switch', fromTerminal: 'ST', toModule: 'starter-relay', toTerminal: 'C+'),
  (id: 'relay-cdi', color: 'Gr', label: 'Relay C- CDI', description: 'Starter relay coil negative -> CDI', fromModule: 'starter-relay', fromTerminal: 'C-', toModule: 'cdi-unit', toTerminal: 'P6'),
  (id: 'bat-relay', color: 'Bl', label: 'Batt to Relay', description: 'Battery B+ -> relay main lug', fromModule: 'battery-fuses', fromTerminal: 'MB+', toModule: 'starter-relay', toTerminal: 'MB+'),
  (id: 'relay-motor', color: 'Bl', label: 'Relay to Motor', description: 'Relay output -> starter motor', fromModule: 'starter-relay', fromTerminal: 'MO', toModule: 'starter-motor', toTerminal: 'B+'),
  (id: 'motor-gnd', color: 'G', label: 'Motor GND', description: 'Starter motor body ground', fromModule: 'starter-motor', fromTerminal: 'BODY', toModule: 'chassis-ground', toTerminal: 'B'),
  (id: 'bat-neg', color: 'Bl', label: 'Battery GND', description: 'Battery negative -> chassis ground', fromModule: 'battery-fuses', fromTerminal: 'B-', toModule: 'chassis-ground', toTerminal: 'B'),
  (id: 'hlsw-lo', color: 'W', label: 'SW Low Beam', description: 'Handlebar switch low beam -> RH headlight', fromModule: 'left-handlebar-switch', fromTerminal: 'LO', toModule: 'rh-headlight', toTerminal: 'LO'),
  (id: 'hlsw-hi', color: 'Bu', label: 'SW High Beam', description: 'Handlebar switch high beam -> RH headlight', fromModule: 'left-handlebar-switch', fromTerminal: 'HI', toModule: 'rh-headlight', toTerminal: 'HI'),
  (id: 'rh-gnd', color: 'G', label: 'RH HL GND', description: 'Right headlight ground', fromModule: 'rh-headlight', fromTerminal: 'GND', toModule: 'chassis-ground', toTerminal: 'B'),
  (id: 'lh-hi-spl', color: 'Bu', label: 'LH HI Splice', description: 'Splice: RH/LH high beam shared', fromModule: 'rh-headlight', fromTerminal: 'HI', toModule: 'lh-headlight', toTerminal: 'HI'),
  (id: 'lh-lo-spl', color: 'W', label: 'LH LO Splice', description: 'Splice: RH/LH low beam shared', fromModule: 'rh-headlight', fromTerminal: 'LO', toModule: 'lh-headlight', toTerminal: 'LO'),
  (id: 'lh-gnd-spl', color: 'G', label: 'LH GND Splice', description: 'Splice: RH/LH headlight grounds shared', fromModule: 'rh-headlight', fromTerminal: 'GND', toModule: 'lh-headlight', toTerminal: 'GND'),
  (id: 'neu-sw-ind', color: 'Lg', label: 'Neutral Sense', description: 'Neutral switch -> indicator', fromModule: 'neutral-switch', fromTerminal: 'OUT', toModule: 'indicator-lights', toTerminal: 'NEU'),
  (id: 'oil-sw-ind', color: 'Bl', label: 'Oil Temp Sw Ind', description: 'Oil temp switch -> indicator', fromModule: 'oil-temp-switch', fromTerminal: 'OUT', toModule: 'indicator-lights', toTerminal: 'OIL'),
  (id: 'tail-pw', color: 'P/W', label: 'Tail P/W', description: 'Battery BAT3 -> tail light (Pink/White)', fromModule: 'ignition-switch', fromTerminal: 'BAT3', toModule: 'tail-light', toTerminal: 'P/W'),
  (id: 'tail-r', color: 'R', label: 'Tail R', description: 'Battery B+(R) -> tail light (Red)', fromModule: 'battery-fuses', fromTerminal: 'B+(R)', toModule: 'tail-light', toTerminal: 'R'),
];

const Map<String, ({double x, double y})> _positions = {
  'indicator-lights': (x: 20, y: 30),
  'cdi-unit': (x: 130, y: 30),
  'alarm-unit': (x: 255, y: 30),
  'ignition-switch': (x: 380, y: 30),
  'dc-consent-jack': (x: 500, y: 30),
  'rectifier-diode': (x: 590, y: 30),
  'regulator-rectifier': (x: 668, y: 30),
  'rh-headlight': (x: 20, y: 390),
  'lh-headlight': (x: 20, y: 470),
  'left-handlebar-switch': (x: 155, y: 580),
  'chassis-ground': (x: 320, y: 580),
  'ignition-coil': (x: 400, y: 580),
  'spark-plug': (x: 480, y: 580),
  'reverse-switch': (x: 540, y: 580),
  'neutral-switch': (x: 610, y: 580),
  'oil-temp-switch': (x: 680, y: 580),
  'pulser-coil': (x: 750, y: 580),
  'alternator-stator': (x: 820, y: 580),
  'starter-motor': (x: 940, y: 580),
  'starter-relay': (x: 1020, y: 580),
  'battery-fuses': (x: 1130, y: 580),
  'tail-light': (x: 1460, y: 390),
};

EngineeringGraph _buildGraph() {
  final nodes = <String, EngineeringNode>{};
  for (final entry in _modules.entries) {
    final id = entry.key;
    final data = entry.value;
    nodes[id] = EngineeringNode(
      id: id,
      category: _categoryByModuleId[id]!,
      displayName: data.label,
      metadata: {'sublabel': data.sublabel, 'exit': data.exit},
      ports: [
        for (final terminal in data.terminals) Port(id: terminal, name: terminal, direction: PortDirection.unspecified),
      ],
    );
  }

  final relationships = <String, EngineeringRelationship>{};
  for (final wire in _wires) {
    final isGroundWire = wire.toModule == 'chassis-ground';
    final isPowerWire = wire.fromModule == 'battery-fuses' || (wire.fromModule == 'regulator-rectifier' && wire.fromTerminal == 'B+');

    final RelationshipType type;
    final String sourceNode;
    final String targetNode;
    if (isGroundWire) {
      type = RelationshipType.grounds;
      // The engine's own convention (SignalPropagator) treats the
      // SOURCE of a `grounds` relationship as the ground source --
      // the reference's wire direction (component -> chassis-ground)
      // is the opposite of that, so it's deliberately reversed here.
      sourceNode = wire.toModule;
      targetNode = wire.fromModule;
    } else if (isPowerWire) {
      type = RelationshipType.suppliesPower;
      sourceNode = wire.fromModule;
      targetNode = wire.toModule;
    } else {
      type = RelationshipType.connectedTo;
      sourceNode = wire.fromModule;
      targetNode = wire.toModule;
    }

    relationships[wire.id] = EngineeringRelationship(
      id: wire.id,
      relationshipType: type,
      sourceNode: sourceNode,
      targetNode: targetNode,
      metadata: {
        'sourcePort': wire.fromTerminal,
        'targetPort': wire.toTerminal,
        'color': wire.color,
        'label': wire.label,
        'description': wire.description,
      },
    );
  }

  return EngineeringGraph(id: 'trx300', nodes: nodes, relationships: relationships);
}

DiagramLayoutState _buildLayout() {
  return DiagramLayoutState(
    positions: {
      for (final entry in _positions.entries) entry.key: Point2D(entry.value.x, entry.value.y),
    },
  );
}

DomainProfile _buildProfile() {
  return const DomainProfile(
    id: 'trx300',
    name: 'Honda TRX300',
    operatingStates: [
      OperatingStateDefinition(id: 'key_off', name: 'Key Off / Engine Off'),
      OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off'),
      OperatingStateDefinition(id: 'key_crank', name: 'Cranking'),
      OperatingStateDefinition(id: 'key_run', name: 'Engine Running'),
    ],
    inputStates: [
      InputStateDefinition(id: 'low_beam', label: 'Low Beam', targetRelationshipId: 'hlsw-lo'),
      InputStateDefinition(id: 'high_beam', label: 'High Beam', targetRelationshipId: 'hlsw-hi'),
      InputStateDefinition(id: 'run_switch', label: 'Kill Switch (Run)', targetRelationshipId: 'kill-cdi'),
      InputStateDefinition(id: 'start_button', label: 'Start Button', targetRelationshipId: 'start-relay'),
    ],
  );
}
