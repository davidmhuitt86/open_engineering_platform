/// OIP-PROBE-001 §5 — supported probe types.
enum ProbeType {
  measurement,
  reference,
  ground,
  current,
  differential,
  logic,
  can,
  lin,
}

/// OIP-PROBE-001 §8 — a probe's own state; only one is active at a time.
enum ProbeState {
  available,
  selected,
  dragging,
  hovering,
  attached,
  measuring,
  released,
  disabled,
  unavailable,
}
