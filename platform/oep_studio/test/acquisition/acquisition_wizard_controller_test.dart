import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_exception.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_controller.dart';

/// Exercises the Acquisition Wizard's own orchestration logic -- the
/// automatic Source -> Job -> Download -> Verify -> Metadata -> Vault
/// chain it drives so the engineer never has to (Wizard Step 5: "The
/// user should never need to press Run twice").
///
/// The EAM backend itself is faked at the `AcquisitionRuntimeNotifier`
/// seam (a real subclass overriding only the value-returning methods the
/// wizard calls) -- no real network call and no running `oep_acquisition`
/// process, matching `anthropic_provider_test.dart`'s own precedent of
/// faking the transport rather than the logic under test. What's being
/// verified here is the *sequencing and failure handling the wizard
/// itself owns*, which is the genuinely new code.
class _FakeRuntimeNotifier extends AcquisitionRuntimeNotifier {
  _FakeRuntimeNotifier({this.failAt});

  /// Which pipeline stage should fail, if any (e.g. `'download'`).
  final String? failAt;
  final List<String> calls = [];

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) async {
    calls.add('createJob');
    return {'id': 'job-1', 'status': 'created'};
  }

  @override
  Future<Map<String, Object?>> executeJobReturning(String jobId) async {
    calls.add('executeJob');
    return {'id': jobId, 'status': 'running'};
  }

  @override
  Future<Map<String, Object?>> startDownloadReturning(Map<String, Object?> body) async {
    calls.add('startDownload');
    if (failAt == 'download') {
      return {'id': 'dl-1', 'status': 'failed', 'error_message': 'host unreachable'};
    }
    return {'id': 'dl-1', 'status': 'completed', 'file_size_bytes': 1234};
  }

  @override
  Future<Map<String, Object?>> verifyReturning(String downloadSessionId) async {
    calls.add('verify');
    if (failAt == 'verify') {
      return {'id': 'v-1', 'status': 'failed', 'error_message': 'hash mismatch'};
    }
    return {'id': 'v-1', 'status': 'verified', 'sha256_hash': 'abc123'};
  }

  @override
  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) async {
    calls.add('extractMetadata');
    return {'id': 'm-1', 'status': 'extracted'};
  }

  @override
  Future<Map<String, Object?>> publishReturning(String metadataId) async {
    calls.add('publish');
    return {'id': 'vault-1', 'vault_path': './data/vault/ab/abc123'};
  }
}

void main() {
  ProviderContainer containerWith(AcquisitionRuntimeNotifier fake) {
    final container = ProviderContainer(
      overrides: [
        acquisitionRuntimeServiceProvider.overrideWith(() => fake),
        // A no-op Chain of Custody saver: these tests exercise
        // orchestration, and must never write into the real
        // `%APPDATA%/oep_studio` the running app itself uses.
        acquisitionWizardControllerProvider.overrideWith(
          (ref) => AcquisitionWizardController(ref, saveCustody: (_, __) async {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    // `acquisitionWizardControllerProvider` is `autoDispose`; without a
    // listener it is torn down at the first `await` inside `run()`.
    container.listen(acquisitionWizardControllerProvider, (_, __) {});
    return container;
  }

  AcquisitionWizardController readyController(ProviderContainer container) {
    final controller = container.read(acquisitionWizardControllerProvider);
    controller.setKnowledgeType('Engineering Standard');
    controller.setSource('src-1', 'IETF');
    controller.updateCustody(originalUrl: 'https://example.org/spec.txt', engineer: 'jsmith');
    return controller;
  }

  test('run() drives the whole backend chain in order, from one press', () async {
    final fake = _FakeRuntimeNotifier();
    final controller = readyController(containerWith(fake));

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.completed);
    // Job creation, two execute calls to reach `running`, the real
    // pipeline, then a final execute to reach `completed`.
    expect(fake.calls, [
      'createJob',
      'executeJob',
      'executeJob',
      'startDownload',
      'verify',
      'extractMetadata',
      'publish',
      'executeJob',
    ]);
    expect(controller.sha256Hash, 'abc123');
    expect(controller.vaultEntryId, 'vault-1');
  });

  test('a failed download stops the chain -- nothing downstream is attempted', () async {
    final fake = _FakeRuntimeNotifier(failAt: 'download');
    final controller = readyController(containerWith(fake));

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.failed);
    expect(controller.failureMessage, contains('host unreachable'));
    expect(fake.calls, isNot(contains('verify')));
    expect(fake.calls, isNot(contains('publish')));
  });

  test('a failed integrity verification stops before metadata and vault', () async {
    final fake = _FakeRuntimeNotifier(failAt: 'verify');
    final controller = readyController(containerWith(fake));

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.failed);
    expect(controller.failureMessage, contains('hash mismatch'));
    expect(fake.calls, contains('verify'));
    expect(fake.calls, isNot(contains('extractMetadata')));
    expect(fake.calls, isNot(contains('publish')));
  });

  test('the live log records every stage, so no operation is silent', () async {
    final fake = _FakeRuntimeNotifier();
    final controller = readyController(containerWith(fake));

    await controller.run();

    final messages = controller.log.map((e) => e.message).join('\n');
    expect(messages, contains('Initializing'));
    expect(messages, contains('Downloading'));
    expect(messages, contains('Download Complete'));
    expect(messages, contains('SHA-256 Verified'));
    expect(messages, contains('Metadata Extracted'));
    expect(messages, contains('Reference Vault'));
    expect(messages, contains('Completed'));
  });

  test('step gating: cannot advance past a step whose required input is missing', () {
    final controller = containerWith(_FakeRuntimeNotifier()).read(acquisitionWizardControllerProvider);

    expect(controller.canGoNext, isFalse); // no knowledge type yet
    controller.setKnowledgeType('Datasheet');
    expect(controller.canGoNext, isTrue);

    controller.next();
    expect(controller.canGoNext, isFalse); // no source selected yet
    controller.setSource('src-1', 'IETF');
    expect(controller.canGoNext, isTrue);

    controller.next();
    expect(controller.canGoNext, isFalse); // chain of custody incomplete
    controller.updateCustody(originalUrl: 'https://example.org/x', engineer: 'jsmith');
    expect(controller.canGoNext, isTrue);
  });

  test('run() is not re-entrant -- a second press while running is ignored', () async {
    final fake = _FakeRuntimeNotifier();
    final controller = readyController(containerWith(fake));

    await Future.wait([controller.run(), controller.run()]);

    expect(fake.calls.where((c) => c == 'createJob').length, 1);
  });

  test('AcquisitionApiException surfaces its curated message, not a raw error', () async {
    final controller = readyController(containerWith(_ThrowingRuntimeNotifier()));

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.failed);
    expect(controller.failureMessage, contains('Could not reach the Engineering Acquisition service'));
  });
}

class _ThrowingRuntimeNotifier extends AcquisitionRuntimeNotifier {
  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) async {
    throw AcquisitionApiException.network('connection refused');
  }
}
