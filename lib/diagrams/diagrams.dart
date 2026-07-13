/// Public surface for the View layer (SDD-024/025/026).
///
/// Diagram View is the first View — a read-only visualization of the
/// Engineering Graph. Future sibling Views (Harness, Diagnostic, Physical
/// Layout, Simulation, Print) will export from `lib/diagrams/` in the same
/// way, or from a renamed `lib/views/` barrel if a second View is added
/// before Phase 2 — see docs/ARCHITECTURE_DECISIONS.md ADR-003.
library;

export '../core/views/diagram/diagram_geometry.dart';
export '../core/views/diagram/diagram_layout.dart';
export '../core/views/diagram/diagram_renderer.dart';
export '../core/views/diagram/diagram_scene.dart';
export '../core/views/diagram/diagram_view.dart';
export '../core/views/view.dart';
