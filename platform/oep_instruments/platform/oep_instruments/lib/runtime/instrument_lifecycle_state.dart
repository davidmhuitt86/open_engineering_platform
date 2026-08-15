/// OIP-LIFECYCLE-001 §4 — governs an instrument's *existence* within the
/// Runtime, independent of [InstrumentOperationalState] (OIP-STATE-001),
/// which governs what an already-connected instrument is currently
/// doing (§1 of that document: "The lifecycle governs the operational
/// state of the instrument, not the engineering session.").
enum InstrumentLifecycleState {
  notInstalled,
  installed,
  discovered,
  loaded,
  initializing,
  ready,
  connected,
  active,
  paused,
  disconnected,
  unloaded,
  destroyed,
}
