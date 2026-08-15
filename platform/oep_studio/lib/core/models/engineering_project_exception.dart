/// A Studio-only failure persisting or loading an [EngineeringProject]
/// (WORK_PACKAGE_025). Mirrors `KnowledgeValidationException`'s shape —
/// a professional message, never a raw `IOException`/`FormatException`
/// reaching the UI.
class EngineeringProjectException implements Exception {
  const EngineeringProjectException(this.message);

  final String message;

  @override
  String toString() => 'EngineeringProjectException: $message';
}
