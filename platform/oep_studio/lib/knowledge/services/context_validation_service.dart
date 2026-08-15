import '../models/candidate_validation_result.dart';
import '../models/context_validation_result.dart';
import '../models/engineering_context.dart';
import '../models/engineering_entity.dart';

/// Engineering Context Validation (Work Package 015
/// STUDIO-TASK-000044): "Detect: Empty contexts, Duplicate contexts,
/// Overlapping contexts, Orphaned entities, Invalid hierarchy.
/// Validation remains informational only." Pure — reads already-
/// detected contexts and entities, returns findings; never mutates a
/// context, never fixes anything it finds wrong.
abstract final class ContextValidationService {
  static Map<String, ContextValidationResult> computeValidation({
    required List<EngineeringContext> contexts,
    required List<EngineeringEntity> entities,
  }) {
    final byId = {for (final context in contexts) context.id: context};
    final duplicateCounts = <String, int>{};
    for (final context in contexts) {
      if (context.isIgnored) continue;
      duplicateCounts[_duplicateKey(context)] = (duplicateCounts[_duplicateKey(context)] ?? 0) + 1;
    }

    final results = <String, ContextValidationResult>{};
    for (final context in contexts) {
      final issues = <String>[];
      var severity = ValidationSeverity.ok;
      void flag(String message, ValidationSeverity level) {
        issues.add(message);
        if (level.index > severity.index) severity = level;
      }

      if (context.childEntityIds.isEmpty) {
        flag('This context has no child entities.', ValidationSeverity.warning);
      }

      if (!context.isIgnored && (duplicateCounts[_duplicateKey(context)] ?? 0) > 1) {
        flag(
          'Duplicate of another ${context.type.label} context with the same title and page range.',
          ValidationSeverity.warning,
        );
      }

      if (!context.isIgnored) {
        for (final other in contexts) {
          if (other.id == context.id || other.isIgnored || other.sourceId != context.sourceId) continue;
          if (context.parentContextId == other.id || other.parentContextId == context.id) continue;
          final overlaps = context.pageStart <= other.pageEnd && other.pageStart <= context.pageEnd;
          if (overlaps) {
            flag(
              'Overlaps with "${other.title}" (pages ${other.pageStart}-${other.pageEnd}) without a parent/child relationship.',
              ValidationSeverity.warning,
            );
            break;
          }
        }
      }

      final hierarchyIssue = _invalidHierarchy(context, byId);
      if (hierarchyIssue != null) {
        flag(hierarchyIssue, ValidationSeverity.error);
      }

      results[context.id] = ContextValidationResult(contextId: context.id, severity: severity, issues: issues);
    }
    return results;
  }

  /// Entities with no context claiming them at all — regardless of any
  /// claiming context's own accept/ignore status, since ignoring a
  /// context's *grouping* is a review judgment about the context, not
  /// a retroactive statement that its entities have no home.
  static Set<String> computeOrphanedEntityIds({
    required List<EngineeringContext> contexts,
    required List<EngineeringEntity> entities,
  }) {
    final claimed = <String>{for (final context in contexts) ...context.childEntityIds};
    return {for (final entity in entities) if (!claimed.contains(entity.id)) entity.id};
  }

  static String _duplicateKey(EngineeringContext context) =>
      '${context.sourceId}|${context.type.name}|${context.title}|${context.pageStart}|${context.pageEnd}';

  static String? _invalidHierarchy(EngineeringContext context, Map<String, EngineeringContext> byId) {
    final parentId = context.parentContextId;
    if (parentId == null) return null;
    final parent = byId[parentId];
    if (parent == null) {
      return 'This context\'s parent context no longer exists.';
    }
    if (parent.sourceId != context.sourceId) {
      return 'This context\'s parent belongs to a different source.';
    }
    if (context.pageStart < parent.pageStart || context.pageEnd > parent.pageEnd) {
      return 'This context\'s page range (${context.pageStart}-${context.pageEnd}) falls outside its parent\'s range (${parent.pageStart}-${parent.pageEnd}).';
    }
    // Cycle detection: walk the parent chain; a context should never
    // reach itself again.
    var current = parent;
    final visited = <String>{context.id};
    while (true) {
      if (!visited.add(current.id)) {
        return 'This context\'s parent chain contains a cycle.';
      }
      final nextParentId = current.parentContextId;
      if (nextParentId == null) break;
      final next = byId[nextParentId];
      if (next == null) break;
      current = next;
    }
    return null;
  }
}
