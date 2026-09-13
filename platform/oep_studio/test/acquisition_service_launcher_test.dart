import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/models/acquisition_connection_status.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/services/acquisition_service_launcher.dart';
import 'package:oep_studio/acquisition/services/acquisition_service_launcher_state.dart';
import 'package:oep_studio/acquisition/settings/acquisition_settings.dart';
import 'package:oep_studio/acquisition/settings/acquisition_settings_provider.dart';

/// WP-EAM-LOCAL-SERVICE-001's own unit tests: every status transition
/// exercised with injected fakes ([ProcessStarter], [LaunchPlanResolver],
/// [PortReachabilityCheck], and a fake `acquisitionRuntimeServiceProvider`
/// standing in for the real `GET /health` round-trip) -- never a real
/// spawned process or a real socket, per this WP's own instruction not
/// to make the suite depend on a real, permanently running local server.
/// `acquisition_service_launcher_real_process_test.dart` separately
/// proves the real, default resolver/starter against the real,
/// already-built `oep_acquisition.exe`.
void main() {
  AcquisitionLaunchPlan fakePlan() => const AcquisitionLaunchPlan(
        executable: 'fake_oep_acquisition.exe',
        arguments: ['config/config.toml'],
        workingDirectory: 'fake_dir',
        environment: {},
      );

  ProviderContainer buildContainer({
    required ProcessStarter processStarter,
    LaunchPlanResolver? launchPlanResolver,
    PortReachabilityCheck? portReachable,
    required _FakeAcquisitionRuntimeNotifier Function() fakeRuntime,
    String apiBaseUrl = 'http://127.0.0.1:8080',
  }) {
    return ProviderContainer(
      overrides: [
        acquisitionSettingsProvider.overrideWith(() => _FixedAcquisitionSettingsNotifier(apiBaseUrl)),
        acquisitionRuntimeServiceProvider.overrideWith(fakeRuntime),
        acquisitionServiceLauncherProvider.overrideWith(
          () => AcquisitionServiceLauncherNotifier(
            processStarter: processStarter,
            launchPlanResolver: launchPlanResolver ?? fakePlan,
            portReachable: portReachable ?? (host, port) async => false,
          ),
        ),
      ],
    );
  }

  test('1. initial state is stopped', () {
    final container = buildContainer(
      processStarter: (plan) async => throw StateError('should not be called'),
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: false),
    );
    addTearDown(container.dispose);

    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.stopped);
  });

  test('2/3/4. a start request that becomes reachable ends in the running state', () async {
    final fakeProcess = _FakeProcess();
    var startCalls = 0;
    final container = buildContainer(
      processStarter: (plan) async {
        startCalls++;
        return fakeProcess;
      },
      portReachable: (host, port) async => startCalls > 0, // "occupied" only after our own process starts
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: true),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    expect(startCalls, 1);
    final state = container.read(acquisitionServiceLauncherProvider);
    expect(state.status, AcquisitionServiceLauncherStatus.running);
    expect(state.errorMessage, isNull);
  });

  test('5. a stop request kills the process this launcher started and returns to stopped', () async {
    final fakeProcess = _FakeProcess();
    var startCalls = 0;
    final container = buildContainer(
      processStarter: (plan) async {
        startCalls++;
        return fakeProcess;
      },
      portReachable: (host, port) async => startCalls > 0,
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: true),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();
    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.running);

    await container.read(acquisitionServiceLauncherProvider.notifier).stop();

    expect(fakeProcess.killed, isTrue);
    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.stopped);
  });

  test('6. a startup failure (process never becomes reachable) is reported as an error', () async {
    final fakeProcess = _FakeProcess();
    final container = buildContainer(
      processStarter: (plan) async => fakeProcess,
      portReachable: (host, port) async => false, // never comes up
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: false),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    final state = container.read(acquisitionServiceLauncherProvider);
    expect(state.status, AcquisitionServiceLauncherStatus.error);
    expect(state.errorMessage, 'EAM service started but did not become reachable.');
  });

  test('6b. a process that exits immediately is reported as a startup failure, not left running', () async {
    final fakeProcess = _FakeProcess()..completeExit(1);
    final container = buildContainer(
      processStarter: (plan) async => fakeProcess,
      portReachable: (host, port) async => false,
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: false),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.error);
  });

  test('6c. an unresolvable launch plan is reported as "Unable to start EAM service." without throwing', () async {
    final container = buildContainer(
      processStarter: (plan) async => throw StateError('should not be called'),
      launchPlanResolver: () => null,
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: false),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    final state = container.read(acquisitionServiceLauncherProvider);
    expect(state.status, AcquisitionServiceLauncherStatus.error);
    expect(state.errorMessage, 'Unable to start EAM service.');
  });

  test('7. an already-occupied port is reported without spawning a process, and Test Connection is still attempted',
      () async {
    var startCalls = 0;
    var testConnectionCalls = 0;
    final container = buildContainer(
      processStarter: (plan) async {
        startCalls++;
        throw StateError('must not spawn when the port is already occupied');
      },
      portReachable: (host, port) async => true, // already occupied, from the very first check
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(
        alwaysConnected: true,
        onTestConnection: () => testConnectionCalls++,
      ),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    expect(startCalls, 0);
    expect(testConnectionCalls, 1);
    final state = container.read(acquisitionServiceLauncherProvider);
    expect(state.status, AcquisitionServiceLauncherStatus.error);
    expect(state.errorMessage, 'Port 8080 is already in use.');
  });

  test('8. Test Connection succeeds once the service is reachable after startup', () async {
    final fakeProcess = _FakeProcess();
    var startCalls = 0;
    final container = buildContainer(
      processStarter: (plan) async {
        startCalls++;
        return fakeProcess;
      },
      portReachable: (host, port) async => startCalls > 0,
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: true),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();
    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.running);

    await container.read(acquisitionRuntimeServiceProvider.notifier).testConnection();
    expect(container.read(acquisitionRuntimeServiceProvider).connectionStatus, AcquisitionConnectionStatus.connected);
  });

  test('AC-10: a remote (non-local) service address is refused rather than started', () async {
    var startCalls = 0;
    final container = buildContainer(
      apiBaseUrl: 'https://example.oep.com',
      processStarter: (plan) async {
        startCalls++;
        throw StateError('must not spawn for a remote address');
      },
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: false),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    expect(startCalls, 0);
    final state = container.read(acquisitionServiceLauncherProvider);
    expect(state.status, AcquisitionServiceLauncherStatus.error);
    expect(isLocalServiceAddress('https://example.oep.com'), isFalse);
    expect(isLocalServiceAddress('http://127.0.0.1:8080'), isTrue);
    expect(isLocalServiceAddress('http://localhost:8080'), isTrue);
  });

  test('a second start() call while already running/starting is a no-op', () async {
    var startCalls = 0;
    final fakeProcess = _FakeProcess();
    final container = buildContainer(
      processStarter: (plan) async {
        startCalls++;
        return fakeProcess;
      },
      portReachable: (host, port) async => startCalls > 0,
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: true),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();
    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    expect(startCalls, 1);
  });

  test('stop() before any start() is a harmless no-op', () async {
    final container = buildContainer(
      processStarter: (plan) async => throw StateError('should not be called'),
      fakeRuntime: () => _FakeAcquisitionRuntimeNotifier(alwaysConnected: false),
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).stop();

    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.stopped);
  });
}

class _FixedAcquisitionSettingsNotifier extends AcquisitionSettingsNotifier {
  _FixedAcquisitionSettingsNotifier(this._apiBaseUrl);
  final String _apiBaseUrl;

  @override
  AcquisitionSettings build() => AcquisitionSettings(apiBaseUrl: _apiBaseUrl);
}

/// Stands in for the real `GET /health` round-trip
/// (`AcquisitionRuntimeNotifier.testConnection`) without a real HTTP
/// client or a real server -- [alwaysConnected] decides what every call
/// reports.
class _FakeAcquisitionRuntimeNotifier extends AcquisitionRuntimeNotifier {
  _FakeAcquisitionRuntimeNotifier({required this.alwaysConnected, this.onTestConnection});

  final bool alwaysConnected;
  final void Function()? onTestConnection;

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<void> testConnection() async {
    onTestConnection?.call();
    state = AcquisitionServiceState(
      connectionStatus: alwaysConnected ? AcquisitionConnectionStatus.connected : AcquisitionConnectionStatus.networkError,
    );
  }
}

/// A fake `dart:io Process` -- never a real OS process. `kill()` and
/// `completeExit()` both resolve [exitCode], exactly like a real
/// process terminating for either reason (killed by us, or exiting on
/// its own).
class _FakeProcess implements Process {
  final _exitCodeCompleter = Completer<int>();
  bool killed = false;

  void completeExit(int code) {
    if (!_exitCodeCompleter.isCompleted) _exitCodeCompleter.complete(code);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    completeExit(0);
    return true;
  }

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  int get pid => 424242;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();
}
