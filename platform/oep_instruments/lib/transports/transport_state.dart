/// OIP-TRANSPORT-001 §9 — the connection lifecycle a transport reports.
/// "The Transport Layer reports state only" — never interprets it.
enum TransportConnectionState {
  disconnected,
  discovering,
  connecting,
  connected,
  authenticated,
  streaming,
  suspended,
  reconnecting,
}

/// OIP-TRANSPORT-001 §13 — diagnostics a transport reports to the
/// Runtime.
class TransportDiagnostics {
  const TransportDiagnostics({
    this.currentLatencyMs,
    this.averageLatencyMs,
    this.peakLatencyMs,
    this.roundTripTimeMs,
    this.bandwidthBytesPerSecond,
    this.packetLossPercent,
  });

  final double? currentLatencyMs;
  final double? averageLatencyMs;
  final double? peakLatencyMs;
  final double? roundTripTimeMs;
  final double? bandwidthBytesPerSecond;
  final double? packetLossPercent;
}
