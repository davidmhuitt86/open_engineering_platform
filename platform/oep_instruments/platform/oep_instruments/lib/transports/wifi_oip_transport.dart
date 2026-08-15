import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/oip_message.dart';
import 'oip_transport.dart';
import 'transport_state.dart';

/// OIP-TRANSPORT-001 §7 — a real, working Wi-Fi (LAN) transport: plain
/// TCP sockets carrying newline-delimited JSON-encoded [OipMessage]s.
/// Chosen as the first real transport per this Work Package's own
/// scope decision — genuine PC<->Android USB communication needs native
/// Android Open Accessory + Windows WinUSB code (see [UsbOipTransport]'s
/// own doc comment for why that's deliberately stubbed, not built,
/// here) and cannot be verified without real hardware; TCP sockets over
/// `dart:io` work identically on Windows and Android with no native
/// plugin, and are exercised by a real loopback client/server test in
/// this package (`test/transports/wifi_oip_transport_test.dart`).
///
/// Framing: each message is JSON-encoded then terminated by `\n` — a
/// simple, sufficient framing for this transport per OIP-TRANSPORT-001
/// §11 ("The Transport Layer is responsible for: Message boundaries...
/// OIP remains unaware of framing."). Messages themselves never contain
/// a raw newline since [OipMessage.toJson] only produces primitive
/// JSON values.
class WifiOipTransport implements OipTransport {
  WifiOipTransport({required this.transportId});

  @override
  final String transportId;

  Socket? _socket;
  TransportConnectionState _state = TransportConnectionState.disconnected;
  final StreamController<OipMessage> _incoming = StreamController<OipMessage>.broadcast();
  StreamSubscription<List<int>>? _socketSubscription;
  final StringBuffer _receiveBuffer = StringBuffer();

  @override
  TransportConnectionState get state => _state;

  @override
  Future<void> initialize() async {
    _state = TransportConnectionState.disconnected;
  }

  @override
  Future<void> shutdown() async {
    await disconnect();
    await _incoming.close();
  }

  /// OIP-TRANSPORT-001 §8 — this transport does not implement network
  /// discovery (e.g. mDNS/UDP broadcast) yet; [deviceId] passed to
  /// [connect] is expected to be a `'host:port'` string a user enters
  /// manually (matching this Work Package's own disclosed scope — see
  /// this package's README). [discover] therefore yields nothing; it
  /// exists to satisfy [OipTransport]'s contract, not as a functioning
  /// discovery mechanism.
  @override
  Stream<String> discover() => const Stream.empty();

  /// Connects to `deviceId` formatted as `'host:port'` (e.g.
  /// `'192.168.1.42:9411'`).
  @override
  Future<void> connect(String deviceId) async {
    final parts = deviceId.split(':');
    if (parts.length != 2) {
      throw ArgumentError('WifiOipTransport.connect expects "host:port", got "$deviceId".');
    }
    final host = parts[0];
    final port = int.parse(parts[1]);

    _state = TransportConnectionState.connecting;
    _socket = await Socket.connect(host, port);
    _state = TransportConnectionState.connected;

    _socketSubscription = _socket!.listen(
      _onData,
      onDone: () => _state = TransportConnectionState.disconnected,
      onError: (Object _) => _state = TransportConnectionState.disconnected,
      cancelOnError: false,
    );
  }

  void _onData(List<int> chunk) {
    _receiveBuffer.write(utf8.decode(chunk));
    var text = _receiveBuffer.toString();
    var newlineIndex = text.indexOf('\n');
    while (newlineIndex != -1) {
      final line = text.substring(0, newlineIndex);
      if (line.isNotEmpty) {
        final decoded = jsonDecode(line) as Map<String, Object?>;
        _incoming.add(OipMessage.fromJson(decoded));
      }
      text = text.substring(newlineIndex + 1);
      newlineIndex = text.indexOf('\n');
    }
    _receiveBuffer
      ..clear()
      ..write(text);
  }

  @override
  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _state = TransportConnectionState.disconnected;
  }

  @override
  Future<void> reconnect() async {
    // Deliberately not automatic (§16's "Attempt reconnection" is a
    // Runtime-level policy decision, not this transport's own job per
    // OIP-TRANSPORT-001 §5: "Responsibilities Not Owned... these belong
    // to higher layers") -- this method exists so the Runtime CAN
    // trigger one, using whatever address it last connected with.
    final socket = _socket;
    if (socket == null) {
      throw StateError('WifiOipTransport.reconnect: no prior connection to reconnect to.');
    }
    final deviceId = '${socket.remoteAddress.address}:${socket.remotePort}';
    await disconnect();
    await connect(deviceId);
  }

  @override
  Future<void> send(OipMessage message) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('WifiOipTransport.send: not connected.');
    }
    socket.write('${jsonEncode(message.toJson())}\n');
  }

  @override
  Stream<OipMessage> receive() => _incoming.stream;

  @override
  Future<void> flush() async {
    await _socket?.flush();
  }

  @override
  TransportDiagnostics status() => const TransportDiagnostics();
}
