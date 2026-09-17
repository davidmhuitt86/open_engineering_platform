import 'dart:io';

import '../../ingestion/models/artifact_type.dart';
import '../../ingestion/models/vault_object_input.dart';
import '../models/vault_entry_record.dart';
import 'acquisition_api_client.dart';
import 'acquisition_api_exception.dart';

/// Thrown by [ReferenceVaultAdapter] itself -- as opposed to
/// [AcquisitionApiException], which is thrown by [AcquisitionApiClient]
/// for transport/integrity failures -- for adapter-level rejections that
/// are not an EAM API failure: today, exactly one case, an artifact whose
/// authoritative MIME type the Universal Ingestion Framework has no
/// parser for (WP-INGEST-003 § 13/§ 21 "UNSUPPORTED MIME TYPE... Reject at
/// the appropriate input boundary. Do not falsely classify it as PDF.").
class ReferenceVaultAdapterException implements Exception {
  const ReferenceVaultAdapterException(this.message);

  final String message;

  @override
  String toString() => 'ReferenceVaultAdapterException: $message';
}

/// The Studio-side Reference Vault Adapter (WP-INGEST-003 § 10,
/// AP-INGEST-003 § 7) -- translates an authoritative EAM Vault Entry plus
/// its verified artifact bytes into the Universal Ingestion Framework's
/// existing input contract, [VaultObjectInput].
///
/// This is the one and only place in Studio where
/// [AcquisitionApiClient] and [VaultObjectInput] are both in scope. The
/// required dependency direction (WP-INGEST-003 § 18) is:
///
/// ```
/// AcquisitionApiClient -> ReferenceVaultAdapter -> VaultObjectInput -> UIF
/// ```
///
/// `lib/ingestion/` (the UIF itself) never imports this file, never
/// imports `AcquisitionApiClient`, and never imports `dart:io` for
/// network purposes -- confirmed by this class living under
/// `lib/acquisition/`, not `lib/ingestion/`, even though it imports two
/// ingestion models ([ArtifactType], [VaultObjectInput]). That import
/// direction (adapter -> ingestion models) is the *allowed* one; the
/// prohibited one (ingestion -> acquisition) does not exist anywhere in
/// this file or elsewhere in `lib/ingestion/`.
///
/// Owns translation/materialization only (AP-INGEST-003 § 2 "Reference
/// Vault Adapter"). It does **not** become a second Vault: the temporary
/// file [materialize] writes is a disposable processing copy the caller
/// must clean up with [cleanupTemporaryFile] once ingestion has consumed
/// it -- never a second system of record (WP-INGEST-003 § 14/§ 29/§ 34).
abstract final class ReferenceVaultAdapter {
  /// Retrieves the Vault Entry, downloads and integrity-verifies its
  /// artifact bytes, materializes them to a temporary local file (the
  /// existing PDF parser/OCR pipeline requires a real filesystem path --
  /// see `PdfIngestionParser.parse` opening `input.storageReference` via
  /// `pdfrx`'s `PdfDocument.openFile`), and returns the resulting
  /// [VaultObjectInput].
  ///
  /// Per WP-INGEST-003 § 11/§ 12: [VaultEntryRecord.id] becomes
  /// [VaultObjectInput.vaultObjectId] exactly (never regenerated), and the
  /// verified SHA-256 [AcquisitionApiClient.downloadVaultArtifact] already
  /// computed becomes [VaultObjectInput.contentHash] exactly. Both are
  /// additionally cross-checked here against the Vault Entry's own
  /// authoritative `sha256_hash` (belt-and-braces: the artifact route and
  /// the entry route are two independent EAM responses, and WP-INGEST-003
  /// § 8 requires treating any integrity discrepancy as a hard failure,
  /// not just a discrepancy against the artifact response's own header).
  ///
  /// Throws [AcquisitionApiException] for any EAM retrieval/integrity
  /// failure (404, 401, 403, network, checksum mismatch/missing --
  /// [AcquisitionApiClient] already produces exactly these), and
  /// [ReferenceVaultAdapterException] if the authoritative MIME type has
  /// no UIF artifact-type mapping. In every failure case, no
  /// [VaultObjectInput] is returned and the Universal Ingestion Framework
  /// is never invoked (WP-INGEST-003 § 21).
  static Future<VaultObjectInput> materialize({
    required AcquisitionApiClient client,
    required String vaultObjectId,
  }) async {
    final entry = await client.getVaultEntry(vaultObjectId);
    final artifact = await client.downloadVaultArtifact(vaultObjectId);

    // Cross-check: the artifact route's own verified checksum must also
    // agree with the Vault Entry's authoritative sha256_hash. A mismatch
    // here would mean the Vault Entry row and its artifact file have
    // drifted apart server-side -- an integrity failure this adapter must
    // not paper over.
    if (artifact.checksum.toLowerCase() != entry.sha256Hash.toLowerCase()) {
      throw AcquisitionApiException.integrity(
        'Vault Entry $vaultObjectId reports sha256_hash=${entry.sha256Hash} but the downloaded '
        'artifact\'s verified checksum is ${artifact.checksum}.',
      );
    }

    final artifactType = ArtifactType.fromMimeType(entry.mimeType);
    if (artifactType == ArtifactType.unknown) {
      throw ReferenceVaultAdapterException(
        'Vault Entry $vaultObjectId has mime_type="${entry.mimeType}", which has no supported Universal '
        'Ingestion Framework artifact type. Rejected at the Reference Vault boundary rather than being '
        'ingested as an unsupported type.',
      );
    }

    final acquisitionRecordIds = await _resolveAcquisitionRecordIds(client, entry);

    final temporaryFile = await _materializeTemporaryFile(vaultObjectId, artifact.bytes);

    return VaultObjectInput(
      vaultObjectId: entry.id,
      acquisitionRecordIds: acquisitionRecordIds,
      artifactType: artifactType,
      mimeType: entry.mimeType,
      contentHash: artifact.checksum,
      storageReference: temporaryFile.path,
      immutableMetadataSnapshot: {
        'vaultEntryId': entry.id,
        'metadataId': entry.metadataId,
        'verificationId': entry.verificationId,
        'downloadSessionId': entry.downloadSessionId,
        'sourceId': entry.sourceId,
        'sha256Hash': entry.sha256Hash,
        'mimeType': entry.mimeType,
        'fileSizeBytes': entry.fileSizeBytes,
        'status': entry.status,
        'publishedAt': entry.publishedAt,
        'createdAt': entry.createdAt,
      },
    );
  }

  /// Resolves the Acquisition Record(s) provenance for [entry]
  /// (WP-INGEST-003 § 16) by correlating its `download_session_id`
  /// against `GET /acquisition-records` -- the only authoritative EAM
  /// route that exposes Acquisition Record identity (see
  /// [AcquisitionApiClient.listAcquisitionRecords]'s own doc comment).
  ///
  /// If `entry.downloadSessionId` is empty, or no Acquisition Record's
  /// own `download_session_id` matches it, this returns an empty list --
  /// the honest representation of "no acquisition provenance is
  /// exposed/resolvable for this Vault Entry", never a fabricated id
  /// (WP-INGEST-003 § 6/§ 16: "Do not fabricate Acquisition Record IDs").
  static Future<List<String>> _resolveAcquisitionRecordIds(
    AcquisitionApiClient client,
    VaultEntryRecord entry,
  ) async {
    if (entry.downloadSessionId.isEmpty) return const [];
    final records = await client.listAcquisitionRecords();
    final match = records.where((record) => record['download_session_id'] == entry.downloadSessionId);
    if (match.isEmpty) return const [];
    final id = match.first['id'];
    return id is String && id.isNotEmpty ? [id] : const [];
  }

  /// Writes [bytes] -- the exact verified artifact bytes, never modified
  /// (WP-INGEST-003 § 34) -- to a fresh temporary file, following the
  /// existing `oep_*` temp-directory convention
  /// `ExchangeInstallBridge` already established
  /// (`Directory.systemTemp.createTempSync('oep_exchange_install_')` in
  /// `lib/exchange/services/exchange_install_bridge.dart`) rather than
  /// inventing a new temp-file pattern.
  ///
  /// This is explicitly a disposable processing copy, not a second Vault
  /// (WP-INGEST-003 § 29) -- see [cleanupTemporaryFile].
  static Future<File> _materializeTemporaryFile(String vaultObjectId, List<int> bytes) async {
    final directory = Directory.systemTemp.createTempSync('oep_vault_artifact_');
    final safeName = vaultObjectId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Deletes the temporary materialization [materialize] created for
  /// [input], once the caller (the ingestion entry point) has finished
  /// using it. Refuses to delete anything outside [Directory.systemTemp]
  /// as a defense-in-depth safeguard against ever deleting an unrelated
  /// path, since [VaultObjectInput.storageReference] is a plain string a
  /// caller could in principle have built differently (e.g. via
  /// `VaultObjectInput.fromFile` for a test fixture, which this method
  /// must never touch).
  static Future<void> cleanupTemporaryFile(VaultObjectInput input) async {
    final path = input.storageReference;
    if (!path.startsWith(Directory.systemTemp.path)) return;
    final file = File(path);
    final parent = file.parent;
    try {
      if (await file.exists()) await file.delete();
      if (await parent.exists()) await parent.delete(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup only -- a failure to delete a temp file is
      // not an ingestion failure and must not be surfaced as one.
    }
  }
}
