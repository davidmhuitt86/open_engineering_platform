/// What kind of navigation just occurred (SDD-026: "Selection, Navigation,
/// Highlight, Evidence synchronization").
enum NavigationEventKind { focusNode, highlightPath, clearHighlight, evidenceSync }

/// Emitted by [NavigationService] when focus, highlighting, or
/// evidence-synchronization state changes. Consumers (e.g. a View, or the
/// Demonstration Host's Graph View panel) subscribe rather than poll.
class NavigationEvent {
  final NavigationEventKind kind;
  final String? focusedNodeId;
  final List<String> highlightedNodeIds;
  final List<String> highlightedRelationshipIds;
  final String? evidenceId;

  const NavigationEvent({
    required this.kind,
    this.focusedNodeId,
    this.highlightedNodeIds = const [],
    this.highlightedRelationshipIds = const [],
    this.evidenceId,
  });
}
