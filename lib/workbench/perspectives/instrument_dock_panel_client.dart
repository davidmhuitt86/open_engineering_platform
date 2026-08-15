import 'package:flutter/widgets.dart';

import '../../diagram_studio/instruments/core/engineering_instrument.dart';
import '../dock/dock_panel_client.dart';

/// WP-DS-006 Engineering Workbench — adapts one existing, untouched
/// WP-DS-005A [EngineeringInstrument] into the new generic
/// [DockPanelClient] contract, so it can be shown inside a
/// [DockManager]/[DockRegion]-driven dock (the Instruments Perspective's
/// bottom dock) without WP-DS-005A's own [EngineeringInstrument] contract,
/// `InstrumentRegistry`, or `InstrumentDock` widget being modified in any
/// way — this is a pure wrapper, not a migration.
///
/// [id]/[title]/[icon] pass straight through; [buildPanel] delegates to the
/// wrapped instrument's own [EngineeringInstrument.buildPanel]. Diagram
/// Studio's own in-page Instrument Dock (`diagram_studio_page.dart`)
/// continues to construct and render its `EngineeringInstrument`s exactly
/// as before, through its own `InstrumentRegistry`/`InstrumentDockController`
/// — this class is a second, independent way to reach the same kind of
/// content through the new generic dock framework, proving that framework
/// is genuinely reusable rather than hardcoded to Instruments.
class InstrumentDockPanelClient extends DockPanelClient {
  const InstrumentDockPanelClient(this._instrument);

  final EngineeringInstrument _instrument;

  @override
  String get id => _instrument.id;

  @override
  String get title => _instrument.title;

  @override
  IconData get icon => _instrument.icon;

  @override
  Widget buildPanel(BuildContext context) => _instrument.buildPanel(context);
}
