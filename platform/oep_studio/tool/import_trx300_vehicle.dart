// ignore_for_file: avoid_print
//
// One-time importer: converts the Legacy Wiring Simulator V2's own
// built-in "trx300" demo vehicle (reference/legacy_wiring_sim_v2/
// eke-wiring-sim/diagrams/trx300/*.json) into a real, fully-bridged OEP
// DiagramDocument — every V2 module becomes a real EngineeringNode
// carrying metadata['v2ModuleId']/['v2Category'], every V2 wire becomes a
// real EngineeringRelationship carrying metadata['v2WireId']/['label']/
// ['wireColor']/['sourcePort']/['targetPort'], and V2's own layout.json
// becomes this document's DiagramLayoutState.positions.
//
// Why this exists: V2 loads this demo vehicle unconditionally on every
// page load (`Bootstrap.run('trx300')`, app.js), independent of whatever
// OEP document happens to be open. LegacyV2StateAdapter.initializeFromDocument
// only seeds V2 from OEP nodes that already carry `metadata['v2ModuleId']`
// — the previous samples/trx300.json had none, so this demo vehicle had
// no OEP-side representation at all, and none of its module positions or
// wire routes could ever persist. Running this importer once produces a
// samples/trx300.json where every module/wire the demo vehicle shows IS
// a real, trackable OEP object, so it becomes real, permanent starting
// data for the repository rather than a throwaway fixture.
//
// Symbol mapping for the 8 V2 categories beyond the two the live bridge
// already maps deterministically (ground/connector) is evidence-based,
// not guessed: `lighting`/`indicator` -> lamp (every demo module in
// those categories is literally a bulb), `switch` -> spst_switch
// (literal switches), `power` -> battery (the only demo module in that
// category is literally a battery). The remaining categories
// (control/charging/ignition/starter/accessory) mix genuinely different
// real component types within the SAME V2 category in the demo data
// itself (e.g. "charging" contains a diode, a regulator, AND an
// alternator) — category-level mapping cannot honestly pick one specific
// symbol for all of them, so they map to `generic_module`: a real,
// existing OEP symbol for "a real object of unspecified specific type",
// not a fabricated guess.
//
// Run from platform/oep_studio: `dart run tool/import_trx300_vehicle.dart`
import 'dart:convert';
import 'dart:io';

// Deliberately importing the specific pure-Dart model files rather than
// the `engineering_engine.dart` barrel — that barrel also re-exports
// Flutter-widget-based views/dialogs/exporters, which pull in `dart:ui`
// and cannot run under a plain `dart run` (no Flutter engine attached).
// This script only needs the plain data model classes.
import 'package:engineering_engine/core/graph/models/engineering_graph.dart';
import 'package:engineering_engine/core/graph/models/engineering_node.dart';
import 'package:engineering_engine/core/graph/models/engineering_relationship.dart';
import 'package:engineering_engine/core/graph/models/port.dart';
import 'package:engineering_engine/core/views/diagram/diagram_geometry.dart';
import 'package:engineering_engine/core/views/diagram/diagram_layout_state.dart';

const Map<String, String> _categoryToSymbolId = {
  'ground': 'ground',
  'connector': 'connector',
  'lighting': 'lamp',
  'indicator': 'lamp',
  'switch': 'spst_switch',
  'power': 'battery',
  'control': 'generic_module',
  'charging': 'generic_module',
  'ignition': 'generic_module',
  'starter': 'generic_module',
  'accessory': 'generic_module',
};

Future<void> main() async {
  final v2Dir = Directory(
    '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..'
    '${Platform.pathSeparator}reference${Platform.pathSeparator}legacy_wiring_sim_v2'
    '${Platform.pathSeparator}eke-wiring-sim${Platform.pathSeparator}diagrams${Platform.pathSeparator}trx300',
  );
  if (!v2Dir.existsSync()) {
    stderr.writeln('V2 trx300 demo data not found at ${v2Dir.path}');
    exit(1);
  }

  final modules = jsonDecode(
      await File('${v2Dir.path}${Platform.pathSeparator}modules.json')
          .readAsString()) as List;
  final wiresEnvelope = jsonDecode(
      await File('${v2Dir.path}${Platform.pathSeparator}wires.json')
          .readAsString()) as Map<String, Object?>;
  final wires = wiresEnvelope['wires'] as List;
  final layout = jsonDecode(
      await File('${v2Dir.path}${Platform.pathSeparator}layout.json')
          .readAsString()) as Map<String, Object?>;

  final nodes = <String, EngineeringNode>{};
  final positions = <String, Point2D>{};
  final unmappedCategories = <String>{};

  for (final raw in modules) {
    final m = raw as Map<String, Object?>;
    final v2Id = m['id'] as String;
    final category = m['category'] as String;
    final symbolId = _categoryToSymbolId[category];
    if (symbolId == null) unmappedCategories.add(category);

    final terminals = (m['terminals'] as List? ?? const [])
        .map((t) => t as Map<String, Object?>)
        .map((t) => Port(
              id: t['name'] as String,
              name: t['name'] as String,
              type: 'electrical',
              metadata: {'v2Color': t['color']},
            ))
        .toList();

    nodes[v2Id] = EngineeringNode(
      id: v2Id,
      category: NodeCategory.component,
      displayName: m['label'] as String,
      symbolId: symbolId ?? 'generic_module',
      metadata: {
        'v2ModuleId': v2Id,
        'v2Category': category,
        if ((m['sublabel'] as String?)?.isNotEmpty ?? false)
          'v2Sublabel': m['sublabel'],
        if (m['notes'] != null) 'notes': m['notes'],
      },
      ports: terminals,
    );

    final pos = layout[v2Id] as Map<String, Object?>?;
    if (pos != null) {
      positions[v2Id] =
          Point2D((pos['x'] as num).toDouble(), (pos['y'] as num).toDouble());
    }
  }

  final relationships = <String, EngineeringRelationship>{};
  for (final raw in wires) {
    final w = raw as Map<String, Object?>;
    final v2Id = w['id'] as String;
    final from = w['from'] as Map<String, Object?>;
    final to = w['to'] as Map<String, Object?>;
    relationships[v2Id] = EngineeringRelationship(
      id: v2Id,
      relationshipType: RelationshipType.connectedTo,
      sourceNode: from['module'] as String,
      targetNode: to['module'] as String,
      metadata: {
        'v2WireId': v2Id,
        'label': w['label'] as String? ?? '',
        'wireColor': w['color'] as String? ?? '',
        if ((from['terminal'] as String?)?.isNotEmpty ?? false)
          'sourcePort': from['terminal'],
        if ((to['terminal'] as String?)?.isNotEmpty ?? false)
          'targetPort': to['terminal'],
        if ((w['description'] as String?)?.isNotEmpty ?? false)
          'v2Description': w['description'],
      },
    );
  }

  final graph = EngineeringGraph(
      id: 'trx300', nodes: nodes, relationships: relationships);
  final layoutState = DiagramLayoutState(positions: positions);

  final envelope = {
    'schemaVersion': 1,
    'documentId': 'trx300-imported-0001',
    'graph': graph.toJson(),
    'layout': layoutState.toJson(),
    'metadata': {
      'title': 'TRX300',
      'createdAt': DateTime.now().toIso8601String(),
      'modifiedAt': DateTime.now().toIso8601String(),
    },
  };

  final outPath =
      '${Directory.current.path}${Platform.pathSeparator}samples${Platform.pathSeparator}trx300.json';
  await File(outPath)
      .writeAsString(const JsonEncoder.withIndent('  ').convert(envelope));

  print(
      'Imported ${nodes.length} modules, ${relationships.length} wires, ${positions.length} positions.');
  if (unmappedCategories.isNotEmpty) {
    print(
        'WARNING: categories with no explicit mapping (defaulted to generic_module): $unmappedCategories');
  }
  print('Wrote $outPath');
}
