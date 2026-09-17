import 'dart:io';

import 'package:crypto/crypto.dart';

import 'artifact_type.dart';

/// UIF's input contract (AP-INGEST-001 § 5, WP-INGEST-001 § 6.1) — the
/// conceptual `VaultObjectInput` the architecture document specifies,
/// carrying exactly the semantics it requires and nothing more.
///
/// **Reference Vault stand-in for this slice.** No first-class Dart
/// `VaultObject`/Reference Vault model exists anywhere in this codebase
/// (confirmed by repository-wide search for "VaultObject", "ReferenceVault",
/// "vaultObjectId" before writing this file) — `services/acquisition/`'s
/// C++ vault is a real, working, generic document-custody pipeline, but a
/// cross-language integration into it is explicitly out of scope for this
/// vertical slice per the task instructions this work package was
/// implemented under. Per WP-INGEST-001 § 6.1 ("check for an existing
/// acquisition-side vault concept first... if the TRX300 PDF itself, read
/// directly from `reference/ingestion/trx300/source/`, is the practical
/// stand-in for 'vault evidence' for this slice, that is acceptable —
/// document that decision explicitly in the AAR rather than inventing a
/// full cross-language Vault integration"), [VaultObjectInput.fromFile]
/// treats the TRX300 source PDF's own file path as [storageReference] and
/// its own content hash as [contentHash] — an honest stand-in for "the
/// Reference Vault", not a claim that a Reference Vault now exists in
/// Dart. This decision is documented in the AAR, not silently assumed.
class VaultObjectInput {
  const VaultObjectInput({
    required this.vaultObjectId,
    required this.acquisitionRecordIds,
    required this.artifactType,
    required this.mimeType,
    required this.contentHash,
    required this.storageReference,
    required this.immutableMetadataSnapshot,
  });

  /// Permanent identity of the Reference Vault object being processed
  /// (AP-INGEST-001 § 5.1).
  final String vaultObjectId;

  /// References the acquisition history associated with the evidence
  /// (AP-INGEST-001 § 5.2). Empty for this stand-in — no EAM acquisition
  /// record exists for the TRX300 reference dataset (it was placed
  /// directly under `reference/ingestion/trx300/`, not acquired through
  /// `services/acquisition/`); an empty list is the honest representation
  /// of that, not a placeholder value.
  final List<String> acquisitionRecordIds;

  /// Logical artifact classification (AP-INGEST-001 § 5.3).
  final ArtifactType artifactType;

  /// The detected or recorded MIME type (AP-INGEST-001 § 5.4).
  final String mimeType;

  /// Content identity used for integrity, reproducibility, and ingestion
  /// identity (AP-INGEST-001 § 5.5) — a SHA-256 hex digest of the
  /// artifact's bytes, using the exact same hashing convention
  /// `OcrCacheService.computeFingerprint` already established for Source
  /// Material content identity, rather than inventing a second one.
  final String contentHash;

  /// An implementation-level reference that permits UIF to obtain the
  /// immutable content (AP-INGEST-001 § 5.6) — a local file path for this
  /// slice's filesystem-backed stand-in. "UIF shall not depend on a
  /// particular physical storage implementation": nothing downstream of
  /// [VaultObjectInput] inspects this field's shape — it is opaque to the
  /// parser/OCR/entity stages, which only ever receive the
  /// `SourceMaterial` the parser derives from it.
  final String storageReference;

  /// Metadata supplied with the Vault Object at ingestion time
  /// (AP-INGEST-001 § 5.7) — read-only input to UIF, never rewritten by
  /// it. For this slice: the contents of the TRX300 dataset's own
  /// `source/source_manifest.json`, passed through unchanged.
  final Map<String, dynamic> immutableMetadataSnapshot;

  /// Builds a [VaultObjectInput] for a local file, computing [contentHash]
  /// from the file's current bytes. This is the "Reference Vault
  /// stand-in" constructor described in this class's own doc comment.
  static Future<VaultObjectInput> fromFile({
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required ArtifactType artifactType,
    required String mimeType,
    required String filePath,
    required Map<String, dynamic> immutableMetadataSnapshot,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    return VaultObjectInput(
      vaultObjectId: vaultObjectId,
      acquisitionRecordIds: acquisitionRecordIds,
      artifactType: artifactType,
      mimeType: mimeType,
      contentHash: sha256.convert(bytes).toString(),
      storageReference: filePath,
      immutableMetadataSnapshot: immutableMetadataSnapshot,
    );
  }
}
