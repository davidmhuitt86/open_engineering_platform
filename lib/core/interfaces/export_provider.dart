import '../exporters/shared/export_request.dart';
import '../exporters/shared/export_result.dart';

/// Converts an Engineering Graph into an external format (SDD-025/026).
/// Never modifies Engineering Knowledge.
abstract class ExportProvider {
  bool supports(String formatId);

  Future<ExportResult> export(ExportRequest request);
}
