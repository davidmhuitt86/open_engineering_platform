/// OIP-SESSION-001 §5 — Session lifecycle states.
enum EngineeringSessionState {
  created,
  authenticated,
  initialized,
  running,
  paused,
  resumed,
  completed,
  archived,
  destroyed,
}
