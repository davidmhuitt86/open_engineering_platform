import 'dart:async';

import '../protocol/oip_message.dart';
import 'oip_transport.dart';
import 'transport_state.dart';

/// OIP-TRANSPORT-001 §7 — the USB transport.
///
/// **Disclosed status: interface-only, not implemented.** Genuine
/// bidirectional USB communication between a Windows PC (Host) and an
/// Android phone (Client) is not achievable in pure Dart: Android
/// enumerates as a USB *device* to a PC by default (how ADB/MTP work),
/// so custom app-level USB communication requires the **Android Open
/// Accessory (AOA)** protocol — native Android code (`UsbManager`/
/// `UsbAccessory` APIs, via a platform channel) on the phone side, and
/// native Windows code (WinUSB or libusb, also via a platform channel or
/// FFI) on the PC side to put the connection into accessory mode and
/// exchange bytes over its bulk endpoints. Building that requires real
/// USB hardware to test against — this environment has none — so, per
/// this Work Package's own explicit scope decision, USB is stubbed here
/// rather than built untested: every method throws
/// [UnimplementedError] with a message pointing at this doc comment.
///
/// [WifiOipTransport] is the real, working, tested first transport.
/// This class exists so the [OipTransport] interface has a named USB
/// implementation slot ready — swapping it for a real one later (once
/// real hardware is available to build and test against) requires no
/// change to [InstrumentPlugin], [PluginManager], the Host bridge, or
/// any UI: everything above this layer only depends on the
/// [OipTransport] interface, never on which concrete transport is in
/// use (Constitution §10: "Transport Independence... Future transports
/// shall require no protocol redesign.").
class UsbOipTransport implements OipTransport {
  UsbOipTransport({required this.transportId});

  @override
  final String transportId;

  @override
  TransportConnectionState get state => TransportConnectionState.disconnected;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Stream<String> discover() => Stream.error(_notImplemented());

  @override
  Future<void> connect(String deviceId) => Future.error(_notImplemented());

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect() => Future.error(_notImplemented());

  @override
  Future<void> send(OipMessage message) => Future.error(_notImplemented());

  @override
  Stream<OipMessage> receive() => Stream.error(_notImplemented());

  @override
  Future<void> flush() async {}

  @override
  TransportDiagnostics status() => const TransportDiagnostics();

  UnimplementedError _notImplemented() => UnimplementedError(
        'UsbOipTransport is not implemented — see this class\'s own doc comment. '
        'It requires native Android Open Accessory + Windows WinUSB/libusb code, '
        'and real USB hardware to build and verify against. Use WifiOipTransport instead.',
      );
}
