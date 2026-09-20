/// Public surface for the Engineering Knowledge Runtime (AP-EK-013).
///
/// `lib/core/knowledge/` holds the implementation; this barrel is what
/// consumers (Diagram Studio, tests) import.
library;

export '../core/knowledge/discovery/reference_discovery.dart';
export '../core/knowledge/discovery/reference_discovery_indexes.dart';
export '../core/symbols/binding/symbol_binding.dart';
export '../core/knowledge/fixtures/electrical_core_package.dart';
export '../core/knowledge/knowledge_runtime.dart';
export '../core/knowledge/knowledge_runtime_errors.dart';
export '../core/knowledge/models/knowledge_definitions.dart';
export '../core/knowledge/models/knowledge_package.dart';
export '../core/knowledge/models/quantity.dart';
export '../core/knowledge/oerp/minimal_zip_reader.dart';
export '../core/knowledge/oerp/oerp_reader.dart';
