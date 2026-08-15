import 'settings_enums.dart';

/// Settings > Artificial Intelligence (SDD-023): "Enable AI, Provider,
/// Model, API Configuration, Local Server Configuration, Temperature,
/// Timeout, Context Window, Reasoning Depth, Privacy Controls, Test
/// Connection."
///
/// As of Work Package 018, `providerId`/`modelId` are genuinely
/// consumed by `AnthropicProvider` (`lib/knowledge/services/`) —
/// superseding Work Package 017's deliberate decoupling from
/// `AiProviderRegistry`, which was itself scoped "yet" pending the
/// first production provider. See `docs/STUDIO_SETTINGS.md` and
/// `docs/ANTHROPIC_PROVIDER.md` Architectural Observations.
///
/// **No API key or credential field exists on this model, and none
/// shall ever be added directly here** — SDD-023 Security: "AI
/// credentials shall never be stored inside Knowledge Sessions," and
/// this work package's own "Credentials shall never be written into
/// User Configuration, Repository data, or Knowledge Sessions." The
/// API key lives only in `CredentialStore` (`lib/core/security/`, OS
/// secure storage), entirely outside this model and outside
/// `SettingsService.exportToJson`.
class AiSettings {
  const AiSettings({
    required this.enabled,
    required this.providerId,
    required this.modelId,
    required this.temperature,
    required this.timeoutSeconds,
    required this.contextWindowTokens,
    required this.maxOutputTokens,
    required this.reasoningDepth,
    required this.privacyControlsEnabled,
  });

  factory AiSettings.defaults() => const AiSettings(
    enabled: false,
    providerId: 'mock',
    modelId: '',
    temperature: 0.7,
    timeoutSeconds: 120,
    contextWindowTokens: 8192,
    maxOutputTokens: 4096,
    reasoningDepth: ReasoningDepthPreference.standard,
    privacyControlsEnabled: true,
  );

  final bool enabled;
  final String providerId;
  final String modelId;
  final double temperature;
  final int timeoutSeconds;

  /// Informational only — Anthropic's context window is a fixed model
  /// property, not a request parameter, so this value is displayed but
  /// not sent to the provider. Distinct from [maxOutputTokens], which
  /// genuinely is a request parameter (`max_tokens`).
  final int contextWindowTokens;

  /// The maximum number of tokens a provider may generate in one
  /// response — Anthropic's Messages API requires this on every
  /// request (Work Package 018 STUDIO-TASK-000057: "Max Tokens").
  final int maxOutputTokens;
  final ReasoningDepthPreference reasoningDepth;
  final bool privacyControlsEnabled;

  AiSettings copyWith({
    bool? enabled,
    String? providerId,
    String? modelId,
    double? temperature,
    int? timeoutSeconds,
    int? contextWindowTokens,
    int? maxOutputTokens,
    ReasoningDepthPreference? reasoningDepth,
    bool? privacyControlsEnabled,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      reasoningDepth: reasoningDepth ?? this.reasoningDepth,
      privacyControlsEnabled: privacyControlsEnabled ?? this.privacyControlsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'providerId': providerId,
    'modelId': modelId,
    'temperature': temperature,
    'timeoutSeconds': timeoutSeconds,
    'contextWindowTokens': contextWindowTokens,
    'maxOutputTokens': maxOutputTokens,
    'reasoningDepth': reasoningDepth.name,
    'privacyControlsEnabled': privacyControlsEnabled,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AiSettings.defaults();
    return AiSettings(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      providerId: json['providerId'] as String? ?? defaults.providerId,
      modelId: json['modelId'] as String? ?? defaults.modelId,
      temperature: (json['temperature'] as num?)?.toDouble() ?? defaults.temperature,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? defaults.timeoutSeconds,
      contextWindowTokens: json['contextWindowTokens'] as int? ?? defaults.contextWindowTokens,
      maxOutputTokens: json['maxOutputTokens'] as int? ?? defaults.maxOutputTokens,
      reasoningDepth: ReasoningDepthPreference.values.firstWhere(
        (value) => value.name == json['reasoningDepth'],
        orElse: () => defaults.reasoningDepth,
      ),
      privacyControlsEnabled: json['privacyControlsEnabled'] as bool? ?? defaults.privacyControlsEnabled,
    );
  }
}
