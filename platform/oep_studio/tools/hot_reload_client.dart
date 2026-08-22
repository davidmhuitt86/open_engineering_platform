import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal Dart VM Service JSON-RPC client for driving genuine Flutter
/// hot reload against an already-running `flutter run --debug` session,
/// without an interactive terminal. Pure `dart:io`/`dart:convert` — no
/// external packages, since the VM Service protocol is plain JSON-RPC
/// 2.0 over a WebSocket and `dart:io` already has both `WebSocket` and
/// `jsonEncode`/`jsonDecode`.
///
/// Invoked by `flutter_hot_reload.ps1`; not meant to be run directly in
/// normal use, but works standalone:
///
///   dart run tools/hot_reload_client.dart <ws-vm-service-uri> <status|reload>
///
/// `reload` performs, in order:
///   1. `getVM` — discover the running isolate(s).
///   2. `reloadSources` — the actual Dart hot-reload RPC: recompiles and
///      injects changed source into the running VM.
///   3. `ext.flutter.reassemble` — the Flutter framework's own service
///      extension that rebuilds the widget tree after a reload lands
///      (without this, changed code is loaded but not necessarily
///      reflected on screen).
///
/// Exit code 0 and a line starting with `SUCCESS:` means a genuine
/// reload occurred. Any other outcome prints a line starting with
/// `FAILED:` to stderr and exits non-zero — this script never reports
/// success just because the process is still alive.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run hot_reload_client.dart <ws-vm-service-uri> <status|reload>');
    exit(2);
  }
  final wsUri = args[0];
  final command = args[1];

  final WebSocket socket;
  try {
    socket = await WebSocket.connect(wsUri).timeout(const Duration(seconds: 10));
  } catch (e) {
    stderr.writeln('FAILED: could not connect to VM Service at $wsUri: $e');
    exit(1);
  }

  var nextId = 1;
  final responseController = StreamController<Map<String, dynamic>>.broadcast();
  socket.listen(
    (data) {
      try {
        final decoded = jsonDecode(data as String) as Map<String, dynamic>;
        responseController.add(decoded);
      } catch (_) {
        // Non-JSON-RPC frame (shouldn't happen on this endpoint) — ignore.
      }
    },
    onError: (Object e) => responseController.addError(e),
  );

  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic>? params]) async {
    final id = (nextId++).toString();
    final future = responseController.stream.firstWhere((m) => m['id'] == id).timeout(const Duration(seconds: 30));
    socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    return future;
  }

  var exitCode = 0;
  try {
    final vmResponse = await call('getVM');
    final vm = vmResponse['result'] as Map<String, dynamic>?;
    if (vm == null) {
      stderr.writeln('FAILED: getVM did not return a result: ${jsonEncode(vmResponse)}');
      exit(1);
    }
    final isolates = (vm['isolates'] as List).cast<Map<String, dynamic>>();
    if (isolates.isEmpty) {
      stderr.writeln('FAILED: getVM returned no isolates');
      exit(1);
    }
    final isolateId = isolates.first['id'] as String;

    if (command == 'status') {
      print('SUCCESS: connected to VM Service, isolate=$isolateId');
      return;
    }

    if (command != 'reload') {
      stderr.writeln('FAILED: unknown command "$command"');
      exit(2);
    }

    final reloadResponse = await call('reloadSources', {
      'isolateId': isolateId,
      // Normally supplied automatically by `flutter_tool`'s own
      // incremental-compiler orchestration (which is what actually
      // drives hot reload behind the interactive `r` key) -- without
      // these, the target isolate's Kernel/CFE compiler tries to
      // resolve `package:`/root URIs on its own and, on a Windows
      // desktop debug build, fails with "Error while starting Kernel
      // isolate task".
      'rootLibUri': 'package:oep_studio/main.dart',
      'packagesUri': 'package_config.json',
    });
    if (reloadResponse.containsKey('error')) {
      stderr.writeln('FAILED: reloadSources returned an error: ${jsonEncode(reloadResponse['error'])}');
      exit(1);
    }
    final reloadResult = reloadResponse['result'] as Map<String, dynamic>?;
    final success = reloadResult?['success'] as bool? ?? false;
    if (!success) {
      stderr.writeln('FAILED: reloadSources reported failure: ${jsonEncode(reloadResult)}');
      exit(1);
    }

    // Reassemble the widget tree so the reload is actually reflected on
    // screen. Treated as a warning, not fatal, if it errors — the
    // source reload itself (the part that matters for "is this a
    // genuine hot reload") already succeeded above.
    try {
      final reassembleResponse = await call('ext.flutter.reassemble', {'isolateId': isolateId});
      if (reassembleResponse.containsKey('error')) {
        stderr.writeln('WARNING: ext.flutter.reassemble returned an error (source reload itself still succeeded): ${jsonEncode(reassembleResponse['error'])}');
      }
    } catch (e) {
      stderr.writeln('WARNING: ext.flutter.reassemble call failed (source reload itself still succeeded): $e');
    }

    print('SUCCESS: hot reload applied (isolate=$isolateId)');
  } catch (e) {
    stderr.writeln('FAILED: $e');
    exitCode = 1;
  } finally {
    await responseController.close();
    await socket.close();
  }
  exit(exitCode);
}
