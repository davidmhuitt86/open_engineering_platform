/// The canonical UIF stage vocabulary (AP-INGEST-001 § 7). Not every
/// artifact executes every stage — "Stage execution is capability-driven."
///
/// This first vertical slice executes only the stages WP-INGEST-001 § 5
/// authorizes as "first executable stages": [identify] through
/// [candidateGeneration]. [chunkGeneration] and [embeddingGeneration]
/// exist in this enum purely as the extensibility points AP-INGEST-001
/// § 7/§ 34 requires the architecture to support ("Chunk and embedding
/// generation may be added later without changing the preceding
/// contracts") — no [IngestionOrchestrator] code path ever executes them
/// in this work package.
enum IngestionStage {
  identify,
  parserSelection,
  metadataExtraction,
  contentExtraction,
  structuralAnalysis,
  ocr,
  entityExtraction,
  relationshipExtraction,
  candidateGeneration,
  chunkGeneration,
  embeddingGeneration;

  /// The stages this first vertical slice actually executes, in pipeline
  /// order (WP-INGEST-001 § 5).
  static const executedInFirstSlice = [
    IngestionStage.identify,
    IngestionStage.parserSelection,
    IngestionStage.metadataExtraction,
    IngestionStage.contentExtraction,
    IngestionStage.structuralAnalysis,
    IngestionStage.ocr,
    IngestionStage.entityExtraction,
    IngestionStage.relationshipExtraction,
    IngestionStage.candidateGeneration,
  ];
}
