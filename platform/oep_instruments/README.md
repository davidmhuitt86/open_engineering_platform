# OEP Instruments Runtime

A platform-independent execution environment for engineering instrument
plugins, built directly from the `oep_instruments` repository's own
architecture specifications (`docs/architecture/`). Completely independent
from engineering computation — see `OIP-CON-001` (the Constitution) for
the governing philosophy: **"OEP Instruments shall never become another
engineering engine. It is an engineering interface."**

## What this is

A real, tested Dart/Flutter package (`oep_instruments_runtime`) implementing
the core Runtime architecture, a real working Wi-Fi transport, a Host-side
bridge inside `oep_studio`, and a real Android app — a genuine, end-to-end
Digital Multimeter companion app for the Open Engineering Platform.

### Runtime core

- **Capability Model** (`lib/capability/`, per `OIP-CAPABILITY-001`) —
  `Capability`, `CapabilityCategory`, `CapabilityRegistry`.
- **Instrument State Machines** (`lib/runtime/`, per `OIP-STATE-001` /
  `OIP-LIFECYCLE-001`) — two *distinct* deterministic FSMs (operational
  state vs. lifecycle state), both rejecting illegal transitions by
  construction.
- **OEP Instrument Protocol (OIP) message model** (`lib/protocol/`, per
  `OIP-SPEC-001`) — `OipMessage`, `OipMessageCategory`,
  `OipConnectionState`, version negotiation, error model.
- **Session Management** (`lib/session/`, per `OIP-SESSION-001`) —
  `EngineeringSession`.
- **Plugin Architecture** (`lib/plugins/`, per `OIP-PLUGIN-001`) —
  `InstrumentPlugin`, `PluginManifest`, `PluginContext`, `PluginManager`.
- **Measurement Framework** (`lib/measurement/`, per `OIP-MEASUREMENT-001`)
  — `Measurement`, `MeasurementState`, `MeasurementQuality`. A
  `Measurement` never computes a value — it only carries one the Host
  already produced (Constitution §13, Determinism).
- **Probe System** (`lib/probe/`, per `OIP-PROBE-001`) — `Probe`,
  `ProbeType`, `ProbeState`.

### Transports (`lib/transports/`, per `OIP-TRANSPORT-001`)

- **`WifiOipTransport` + `OipHostServer`** — real, working, tested. Plain
  TCP sockets, newline-delimited JSON `OipMessage` framing. Proven with a
  real client↔server loopback test (`test/transports/wifi_oip_transport_test.dart`)
  and a real Digital Multimeter → `oep_studio` Host bridge integration
  test (`oep_studio/test/instruments_host/oip_host_bridge_service_test.dart`).
- **`UsbOipTransport`** — a disclosed, deliberate stub. Genuine PC↔Android
  USB requires the Android Open Accessory protocol (native code on both
  the Android side and the Windows side) and real hardware to build and
  verify against, neither of which is available here. Every method throws
  `UnimplementedError` rather than silently pretending to work — see the
  class's own doc comment. Swapping in a real implementation later
  requires no change anywhere else, since everything above this layer
  only depends on the `OipTransport` interface.

### First instrument: Digital Multimeter (`lib/instruments/digital_multimeter/`)

A real `InstrumentPlugin` implementation, matching a premium bezel-and-
console reference design (bezel header, mode tab strip, main display card
with REL/HOLD/analog bargraph, TREND/MIN-MAX/RECORD row, instrument-spec
info chips, bottom navigation, rotary control cluster, and a 4-jack probe
row matching `OIP-DMM-007`'s physical-jack model). Real, wired behavior:

- **DC/AC Voltage, Resistance, Continuity** modes — mode selection → probe
  pair (black/red) → live request/response over a connected transport →
  display.
- **HOLD** (`OIP-DMM-018`) — freezes the displayed value; the plugin keeps
  recording real incoming measurements underneath.
- **REL** (`OIP-DMM-017`) — captures a zero-reference, subtracts it from
  the live value; cleared automatically on a mode change.
- **MIN/MAX** (`OIP-DMM-019`) — a real running min/max over every numeric
  value received since the last reset or mode change.
- **Probe jack selection** (`OIP-DMM-007`) — the red lead's physical jack
  (VΩ / mA / 10A) is tracked and validated against the active mode, exactly
  like a real meter's own constraint; a wrong-jack state is surfaced, not
  silently ignored.
- **Tones/haptics** — real `SystemSound`/`HapticFeedback` calls on mode
  change, jack change, HOLD, REL, probe attach, and connect, using
  Flutter's own built-in APIs (no fabricated custom audio assets).
- **What's cosmetic, disclosed in the panel's own doc comment**:
  auto-ranging, TREND/graphing, RECORD, SAVE, FUNC, and the
  Measure/Graph/Data/Settings bottom-nav destinations render faithfully
  but tapping them shows an honest "not yet available" affordance. Battery
  percentage is a static placeholder, not live device telemetry.
- Current/Diode/Frequency/Duty Cycle/Temperature/Capacitance are real,
  selectable modes with a real live request path (the Host bridge answers
  all ten `MeasurementType`s `oep_engine` supports) — only their
  measurement-specific UI affordances (e.g. a real diode forward-voltage
  display convention) are not specially tailored beyond the shared numeric
  readout.

## Real end-to-end path (this is not simulated)

```
Android app (apps/android)
  -> ConnectScreen: real WifiOipTransport.connect('host:port')
  -> DigitalMultimeterPlugin.connectTransport(transport)
  -> user selects a mode / probe jack -> plugin.requestMeasurement()
  -> real TCP message sent: OipMessage(category: measurement, type: 'requestMeasurement', ...)

oep_studio (lib/diagram_studio/instruments_host/oip_host_bridge_service.dart)
  -> OipHostServer accepts the connection
  -> OipHostBridgeService decodes the request, calls the REAL SimulationEngine.measure(...)
     against the current diagram's graph -- the same engine WP-DS-005A's
     embedded Digital Multimeter (inside Diagram Studio itself) already uses
  -> sends back a real 'measurementResult' OipMessage

Android app
  -> plugin.receiveMeasurement(...) -- never computes anything itself
  -> the panel displays the real value, applies HOLD/REL if active
```

`OipHostBridgeService` is off by default — it does not open a listening
network port until `start()` is called explicitly (opening a socket is a
deliberate, visible action, not something that happens silently because
Diagram Studio is open). **Wiring `start()` into Diagram Studio's own UI
(a toggle to enable/disable the companion connection, with the port
configurable) is a disclosed follow-up** — this increment proves the real
service works end-to-end via tests, not via a Studio-side UI control yet.

## Explicitly NOT built yet (disclosed, not silently skipped)

This repository's own docs describe roughly 90 specification documents and
a genuinely large, multi-platform, multi-transport, multi-instrument
product. Not yet implemented:

- **Real USB communication** — see `UsbOipTransport`'s own disclosure above.
- **A Diagram Studio UI control to start/stop the companion connection** —
  `OipHostBridgeService` is real and tested but has no on-screen toggle yet.
- **Discovery/Host Manager** (`OIP-ARCH-001` §7) — pairing, mDNS/broadcast
  discovery, authentication are not implemented; a user enters an IP
  address and port by hand.
- **The full multi-client shared-Session architecture** (`OIP-SESSION-001`)
  — the Host bridge creates one real engine session per distinct OIP
  session id it sees; a full implementation would have the Host create
  Sessions and clients join them, with true cross-client synchronization
  (probe moves on one device reflected on another). See
  `OipHostBridgeService`'s own doc comment for the exact, disclosed gap.
- **Calibration workflows** (`OIP-CAL-001`) — understood, not built.
- **Persistence** (`OIP-PERSISTENCE-001`) — nothing survives an app
  restart yet (no saved Host address, no remembered layout/preferences).
- **History/Bookmarks** (`OIP-HISTORY-001`) — no measurement history store.
- **Auto-ranging, publishing/export, licensing, cloud sync, self-test,
  calibration UI** — the remaining `OIP-DMM-0XX` feature specs beyond the
  core measurement/HOLD/REL/MIN-MAX path.
- **Any instrument other than the Digital Multimeter** — Oscilloscope,
  Logic Probe, CAN/LIN Analyzer, Power Probe, etc. are named throughout the
  architecture docs as future plugins; none exist yet.

## Testing

`oep_instruments_runtime`: 42 tests across `test/capability/`,
`test/runtime/`, `test/protocol/`, `test/session/`, `test/plugins/`,
`test/transports/`, `test/instruments/digital_multimeter/` — real
state-machine transition tests, a real `PluginManager` lifecycle walk, a
real TCP loopback test proving `WifiOipTransport`/`OipHostServer`
interoperate, a real request/response test proving the Digital Multimeter
plugin talks to a real transport end-to-end, and a real `testWidgets`
render of the full instrument panel. `flutter test` / `flutter analyze`
both clean.

`apps/android` (`oep_dmm`): 2 widget tests (Connect screen renders; empty
host shows a validation error, not a silent failure). `flutter analyze`
clean.

`oep_studio`: `test/instruments_host/oip_host_bridge_service_test.dart` —
a real Digital Multimeter client, over a real TCP loopback connection,
requesting and receiving a real measurement from `SimulationEngine`
against a fixture graph. Full `oep_studio` suite (638 tests) and
`flutter analyze` both clean with this addition.
