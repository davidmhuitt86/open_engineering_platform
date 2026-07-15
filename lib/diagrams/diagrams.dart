/// Public surface for the View layer (SDD-024/025/026).
///
/// Diagram View is the first View — a read-only visualization of the
/// Engineering Graph. Future sibling Views (Harness, Diagnostic, Physical
/// Layout, Simulation, Print) will export from `lib/diagrams/` in the same
/// way, or from a renamed `lib/views/` barrel if a second View is added
/// before Phase 2 — see docs/ARCHITECTURE_DECISIONS.md ADR-003.
///
/// Layout ([DiagramLayoutState]/[LayoutProvider]) and routing
/// ([RoutingProvider]/[OrthogonalRoutingProvider]) were added in
/// WORK_PACKAGE_021 — see ADR-011 for why layout lives here and not on
/// the graph. Grid ([GridComputer]), alignment guides
/// ([AlignmentGuideComputer]), port references ([PortReference]), and
/// named-layout persistence ([JsonFileLayoutSerializer]) were added in
/// WORK_PACKAGE_022. Annotations ([DiagramAnnotation]), layers
/// ([DiagramLayer]), per-node transforms ([NodeTransform]), and manual
/// wire editing ([WireEditing]) were added in WORK_PACKAGE_023 — all
/// Diagram Layout siblings of position, never Engineering Graph data.
library;

export '../core/interfaces/layout_provider.dart';
export '../core/interfaces/routing_provider.dart';
export '../core/views/diagram/alignment_guide.dart';
export '../core/views/diagram/alignment_guide_computer.dart';
export '../core/views/diagram/diagram_annotation.dart';
export '../core/views/diagram/diagram_geometry.dart';
export '../core/views/diagram/diagram_hit_testing.dart';
export '../core/views/diagram/diagram_layer.dart';
export '../core/views/diagram/diagram_layout.dart';
export '../core/views/diagram/diagram_layout_state.dart';
export '../core/views/diagram/diagram_renderer.dart';
export '../core/views/diagram/diagram_scene.dart';
export '../core/views/diagram/diagram_view.dart';
export '../core/views/diagram/grid_computer.dart';
export '../core/views/diagram/grid_line.dart';
export '../core/views/diagram/in_memory_layout_provider.dart';
export '../core/views/diagram/json_file_layout_serializer.dart';
export '../core/views/diagram/node_transform.dart';
export '../core/views/diagram/orthogonal_routing_provider.dart';
export '../core/views/diagram/port_reference.dart';
export '../core/views/diagram/rect2d.dart';
export '../core/views/diagram/routing_context.dart';
export '../core/views/diagram/routing_request.dart';
export '../core/views/diagram/wire_editing.dart';
export '../core/views/view.dart';
