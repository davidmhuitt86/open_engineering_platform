/// Public surface for undoable Engineering Graph/Layout editing
/// (WORK_PACKAGE_021). See docs/GRAPH_EDITING.md and docs/UNDO_REDO.md.
///
/// WORK_PACKAGE_023 additions: wire editing ([SetWireRouteCommand] +
/// pure `WireEditing` — see `lib/diagrams/diagrams.dart`), annotations,
/// layers, placement tools (rotate/mirror/array/replace-symbol), and
/// editing constraints ([EditingConstraints]/`ConstraintMath`).
library;

export '../core/editing/command_history.dart';
export '../core/editing/commands/align_nodes_command.dart';
export '../core/editing/commands/array_place_command.dart';
export '../core/editing/commands/assign_layer_command.dart';
export '../core/editing/commands/change_node_category_command.dart';
export '../core/editing/commands/create_annotation_command.dart';
export '../core/editing/commands/create_group_command.dart';
export '../core/editing/commands/create_layer_command.dart';
export '../core/editing/commands/create_node_command.dart';
export '../core/editing/commands/create_relationship_command.dart';
export '../core/editing/commands/delete_annotation_command.dart';
export '../core/editing/commands/delete_layer_command.dart';
export '../core/editing/commands/delete_many_command.dart';
export '../core/editing/commands/delete_node_command.dart';
export '../core/editing/commands/delete_relationship_command.dart';
export '../core/editing/commands/distribute_nodes_command.dart';
export '../core/editing/commands/duplicate_node_command.dart';
export '../core/editing/commands/duplicate_selection_command.dart';
export '../core/editing/commands/mirror_nodes_command.dart';
export '../core/editing/commands/move_nodes_command.dart';
export '../core/editing/commands/paste_command.dart';
export '../core/editing/commands/reconnect_relationship_command.dart';
export '../core/editing/commands/rename_group_command.dart';
export '../core/editing/commands/rename_node_command.dart';
export '../core/editing/commands/replace_symbol_command.dart';
export '../core/editing/commands/resize_node_command.dart';
export '../core/editing/commands/rotate_nodes_command.dart';
export '../core/editing/commands/set_group_locked_command.dart';
export '../core/editing/commands/set_wire_route_command.dart';
export '../core/editing/commands/set_wire_segment_offsets_command.dart';
export '../core/editing/commands/ungroup_command.dart';
export '../core/editing/commands/update_annotation_command.dart';
export '../core/editing/commands/update_evidence_link_command.dart';
export '../core/editing/commands/update_layer_command.dart';
export '../core/editing/commands/update_node_metadata_command.dart';
export '../core/editing/commands/update_node_properties_command.dart';
export '../core/editing/commands/update_port_command.dart';
export '../core/editing/commands/update_relationship_properties_command.dart';
export '../core/editing/constraint_math.dart';
export '../core/editing/editing_command.dart';
export '../core/editing/editing_constraints.dart';
export '../core/editing/editing_service.dart';
export '../core/editing/editing_session.dart';
export '../core/editing/placement_math.dart';
