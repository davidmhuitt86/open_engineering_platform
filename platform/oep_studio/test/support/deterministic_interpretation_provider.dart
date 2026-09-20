import 'package:oep_studio/knowledge/inference/inference_record.dart';
import 'package:oep_studio/knowledge/interpretation/adapter/interpretation_provider.dart';
import 'package:oep_studio/knowledge/interpretation/adapter/interpretation_request.dart';
import 'package:oep_studio/knowledge/interpretation/adapter/provider_result.dart';

/// A deterministic test double for an [InterpretationProvider] (WP-EKE-018).
///
/// It is not a model: it returns exactly the result its caller controls. It
/// records the requests it receives, has no way to call ReferenceDiscovery, the
/// KnowledgeRuntime, package files, the Repository or a network, and identifies
/// itself explicitly as a test adapter.
class DeterministicTestInterpretationProvider
    implements InterpretationProvider {
  DeterministicTestInterpretationProvider(
    this._respond, {
    Set<InterpretationObjective>? supported,
  }) : supportedObjectives =
            supported ?? InterpretationObjective.values.toSet();

  final Future<ProviderResult> Function(
    InterpretationRequest request,
    bool Function()? isCancelled,
  ) _respond;

  /// Every request this provider was given, in order.
  final List<InterpretationRequest> received = [];

  @override
  final Set<InterpretationObjective> supportedObjectives;

  @override
  InferenceAdapterProvenance get identity => const InferenceAdapterProvenance(
        adapterId: 'test-adapter.deterministic',
        provider: 'test-double (not a model)',
      );

  @override
  Future<ProviderResult> interpret(
    InterpretationRequest request, {
    bool Function()? isCancelled,
  }) {
    received.add(request);
    return _respond(request, isCancelled);
  }

  /// Convenience: always returns [result].
  factory DeterministicTestInterpretationProvider.returning(
    ProviderResult result, {
    Set<InterpretationObjective>? supported,
  }) =>
      DeterministicTestInterpretationProvider(
        (request, cancelled) async => result,
        supported: supported,
      );
}
