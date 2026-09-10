/// PRODUCT-READINESS-004 Phase A — whether a branch (or a pair of
/// terminals) is presently conducting, independent of any specific
/// quantity's own [ElectricalReadingState] (`electrical_reading_state.dart`).
/// A branch's own wire can be physically intact while still not conducting
/// (an open switch elsewhere on it) — see `electrical_branch_state.dart`'s
/// own doc comment ("physical topology vs. electrical topology").
enum ElectricalConductingState {
  /// A conductive path exists across this branch/terminal pair under the
  /// current operating state.
  conducting,

  /// No conductive path exists (an open switch, blown fuse, disconnected
  /// connector pin, or simply no relevant source/reference reachable).
  open,

  /// Not yet determined by the solver.
  unknown,
}

/// PRODUCT-READINESS-004 Phase A — current direction along a branch,
/// relative to the branch's own declared source/destination terminals
/// (`electrical_branch_state.dart`). Never inferred from voltage alone —
/// see [ElectricalBranchState]'s own doc comment on why "nonzero voltage"
/// is not the same thing as "current is flowing in a known direction"
/// (PRODUCT-READINESS-004's own audit finding: the current solver has no
/// current/Ohm's-law model at all).
enum ElectricalCurrentDirection {
  /// Current flows from the branch's declared source terminal toward its
  /// declared destination terminal.
  sourceToDestination,

  /// Current flows the opposite way.
  destinationToSource,

  /// The branch is conducting but carries zero current (a real, valid
  /// answer — distinct from [unknown]; see [ElectricalReading]'s own
  /// "zero is not the same as unavailable" invariant).
  none,

  /// Not yet determined by the solver (no current model exists yet, or
  /// this branch was never evaluated for direction).
  unknown,
}
