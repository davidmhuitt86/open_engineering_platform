/// A Studio-only validation failure in the Knowledge Curation workflow
/// (Work Package 007 Error Handling: "Invalid session names, Duplicate
/// proposal names, Missing repository ... Display professional
/// validation messages").
///
/// Distinct from `FoundationBridgeException` — nothing here ever
/// reaches Foundation; these are local, in-memory Studio checks over
/// data that never leaves the Connection Manager.
class KnowledgeValidationException implements Exception {
  const KnowledgeValidationException(this.message);

  final String message;

  @override
  String toString() => 'KnowledgeValidationException: $message';
}
