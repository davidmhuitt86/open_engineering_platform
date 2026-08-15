/// OIP-SPEC-001 §7 — every OIP message belongs to exactly one category.
enum OipMessageCategory {
  connection,
  authentication,
  session,
  discovery,
  measurement,
  simulation,
  playback,
  diagnostics,
  instrument,
  configuration,
  history,
  notification,
  error,
  heartbeat,
}
