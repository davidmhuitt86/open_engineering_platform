/// Outcome of an export operation.
class ExportResult {
  final bool success;
  final String? outputPath;
  final List<int>? bytes;
  final String? errorMessage;

  const ExportResult({
    required this.success,
    this.outputPath,
    this.bytes,
    this.errorMessage,
  });

  factory ExportResult.ok({String? outputPath, List<int>? bytes}) =>
      ExportResult(success: true, outputPath: outputPath, bytes: bytes);

  factory ExportResult.failure(String message) =>
      ExportResult(success: false, errorMessage: message);
}
