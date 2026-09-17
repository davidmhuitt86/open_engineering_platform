import 'normalized_metadata.dart';
import 'normalized_page.dart';

/// UIF's normalized extraction model (AP-INGEST-001 § 11, WP-INGEST-001
/// § 7): "a minimal normalized representation capable of carrying document
/// identity, pages, text, structural locations, ... source locations,
/// metadata." Every [NormalizedPage] retains its own source location
/// (page number) so downstream stages (OCR, entity extraction) can cite
/// exactly which page a finding came from — "Every normalized item must
/// retain enough provenance to identify its originating Vault Object and
/// source location."
class NormalizedDocument {
  const NormalizedDocument({required this.vaultObjectId, required this.metadata, required this.pages});

  final String vaultObjectId;
  final NormalizedMetadata metadata;
  final List<NormalizedPage> pages;

  Map<String, dynamic> toJson() => {
    'vaultObjectId': vaultObjectId,
    'metadata': metadata.toJson(),
    'pages': pages.map((page) => page.toJson()).toList(),
  };
}
