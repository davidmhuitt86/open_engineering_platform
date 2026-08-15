/// Public surface for the Import Engine (SDD-025/026). JSON only in
/// Phase 1; PDF/PNG/JPG/TIFF/SVG (OCR-dependent) are Phase 2 work.
library;

export '../core/importers/json/json_import_provider.dart';
export '../core/importers/shared/import_request.dart';
export '../core/importers/shared/import_result.dart';
export '../core/interfaces/import_provider.dart';
