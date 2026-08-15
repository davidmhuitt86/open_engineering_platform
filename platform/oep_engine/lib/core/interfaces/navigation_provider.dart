import '../navigation/navigation_event.dart';

/// Selection/navigation/highlight/evidence-sync coordination (SDD-026
/// `NavigationEngine`).
abstract class NavigationProvider {
  Stream<NavigationEvent> get events;

  void focusNode(String nodeId);

  void highlightPath(List<String> nodeIds, List<String> relationshipIds);

  void clearHighlight();

  void syncEvidence(String evidenceId);
}
