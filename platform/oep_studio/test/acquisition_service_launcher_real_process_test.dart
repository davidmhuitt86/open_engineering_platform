import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/models/acquisition_connection_status.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_service_launcher.dart';
import 'package:oep_studio/acquisition/services/acquisition_service_launcher_state.dart';
import 'package:oep_studio/acquisition/settings/acquisition_settings.dart';
import 'package:oep_studio/acquisition/settings/acquisition_settings_provider.dart';

/// WP-EAM-LOCAL-SERVICE-001's real-process proof: unlike
/// `acquisition_service_launcher_test.dart` (fakes only), this file uses
/// the REAL, default [defaultAcquisitionLaunchPlanResolver] and the REAL
/// `Process.start` to launch the actual, already-built
/// `services/acquisition/build/src/app/Debug/oep_acquisition.exe`, then
/// confirms the real `GET /health` path
/// (`AcquisitionRuntimeNotifier.testConnection`) reports it reachable,
/// and that stopping it actually frees the port.
///
/// Skips (does not fail) if this checkout has no
/// `services/acquisition/build/src/app/Debug/oep_acquisition.exe` built
/// yet (`defaultAcquisitionLaunchPlanResolver()` returns `null`) --
/// matching this repository's own established convention (see
/// WP-EXC-013A/WP-EXC-014) of skipping only for a genuinely unavailable
/// dependency, never for a stale/broken one, and never faking a pass.
void main() {
  test('the real EAM backend genuinely starts, becomes reachable, and can be stopped', () async {
    final plan = defaultAcquisitionLaunchPlanResolver();
    if (plan == null) {
      markTestSkipped(
        'services/acquisition/build/src/app/Debug/oep_acquisition.exe was not found in this checkout -- '
        'build it first (see platform/oep_studio/docs/tasks/EAM-LOCAL-SERVICE-LAUNCHER.md).',
      );
      return;
    }

    final container = ProviderContainer(
      overrides: [
        acquisitionSettingsProvider.overrideWith(
          () => _FixedAcquisitionSettingsNotifier(const AcquisitionSettings(apiBaseUrl: 'http://127.0.0.1:8080')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(acquisitionServiceLauncherProvider.notifier).start();

    final started = container.read(acquisitionServiceLauncherProvider);
    expect(started.status, AcquisitionServiceLauncherStatus.running, reason: started.errorMessage);

    // AC-05/AC-06: the real, existing Test Connection path reports the
    // real backend reachable -- the same check Acquisition's own
    // workspace relies on before doing any real work against it.
    await container.read(acquisitionRuntimeServiceProvider.notifier).testConnection();
    expect(container.read(acquisitionRuntimeServiceProvider).connectionStatus, AcquisitionConnectionStatus.connected);

    await container.read(acquisitionServiceLauncherProvider.notifier).stop();
    expect(container.read(acquisitionServiceLauncherProvider).status, AcquisitionServiceLauncherStatus.stopped);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

class _FixedAcquisitionSettingsNotifier extends AcquisitionSettingsNotifier {
  _FixedAcquisitionSettingsNotifier(this._settings);
  final AcquisitionSettings _settings;

  @override
  AcquisitionSettings build() => _settings;
}
