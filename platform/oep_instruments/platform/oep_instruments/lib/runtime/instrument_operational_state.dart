/// OIP-STATE-001 §4 — the operational state machine every instrument
/// behaves as while executing. Distinct from [InstrumentLifecycleState]
/// (OIP-LIFECYCLE-001): lifecycle governs the instrument's *existence*;
/// operational state governs what it is currently *doing* (§1).
enum InstrumentOperationalState {
  idle,
  waiting,
  measuring,
  holding,
  recording,
  playback,
  paused,
  fault,
  recovering,
  shutdown,
}
