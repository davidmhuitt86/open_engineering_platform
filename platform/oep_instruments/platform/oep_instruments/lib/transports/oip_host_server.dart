import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/oip_message.dart';

/// One connected client's own send/receive channel, handed out by
/// [OipHostServer.connections] as each client connects. Mirrors
/// [WifiOipTransport]'s client-side framing (newline-delimited JSON)
/// exactly, so a [WifiOipTransport] client and this server interoperate.
class OipHostConnection {
  OipHostConnection._(this._socket, this.remoteAddress)
      : messages = _decodeMessages(_socket);

  final Socket _socket;
  final String remoteAddress;
  final Stream<OipMessage> messages;

  void send(OipMessage message) => _socket.write('${jsonEncode(message.toJson())}\n');

  Future<void> close() => _socket.close();

  static Stream<OipMessage> _decodeMessages(Socket socket) {
    final controller = StreamController<OipMessage>.broadcast();
    final buffer = StringBuffer();
    socket.listen(
      (chunk) {
        buffer.write(utf8.decode(chunk));
        var text = buffer.toString();
        var newlineIndex = text.indexOf('\n');
        while (newlineIndex != -1) {
          final line = text.substring(0, newlineIndex);
          if (line.isNotEmpty) {
            controller.add(OipMessage.fromJson(jsonDecode(line) as Map<String, Object?>));
          }
          text = text.substring(newlineIndex + 1);
          newlineIndex = text.indexOf('\n');
        }
        buffer
          ..clear()
          ..write(text);
      },
      onDone: () => controller.close(),
      onError: controller.addError,
      cancelOnError: false,
    );
    return controller.stream;
  }
}

/// OIP-API-001 / OIP-TRANSPORT-001 §7 — the Host side of the Wi-Fi (LAN)
/// transport: a plain TCP listener a Host (Diagram Studio) runs so
/// Instrument Clients (the Android DMM app, or any other future OIP
/// client) can connect to it. This class is pure transport/framing — it
/// has no knowledge of engineering data or the OIP message categories
/// it carries (Constitution §6: the Host API layer above this, not the
/// transport, computes/exposes engineering values).
///
/// One [OipHostServer] instance accepts many simultaneous client
/// connections (OIP-SESSION-001 §23's multi-client example), each
/// surfaced as its own [OipHostConnection] on the [connections] stream.
class OipHostServer {
  OipHostServer._(this._serverSocket);

  final ServerSocket _serverSocket;
  final StreamController<OipHostConnection> _connections = StreamController<OipHostConnection>.broadcast();

  int get port => _serverSocket.port;

  /// Fires once per newly-accepted client connection. The Host
  /// (oep_studio's own bridging service) listens here to bind each new
  /// [OipHostConnection] to a Session/Host API handler.
  Stream<OipHostConnection> get connections => _connections.stream;

  static Future<OipHostServer> bind({String address = '0.0.0.0', int port = 9411}) async {
    final serverSocket = await ServerSocket.bind(address, port);
    final server = OipHostServer._(serverSocket);
    serverSocket.listen((socket) {
      server._connections.add(OipHostConnection._(socket, '${socket.remoteAddress.address}:${socket.remotePort}'));
    });
    return server;
  }

  Future<void> close() async {
    await _serverSocket.close();
    await _connections.close();
  }
}
