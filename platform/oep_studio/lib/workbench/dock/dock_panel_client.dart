import 'package:flutter/widgets.dart';

/// WP-DS-006 Engineering Workbench — the contract any dockable panel
/// implements to appear in a [DockManager]-driven dock region. Generalizes
/// WP-DS-005A's `EngineeringInstrument` contract (Digital Multimeter) to be
/// usable by any future dock content, not just instruments — see
/// `docs/architecture/diagram_studio/ENGINEERING_WORKBENCH.md` for why the
/// Instrument Dock's own chrome is NOT rebuilt on top of this in Phase 1
/// (a disclosed, deliberate scope boundary), while the Instruments
/// Perspective's own bottom dock DOES use this framework, adapting the
/// existing, untouched `EngineeringInstrument`s into [DockPanelClient]s.
abstract class DockPanelClient {
  const DockPanelClient();

  /// Stable identifier — used as the dock tab key and in persisted dock
  /// state, so it must never change once shipped.
  String get id;

  String get title;

  IconData get icon;

  Widget buildPanel(BuildContext context);
}

/// Registers every [DockPanelClient] available to one [DockManager]
/// instance and notifies listeners when the set changes — one registry per
/// dock region, matching `InstrumentRegistry`'s own "one per owning page"
/// pattern.
class DockPanelClientRegistry extends ChangeNotifier {
  final Map<String, DockPanelClient> _clients = {};

  List<DockPanelClient> get all => List.unmodifiable(_clients.values);

  DockPanelClient? byId(String id) => _clients[id];

  bool get isEmpty => _clients.isEmpty;

  void register(DockPanelClient client) {
    if (_clients.containsKey(client.id)) {
      throw StateError('DockPanelClientRegistry: a client with id "${client.id}" is already registered.');
    }
    _clients[client.id] = client;
    notifyListeners();
  }

  void unregister(String id) {
    if (_clients.remove(id) != null) notifyListeners();
  }
}
