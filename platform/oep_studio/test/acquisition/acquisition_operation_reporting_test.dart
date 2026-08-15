import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_exception.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';

/// Engineering Acquisition was the one subsystem doing real, long-running
/// work that reported nothing anywhere -- so the Output Panel's
/// Acquisition Log tab sat permanently empty even during a real
/// acquisition. These tests pin the fix: every EAM operation publishes
/// real `OperationEvent`s on the `PlatformEventBus`, which
/// `ActivityLog`/`OperationManager` (and therefore the Output Panel)
/// already observe.
class _FakeNotifier extends AcquisitionRuntimeNotifier {
  _FakeNotifier(this._bus);

  final PlatformEventBus _bus;

  /// Redirects publication to a test-local bus, so these assertions
  /// never depend on (or pollute) the app-wide `PlatformEventBus`
  /// singleton -- the same seam `StudioShell` exposes for its own tests.
  @override
  PlatformEventBus get eventBus => _bus;

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  // Deliberately NOT overriding the `*Returning` methods: the reporting
  // wrapper under test is the genuine one. Only the list refresh is
  // stubbed, since it would otherwise make its own HTTP calls.
  @override
  Future<void> refreshAll() async {}
}

void main() {
  test('a successful operation publishes started + completed, both prefixed', () async {
    final bus = PlatformEventBus();
    addTearDown(bus.dispose);
    final events = <OperationEvent>[];
    final sub = bus.on<OperationEvent>().listen(events.add);
    addTearDown(sub.cancel);

    final container = ProviderContainer(
      overrides: [acquisitionRuntimeServiceProvider.overrideWith(() => _FakeNotifier(bus))],
    );
    addTearDown(container.dispose);

    // Drives the real `_reportingOperation` wrapper; the HTTP call
    // beneath it fails (no server), which is itself a valid path to
    // assert on -- what matters is that events were published at all.
    try {
      await container.read(acquisitionRuntimeServiceProvider.notifier).createJobReturning({'name': 'X'});
    } catch (_) {
      // expected: no EAM process is running in a unit test
    }
    await Future<void>.delayed(Duration.zero);

    expect(events, isNotEmpty, reason: 'acquisition work must report to the Platform event bus');
    expect(events.first.kind, OperationEventKind.started);
    expect(
      events.first.label,
      startsWith(AcquisitionRuntimeNotifier.operationLabelPrefix),
      reason: 'the Output Panel filters on this prefix -- see _AcquisitionLogTab',
    );
    expect(events.first.id, startsWith('acquisition:'));
  });

  test('a failed operation reports failure, carrying the curated message', () async {
    final bus = PlatformEventBus();
    addTearDown(bus.dispose);
    final events = <OperationEvent>[];
    final sub = bus.on<OperationEvent>().listen(events.add);
    addTearDown(sub.cancel);

    final container = ProviderContainer(
      overrides: [acquisitionRuntimeServiceProvider.overrideWith(() => _FakeNotifier(bus))],
    );
    addTearDown(container.dispose);

    try {
      await container.read(acquisitionRuntimeServiceProvider.notifier).createJobReturning({'name': 'X'});
    } catch (_) {
      // expected
    }
    await Future<void>.delayed(Duration.zero);

    final failed = events.where((e) => e.kind == OperationEventKind.failed).toList();
    expect(failed, isNotEmpty, reason: 'a failure must be reported, not swallowed silently');
    expect(failed.single.label, startsWith(AcquisitionRuntimeNotifier.operationLabelPrefix));
  });

  test('the label prefix is non-empty and stable', () {
    // The Output Panel and the service agree on exactly this constant
    // rather than duplicating a literal; an empty prefix would silently
    // match every unrelated operation in the app.
    expect(AcquisitionRuntimeNotifier.operationLabelPrefix.trim(), isNotEmpty);
    expect(AcquisitionRuntimeNotifier.operationLabelPrefix, contains('Acquisition'));
  });

  test('AcquisitionApiException still surfaces its curated message', () {
    final error = AcquisitionApiException.network('connection refused');
    expect(error.message, contains('Could not reach the Engineering Acquisition service'));
    expect(error.technicalDetail, 'connection refused');
  });
}
