import '../../inference/inference_record.dart';
import '../reference_context.dart';
import 'interpretation_request.dart';

/// WP-EKE-018: the constrained output schema an [InterpretationProvider]
/// returns. **It is untrusted input.** Nothing here is authoritative until the
/// adapter validates it into an `InferenceRecord`; the adapter builds source
/// identity, context identity, package/runtime identity, usage ids and
/// reference identity itself and never copies them from a provider.
///
/// The schema is typed and deliberately has no field for Engineering Objects,
/// relationships, repository operations, candidates, commits or acceptance. A
/// provider that emits one (through [ProviderResult.fromJson]) is rejected.
///
/// Constrained-vocabulary fields (`status`, evidence `type`, usage `purpose` /
/// `role`) are plain strings here on purpose: this is the untrusted boundary,
/// and an invalid value must be representable in order to be rejected
/// explicitly rather than made unrepresentable by a provider-side enum.

/// A provider raised a failure (or produced output that cannot be read). The
/// adapter records it as a FAILED inference; nothing is silently dropped.
class InterpretationProviderException implements Exception {
  final String message;
  const InterpretationProviderException(this.message);

  @override
  String toString() => 'InterpretationProviderException: $message';
}

/// Strict-parse failure of provider JSON (an unsupported schema or field).
class ProviderResultException extends InterpretationProviderException {
  final InterpretationFailureCode code;
  const ProviderResultException(this.code, super.message);
}

enum ProviderOutcome {
  completed,

  /// The provider itself says its output is incomplete.
  partial,

  /// The provider observed cancellation and returns what it had produced.
  cancelled,
}

/// A pointer to existing evidence. `type` is one of `evidenceRegion`,
/// `evidenceLink`, `ocrPage`, `knowledgeCandidate` (checked by the adapter).
class ProviderEvidenceRef {
  final String type;
  final String id;
  final int? page;

  const ProviderEvidenceRef({required this.type, required this.id, this.page});
}

/// A confidence exactly as the provider supplied it. `calibrated: true` is
/// rejected: no provider contract establishes calibration yet.
class ProviderConfidence {
  final double value;
  final String? basis;
  final bool calibrated;

  const ProviderConfidence({
    required this.value,
    this.basis,
    this.calibrated = false,
  });
}

class ProviderHypothesis {
  final String hypothesisId;
  final String category;
  final String proposedValue;
  final String? label;

  /// `proposed` or `rejected` (a provider's own considered-and-rejected
  /// alternative). `accepted`, or anything else, is rejected: acceptance is a
  /// human review outcome and never a provider claim.
  final String status;
  final String? statusReason;
  final List<ProviderEvidenceRef> evidence;

  /// Reference object ids from the supplied context.
  final List<String> referenceObjectIds;
  final ProviderConfidence? confidence;
  final String? rationale;

  const ProviderHypothesis({
    required this.hypothesisId,
    required this.category,
    required this.proposedValue,
    this.label,
    this.status = 'proposed',
    this.statusReason,
    this.evidence = const [],
    this.referenceObjectIds = const [],
    this.confidence,
    this.rationale,
  });
}

class ProviderStatement {
  final String statementId;
  final String text;
  final List<String> hypothesisIds;

  const ProviderStatement({
    required this.statementId,
    required this.text,
    this.hypothesisIds = const [],
  });
}

/// A declaration that a supplied context item was actually USED. The adapter
/// resolves [referenceObjectId] against the supplied context and constructs
/// the `ReferenceUsage` itself (identity, package/runtime, retrieval provenance
/// and symbol binding come from the context item, not from here).
class ProviderReferenceUsage {
  final String referenceObjectId;

  /// One of the `ReferenceRetrievalPurpose` wire names (checked by the adapter).
  final String purpose;

  /// `primary` or `supporting`.
  final String role;
  final String rationale;
  final List<String> evidenceRegionIds;
  final List<String> hypothesisIds;
  final List<String> statementIds;

  /// Which retrieval (query index) of the object was relied on; when null the
  /// object's first context item (lowest query index) is used.
  final int? queryIndex;

  /// An UNTRUSTED claim about the bound Engine symbol. It is checked against
  /// the context's binding view and rejected if it disagrees or if no binding
  /// exists; the adapter never accepts an invented mapping.
  final String? claimedEngineSymbolId;

  const ProviderReferenceUsage({
    required this.referenceObjectId,
    required this.purpose,
    this.role = 'supporting',
    required this.rationale,
    this.evidenceRegionIds = const [],
    this.hypothesisIds = const [],
    this.statementIds = const [],
    this.queryIndex,
    this.claimedEngineSymbolId,
  });
}

class ProviderResult {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;

  /// What the provider CLAIMS it received. The adapter only verifies these
  /// against the request; they are never copied into the record.
  final String? claimedContextDigest;
  final ReferenceContextIdentity? claimedPackage;
  final ProviderOutcome outcome;
  final List<ProviderHypothesis> hypotheses;
  final List<ProviderStatement> statements;
  final List<ProviderReferenceUsage> referenceUsage;
  final List<InferenceDiagnostic> warnings;
  final List<InferenceDiagnostic> errors;

  /// What Reference Knowledge the provider wanted but the supplied context did
  /// not contain. The adapter records it as an explicit condition and performs
  /// no retrieval of its own.
  final List<String> referenceContextInsufficient;

  const ProviderResult({
    this.schemaVersion = currentSchemaVersion,
    this.claimedContextDigest,
    this.claimedPackage,
    this.outcome = ProviderOutcome.completed,
    this.hypotheses = const [],
    this.statements = const [],
    this.referenceUsage = const [],
    this.warnings = const [],
    this.errors = const [],
    this.referenceContextInsufficient = const [],
  });

  /// Strictly parses a provider's JSON output. Any key the schema does not
  /// define (for example `engineeringObjects`, `repository`, `commit`,
  /// `candidates`, `autoAccept`) is rejected with `unsupportedProviderField`,
  /// never ignored and never treated as authoritative; a wrong or missing
  /// `schemaVersion` is rejected with `unsupportedProviderSchema`.
  factory ProviderResult.fromJson(Map<String, dynamic> json) {
    void only(Map<String, dynamic> m, Set<String> allowed, String where) {
      final extra = m.keys.where((k) => !allowed.contains(k)).toList()..sort();
      if (extra.isNotEmpty) {
        throw ProviderResultException(
          InterpretationFailureCode.unsupportedProviderField,
          'Unsupported field(s) in $where: ${extra.join(', ')}.',
        );
      }
    }

    only(
        json,
        const {
          'schemaVersion',
          'claimedContextDigest',
          'claimedPackage',
          'outcome',
          'hypotheses',
          'statements',
          'referenceUsage',
          'warnings',
          'errors',
          'referenceContextInsufficient',
        },
        'the provider result');
    final version = json['schemaVersion'];
    if (version is! int || version != currentSchemaVersion) {
      throw ProviderResultException(
        InterpretationFailureCode.unsupportedProviderSchema,
        'Provider result schemaVersion $version is unsupported '
        '(supported: $currentSchemaVersion).',
      );
    }

    List<Map<String, dynamic>> maps(String key) => [
          for (final e in (json[key] as List? ?? const []))
            e as Map<String, dynamic>,
        ];
    List<String> strings(Map<String, dynamic> m, String key) => [
          for (final e in (m[key] as List? ?? const [])) e as String,
        ];
    List<InferenceDiagnostic> diagnostics(String key) => [
          for (final d in maps(key))
            InferenceDiagnostic(
              code: d['code'] as String? ?? '',
              message: d['message'] as String? ?? '',
            ),
        ];

    final outcomeName =
        json['outcome'] as String? ?? ProviderOutcome.completed.name;
    final outcome = ProviderOutcome.values.where((o) => o.name == outcomeName);
    if (outcome.isEmpty) {
      throw ProviderResultException(
        InterpretationFailureCode.unsupportedProviderField,
        'Unknown provider outcome "$outcomeName".',
      );
    }

    final hypotheses = <ProviderHypothesis>[];
    for (final h in maps('hypotheses')) {
      only(
          h,
          const {
            'hypothesisId',
            'category',
            'proposedValue',
            'label',
            'status',
            'statusReason',
            'evidence',
            'referenceObjectIds',
            'confidence',
            'rationale',
          },
          'a hypothesis');
      final c = h['confidence'] as Map<String, dynamic>?;
      if (c != null) {
        only(c, const {'value', 'basis', 'calibrated'}, 'a confidence');
      }
      hypotheses.add(
        ProviderHypothesis(
          hypothesisId: h['hypothesisId'] as String? ?? '',
          category: h['category'] as String? ?? '',
          proposedValue: h['proposedValue'] as String? ?? '',
          label: h['label'] as String?,
          status: h['status'] as String? ?? 'proposed',
          statusReason: h['statusReason'] as String?,
          evidence: [
            for (final e in (h['evidence'] as List? ?? const []))
              ProviderEvidenceRef(
                type: (e as Map<String, dynamic>)['type'] as String? ?? '',
                id: e['id'] as String? ?? '',
                page: e['page'] as int?,
              ),
          ],
          referenceObjectIds: strings(h, 'referenceObjectIds'),
          confidence: c == null
              ? null
              : ProviderConfidence(
                  value: (c['value'] as num).toDouble(),
                  basis: c['basis'] as String?,
                  calibrated: c['calibrated'] as bool? ?? false,
                ),
          rationale: h['rationale'] as String?,
        ),
      );
    }

    final statements = <ProviderStatement>[];
    for (final s in maps('statements')) {
      only(s, const {'statementId', 'text', 'hypothesisIds'}, 'a statement');
      statements.add(
        ProviderStatement(
          statementId: s['statementId'] as String? ?? '',
          text: s['text'] as String? ?? '',
          hypothesisIds: strings(s, 'hypothesisIds'),
        ),
      );
    }

    final usages = <ProviderReferenceUsage>[];
    for (final u in maps('referenceUsage')) {
      only(
          u,
          const {
            'referenceObjectId',
            'purpose',
            'role',
            'rationale',
            'evidenceRegionIds',
            'hypothesisIds',
            'statementIds',
            'queryIndex',
            'claimedEngineSymbolId',
          },
          'a reference usage');
      usages.add(
        ProviderReferenceUsage(
          referenceObjectId: u['referenceObjectId'] as String? ?? '',
          purpose: u['purpose'] as String? ?? '',
          role: u['role'] as String? ?? 'supporting',
          rationale: u['rationale'] as String? ?? '',
          evidenceRegionIds: strings(u, 'evidenceRegionIds'),
          hypothesisIds: strings(u, 'hypothesisIds'),
          statementIds: strings(u, 'statementIds'),
          queryIndex: u['queryIndex'] as int?,
          claimedEngineSymbolId: u['claimedEngineSymbolId'] as String?,
        ),
      );
    }

    return ProviderResult(
      schemaVersion: version,
      claimedContextDigest: json['claimedContextDigest'] as String?,
      claimedPackage: json['claimedPackage'] == null
          ? null
          : ReferenceContextIdentity.fromJson(
              json['claimedPackage'] as Map<String, dynamic>),
      outcome: outcome.first,
      hypotheses: hypotheses,
      statements: statements,
      referenceUsage: usages,
      warnings: diagnostics('warnings'),
      errors: diagnostics('errors'),
      referenceContextInsufficient: [
        for (final e
            in (json['referenceContextInsufficient'] as List? ?? const []))
          e as String,
      ],
    );
  }
}
