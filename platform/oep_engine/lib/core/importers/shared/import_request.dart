/// Input to an [ImportProvider] (SDD-025/026). Importers never modify
/// Source Material — [sourcePath]/[bytes] are read-only inputs.
class ImportRequest {
  final String formatId;
  final String? sourcePath;
  final List<int>? bytes;
  final Map<String, Object?> options;

  const ImportRequest({
    required this.formatId,
    this.sourcePath,
    this.bytes,
    this.options = const {},
  });
}
