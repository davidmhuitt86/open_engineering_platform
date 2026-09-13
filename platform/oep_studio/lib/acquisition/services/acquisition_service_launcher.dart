import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/acquisition_connection_status.dart';
import '../settings/acquisition_settings_provider.dart';
import 'acquisition_runtime_service.dart';
import 'acquisition_service_launcher_state.dart';

/// WP-EAM-LOCAL-SERVICE-001 — a local development convenience only.
/// Studio's architecture remains `Studio -> HTTP -> EAM Service`
/// (`docs/CONNECTION_MANAGER.md`'s own boundary for Foundation, mirrored
/// here for Acquisition); this class does not embed, reimplement, or
/// duplicate the EAM backend -- it starts the exact same
/// `oep_acquisition.exe` a developer would otherwise start by hand
/// (`services/acquisition/run_server.bat`'s own command, corrected for
/// this checkout's actual layout and Debug/multi-config build output
/// path) as a child process, and talks to it only through the existing
/// `AcquisitionApiClient`/`GET /health` path -- never a second API.
///
/// Injectable seams ([ProcessStarter], [LaunchPlanResolver],
/// [PortReachabilityCheck]) keep the actual OS process/socket calls out
/// of the notifier's own control-flow logic, so
/// `test/acquisition_service_launcher_test.dart` can exercise every
/// status transition (including a startup failure and an occupied port)
/// without ever spawning a real process -- per this WP's own instruction
/// not to make the suite depend on a real, permanently running local
/// server. `acquisition_service_launcher_real_process_test.dart` (a
/// separate, honestly-skippable file) additionally proves the real,
/// default resolver/starter against the real `oep_acquisition.exe` this
/// checkout already has built.

/// One resolved, ready-to-spawn command for the local EAM backend.
class AcquisitionLaunchPlan {
  const AcquisitionLaunchPlan({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;

  /// Merged into the *inherited* process environment by [ProcessStarter]
  /// (a `PATH` prepend for `libpq.dll`/OpenSSL, mirroring
  /// `run_server.bat`'s own `set PATH=...` line) -- never a replacement
  /// of it.
  final Map<String, String> environment;
}

typedef ProcessStarter = Future<Process> Function(AcquisitionLaunchPlan plan);

typedef LaunchPlanResolver = AcquisitionLaunchPlan? Function();

typedef PortReachabilityCheck = Future<bool> Function(String host, int port);

/// True iff [apiBaseUrl]'s host is a loopback address -- the local
/// launcher must never attempt to start a process for a remote address
/// (WP-EAM-LOCAL-SERVICE-001 AC-10; "the remote service should be
/// treated as externally managed").
bool isLocalServiceAddress(String apiBaseUrl) {
  final host = Uri.tryParse(apiBaseUrl)?.host.toLowerCase();
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

/// Walks upward from both the current working directory and the
/// running executable's own directory (whichever exists first) looking
/// for `services/acquisition/config/config.toml` -- the one file that
/// unambiguously identifies this repository's own checkout layout,
/// avoiding a hardcoded assumption about where Studio happens to be
/// launched from (`flutter test`/`flutter run` use the package root as
/// CWD; the built `.exe` may be launched from
/// `build/windows/x64/runner/Debug/` or anywhere else).
Directory? _findAcquisitionServiceDirectory() {
  final candidates = <Directory>[Directory.current, File(Platform.resolvedExecutable).parent];
  for (final start in candidates) {
    var dir = start;
    for (var i = 0; i < 8; i++) {
      final marker = File('${dir.path}${Platform.pathSeparator}services${Platform.pathSeparator}acquisition'
          '${Platform.pathSeparator}config${Platform.pathSeparator}config.toml');
      if (marker.existsSync()) {
        return Directory('${dir.path}${Platform.pathSeparator}services${Platform.pathSeparator}acquisition');
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  return null;
}

/// Scans `C:\Program Files\PostgreSQL\*\bin` for `libpq.dll` (the
/// dynamic library `oep_acquisition.exe` needs on `PATH` at runtime --
/// confirmed absent from its own build output directory) and returns
/// the highest-numbered version's `bin` directory found, or `null` if
/// none is installed at the conventional location (`run_server.bat`'s
/// own, only documented convention).
String? _findPostgresBinDirectory() {
  final root = Directory(r'C:\Program Files\PostgreSQL');
  if (!root.existsSync()) return null;
  final versions = root
      .listSync()
      .whereType<Directory>()
      .where((dir) => File('${dir.path}${Platform.pathSeparator}bin${Platform.pathSeparator}libpq.dll').existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (versions.isEmpty) return null;
  return '${versions.last.path}${Platform.pathSeparator}bin';
}

String? _findOpenSslBinDirectory() {
  const dir = r'C:\Program Files\OpenSSL-Win64\bin';
  return Directory(dir).existsSync() ? dir : null;
}

/// The default [LaunchPlanResolver]: the real
/// `services/acquisition/build/src/app/Debug/oep_acquisition.exe`, run
/// with CWD = `services/acquisition` (so its own default
/// `config/config.toml` argument, and that file's own
/// `./data/vault`/`./data/workspace` relative paths, resolve correctly
/// -- `main.cpp`'s own documented convention), `PATH` prepended with
/// PostgreSQL's and OpenSSL's `bin` directories if found (mirroring
/// `run_server.bat`, corrected for this checkout's real location and
/// Debug/multi-config build output path -- that script's own hardcoded
/// `cd /d C:\dev\platform\oep_acquisition` predates this repository's
/// current layout and is not reused literally). Returns `null` if this
/// checkout's `services/acquisition` cannot be located at all (e.g. a
/// packaged/installed Studio build with no sibling source checkout) --
/// [AcquisitionServiceLauncherNotifier.start] reports that as a clear
/// error rather than throwing.
AcquisitionLaunchPlan? defaultAcquisitionLaunchPlanResolver() {
  final serviceDir = _findAcquisitionServiceDirectory();
  if (serviceDir == null) return null;

  final executable =
      '${serviceDir.path}${Platform.pathSeparator}build${Platform.pathSeparator}src${Platform.pathSeparator}app'
      '${Platform.pathSeparator}Debug${Platform.pathSeparator}oep_acquisition.exe';
  if (!File(executable).existsSync()) return null;

  // `;` is the Windows PATH entry separator -- distinct from
  // `Platform.pathSeparator` (`\`, the directory separator).
  const pathEntrySeparator = ';';
  final pathPrefixes = [_findPostgresBinDirectory(), _findOpenSslBinDirectory()].whereType<String>().toList();
  final environment = <String, String>{
    if (pathPrefixes.isNotEmpty)
      'PATH': '${pathPrefixes.join(pathEntrySeparator)}$pathEntrySeparator${Platform.environment['PATH'] ?? ''}',
  };

  return AcquisitionLaunchPlan(
    executable: executable,
    arguments: ['config${Platform.pathSeparator}config.toml'],
    workingDirectory: serviceDir.path,
    environment: environment,
  );
}

Future<bool> _defaultPortReachable(String host, int port) async {
  try {
    final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 500));
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}

Future<Process> _defaultProcessStarter(AcquisitionLaunchPlan plan) => Process.start(
      plan.executable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      environment: plan.environment,
      includeParentEnvironment: true,
    );

/// The local EAM service launcher (WP-EAM-LOCAL-SERVICE-001) -- Settings'
/// own convenience for starting/stopping the exact, unmodified EAM
/// backend `oep_acquisition.exe` during local development. Never a
/// second backend, never a second API: [start] spawns the real
/// executable and then defers entirely to the existing
/// [AcquisitionRuntimeNotifier.testConnection]/`GET /health` path to
/// confirm it came up; [stop] only ever terminates the process *this*
/// notifier itself spawned, never an unrelated one already occupying the
/// configured port (WP-EAM-LOCAL-SERVICE-001 AC-09).
class AcquisitionServiceLauncherNotifier extends Notifier<AcquisitionServiceLauncherState> {
  AcquisitionServiceLauncherNotifier({
    ProcessStarter? processStarter,
    LaunchPlanResolver? launchPlanResolver,
    PortReachabilityCheck? portReachable,
  })  : _processStarter = processStarter ?? _defaultProcessStarter,
        _launchPlanResolver = launchPlanResolver ?? defaultAcquisitionLaunchPlanResolver,
        _portReachable = portReachable ?? _defaultPortReachable;

  final ProcessStarter _processStarter;
  final LaunchPlanResolver _launchPlanResolver;
  final PortReachabilityCheck _portReachable;

  Process? _process;

  @override
  AcquisitionServiceLauncherState build() {
    ref.onDispose(() {
      // Best-effort only -- this notifier's own dispose is not a
      // guaranteed graceful-shutdown point (e.g. a forcibly killed
      // Studio process never runs it at all), so `stop()`'s own
      // `errorMessage`/state updates are meaningless here; only the OS
      // signal matters.
      _process?.kill();
    });
    return const AcquisitionServiceLauncherState();
  }

  /// Starts the real local EAM backend, if [apiBaseUrl] is a local
  /// address and nothing else already occupies its port. No-op if a
  /// start/stop is already in flight state (`starting`/`running`).
  Future<void> start() async {
    if (state.status == AcquisitionServiceLauncherStatus.starting ||
        state.status == AcquisitionServiceLauncherStatus.running) {
      return;
    }

    final apiBaseUrl = ref.read(acquisitionSettingsProvider).apiBaseUrl;
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !isLocalServiceAddress(apiBaseUrl)) {
      // The widget layer itself hides the Start button for a remote
      // address (AC-10); this guard only protects a direct programmatic
      // call (e.g. a test) from doing the wrong thing silently.
      state = state.copyWith(
        status: AcquisitionServiceLauncherStatus.error,
        errorMessage: 'Only a local service address can be started locally.',
      );
      return;
    }
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 80;

    if (await _portReachable(host, port)) {
      state = state.copyWith(
        status: AcquisitionServiceLauncherStatus.error,
        errorMessage: 'Port $port is already in use.',
      );
      // WP-EAM-LOCAL-SERVICE-001: "attempt the existing Test Connection
      // behavior" -- whatever already holds the port might in fact be a
      // healthy EAM instance a developer started another way.
      await ref.read(acquisitionRuntimeServiceProvider.notifier).testConnection();
      return;
    }

    final plan = _launchPlanResolver();
    if (plan == null) {
      state = state.copyWith(
        status: AcquisitionServiceLauncherStatus.error,
        errorMessage: 'Unable to start EAM service.',
      );
      return;
    }

    state = state.copyWith(status: AcquisitionServiceLauncherStatus.starting, clearErrorMessage: true);

    final Process process;
    try {
      process = await _processStarter(plan);
    } catch (_) {
      state = state.copyWith(
        status: AcquisitionServiceLauncherStatus.error,
        errorMessage: 'Unable to start EAM service.',
      );
      return;
    }
    _process = process;
    // The child process's own stdout/stderr pipes MUST be drained: on
    // Windows, an unread pipe fills its OS buffer once the process logs
    // enough at startup, which blocks the child process itself (not
    // just the log) until something reads from the pipe -- confirmed
    // directly against the real `oep_acquisition.exe` in this WP's own
    // testing, where an undrained pipe made the real backend appear to
    // "hang" and never become reachable. Kept only as a short rolling
    // diagnostic buffer, never printed/logged as the primary UI message.
    final recentOutput = _RecentOutputBuffer();
    process.stdout.transform(const SystemEncoding().decoder).listen(recentOutput.add);
    process.stderr.transform(const SystemEncoding().decoder).listen(recentOutput.add);

    final becameReachable = await _pollUntilReachable(process, host, port);
    if (!becameReachable) {
      state = state.copyWith(
        status: AcquisitionServiceLauncherStatus.error,
        errorMessage: 'EAM service started but did not become reachable.',
        technicalDetail: recentOutput.toString(),
      );
      return;
    }

    state = state.copyWith(status: AcquisitionServiceLauncherStatus.running, clearErrorMessage: true);
  }

  /// Polls [AcquisitionRuntimeNotifier.testConnection] (the existing
  /// `GET /health` path -- no new endpoint) until it reports connected,
  /// [process] exits on its own (a real startup failure, e.g. a missing
  /// required backend dependency), or a bounded number of attempts is
  /// exhausted.
  Future<bool> _pollUntilReachable(Process process, String host, int port, {int maxAttempts = 20}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (await _portReachable(host, port)) {
        await ref.read(acquisitionRuntimeServiceProvider.notifier).testConnection();
        final connected =
            ref.read(acquisitionRuntimeServiceProvider).connectionStatus == AcquisitionConnectionStatus.connected;
        if (connected) return true;
      }
      final exited = await Future.any([
        process.exitCode.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 250), () => false),
      ]);
      if (exited) return false;
    }
    return false;
  }

  /// Stops the process *this* notifier started. A no-op if nothing was
  /// started here (e.g. the configured port turned out to already be
  /// occupied by something else, or the service is remote) --
  /// WP-EAM-LOCAL-SERVICE-001 AC-09: never touches a process this
  /// launcher did not itself spawn.
  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      state = state.copyWith(status: AcquisitionServiceLauncherStatus.stopped, clearErrorMessage: true);
      return;
    }
    process.kill();
    await process.exitCode;
    _process = null;
    state = state.copyWith(status: AcquisitionServiceLauncherStatus.stopped, clearErrorMessage: true);
  }

  Future<void> restart() async {
    await stop();
    await start();
  }
}

final acquisitionServiceLauncherProvider =
    NotifierProvider<AcquisitionServiceLauncherNotifier, AcquisitionServiceLauncherState>(
  AcquisitionServiceLauncherNotifier.new,
);

/// Keeps only the last few lines of a spawned process's combined
/// stdout/stderr -- enough to diagnose a startup failure, never the
/// primary user-facing message.
class _RecentOutputBuffer {
  final _lines = <String>[];
  static const _maxLines = 20;

  void add(String chunk) {
    _lines.addAll(chunk.split('\n').where((line) => line.trim().isNotEmpty));
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
  }

  @override
  String toString() => _lines.join('\n');
}
