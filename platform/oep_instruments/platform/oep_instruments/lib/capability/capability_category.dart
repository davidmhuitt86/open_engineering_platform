/// OIP-CAPABILITY-001 §5 — the categories a [Capability] is organized
/// into. Descriptive only; a category never implies HOW a capability is
/// implemented, only what kind of feature it describes.
enum CapabilityCategory {
  measurement,
  visualization,
  interaction,
  playback,
  recording,
  export,
  communication,
  diagnostics,
  accessibility,
  hardware,
}
