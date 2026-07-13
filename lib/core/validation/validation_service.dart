import '../graph/algorithms/graph_traversal.dart';
import '../graph/models/engineering_graph.dart';
import '../interfaces/symbol_provider.dart';
import '../interfaces/validation_provider.dart';
import 'validation_finding.dart';
import 'validation_report.dart';

/// Deterministic Engineering Graph validation (SDD-025/026).
///
/// Checks: missing/unknown symbols, broken relationships, duplicate
/// nodes/ports, floating nodes, evidence mapping. Report-only — never
/// mutates the graph it validates.
class ValidationService implements ValidationProvider {
  final SymbolProvider symbols;

  ValidationService({required this.symbols});

  @override
  ValidationReport validate(EngineeringGraph graph) {
    final findings = <ValidationFinding>[];

    findings.addAll(_checkSymbols(graph));
    findings.addAll(_checkRelationships(graph));
    findings.addAll(_checkDuplicateRepositoryMappings(graph));
    findings.addAll(_checkDuplicatePorts(graph));
    findings.addAll(_checkFloatingNodes(graph));
    findings.addAll(_checkEvidence(graph));

    return ValidationReport(findings: findings);
  }

  List<ValidationFinding> _checkSymbols(EngineeringGraph graph) {
    final findings = <ValidationFinding>[];
    for (final node in graph.nodes.values) {
      final symbolId = node.symbolId;
      if (symbolId == null) {
        findings.add(ValidationFinding(
          code: 'missing_symbol',
          severity: ValidationSeverity.warning,
          message: '${node.displayName} has no symbol assigned.',
          subjectId: node.id,
        ));
        continue;
      }
      if (symbols.lookup(symbolId) == null) {
        findings.add(ValidationFinding(
          code: 'unknown_symbol',
          severity: ValidationSeverity.warning,
          message:
              '${node.displayName} references unknown symbol "$symbolId".',
          subjectId: node.id,
        ));
      }
    }
    return findings;
  }

  List<ValidationFinding> _checkRelationships(EngineeringGraph graph) {
    final findings = <ValidationFinding>[];
    for (final r in graph.relationships.values) {
      if (!graph.nodes.containsKey(r.sourceNode)) {
        findings.add(ValidationFinding(
          code: 'broken_relationship',
          severity: ValidationSeverity.error,
          message:
              'Relationship ${r.id} references missing source node ${r.sourceNode}.',
          subjectId: r.id,
        ));
      }
      if (!graph.nodes.containsKey(r.targetNode)) {
        findings.add(ValidationFinding(
          code: 'broken_relationship',
          severity: ValidationSeverity.error,
          message:
              'Relationship ${r.id} references missing target node ${r.targetNode}.',
          subjectId: r.id,
        ));
      }
    }
    return findings;
  }

  List<ValidationFinding> _checkDuplicateRepositoryMappings(
    EngineeringGraph graph,
  ) {
    final findings = <ValidationFinding>[];
    final seen = <String, String>{};
    for (final node in graph.nodes.values) {
      final repoId = node.repositoryObjectId;
      if (repoId == null) continue;
      final existing = seen[repoId];
      if (existing != null) {
        findings.add(ValidationFinding(
          code: 'duplicate_node',
          severity: ValidationSeverity.error,
          message:
              'Nodes ${node.id} and $existing both map to Foundation object $repoId.',
          subjectId: node.id,
        ));
      } else {
        seen[repoId] = node.id;
      }
    }
    return findings;
  }

  List<ValidationFinding> _checkDuplicatePorts(EngineeringGraph graph) {
    final findings = <ValidationFinding>[];
    for (final node in graph.nodes.values) {
      final seen = <String>{};
      for (final port in node.ports) {
        if (!seen.add(port.id)) {
          findings.add(ValidationFinding(
            code: 'duplicate_port',
            severity: ValidationSeverity.error,
            message: '${node.displayName} declares port "${port.id}" more than once.',
            subjectId: node.id,
          ));
        }
      }
    }
    return findings;
  }

  List<ValidationFinding> _checkFloatingNodes(EngineeringGraph graph) {
    return GraphTraversal.isolatedNodes(graph).map((nodeId) {
      final node = graph.nodes[nodeId]!;
      return ValidationFinding(
        code: 'floating_node',
        severity: ValidationSeverity.info,
        message: '${node.displayName} has no relationships.',
        subjectId: nodeId,
      );
    }).toList();
  }

  List<ValidationFinding> _checkEvidence(EngineeringGraph graph) {
    final findings = <ValidationFinding>[];
    for (final node in graph.nodes.values) {
      for (final link in node.evidenceLinks) {
        if (link.sourceReference.trim().isEmpty) {
          findings.add(ValidationFinding(
            code: 'invalid_evidence_mapping',
            severity: ValidationSeverity.error,
            message:
                '${node.displayName} has an evidence link with no source reference.',
            subjectId: node.id,
          ));
        }
      }
    }
    return findings;
  }
}
