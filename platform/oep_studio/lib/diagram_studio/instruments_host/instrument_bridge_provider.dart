import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart';
import 'oip_host_bridge_service.dart';

/// The single, app-wide [OipHostBridgeService] instance — created once,
/// never per-page. Diagram Studio's own document/session can open, close,
/// or be replaced independently of whether the bridge is running, so the
/// service resolves the current [EngineeringGraph]/`SimulationEngine`
/// fresh on every request (via `engineeringProjectServiceProvider`)
/// rather than being tied to whichever `DiagramStudioPage` happened to be
/// mounted when it was started.
///
/// Controlled from Settings > Diagram Studio (`_InstrumentBridgeSection`)
/// -- see that widget for why the control lives there rather than as a
/// toolbar icon: it's connection/network-exposure configuration, the same
/// category as every other "Settings" concern in this app, not a
/// per-document editing action.
final instrumentBridgeServiceProvider = Provider<OipHostBridgeService>((ref) {
  final service = OipHostBridgeService();
  ref.onDispose(() {
    unawaited(service.stop());
  });
  return service;
});

/// Fresh on every call, not captured once — the currently open diagram's
/// graph, or `null` if none is open yet. Answers the backward-compatible
/// "primary" diagram (no `diagramInstanceId`) — see
/// [instrumentBridgeGraphForInstance] for the multi-instance-aware form.
EngineeringGraph? currentInstrumentBridgeGraph(WidgetRef ref) =>
    ref.read(engineeringProjectServiceProvider).session?.graph;

/// PRODUCT-READINESS-007 §10 — resolves a specific, non-primary Diagram
/// instance's own graph by its real instance id (a `WorkspaceTab.id`,
/// per `engineeringProjectServiceFamily`'s own doc comment), for
/// [OipHostBridgeService.start]'s `graphProviderByInstance`. Returns
/// `null` when no diagram is open for that id — the bridge reports this
/// as a real protocol error rather than silently answering against a
/// different diagram.
EngineeringGraph? instrumentBridgeGraphForInstance(WidgetRef ref, String diagramInstanceId) =>
    ref.read(engineeringProjectServiceFamily(diagramInstanceId)).session?.graph;
