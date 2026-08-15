/// OIP-MEASUREMENT-001 §8 — a measurement's own lifecycle state (distinct
/// from [InstrumentOperationalState] — a measurement is one observation,
/// an instrument's operational state spans many).
enum MeasurementState {
  requested,
  pending,
  streaming,
  stable,
  held,
  completed,
  invalid,
  unavailable,
  archived,
}

/// OIP-MEASUREMENT-001 §9 — quality metadata. "Quality shall never
/// modify engineering value" — this describes confidence/provenance in
/// the value, never adjusts the value itself.
enum MeasurementQuality {
  stable,
  changing,
  estimated,
  simulated,
  measured,
  calculated,
  invalid,
  unavailable,
}
