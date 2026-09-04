/// AP-EK-020 §18 — Analysis Request. Immutable once execution begins;
/// identifies the exact document version being analyzed.
library;

enum AnalysisMode { linearDc }

class AnalysisRequest {
  final String requestId;
  final String documentId;
  final String documentVersion;
  final AnalysisMode analysisMode;
  final List<String> requestedOutputs;
  final String knowledgePackageId;
  final String numericPolicy;

  const AnalysisRequest({
    required this.requestId,
    required this.documentId,
    required this.documentVersion,
    this.analysisMode = AnalysisMode.linearDc,
    this.requestedOutputs = const ['current', 'power'],
    required this.knowledgePackageId,
    this.numericPolicy = 'ieee754-double-1e-9',
  });

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'documentId': documentId,
    'documentVersion': documentVersion,
    'analysisMode': analysisMode.name,
    'requestedOutputs': requestedOutputs,
    'knowledgePackageId': knowledgePackageId,
    'numericPolicy': numericPolicy,
  };
}
