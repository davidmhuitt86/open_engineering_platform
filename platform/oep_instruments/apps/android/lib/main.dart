import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oep_instruments_runtime/oep_instruments_runtime.dart';

/// The OEP Digital Multimeter Android app (OIP-ANDROID-001) — a thin
/// presentation shell hosting [DigitalMultimeterPlugin]. Per this
/// document's own Constitution, no engineering computation happens
/// here: every measurement is requested from, and answered by, a
/// connected OEP Host (Diagram Studio) over a real [WifiOipTransport]
/// connection (§4/§5).
void main() {
  runApp(const OepDmmApp());
}

class OepDmmApp extends StatelessWidget {
  const OepDmmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OEP Digital Multimeter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF06070A),
      ),
      home: const ConnectScreen(),
    );
  }
}

/// OIP-ANDROID-001 §7 — the app's Home/Workspace Selector: connect to a
/// Host, then open the Digital Multimeter instrument. Per §7, no
/// instrument opens automatically -- the user explicitly navigates to
/// it once connected.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _addressController = TextEditingController(text: '192.168.1.');
  final _portController = TextEditingController(text: '9411');
  bool _connecting = false;
  String? _error;

  // No `_transport` field: [DigitalMultimeterPlugin.shutdown] already
  // disconnects whatever transport was bound via `connectTransport`
  // (see its own implementation), so keeping a second reference here
  // just to close it in `dispose` would be a redundant, drift-prone
  // duplicate of state the plugin already owns.
  DigitalMultimeterPlugin? _plugin;

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    unawaited(_plugin?.shutdown());
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    final host = _addressController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null) {
      setState(() {
        _connecting = false;
        _error = 'Enter a valid host and port.';
      });
      return;
    }

    try {
      final transport = WifiOipTransport(transportId: 'android-dmm-client');
      await transport.initialize();
      await transport.connect('$host:$port');

      final session = EngineeringSession(
        id: 'android-${DateTime.now().millisecondsSinceEpoch}',
        hostId: host,
        owner: 'oep_dmm_android',
      );
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(PluginContext(hostId: host, session: session));
      plugin.connectTransport(transport);

      _plugin = plugin;

      if (!mounted) return;
      setState(() => _connecting = false);
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => DigitalMultimeterScreen(plugin: plugin)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Couldn\'t connect: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OEP',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 3),
                  ),
                  const Text(
                    'DIGITAL MULTIMETER',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9AA5B1), fontSize: 12, letterSpacing: 2),
                  ),
                  const SizedBox(height: 32),
                  const Text('Connect to Open Engineering Platform', style: TextStyle(color: Color(0xFFE6E9EE), fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Host IP address'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _connecting ? null : _connect,
                    child: _connecting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Connect'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Wi-Fi connection only in this release. USB support is planned '
                    'but not yet available on any device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5B6572), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hosts the real [DigitalMultimeterPlugin.render] full-screen — this
/// screen itself contains no instrument logic, matching OIP-PLUGIN-001
/// §11 ("Each Plugin owns its own UI... No Runtime modifications
/// required").
class DigitalMultimeterScreen extends StatelessWidget {
  const DigitalMultimeterScreen({super.key, required this.plugin});

  final DigitalMultimeterPlugin plugin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Builder(builder: plugin.render),
        ),
      ),
    );
  }
}
