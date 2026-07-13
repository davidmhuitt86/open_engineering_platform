/// Lane-allocation state shared across every [RoutingProvider.route] call
/// within one render pass — a fresh `RoutingContext` per `DiagramView.render`
/// call keeps parallel routes from overlapping (concept from the reference
/// implementation's per-redraw `usedX`/`usedY` allocation, `EKE_ALGORITHMS.md`
/// #3, reimplemented from scratch).
class RoutingContext {
  static const double laneSpacing = 12;

  final Map<int, int> _columnUsage = {};
  final Map<String, double> _trunkColumns = {};

  /// Returns a column x-coordinate near [preferredX], offset by
  /// [laneSpacing] (alternating left/right) each time the same preferred
  /// column is requested again in this pass.
  double allocateColumn(double preferredX) {
    final key = preferredX.round();
    final count = _columnUsage[key] ?? 0;
    _columnUsage[key] = count + 1;
    if (count == 0) return preferredX;
    final magnitude = (count + 1) ~/ 2;
    final sign = count.isOdd ? 1 : -1;
    return preferredX + sign * magnitude * laneSpacing;
  }

  /// Returns the same column for every request sharing [trunkKey]
  /// (WORK_PACKAGE_022 "Shared Trunks") — the first request for a given
  /// key allocates a lane via [allocateColumn] as normal (so it still
  /// doesn't collide with unrelated wires); every subsequent request with
  /// the same key reuses exactly that column instead of getting its own
  /// offset lane.
  double allocateTrunkColumn(String trunkKey, double preferredX) {
    return _trunkColumns.putIfAbsent(trunkKey, () => allocateColumn(preferredX));
  }
}
