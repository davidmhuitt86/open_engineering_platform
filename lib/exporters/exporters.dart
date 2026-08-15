/// Public surface for the Export Engine (SDD-025/026). AP-DS-004 added
/// tabular-report rendering (CSV/Markdown/PDF) and diagram-drawing
/// rendering (PDF/SVG/PNG) — the vector rendering of the diagram itself
/// (symbols/wires/title block). Studio-side composition (Validation/
/// Reasoning report content, which needs Foundation/EIP data this
/// engine-only package cannot reach) remains future work — see
/// `docs/architecture/diagram_studio/` publishing documentation.
library;

export '../core/exporters/json/json_export_provider.dart';
export '../core/exporters/shared/export_request.dart';
export '../core/exporters/shared/export_result.dart';
export '../core/exporters/shared/tabular_report_renderer.dart';
export '../core/exporters/shared/tabular_report_pdf_renderer.dart';
export '../core/exporters/shared/diagram_print_scene.dart';
export '../core/exporters/pdf/diagram_pdf_renderer.dart';
export '../core/exporters/pdf/drawing_package_pdf_renderer.dart';
export '../core/exporters/pdf/pdf_export_provider.dart';
export '../core/exporters/svg/diagram_svg_renderer.dart';
export '../core/exporters/svg/svg_export_provider.dart';
export '../core/exporters/png/diagram_png_renderer.dart';
export '../core/exporters/png/png_export_provider.dart';
export '../core/publishing/models/title_block.dart';
export '../core/publishing/reports/tabular_report.dart';
export '../core/publishing/reports/bill_of_materials.dart';
export '../core/publishing/reports/wire_report.dart';
export '../core/publishing/reports/connector_report.dart';
export '../core/publishing/reports/harness_report.dart';
export '../core/publishing/reports/relationship_report.dart';
export '../core/publishing/reports/engineering_object_report.dart';
export '../core/interfaces/export_provider.dart';
