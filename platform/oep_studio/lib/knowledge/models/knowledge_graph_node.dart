import 'package:flutter/material.dart';

/// The kind of Knowledge Workspace artifact a [KnowledgeGraphNode]
/// represents (Work Package 011 STUDIO-TASK-000026: "Each node type
/// shall use a distinct icon."). Deliberately does **not** enumerate
/// Knowledge Candidate *types* separately (Procedure, Specification,
/// …) — a Procedure/Specification Candidate is still a
/// [KnowledgeGraphNodeKind.candidate] node; its distinct icon comes
/// from the underlying `KnowledgeCandidate.type.icon` (ten already-
/// distinct icons, Work Package 010), the same way a Source Material
/// node's icon comes from `SourceMaterial.type.icon`. This mirrors
/// this work package's Display list, which names "Procedure
/// Candidates"/"Specification Candidates" alongside "Knowledge
/// Candidates" as things to *visualize*, not as separate node
/// *kinds* — Relationship Candidates are the only listed item that
/// is explicitly excluded from being a node at all ("Relationship
/// Candidates remain edges").
enum KnowledgeGraphNodeKind { candidate, evidenceRegion, sourceMaterial }

/// One node in the Knowledge Session Graph (Work Package 011
/// STUDIO-TASK-000026) — a thin, display-only projection of an
/// existing Workspace artifact (a [KnowledgeCandidate], an
/// [EvidenceRegion], or a [SourceMaterial]). Carries no data beyond
/// what the graph itself needs to render and select; [id] always
/// equals the underlying artifact's own id, so selecting a node maps
/// directly back to the existing `selectKnowledgeCandidate`/
/// `selectEvidenceRegion`/`selectSourceMaterial` Connection Manager
/// methods — see `docs/KNOWLEDGE_GRAPH.md` § Selection Synchronization
/// for why no new "Current Graph Selection" field was introduced.
class KnowledgeGraphNode {
  const KnowledgeGraphNode({required this.id, required this.kind, required this.label, required this.icon});

  final String id;
  final KnowledgeGraphNodeKind kind;
  final String label;
  final IconData icon;
}
