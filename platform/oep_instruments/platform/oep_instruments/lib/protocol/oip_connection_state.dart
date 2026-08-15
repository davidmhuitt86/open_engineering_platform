/// OIP-SPEC-001 §8 / §20 — the connection flow every Host↔Client
/// negotiation walks through, and the resulting instrument-visible
/// connection state.
enum OipConnectionState {
  disconnected,
  connecting,
  authenticating,
  ready,
  busy,
  streaming,
  paused,
  error,
  offline,
}
