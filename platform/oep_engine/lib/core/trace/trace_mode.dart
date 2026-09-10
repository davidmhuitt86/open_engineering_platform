/// PRODUCT-READINESS-005, §4 — the three trace concepts the Trace Engine
/// must keep explicitly distinct. Each answers a genuinely different
/// question; none is a stricter/looser version of another.
enum TraceMode {
  /// "What physical engineering objects are connected?" Does not consult
  /// [SolvedElectricalState] at all, and does not imply current is
  /// flowing — an open switch is still part of a physical chain (§4.1's
  /// own worked example).
  physical,

  /// "What electrically conductive paths exist in the current operating
  /// state?" State-dependent — an open switch breaks this trace even
  /// though it doesn't break [physical].
  conducting,

  /// "Where is actual current flowing according to the solved electrical
  /// state?" Must be based on solved branch current/direction — never
  /// `voltage != 0` as a proxy (§4.3's own explicit prohibition).
  currentFlow,
}
