import '../../knowledge/models/source_material.dart';
import '../models/artifact_type.dart';
import '../models/normalized_document.dart';
import '../models/vault_object_input.dart';

/// The generalized parser abstraction (AP-INGEST-001 § 8, WP-INGEST-001
/// § 6.4). "`parse()` produces normalized extraction data rather than
/// writing directly to application databases" — every [IngestionParser]
/// implementation must uphold the Parser Restrictions (AP-INGEST-001
/// § 8.1): no PostgreSQL writes, no Engineering Object creation, no
/// candidate commits, no Reference Vault mutation, no engineering
/// approval/validation. Nothing in this abstraction's shape gives an
/// implementation the means to do any of those things — it can only
/// return a [ParserOutput].
abstract class IngestionParser {
  String get parserId;
  String get version;
  List<ArtifactType> get supportedArtifactTypes;
  List<String> get supportedMimeTypes;

  bool canParse(VaultObjectInput input) =>
      supportedArtifactTypes.contains(input.artifactType) || supportedMimeTypes.contains(input.mimeType);

  Future<ParserOutput> parse(VaultObjectInput input);
}

/// What [IngestionParser.parse] returns: normalized extraction data plus
/// the [SourceMaterial] downstream stages (OCR, entity extraction) reuse
/// unchanged. [diagnostics] carries parser-level notes (e.g. "no embedded
/// text layer") that belong in the CONTENT_EXTRACTION/STRUCTURAL_ANALYSIS
/// stage results.
class ParserOutput {
  const ParserOutput({required this.document, required this.source, this.diagnostics = const []});

  final NormalizedDocument document;
  final SourceMaterial source;
  final List<String> diagnostics;
}
