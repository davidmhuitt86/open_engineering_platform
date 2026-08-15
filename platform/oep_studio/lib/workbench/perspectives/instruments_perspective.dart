import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../diagram_studio/instruments/core/engineering_instrument.dart';
import '../dock/dock_manager.dart';
import '../dock/dock_panel_client.dart';
import '../dock/dock_region.dart';
import '../perspective/perspective.dart';
import 'instrument_dock_panel_client.dart';

/// WP-DS-006 Engineering Workbench — the Instruments Perspective.
///
/// Governing spec, Dock Manager section: "Existing Instrument Dock should
/// become a generic dock client." Rather than migrating WP-DS-005A's own
/// `InstrumentDock` chrome wholesale into this Perspective (real risk of
/// regressing its 37 passing tests, and "No DMM changes" is explicitly out
/// of scope for this Work Package), this Perspective's bottom dock is built
/// fresh on the new generic [DockManager]/[DockRegion]/
/// [DockPanelClientRegistry] framework, fed by [InstrumentDockPanelClient]
/// adapters wrapping the same, untouched [EngineeringInstrument]s.
///
/// **Disclosed constraint**: a real instrument such as the Digital
/// Multimeter (`DigitalMultimeterInstrument`) needs a live
/// `DiagramSimulationService`, which itself needs an active
/// `EngineeringEngine`/diagram session — both of which belong to a specific
/// open Diagram document. `diagram_studio_page.dart` owns that session and
/// constructs its own `MultimeterController`/`InstrumentRegistry` from it
/// (see `_initInstruments` there). The Instruments Perspective is reached
/// independently of any particular open diagram (it is a sibling
/// Perspective, not part of the Diagram Perspective), so it has no engine/
/// session of its own to construct a real instrument against.
///
/// Rather than fake a session or crash, [instrumentsBottomDock] renders an
/// honest empty state when no [EngineeringInstrument]s have been supplied,
/// while still wiring up the real [DockManager]/[DockPanelClientRegistry]
/// plumbing end to end — proving the dock-adapter path itself works
/// ([InstrumentDockPanelClient] wraps any [EngineeringInstrument] you feed
/// it) without fabricating instrument data. A future Work Package that
/// gives the Workbench access to "the currently open diagram's engine"
/// (out of scope here — no Workspace/Session Manager integration was
/// requested by this Work Package) can pass real instruments into
/// [InstrumentsPerspectiveDock] and this Perspective will render them with
/// zero further changes.
///
/// Diagram Studio's own in-page `InstrumentDock` (`diagram_studio_page.dart`,
/// WP-DS-005A) is completely untouched by this file and keeps working
/// exactly as before when reached via the Diagram Perspective.
final instrumentsPerspective = Perspective(
  id: 'instruments',
  title: 'Instruments',
  icon: Icons.speed_outlined,
  centerBuilder: (context) => const _InstrumentsPerspectiveCenter(),
  bottomPanelProvider: (context) => const InstrumentsPerspectiveDock(instruments: []),
  defaultLayout: const PerspectiveLayout(bottomVisible: true, bottomHeight: 220),
);

/// The Instruments Perspective's bottom dock — a real [DockManager] +
/// [DockPanelClientRegistry] wired through [DockRegion], populated by
/// adapting every [EngineeringInstrument] in [instruments]. Exposed as its
/// own widget (rather than inlined into [instrumentsPerspective]'s
/// `bottomPanelProvider`) so a future caller with real instruments (or a
/// test) can pass them in directly.
class InstrumentsPerspectiveDock extends StatefulWidget {
  const InstrumentsPerspectiveDock({super.key, required this.instruments});

  final List<EngineeringInstrument> instruments;

  @override
  State<InstrumentsPerspectiveDock> createState() => _InstrumentsPerspectiveDockState();
}

class _InstrumentsPerspectiveDockState extends State<InstrumentsPerspectiveDock> {
  DockManager? _dockManager;
  late final DockPanelClientRegistry _registry = DockPanelClientRegistry();

  @override
  void initState() {
    super.initState();
    for (final instrument in widget.instruments) {
      _registry.register(InstrumentDockPanelClient(instrument));
    }
    _load();
  }

  Future<void> _load() async {
    final loaded = await DockManager.load('instruments-perspective');
    if (!mounted) return;
    setState(() => _dockManager = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final dockManager = _dockManager;
    if (dockManager == null) return const SizedBox.shrink();
    if (_registry.isEmpty) {
      return Container(
        color: StudioColors.surface,
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_outlined, size: 28, color: StudioColors.textDisabled),
              SizedBox(height: 8),
              Text(
                'No instruments available in this Perspective yet.',
                style: TextStyle(fontSize: 12, color: StudioColors.textSecondary),
              ),
              SizedBox(height: 4),
              Text(
                'Instruments such as the Digital Multimeter need an open diagram session. '
                'Open the Diagram Perspective to use the Instrument Dock there, or wait for a future '
                'Work Package to connect the currently open diagram\'s session to this Perspective.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: StudioColors.textDisabled),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(children: [DockRegion(manager: dockManager, registry: _registry)]);
  }
}

class _InstrumentsPerspectiveCenter extends StatelessWidget {
  const _InstrumentsPerspectiveCenter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StudioColors.background,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_outlined, size: 40, color: StudioColors.textDisabled),
          SizedBox(height: 12),
          Text('Instruments', style: TextStyle(fontSize: 16, color: StudioColors.textSecondary)),
          SizedBox(height: 4),
          Text(
            'This Perspective\'s workspace is not yet built. Its bottom dock demonstrates the new\n'
            'generic Dock Manager framework, adapting Engineering Instruments via InstrumentDockPanelClient.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: StudioColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
