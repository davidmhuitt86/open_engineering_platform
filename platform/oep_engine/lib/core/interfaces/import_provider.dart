import '../importers/shared/import_request.dart';
import '../importers/shared/import_result.dart';

/// Converts an external document into Engineering Knowledge (SDD-025/026).
/// Never modifies Source Material.
abstract class ImportProvider {
  bool supports(String formatId);

  Future<ImportResult> import(ImportRequest request);
}
