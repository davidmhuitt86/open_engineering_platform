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
  final StreamController<TransportConnectionState> _stateChanges = StreamController<TransportConnectionState>.broadcast();
  StreamSubscription<List<int>>? _socketSubscription;
  final StringBuffer _receiveBuffer = StringBuffer();

  /// PRODUCT-READINESS-007 §20 — automatic, bounded-backoff reconnect.
  /// `'host:port'` from the most recent [connect] call, so a later,
  /// unexpected drop knows what to reconnect to. `null` before the first
  /// successful [connect].
  String? _lastDeviceId;

  /// True only when [disconnect] was called directly by the caller (never
  /// set by a socket-level `onDone`/`onError`) — distinguishes "the user/
  /// Runtime asked to disconnect" (no reconnect attempted) from "the
  /// connection dropped out from under us" (reconnect attempted). Reset
  /// to `false` on every successful [connect].
  bool _manualDisconnect = false;

  /// Guards against ever running more than one reconnect loop at once
  /// (§20 "do not create multiple simultaneous reconnect loops") — e.g. a
  /// second `onDone`/`onError` firing while a reconnect attempt from the
  /// first is still in flight.
  bool _reconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// §20 "bounded retry/backoff" — doubles each attempt, capped at 16s,
  /// so a genuinely offline Host is retried steadily without hammering
  /// the network. Attempts themselves are unbounded in COUNT (a real DMM
  /// session should keep trying for as long as it's plugged in / the app
  /// is open) but always bounded in RATE.
  static const List<Duration> _backoffSchedule = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  @override
  TransportConnectionState get state => _state;

  /// Observable connection-state transitions (including the new
  /// [TransportConnectionState.reconnecting] state this phase starts
  /// actually using) — a UI can subscribe to show live connection status
  /// rather than polling [state].
  Stream<TransportConnectionState> get stateChanges => _stateChanges.stream;

  void _setState(TransportConnectionState next) {
    if (_state == next) return;
    _state = next;
    _stateChanges.add(next);
  }

  @override
  Future<void> initialize() async {
    _setState(TransportConnectionState.disconnected);
  }

  @override
  Future<void> shutdown() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await disconnect();
    await _incoming.close();
    await _stateChanges.close();
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

    _setState(TransportConnectionState.connecting);
    _socket = await Socket.connect(host, port);
    _lastDeviceId = deviceId;
    _manualDisconnect = false;
    _reconnectAttempt = 0;
    _setState(TransportConnectionState.connected);

    _socketSubscription = _socket!.listen(
      _onData,
      onDone: _handleUnexpectedDisconnect,
      onError: (Object _) => _handleUnexpectedDisconnect(),
      cancelOnError: false,
    );
  }

  /// §20 — a socket-level drop (server closed it, Wi-Fi dropped, ...),
  /// distinct from a caller-initiated [disconnect]. Transitions to
  /// [TransportConnectionState.disconnected] immediately (so a UI/caller
  /// sees the real state right away) and, unless the caller asked to
  /// disconnect on purpose, schedules a bounded-backoff reconnect attempt
  /// — see [_scheduleReconnect] for why this never stacks more than one
  /// reconnect loop.
  void _handleUnexpectedDisconnect() {
    _closeSocketResources();
    _setState(TransportConnectionState.disconnected);
    if (!_manualDisconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnecting) return; // §20 — never more than one reconnect loop at once.
    final deviceId = _lastDeviceId;
    if (deviceId == null) return; // Never successfully connected — nothing to reconnect to.
    _reconnecting = true;
    final delay = _backoffSchedule[_reconnectAttempt.clamp(0, _backoffSchedule.length - 1)];
    _reconnectAttempt++;
    _setState(TransportConnectionState.reconnecting);
    _reconnectTimer = Timer(delay, () async {
      _reconnecting = false;
      if (_manualDisconnect) return; // Disconnected on purpose while the backoff timer was pending.
      try {
        await connect(deviceId);
        // §20 "do not duplicate requests" — reconnecting only restores the
        // ABILITY to send/receive; it never replays anything that was
        // in flight when the drop happened (there is nothing buffered to
        // replay in the first place — `send` writes straight to the
        // socket with no outbound queue).
      } catch (_) {
        // Still unreachable — try again, respecting the same bounded
        // backoff schedule (capped, never a tight retry loop).
        _setState(TransportConnectionState.disconnected);
        if (!_manualDisconnect) _scheduleReconnect();
      }
    });
  }

  void _closeSocketResources() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
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

  /// Caller-initiated disconnect (§20) — sets [_manualDisconnect] so no
  /// automatic reconnect is attempted afterward, cancels any reconnect
  /// backoff already pending, and closes the socket cleanly (a graceful
  /// `close()`, not the abrupt `destroy()` an already-broken socket gets
  /// in [_closeSocketResources]).
  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = false;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _setState(TransportConnectionState.disconnected);
  }

  /// A manually-triggered reconnect using whatever address was last
  /// connected to — still available for a caller that wants to force one
  /// immediately rather than waiting for the automatic backoff schedule
  /// (§20's own automatic reconnect, above, is now this transport's
  /// default behavior on an unexpected drop; this method remains for an
  /// explicit, caller-initiated retry, e.g. a "Reconnect now" UI action).
  @override
  Future<void> reconnect() async {
    final deviceId = _lastDeviceId ?? (_socket == null ? null : '${_socket!.remoteAddress.address}:${_socket!.remotePort}');
    if (deviceId == null) {
      throw StateError('WifiOipTransport.reconnect: no prior connection to reconnect to.');
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = false;
    _manualDisconnect = false;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
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
