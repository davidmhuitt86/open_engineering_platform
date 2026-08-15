import 'dmm_measurement_mode.dart';

/// OIP-DMM-007 — the physical input jacks a real digital multimeter
/// exposes. A real DMM requires the operator to plug leads into the
/// correct jack for the selected mode (e.g. current measurement needs
/// the mA or 10A jack, not the standard VΩ jack) — this app models that
/// same constraint in software so "changing lead plugs from your phone"
/// (the user's own framing) behaves like the real instrument, not a
/// simplified abstraction of it.
enum DmmProbeJack {
  /// Common/reference — always where the black (reference) probe goes.
  com,

  /// Voltage / Resistance / Continuity / Diode / Frequency / Capacitance
  /// / Temperature — the standard red-probe jack for every mode except
  /// current.
  voltageOhm,

  /// Low-current (milliamp range).
  milliamp,

  /// High-current (up to 10A, unfused on real meters — modeled here
  /// only as the correct jack selection, no fusing/limits simulation).
  tenAmp,
}

/// Whether [jack] is the correct red-probe jack for [mode] — a real DMM
/// physically prevents a correct reading (or displays an error/blows a
/// fuse) if the red lead is in the wrong jack; this is the software
/// equivalent check.
bool isCorrectJackForMode(DmmProbeJack jack, DmmMeasurementMode mode) {
  switch (mode) {
    case DmmMeasurementMode.current:
      return jack == DmmProbeJack.milliamp || jack == DmmProbeJack.tenAmp;
    case DmmMeasurementMode.dcVoltage:
    case DmmMeasurementMode.acVoltage:
    case DmmMeasurementMode.resistance:
    case DmmMeasurementMode.continuity:
    case DmmMeasurementMode.diode:
    case DmmMeasurementMode.frequency:
    case DmmMeasurementMode.dutyCycle:
    case DmmMeasurementMode.temperature:
    case DmmMeasurementMode.capacitance:
      return jack == DmmProbeJack.voltageOhm;
  }
}
