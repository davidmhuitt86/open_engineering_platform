/// Structured Knowledge Runtime error codes (AP-EK-013 §41).
library;

enum KnowledgeRuntimeErrorCode {
  packageNotFound,
  packageInvalid,
  packageHashMismatch,
  packageSignatureInvalid,
  schemaUnsupported,
  compilerIncompatible,
  dependencyMissing,
  duplicateAuthority,
  referenceNotFound,
  invalidReference,
  knowledgeVersionUnavailable,
  activationFailed,
}

class KnowledgeRuntimeException implements Exception {
  final KnowledgeRuntimeErrorCode code;
  final String message;

  const KnowledgeRuntimeException(this.code, this.message);

  @override
  String toString() => 'KnowledgeRuntimeException(${code.name}): $message';
}
