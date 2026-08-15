import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../capability/capability.dart';
import '../../capability/capability_category.dart';
import '../../capability/capability_registry.dart';
import '../../measurement/measurement.dart';
import '../../measurement/measurement_state.dart';
import '../../plugins/instrument_plugin.dart';
import '../../plugins/plugin_context.dart';
import '../../plugins/plugin_manifest.dart';
import '../../probe/probe.dart';
import '../../probe/probe_type.dart';
import '../../protocol/oip_message.dart';
import '../../protocol/oip_message_category.dart';
import '../../session/engineering_session.dart';
import '../../transports/oip_transport.dart';
import 'dmm_measurement_mode.dart';
import 'dmm_probe_jack.dart';
import 'digital_multimeter_panel.dart';

/// OIP-DMM-059 — the Digital Multimeter, the first permanent OEP
/// Instrument plugin. Implements [InstrumentPlugin] directly; owns no
/// engineering computation (Constitution §6) — every displayed
/// [Measurement] arrives via [receiveMeasurement], sourced from the Host.
///
/// **Scope of this first increment** (see this package's README for the
/// full disclosure): DC/AC Voltage, Resistance, and Continuity modes are
/// wired end-to-end (mode selection -> probe pair -> measurement
/// display). Current/Diode/Frequency/Duty Cycle/Temperature/Capacitance
/// exist as [DmmMeasurementMode] values and capability declarations but
/// are not yet wired to a live display path. Auto-ranging, calibration
/// workflows, recording/playback, publishing integration, and the
/// remaining ~50 OIP-DMM feature specs are not implemented — this
/// mirrors WP-DS-005A's own "real subset over a half-working everything"
/// precedent in the sibling `oep_studio` repository.
class DigitalMultimeterPlugin implements InstrumentPlugin {
  DigitalMultimeterPlugin();

  static const String pluginId = 'oep.instruments.digitalMultimeter';

  @override
  final PluginManifest manifest = PluginManifest(
    pluginId: pluginId,
    displayName: 'Digital Multimeter',
    version: '0.1.0',
    author: 'Open Engineering Platform',
    description: 'A professional virtual digital multimeter instrument.',
    supportedProtocolVersion: '1.0',
    supportedRuntimeVersion: '1.0',
    instrumentCategory: 'measurement',
    entryPoint: pluginId,
    capabilities: const [
      Capability(
        id: 'measurement.dcVoltage',
        displayName: 'DC Voltage',
        description: 'Measures DC voltage between two probe points.',
        category: CapabilityCategory.measurement,
        version: '1.0',
      ),
      Capability(
        id: 'measurement.acVoltage',
        displayName: 'AC Voltage',
        description: 'Measures AC voltage between two probe points.',
        category: CapabilityCategory.measurement,
        version: '1.0',
      ),
      Capability(
        id: 'measurement.resistance',
        displayName: 'Resistance',
        description: 'Measures resistance between two probe points.',
        category: CapabilityCategory.measurement,
        version: '1.0',
      ),
      Capability(
        id: 'measurement.continuity',
        displayName: 'Continuity',
        description: 'Tests continuity between two probe points.',
        category: CapabilityCategory.measurement,
        version: '1.0',
      ),
      Capability(
        id: 'interaction.probePlacement',
        displayName: 'Probe Placement',
        description: 'Place and move the black/red probe pair on measurement targets.',
        category: CapabilityCategory.interaction,
        version: '1.0',
      ),
    ],
  );

  @override
  final CapabilityRegistry capabilities = CapabilityRegistry();

  PluginContext? _context;
  DmmMeasurementMode _mode = DmmMeasurementMode.dcVoltage;
  Measurement? _lastMeasurement;

  Probe _probeBlack = const Probe(id: 'dmm-black', displayName: 'Black Probe', type: ProbeType.reference, color: 'black', state: ProbeState.available);
  Probe _probeRed = const Probe(id: 'dmm-red', displayName: 'Red Probe', type: ProbeType.measurement, color: 'red', state: ProbeState.available);

  /// OIP-DMM-007 — the black lead is always in COM; only the red lead's
  /// jack changes with mode (matching how a real DMM's front panel is
  /// laid out).
  DmmProbeJack _redJack = DmmProbeJack.voltageOhm;

  /// The transport this instrument sends measurement requests over, set
  /// by the hosting app once connected (e.g. the Android app's Connect
  /// screen wires a real [WifiOipTransport] in here). `null` means "not
  /// connected" — [requestMeasurement] is then a deliberate no-op rather
  /// than a silent failure.
  OipTransport? _transport;

  StreamSubscription<OipMessage>? _transportSubscription;

  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// OIP-DMM-018 (Hold and Display Freeze) — when held, the display
  /// stops updating even though [receiveMeasurement] keeps recording
  /// real incoming values; [displayedMeasurement] is what a panel
  /// should actually render.
  bool _held = false;
  Measurement? _heldMeasurement;

  /// OIP-DMM-017 (Relative Measurement Mode) — an offset captured from
  /// the measurement active when REL was engaged; [relativeValue]
  /// subtracts it from the live numeric value. Cleared automatically on
  /// a mode change, matching a real meter (REL is mode-scoped).
  num? _relativeReference;

  /// OIP-DMM-019 (Min/Max/Peak Capture) — running min/max of every
  /// numeric value seen since the last [resetMinMax] or mode change.
  num? _minValue;
  num? _maxValue;

  DmmMeasurementMode get mode => _mode;
  Measurement? get lastMeasurement => _lastMeasurement;
  Probe get probeBlack => _probeBlack;
  Probe get probeRed => _probeRed;
  DmmProbeJack get redJack => _redJack;
  bool get isHeld => _held;
  bool get isRelativeActive => _relativeReference != null;
  num? get minValue => _minValue;
  num? get maxValue => _maxValue;

  /// What a panel should actually display — the held snapshot while
  /// [isHeld], otherwise the latest live [lastMeasurement].
  Measurement? get displayedMeasurement => _held ? _heldMeasurement : _lastMeasurement;

  /// The numeric value a panel should show after applying REL, or
  /// `null` if [displayedMeasurement] has no numeric value.
  num? get relativeValue {
    final value = displayedMeasurement?.value;
    if (value is! num) return null;
    final reference = _relativeReference;
    return reference == null ? value : value - reference;
  }

  /// OIP-DMM-007 — whether the red lead is currently in the jack the
  /// active [mode] actually requires, exactly like a real meter's own
  /// physical constraint. The UI surfaces this as a warning rather than
  /// blocking the request outright — a real operator can plug a lead
  /// into the wrong jack too; the instrument should say so, not pretend
  /// it's impossible.
  bool get isJackCorrectForMode => isCorrectJackForMode(_redJack, _mode);

  /// The Session this plugin was bound to during [initialize] — needed
  /// once a future increment requests a measurement through the Host
  /// (OIP-API-001 §9), so a probe placement can be tagged with the
  /// Session it belongs to. `null` before [initialize] runs / after
  /// [shutdown].
  EngineeringSession? get session => _context?.session;

  /// A plugin-local repaint signal for [render]'s widget tree — the
  /// Runtime pushes state via [receiveMeasurement]/[receiveEvent], not
  /// via a rebuild the framework triggers on its own, so this plugin
  /// needs its own notifier to tell its UI something changed.
  Listenable get revision => _revision;

  /// Changes the active mode and plays a click tone — OIP-DS-001 §16
  /// ("Sound shall reinforce interaction... Rotary detent") models this
  /// as the rotary-selector detent click a real meter makes when turned
  /// to a new mode. Uses `SystemSound`/`HapticFeedback` (real, built
  /// into Flutter, no extra dependency) rather than fabricated custom
  /// audio assets — see this package's README for the disclosed
  /// follow-up (real DMM-specific sound samples).
  void setMode(DmmMeasurementMode mode) {
    _mode = mode;
    // A real meter's REL/Min/Max are mode-scoped -- switching modes
    // always resets them, matching OIP-DMM-017 §-adjacent behavior for
    // relative measurement and min/max capture.
    _relativeReference = null;
    _minValue = null;
    _maxValue = null;
    unawaited(SystemSound.play(SystemSoundType.click));
    HapticFeedback.selectionClick();
    _revision.value++;
  }

  /// OIP-DMM-018 — toggles Hold. Engaging Hold snapshots whatever is
  /// currently displayed so live updates stop being shown; disengaging
  /// resumes showing [lastMeasurement] live.
  void toggleHold() {
    _held = !_held;
    if (_held) _heldMeasurement = _lastMeasurement;
    unawaited(SystemSound.play(SystemSoundType.click));
    HapticFeedback.mediumImpact();
    _revision.value++;
  }

  /// OIP-DMM-017 — toggles Relative mode: engaging it captures the
  /// current numeric value as the new zero reference; disengaging
  /// clears the reference.
  void toggleRelative() {
    if (_relativeReference != null) {
      _relativeReference = null;
    } else {
      final value = displayedMeasurement?.value;
      _relativeReference = value is num ? value : null;
    }
    unawaited(SystemSound.play(SystemSoundType.click));
    HapticFeedback.selectionClick();
    _revision.value++;
  }

  /// OIP-DMM-019 — clears the running Min/Max capture without touching
  /// Hold/REL state or the current mode.
  void resetMinMax() {
    _minValue = null;
    _maxValue = null;
    _revision.value++;
  }

  /// OIP-DMM-007 — moves the red lead to a different physical jack, the
  /// "change lead plugs from your phone" interaction. Also plays a
  /// click tone, matching a real meter's jack insertion feedback.
  void setRedJack(DmmProbeJack jack) {
    _redJack = jack;
    unawaited(SystemSound.play(SystemSoundType.click));
    HapticFeedback.selectionClick();
    _revision.value++;
  }

  void setProbeBlackTarget(String? targetId) {
    _probeBlack = _probeBlack.copyWith(
      state: targetId == null ? ProbeState.available : ProbeState.attached,
      currentTargetId: targetId,
      clearTarget: targetId == null,
    );
    _revision.value++;
  }

  /// Attaching the red probe plays a continuity-style tap tone (OIP-DS-001
  /// §16's "Continuity beep" — a lighter click here since full continuity
  /// tone-on-connect is a disclosed follow-up needing the actual
  /// measurement result, not just probe attachment, to know whether a
  /// real continuity beep is warranted).
  void setProbeRedTarget(String? targetId) {
    _probeRed = _probeRed.copyWith(
      state: targetId == null ? ProbeState.available : ProbeState.attached,
      currentTargetId: targetId,
      clearTarget: targetId == null,
    );
    if (targetId != null) HapticFeedback.lightImpact();
    _revision.value++;
  }

  /// Binds this instrument to a live transport (e.g. a connected
  /// [WifiOipTransport]) — the hosting app calls this once a connection
  /// to a Host is established. Subscribes to the transport's incoming
  /// messages so measurement results the Host pushes back arrive via
  /// [receiveMeasurement] automatically.
  void connectTransport(OipTransport transport) {
    _transportSubscription?.cancel();
    _transport = transport;
    _transportSubscription = transport.receive().listen((message) {
      if (message.category == OipMessageCategory.measurement) {
        receiveMeasurement(message);
      } else {
        receiveEvent(message);
      }
    });
    unawaited(SystemSound.play(SystemSoundType.alert));
    _revision.value++;
  }

  Future<void> disconnectTransport() async {
    await _transportSubscription?.cancel();
    _transportSubscription = null;
    _transport = null;
    _revision.value++;
  }

  bool get isConnected => _transport != null;

  /// OIP-API-001 §9 ("Begin Measurement") — sends a real measurement
  /// request for the current [mode]/probe placement over whatever
  /// transport [connectTransport] bound. This plugin never computes the
  /// resulting value itself; the response arrives later via
  /// [receiveMeasurement] once the Host (Diagram Studio) has actually
  /// computed it. A no-op (not a throw) when nothing is connected, since
  /// requesting a measurement with no Host is a normal, expected UI
  /// state (e.g. browsing modes before connecting), not an error.
  Future<void> requestMeasurement() async {
    final transport = _transport;
    final activeSession = session;
    if (transport == null || activeSession == null) return;

    await transport.send(OipMessage(
      protocolVersion: '1.0',
      category: OipMessageCategory.measurement,
      type: 'requestMeasurement',
      sessionId: activeSession.id,
      messageId: '${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      payload: {
        'measurementType': _mode.name,
        'probeBlackTargetId': _probeBlack.currentTargetId,
        'probeRedTargetId': _probeRed.currentTargetId,
      },
    ));
  }

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    for (final capability in manifest.capabilities) {
      capabilities.register(capability);
    }
  }

  @override
  Future<void> shutdown() async {
    await disconnectTransport();
    _context = null;
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> suspend() async {}

  @override
  Future<void> resume() async {}

  @override
  Widget render(BuildContext context) => DigitalMultimeterPanel(plugin: this);

  @override
  void receiveEvent(OipMessage event) {
    // Non-measurement Runtime events (selection changed, simulation
    // state, ...) -- no engineering interpretation happens here, only
    // UI-relevant bookkeeping a future increment will add as real
    // event-driven behavior is needed.
    _revision.value++;
  }

  @override
  void receiveMeasurement(OipMessage measurement) {
    final payload = measurement.payload;
    _lastMeasurement = Measurement(
      id: payload['id'] as String? ?? measurement.messageId,
      timestamp: measurement.timestamp,
      value: payload['value'],
      unit: payload['unit'] as String? ?? '',
      measurementType: payload['measurementType'] as String? ?? _mode.name,
      source: payload['source'] as String? ?? 'unknown',
      quality: _qualityFromPayload(payload),
      state: _stateFromPayload(payload),
      sessionId: measurement.sessionId,
      engineeringObjectId: payload['engineeringObjectId'] as String?,
    );
    final value = _lastMeasurement?.value;
    if (value is num) {
      _minValue = _minValue == null ? value : (value < _minValue! ? value : _minValue);
      _maxValue = _maxValue == null ? value : (value > _maxValue! ? value : _maxValue);
    }
    _revision.value++;
  }

  MeasurementQuality _qualityFromPayload(Map<String, Object?> payload) {
    final raw = payload['quality'] as String?;
    return MeasurementQuality.values.firstWhere((q) => q.name == raw, orElse: () => MeasurementQuality.measured);
  }

  MeasurementState _stateFromPayload(Map<String, Object?> payload) {
    final raw = payload['state'] as String?;
    return MeasurementState.values.firstWhere((s) => s.name == raw, orElse: () => MeasurementState.stable);
  }
}
