import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_controller.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_page.dart';
import 'package:oep_studio/knowledge/models/document_orientation.dart';

class _FakeRuntime extends AcquisitionRuntimeNotifier {
  final calls = <String>[];

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) async {
    calls.add('createJob');
    return {'id': 'job-1', 'status': 'created'};
  }

  @override
  Future<Map<String, Object?>> executeJobReturning(String jobId) async => {'id': jobId, 'status': 'running'};

  @override
  Future<Map<String, Object?>> startDownloadReturning(Map<String, Object?> body) async =>
      {'id': 'dl-1', 'status': 'completed', 'file_size_bytes': 1};

  @override
  Future<Map<String, Object?>> verifyReturning(String downloadSessionId) async =>
      {'id': 'v-1', 'status': 'verified', 'sha256_hash': 'abc'};

  @override
  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) async =>
      {'id': 'm-1', 'status': 'extracted'};

  @override
  Future<Map<String, Object?>> publishReturning(String metadataId) async => {'id': 'vault-1', 'vault_path': 'x'};
}

/// WP-EAM-007 section C: the execution action lives in the footer's primary slot.
void main() {
  late ProviderContainer container;
  late _FakeRuntime runtime;

  Future<AcquisitionWizardController> pumpWizardAt(WidgetTester tester, int step, {bool ready = true}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    runtime = _FakeRuntime();
    container = ProviderContainer(overrides: [
      acquisitionRuntimeServiceProvider.overrideWith(() => runtime),
      acquisitionWizardControllerProvider.overrideWith(
        (ref) => AcquisitionWizardController(ref, saveCustody: (_, __) async {}),
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(acquisitionWizardControllerProvider, (_, __) {});
    final controller = container.read(acquisitionWizardControllerProvider);
    if (ready) {
      controller.setKnowledgeType('Engineering Standard');
      controller.setSource('src-1', 'IETF');
      controller.updateCustody(originalUrl: 'https://example.org/spec.txt', engineer: 'jsmith');
    }
    for (var i = 0; i < step; i++) {
      controller.next();
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AcquisitionWizardPage()),
    ));
    await tester.pump();
    return controller;
  }

  final acquireButton = find.widgetWithText(FilledButton, 'Acquire Engineering Knowledge');

  testWidgets('at the execution step the single primary action is bottom-right, replacing Next', (tester) async {
    await pumpWizardAt(tester, 4);
    expect(acquireButton, findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
    final rect = tester.getRect(acquireButton);
    final screen = tester.view.physicalSize;
    expect(rect.right, greaterThan(screen.width - 40), reason: 'bottom-right');
    expect(rect.bottom, greaterThan(screen.height - 80), reason: 'footer row');
    final back = tester.getRect(find.widgetWithText(TextButton, 'Back'));
    expect((back.center.dy - rect.center.dy).abs(), lessThan(2), reason: 'aligned with Back');
    expect(find.byType(FilledButton), findsOneWidget, reason: 'exactly one primary action, no centered duplicate');
  });

  testWidgets('earlier steps still show Next in the same footer slot', (tester) async {
    await pumpWizardAt(tester, 3);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    expect(acquireButton, findsNothing);
  });

  testWidgets('pressing the footer action starts the existing acquisition flow', (tester) async {
    final controller = await pumpWizardAt(tester, 4);
    await tester.tap(acquireButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(runtime.calls, contains('createJob'));
    expect(controller.runStatus, isNot(AcquisitionRunStatus.idle));
  });

  testWidgets('validation still applies: the wizard cannot advance without required input', (tester) async {
    final controller = await pumpWizardAt(tester, 0, ready: false);
    controller.next();
    await tester.pump();
    expect(controller.stepIndex, 0, reason: 'blocked on missing knowledge type');
    expect(acquireButton, findsNothing);
  });

  testWidgets('after the action the progress view replaces the idle view and the footer offers Next', (tester) async {
    final controller = await pumpWizardAt(tester, 4);
    await tester.tap(acquireButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(acquireButton, findsNothing);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    expect(controller.stepIndex, 4);
  });

  testWidgets('the Scope step exposes the Extraction Orientation selector and stores the choice', (tester) async {
    final controller = await pumpWizardAt(tester, 3);
    expect(find.byKey(const ValueKey('extraction-orientation-selector')), findsOneWidget);
    // No local file (official-source flow): no fake preview is shown.
    expect(find.byKey(const ValueKey('extraction-orientation-preview')), findsNothing);
    await tester.tap(find.text('180°'));
    await tester.pump();
    expect(controller.extractionOrientation, DocumentOrientation.deg180);
  });
}
