/// One entry in the Engineering Project's shared recent-navigation
/// history (WORK_PACKAGE_025, ENGINE-TASK-000119 "Shared recent
/// history"). Recorded by every `goTo*` function in
/// `lib/shared/navigation/unified_navigation.dart`, regardless of which
/// workspace the navigation lands in — this is what makes history
/// shared *across* Knowledge Studio and Diagram Studio rather than each
/// workspace keeping its own separate list (the way the Search
/// Workspace's now-removed local `_history` used to).
class RecentHistoryEntry {
  const RecentHistoryEntry({
    required this.id,
    required this.label,
    required this.workspaceLabel,
    required this.route,
    required this.timestamp,
  });

  /// A stable identifier for the thing navigated to (an object id,
  /// relationship id, node id, ...) — not unique per history entry,
  /// since navigating to the same item twice records two entries.
  final String id;

  /// Human-readable label shown in the history list (e.g. an object's
  /// display name, a diagram node's name).
  final String label;

  /// The destination workspace's own label (`StudioDestination.label`),
  /// e.g. "Knowledge Studio", "Diagram Studio", "Validation".
  final String workspaceLabel;

  /// The `go_router` path navigated to (`StudioDestination.path`).
  final String route;

  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'workspaceLabel': workspaceLabel,
        'route': route,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RecentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RecentHistoryEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      workspaceLabel: json['workspaceLabel'] as String,
      route: json['route'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
