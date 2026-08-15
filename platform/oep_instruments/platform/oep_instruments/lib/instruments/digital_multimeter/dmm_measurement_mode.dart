/// OIP-DMM-002/008-016 — the Digital Multimeter's supported measurement
/// modes. This first increment covers the core electrical modes
/// (DC/AC Voltage, Resistance, Continuity) plus the remaining modes
/// named in OIP-DMM-013/015/016/012 as enum values so the mode selector
/// UI and capability declarations are complete — Current, Diode,
/// Frequency, Duty Cycle, Temperature, and Capacitance measurement
/// itself (the actual acquisition-and-display wiring for the latter
/// three) is not yet implemented; see this package's README for exactly
/// what's real today.
enum DmmMeasurementMode {
  dcVoltage,
  acVoltage,
  resistance,
  continuity,
  current,
  diode,
  frequency,
  dutyCycle,
  temperature,
  capacitance,
}
