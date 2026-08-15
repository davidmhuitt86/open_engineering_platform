import 'dart:io';
import 'dart:math';

import '../../core/models/relationship_type.dart';
import '../models/candidate_validation_result.dart';
import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/knowledge_session.dart';
import '../models/knowledge_session_record.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/procedure_step.dart';
import '../models/relationship_candidate.dart';
import '../models/session_status.dart';
import '../models/source_material.dart';
import '../models/specification_details.dart';
import 'knowledge_session_storage.dart';

/// Pure validation and ID-generation rules for the Knowledge Curation
/// workflow (Work Package 007/008). Commit planning/conversion/
/// transaction logic lives in `CommitPlanService`/
/// `CommitConversionService`/`CommitTransactionService` (Work Package
/// 012) instead of here — kept separate since none of the three need
/// this class's session/candidate/relationship-candidate validation
/// rules, and commit logic is substantial enough on its own to warrant
/// its own services rather than growing this one further.
///
/// Holds no state of its own — `FoundationRuntimeNotifier` (the
/// Connection Manager) is the sole owner of session/candidate state,
/// per the Architecture Rules both work packages restate ("The
/// Connection Manager owns session state" / "coordinates state only";
/// "Validation belongs in services"). This class exists so that
/// ownership doesn't require reimplementing engineering rules inline
/// in the notifier, and so "no engineering logic shall exist inside
/// widgets" has somewhere to live outside both widgets and the
/// notifier itself.
abstract final class KnowledgeSessionService {
  static final _random = Random();

  /// The forward sequence Session Workflow states may advance through.
  /// `Cancelled` is reachable from any of these but is not part of the
  /// forward sequence itself.
  static const _forwardSequence = [
    SessionStatus.created,
    SessionStatus.preparing,
    SessionStatus.reviewing,
    SessionStatus.readyToCommit,
  ];

  /// An identifier unique enough for a single Studio installation's
  /// sessions — not a repository-durable ID (no commit exists yet to
  /// assign one).
  static String generateId(String prefix) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$prefix-$millis-$suffix';
  }

  /// Validates a new session's name and repository assignment (Error
  /// Handling: "Invalid session names ... Missing repository"). Throws
  /// [KnowledgeValidationException] with a professional, user-facing
  /// message on failure.
  static void validateNewSession({required String name, required String repositoryName}) {
    if (name.trim().isEmpty) {
      throw const KnowledgeValidationException('Session name cannot be empty.');
    }
    if (repositoryName.trim().isEmpty) {
      throw const KnowledgeValidationException('Select a repository for this session before creating it.');
    }
  }

  /// Validates a Knowledge Candidate's name against a session's
  /// existing candidates (Error Handling: "Duplicate proposal names"),
  /// case-insensitively. [excludingId] excludes a candidate (the one
  /// being edited) from the duplicate check against itself.
  static void validateCandidateName(
    String name,
    List<KnowledgeCandidate> existingCandidates, {
    String? excludingId,
  }) {
    if (name.trim().isEmpty) {
      throw const KnowledgeValidationException('Candidate name cannot be empty.');
    }
    final normalized = name.trim().toLowerCase();
    final duplicate = existingCandidates.any(
      (candidate) => candidate.id != excludingId && candidate.name.trim().toLowerCase() == normalized,
    );
    if (duplicate) {
      throw KnowledgeValidationException('A candidate named "${name.trim()}" already exists in this session.');
    }
  }

  /// Validates a session status transition, per the Session Workflow
  /// (Created → Preparing → Reviewing → Ready to Commit, or →
  /// Cancelled from any non-cancelled state). Throws
  /// [KnowledgeValidationException] for any other transition (e.g.
  /// skipping a stage, or advancing a Cancelled session).
  static void validateStatusTransition(SessionStatus from, SessionStatus to) {
    if (to == SessionStatus.cancelled) {
      if (from == SessionStatus.cancelled) {
        throw const KnowledgeValidationException('This session is already cancelled.');
      }
      return;
    }
    final fromIndex = _forwardSequence.indexOf(from);
    final toIndex = _forwardSequence.indexOf(to);
    if (fromIndex == -1 || toIndex != fromIndex + 1) {
      throw KnowledgeValidationException('Cannot move a session from "${from.label}" to "${to.label}".');
    }
  }

  /// Validates a relationship candidate's endpoints (Work Package 008
  /// STUDIO-TASK-000017 Validation: "Source and Target must exist.
  /// Self-reference prohibited."). Duplicate relationships are *warned*
  /// (see [isDuplicateRelationshipCandidate]), not rejected here — the
  /// work package distinguishes "prohibited" from "warned".
  static void validateRelationshipCandidate({
    required String sourceCandidateId,
    required String targetCandidateId,
    required List<KnowledgeCandidate> existingCandidates,
  }) {
    if (sourceCandidateId == targetCandidateId) {
      throw const KnowledgeValidationException('A relationship cannot connect a candidate to itself.');
    }
    final ids = existingCandidates.map((candidate) => candidate.id).toSet();
    if (!ids.contains(sourceCandidateId) || !ids.contains(targetCandidateId)) {
      throw const KnowledgeValidationException('Both the source and target candidate must exist in this session.');
    }
  }

  /// Whether a relationship candidate with the same source, target, and
  /// type already exists (Work Package 008: "Duplicate relationships
  /// warned"). [excludingId] excludes the relationship being edited
  /// from matching against itself.
  static bool isDuplicateRelationshipCandidate({
    required String? sourceCandidateId,
    required String? targetCandidateId,
    required RelationshipType type,
    required List<RelationshipCandidate> existingRelationships,
    String? excludingId,
  }) {
    if (sourceCandidateId == null || targetCandidateId == null) return false;
    return existingRelationships.any(
      (relationship) =>
          relationship.id != excludingId &&
          relationship.sourceCandidateId == sourceCandidateId &&
          relationship.targetCandidateId == targetCandidateId &&
          relationship.type == type,
    );
  }

  /// Validates an Evidence Region's label (Work Package 009
  /// STUDIO-TASK-000020 Evidence Browser: "Support: Rename"). Throws
  /// [KnowledgeValidationException] for an empty label — regions are
  /// always created with an auto-generated default label (see
  /// `FoundationRuntimeNotifier.createEvidenceRegion`), so an empty
  /// label can only occur via Rename, not initial creation.
  static void validateEvidenceRegionLabel(String label) {
    if (label.trim().isEmpty) {
      throw const KnowledgeValidationException('Region label cannot be empty.');
    }
  }

  /// Whether a link between [candidateId] and [regionId] already exists
  /// (Work Package 009 STUDIO-TASK-000021: "One candidate may reference
  /// multiple regions. One region may support multiple candidates.") —
  /// used to keep linking idempotent rather than creating duplicate
  /// [EvidenceLink]s for the same pair.
  static bool isEvidenceLinked({
    required String candidateId,
    required String regionId,
    required List<EvidenceLink> existingLinks,
  }) {
    return existingLinks.any((link) => link.candidateId == candidateId && link.regionId == regionId);
  }

  /// Validates a Procedure Step's title (Work Package 010
  /// STUDIO-TASK-000023). Throws [KnowledgeValidationException] for an
  /// empty title.
  static void validateProcedureStepTitle(String title) {
    if (title.trim().isEmpty) {
      throw const KnowledgeValidationException('Step title cannot be empty.');
    }
  }

  /// Validates a Specification's value and unit (Work Package 010
  /// STUDIO-TASK-000024 Error Handling: "Invalid specifications, Invalid
  /// units"). Throws [KnowledgeValidationException] with a professional
  /// message for either an empty value or an empty unit.
  static void validateSpecificationDetails({required String value, required String unit}) {
    if (value.trim().isEmpty) {
      throw const KnowledgeValidationException('Specification value cannot be empty.');
    }
    if (unit.trim().isEmpty) {
      throw const KnowledgeValidationException('Specification unit cannot be empty.');
    }
  }

  /// Computes a [CandidateValidationResult] for every candidate in the
  /// session (Work Package 010 STUDIO-TASK-000025: "Display validation
  /// status for every Knowledge Candidate."). Pure — takes a snapshot,
  /// returns a value, never mutates [candidates] or anything else ("
  /// Validation shall never modify candidate data"), the same
  /// derived-not-stored discipline `CommitPlanService.computeCommitPlan`
  /// (Work Package 012) also follows.
  ///
  /// Checks, per candidate:
  /// - **Duplicate candidate names**: another candidate in the session
  ///   shares its name (case-insensitively, trimmed) — an `error`. This
  ///   is deliberately *not* rejected at creation/duplication time the
  ///   way [validateCandidateName] rejects it for New/Edit — the
  ///   Candidate List's "Duplicate" action (Work Package 010) is meant
  ///   to allow same-named copies, surfaced here instead as a
  ///   non-blocking finding.
  /// - **Missing evidence**: no [EvidenceLink] references this
  ///   candidate — a `warning` ("Candidates without evidence shall
  ///   display a validation warning").
  /// - **Missing required fields** / **empty procedures**: a Procedure
  ///   candidate with zero [ProcedureStep]s (`warning`); a Specification
  ///   candidate with no [SpecificationDetails], or an empty value/unit
  ///   (`error` — a Specification's Type/Value/Unit are its defining
  ///   content).
  /// - **Invalid relationships**: a [RelationshipCandidate] connecting
  ///   this candidate to a candidate that no longer exists (`error`) —
  ///   the same dangling-reference concern `CommitPlanService` guards
  ///   against separately when building a Commit Plan, repeated
  ///   per-candidate here since this method's whole purpose is a
  ///   per-candidate view.
  /// - **Orphaned procedure steps**: for a Procedure candidate, any of
  ///   its steps referencing a Knowledge Candidate or Evidence Region
  ///   that no longer exists (`warning`) — read as "a step whose
  ///   reference is now orphaned", not "a step disconnected from its
  ///   parent candidate" (the latter cannot occur through this
  ///   notifier's own API, since deleting a candidate cascades to its
  ///   steps the same way it already cascades to relationship
  ///   candidates and evidence links).
  static Map<String, CandidateValidationResult> computeCandidateValidation({
    required List<KnowledgeCandidate> candidates,
    required List<RelationshipCandidate> relationshipCandidates,
    required List<EvidenceLink> evidenceLinks,
    required List<EvidenceRegion> evidenceRegions,
    required List<ProcedureStep> procedureSteps,
    required List<SpecificationDetails> specificationDetails,
  }) {
    final candidateIds = candidates.map((candidate) => candidate.id).toSet();
    final regionIds = evidenceRegions.map((region) => region.id).toSet();
    final nameCounts = <String, int>{};
    for (final candidate in candidates) {
      final key = candidate.name.trim().toLowerCase();
      nameCounts[key] = (nameCounts[key] ?? 0) + 1;
    }

    final results = <String, CandidateValidationResult>{};
    for (final candidate in candidates) {
      final issues = <String>[];
      var severity = ValidationSeverity.ok;
      void flag(String message, ValidationSeverity level) {
        issues.add(message);
        if (level == ValidationSeverity.error) {
          severity = ValidationSeverity.error;
        } else if (severity == ValidationSeverity.ok) {
          severity = ValidationSeverity.warning;
        }
      }

      final nameKey = candidate.name.trim().toLowerCase();
      if ((nameCounts[nameKey] ?? 0) > 1) {
        flag('Another candidate in this session has the same name.', ValidationSeverity.error);
      }

      if (!evidenceLinks.any((link) => link.candidateId == candidate.id)) {
        flag('No evidence is linked to this candidate.', ValidationSeverity.warning);
      }

      if (candidate.type == KnowledgeCandidateType.procedure) {
        final steps = procedureSteps.where((step) => step.candidateId == candidate.id).toList();
        if (steps.isEmpty) {
          flag('This procedure has no steps.', ValidationSeverity.warning);
        } else {
          final hasOrphanedReference = steps.any(
            (step) =>
                step.referencedCandidateIds.any((id) => !candidateIds.contains(id)) ||
                step.referencedRegionIds.any((id) => !regionIds.contains(id)),
          );
          if (hasOrphanedReference) {
            flag('One or more procedure steps reference evidence or a candidate that no longer exists.', ValidationSeverity.warning);
          }
        }
      }

      if (candidate.type == KnowledgeCandidateType.specification) {
        final details = specificationDetails.where((entry) => entry.candidateId == candidate.id);
        if (details.isEmpty) {
          flag('This specification is missing Type, Value, and Unit.', ValidationSeverity.error);
        } else {
          final entry = details.first;
          if (entry.value.trim().isEmpty) flag('Specification value is missing.', ValidationSeverity.error);
          if (entry.unit.trim().isEmpty) flag('Specification unit is missing.', ValidationSeverity.error);
        }
      }

      for (final relationship in relationshipCandidates) {
        final involvesCandidate =
            relationship.sourceCandidateId == candidate.id || relationship.targetCandidateId == candidate.id;
        if (!involvesCandidate) continue;
        final otherId = relationship.sourceCandidateId == candidate.id
            ? relationship.targetCandidateId
            : relationship.sourceCandidateId;
        if (!candidateIds.contains(otherId)) {
          flag('A relationship references a candidate that no longer exists.', ValidationSeverity.error);
        }
      }

      results[candidate.id] = CandidateValidationResult(candidateId: candidate.id, severity: severity, issues: issues);
    }
    return results;
  }

  /// Builds the record for a duplicated session (Work Package 008
  /// Session Browser: "Duplicate") — a fresh ID/name/timestamps, the
  /// same candidates/relationship candidates/review decisions, and
  /// sources whose [SourceMaterial.localPath] is remapped from the
  /// original session's storage directory to the new one (the actual
  /// file copy happens separately via
  /// `KnowledgeSessionStorage.duplicateSourceFiles`, since this method
  /// is pure and performs no I/O).
  static KnowledgeSessionRecord buildDuplicate(KnowledgeSessionRecord original, {required String author}) {
    final newId = generateId('session');
    final now = DateTime.now();
    final newSourcesDir = KnowledgeSessionStorage.sourcesDirectory(newId).path;
    final remappedSources = [
      for (final source in original.sources)
        SourceMaterial(
          id: source.id,
          originalFileName: source.originalFileName,
          localPath: '$newSourcesDir${Platform.pathSeparator}${source.localPath.split(Platform.pathSeparator).last}',
          type: source.type,
          sizeBytes: source.sizeBytes,
          importDate: source.importDate,
          addedBy: source.addedBy,
        ),
    ];
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: newId,
        name: 'Copy of ${original.session.name}',
        repositoryName: original.session.repositoryName,
        author: author,
        description: original.session.description,
        createdTime: now,
        lastModified: now,
        status: SessionStatus.created,
      ),
      candidates: original.candidates,
      relationshipCandidates: original.relationshipCandidates,
      sources: remappedSources,
      reviewDecisions: original.reviewDecisions,
      evidenceRegions: original.evidenceRegions,
      evidenceLinks: original.evidenceLinks,
      pageSelections: original.pageSelections,
      procedureSteps: original.procedureSteps,
      specificationDetails: original.specificationDetails,
      // Carried over unchanged, same as every other list above —
      // including committed candidates' own committedObjectId (also
      // carried over unchanged). A duplicate's "already committed"
      // candidates therefore still read as committed: the underlying
      // Foundation object genuinely already exists, so treating a
      // duplicate's copy as eligible to commit again would create a
      // second Foundation object for what is, at the moment of
      // duplication, identical candidate data. See
      // `docs/REPOSITORY_COMMIT.md` § Architectural Observations.
      commitReports: original.commitReports,
      // Also carried over unchanged: `File.copy` (`SourceMaterialService.attach`'s
      // duplication path) produces byte-identical copies, so each
      // result's `sourceFingerprint` (a content hash, not a file-system-
      // metadata one) still matches the duplicate's copied files —
      // "Reopening a session shall not rerun OCR" extends naturally to
      // "duplicating one shouldn't either" when nothing actually
      // changed. See `docs/OCR_PIPELINE.md` § OCR Cache.
      ocrPageResults: original.ocrPageResults,
      // Same reasoning as ocrPageResults directly above: each entity's
      // own sourceFingerprint still matches the duplicate's byte-
      // identical copied files, so re-extraction is unnecessary, and
      // carrying accepted/ignored entities over unchanged means a
      // duplicate's already-accepted entities correctly still point at
      // the same (also duplicated-unchanged) Knowledge Candidate.
      engineeringEntities: original.engineeringEntities,
      // Same reasoning again: contexts are keyed off a combined OCR
      // fingerprint that still matches the duplicate's byte-identical
      // copied files, so carrying them over unchanged (including
      // accepted/ignored status and parent/child links) is correct,
      // not merely convenient.
      engineeringContexts: original.engineeringContexts,
      // Same reasoning again: AI Suggestions are keyed off a combined
      // fingerprint over OCR/entity/context evidence that still
      // matches the duplicate's byte-identical copied files, so
      // carrying them over unchanged (including accept/edit/reject/
      // defer status and any created Candidate link) is correct.
      aiSuggestions: original.aiSuggestions,
    );
  }
}
