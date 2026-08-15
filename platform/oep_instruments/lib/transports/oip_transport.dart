import '../protocol/oip_message.dart';
import 'transport_state.dart';

/// OIP-TRANSPORT-001 §6 — "Every transport implements: Initialize,
/// Shutdown, Discover, Connect, Disconnect, Reconnect, Send, Receive,
/// Flush, Status, Capabilities. The Runtime communicates only with this
/// interface." A transport moves [OipMessage]s; it never interprets
/// them (§5: "no engineering computation").
abstract class OipTransport {
  String get transportId;

  TransportConnectionState get state;

  Future<void> initialize();

  Future<void> shutdown();

  /// OIP-TRANSPORT-001 §8 — yields discovered devices/hosts as they're
  /// found; the caller decides which (if any) to [connect] to.
  Stream<String> discover();

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> reconnect();

  Future<void> send(OipMessage message);

  /// Incoming messages, in delivery order (§10: "Ordered delivery").
  Stream<OipMessage> receive();

  Future<void> flush();

  TransportDiagnostics status();
}
