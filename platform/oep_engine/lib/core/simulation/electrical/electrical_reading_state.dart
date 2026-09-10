/// PRODUCT-READINESS-004 Phase A — the explicit vocabulary every electrical
/// quantity (voltage, current, resistance, power, ...) in the terminal-
/// centric solved-state model is reported through.
///
/// Existing `oep_engine` types this phase deliberately does NOT duplicate:
/// [SimulationFaultType] (`core/simulation/models/simulation_fault.dart`)
/// classifies WHAT KIND of fault was injected (open circuit, short, relay
/// failure, ...) — an input to solving. This enum classifies HOW a given
/// *reading* came out — an output of solving. They answer different
/// questions and are meant to compose: a `.fault` reading may reference the
/// [SimulationFaultType] responsible via a reading's own `note`, without
/// this enum re-enumerating fault types itself.
///
/// The load-bearing invariant this enum exists to enforce (PRODUCT-
/// READINESS-002/003/004's own repeated finding): a numeric `0` must never
/// be the sole representation for "unknown," "unreached," "open circuit,"
/// or "unsupported measurement." A genuine zero reading is [valid] with a
/// real `0.0`/`0` value; every other case here carries no numeric value at
/// all (see [ElectricalReading]).
enum ElectricalReadingState {
  /// A real, computed value is present (including a genuine zero — see
  /// class doc comment). This is the ONLY state a numeric value is ever
  /// attached to.
  valid,

  /// Not yet computed, or the solver has no basis to answer at all (e.g.
  /// a quantity that depends on component data nothing has authored).
  /// Distinct from [unreached]: this is "we don't know," not "we know
  /// there's no path."
  unknown,

  /// The solver evaluated this terminal/branch and found no conductive
  /// path from any relevant source (or to any relevant reference) under
  /// the current operating state — a definite, computed answer, not an
  /// absence of computation. Distinct from [open]: this answers "does
  /// power/ground arrive here," while [open] answers "is this specific
  /// conductor continuous" — a terminal can be electrically continuous
  /// to another point while still being [unreached] from a power source
  /// (e.g. an unpowered but intact wire), and a branch can be [unreached]
  /// without its own wire being [open] (e.g. a load with no return path).
  unreached,

  /// A genuine open circuit found during a continuity/resistance check
  /// (an open switch, a blown fuse, a disconnected connector pin, ...).
  open,

  /// The measured/computed magnitude exceeds what the solver or a real
  /// instrument could represent (a real DMM's "OL" for an out-of-range
  /// value, distinct from a true open circuit — e.g. a short reads as a
  /// near-zero resistance, not overload; a resistance genuinely beyond a
  /// meter's range is).
  overload,

  /// An active [SimulationFault]/component fault makes this reading
  /// unreliable or not physically meaningful as computed (see class doc
  /// comment for the relationship to [SimulationFaultType]).
  fault,

  /// The requested quantity/mode is not something the current solver
  /// (or this component's behavior model) can compute at all — e.g.
  /// requesting `current` or `power` from a solver with no Ohm's-law
  /// model yet (PRODUCT-READINESS-004's own audit finding). Never
  /// silently answered with a fabricated value.
  unsupported,
}
