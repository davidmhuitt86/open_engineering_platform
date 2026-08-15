import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/models/acquisition_job.dart';
import 'package:oep_studio/acquisition/models/official_source.dart';
import 'package:oep_studio/acquisition/models/vault_entry_record.dart';
import 'package:oep_studio/acquisition/services/acquisition_selection.dart';
import 'package:oep_studio/acquisition/wizard/chain_of_custody_record.dart';

void main() {
  const source = OfficialSource(
    id: 'src-1',
    name: 'IETF',
    baseUrl: 'https://ietf.org',
    category: '',
    country: '',
    trustLevel: 5,
    status: 'active',
    authenticationType: 'none',
    createdAt: '',
    updatedAt: '',
  );
  const job = AcquisitionJob(
    id: 'job-1',
    sourceId: 'src-1',
    name: 'Acquire RFC',
    priority: 2,
    status: 'running',
    requestedBy: 'jsmith',
    createdAt: '',
    updatedAt: '',
  );
  const artifact = VaultEntryRecord(
    id: 'vault-1',
    metadataId: 'm-1',
    verificationId: 'v-1',
    downloadSessionId: 'd-1',
    sourceId: 'src-1',
    vaultPath: './data/vault/ab/abc',
    sha256Hash: 'abc',
    mimeType: 'text/plain',
    fileSizeBytes: 10,
    status: 'published',
    publishedAt: '',
    createdAt: '',
  );

  AcquisitionSelectionNotifier notifierIn(ProviderContainer container) =>
      container.read(acquisitionSelectionProvider.notifier);

  ProviderContainer freshContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('selection starts empty', () {
    expect(freshContainer().read(acquisitionSelectionProvider).isEmpty, isTrue);
  });

  test('the three selection kinds are mutually exclusive', () {
    final container = freshContainer();
    final notifier = notifierIn(container);

    notifier.selectSource(source);
    var state = container.read(acquisitionSelectionProvider);
    expect(state.source, source);
    expect(state.job, isNull);
    expect(state.artifact, isNull);

    // Selecting a Job must clear the Source -- the Property Inspector
    // renders exactly one mode, so two live selections would be
    // ambiguous.
    notifier.selectJob(job);
    state = container.read(acquisitionSelectionProvider);
    expect(state.job, job);
    expect(state.source, isNull);
    expect(state.artifact, isNull);

    notifier.selectArtifact(artifact);
    state = container.read(acquisitionSelectionProvider);
    expect(state.artifact, artifact);
    expect(state.source, isNull);
    expect(state.job, isNull);
  });

  test('clear() empties the selection', () {
    final container = freshContainer();
    notifierIn(container).selectSource(source);
    notifierIn(container).clear();
    expect(container.read(acquisitionSelectionProvider).isEmpty, isTrue);
  });

  test('ChainOfCustodyRecord survives a JSON round trip', () {
    const record = ChainOfCustodyRecord(
      knowledgeType: 'Engineering Standard',
      originalUrl: 'https://www.rfc-editor.org/rfc/rfc2616.txt',
      publisher: 'IETF',
      publicationDate: '1999-06',
      revision: '1',
      license: 'IETF Trust',
      language: 'en',
      acquisitionMethod: 'Direct download',
      engineer: 'jsmith',
      scopeDescription: 'Entire Document',
      recordedAt: '2026-08-05T00:00:00.000',
    );

    final restored = ChainOfCustodyRecord.fromJson(record.toJson());

    expect(restored.knowledgeType, record.knowledgeType);
    expect(restored.originalUrl, record.originalUrl);
    expect(restored.publisher, record.publisher);
    expect(restored.publicationDate, record.publicationDate);
    expect(restored.revision, record.revision);
    expect(restored.license, record.license);
    expect(restored.language, record.language);
    expect(restored.acquisitionMethod, record.acquisitionMethod);
    expect(restored.engineer, record.engineer);
    expect(restored.scopeDescription, record.scopeDescription);
    expect(restored.recordedAt, record.recordedAt);
  });

  test('a malformed record decodes to empty strings rather than throwing', () {
    // Chain of Custody is read back from a plain JSON file a user could
    // in principle hand-edit -- a missing field must degrade, never
    // crash the Property Inspector that renders it.
    final restored = ChainOfCustodyRecord.fromJson(const {'engineer': 'jsmith'});
    expect(restored.engineer, 'jsmith');
    expect(restored.originalUrl, '');
    expect(restored.publisher, '');
  });
}
