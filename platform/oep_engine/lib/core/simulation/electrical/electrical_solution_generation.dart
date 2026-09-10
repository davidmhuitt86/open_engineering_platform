/// PRODUCT-READINESS-004 Phase A, §12 — a solved electrical state's
/// generation/version identity.
///
/// [sequence] is the ONLY field ever consulted for ordering/staleness
/// ("solve B is newer than solve A"). It is a plain, monotonically
/// increasing integer assigned by an [ElectricalSolutionGenerationCounter]
/// — never derived from a wall-clock timestamp (§12/§13's explicit
/// determinism requirement: two solves of the same graph/operating state
/// must be able to produce equal generations' worth of DATA even if solved
/// at different wall-clock moments, and staleness comparisons must not
/// depend on clock resolution/skew). [solvedAt] is carried purely for
/// human/debugging display (e.g. "last solved 2s ago") and is explicitly
/// documented as NOT participating in [compareTo]/[isNewerThan].
class ElectricalSolutionGeneration implements Comparable<ElectricalSolutionGeneration> {
  const ElectricalSolutionGeneration({required this.sequence, required this.solvedAt});

  final int sequence;

  /// Informational only — see class doc comment.
  final DateTime solvedAt;

  bool isNewerThan(ElectricalSolutionGeneration other) => sequence > other.sequence;

  bool isOlderThan(ElectricalSolutionGeneration other) => sequence < other.sequence;

  @override
  int compareTo(ElectricalSolutionGeneration other) => sequence.compareTo(other.sequence);

  Map<String, Object?> toJson() => {
        'sequence': sequence,
        'solvedAt': solvedAt.toIso8601String(),
      };

  factory ElectricalSolutionGeneration.fromJson(Map<String, Object?> json) => ElectricalSolutionGeneration(
        sequence: json['sequence'] as int,
        solvedAt: DateTime.tryParse(json['solvedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  bool operator ==(Object other) =>
      other is ElectricalSolutionGeneration && other.sequence == sequence;

  @override
  int get hashCode => sequence.hashCode;

  @override
  String toString() => 'ElectricalSolutionGeneration(#$sequence)';
}

/// The smallest mechanism that can hand out monotonically increasing
/// [ElectricalSolutionGeneration]s — one instance per solver/session
/// lifetime (§12: "Establish the model now even if full request
/// correlation is implemented later"). Deliberately NOT a singleton/global
/// — a caller (a future solver, or a test) owns its own counter, so
/// generations from two independent solving contexts are never implicitly
/// comparable to each other (comparing generations only makes sense within
/// one counter's own sequence).
class ElectricalSolutionGenerationCounter {
  int _next = 0;

  ElectricalSolutionGeneration next({DateTime? at}) =>
      ElectricalSolutionGeneration(sequence: _next++, solvedAt: at ?? DateTime.now());
}
