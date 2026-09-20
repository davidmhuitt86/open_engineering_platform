import '../../inference/inference_record.dart';
import 'interpretation_request.dart';
import 'provider_result.dart';

/// WP-EKE-018: the interpreter behind the constrained adapter. A provider may
/// be a deterministic test double, a future LLM, a local or multimodal model,
/// or a future vision system; none is implemented here and no vendor, network
/// call, API key or prompt format is assumed.
///
/// A provider is an interpreter only. It receives an [InterpretationRequest]
/// (evidence plus the authoritative Reference Context) and returns an
/// untrusted [ProviderResult]. It knows nothing of the Foundation bridge, the
/// Repository, `CommitPlanService`, Engineering Graph mutation, persistence,
/// `ReferenceDiscovery` or the Reference package.
///
/// Relation to the older `AiProvider` (WP-016 / SDD-022): that interface is a
/// plain-text `complete(AiRequest) -> AiResponse.rawText` completion whose
/// output is parsed into `AiSuggestion`s with a candidate-creation path. It is
/// too broad and untyped for this boundary and is deliberately not reused. A
/// future model-backed provider can implement this interface by wrapping an
/// `AiProvider`: render the structured request, parse the text into a
/// [ProviderResult] via `ProviderResult.fromJson`, and let the adapter validate
/// it, without changing the authority model.
abstract interface class InterpretationProvider {
  /// What the provider declares about itself (adapter id, optional provider,
  /// model name/version, prompt version). Missing fields stay missing; the
  /// adapter does not fabricate them.
  InferenceAdapterProvenance get identity;

  /// The objectives this provider can attempt. The adapter rejects a request
  /// for any other objective (`unsupportedObjective`).
  Set<InterpretationObjective> get supportedObjectives;

  /// Interprets [request]. [isCancelled], when supplied, returns true once the
  /// inference has been cancelled; a provider should then stop and may return a
  /// `ProviderOutcome.cancelled` result containing what it had already
  /// produced. Throw [InterpretationProviderException] to report failure.
  Future<ProviderResult> interpret(
    InterpretationRequest request, {
    bool Function()? isCancelled,
  });
}
