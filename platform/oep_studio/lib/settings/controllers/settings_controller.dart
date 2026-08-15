import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_enums.dart';
import '../models/settings_exception.dart';
import '../models/user_configuration.dart';
import '../services/settings_service.dart';

/// The Settings Workspace's own controller state (Work Package 017
/// STUDIO-TASK-000051): an in-memory *draft* [UserConfiguration] being
/// edited, alongside the last-persisted [savedConfiguration] it was
/// loaded (or last saved) from — [isModified] is a pure structural
/// comparison of the two, computed on demand rather than tracked as a
/// separate mutable flag.
class SettingsControllerState {
  const SettingsControllerState({
    required this.configuration,
    required this.savedConfiguration,
    required this.isLoading,
    this.errorMessage,
  });

  factory SettingsControllerState.initial() {
    final defaults = UserConfiguration.defaults();
    return SettingsControllerState(configuration: defaults, savedConfiguration: defaults, isLoading: true);
  }

  final UserConfiguration configuration;
  final UserConfiguration savedConfiguration;
  final bool isLoading;
  final String? errorMessage;

  bool get isModified => jsonEncode(configuration.toJson()) != jsonEncode(savedConfiguration.toJson());

  SettingsControllerState copyWith({
    UserConfiguration? configuration,
    UserConfiguration? savedConfiguration,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsControllerState(
      configuration: configuration ?? this.configuration,
      savedConfiguration: savedConfiguration ?? this.savedConfiguration,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// The Settings Workspace's controller (Work Package 017
/// STUDIO-TASK-000051; SDD-023). Deliberately a *separate* Riverpod
/// Notifier from `FoundationRuntimeNotifier` (the Connection Manager):
/// this controller owns the User Configuration draft itself (business
/// logic — load/edit/validate/save/reset/import/export), while the
/// Connection Manager only coordinates cross-cutting *navigation* state
/// for the Settings Workspace (current page, search query, a modified
/// flag other parts of the shell can read) — see
/// `docs/STUDIO_SETTINGS.md` Settings Architecture.
///
/// Widgets never call [SettingsService] directly; they only ever read
/// [SettingsControllerState.configuration] and call one of this
/// controller's update methods, one per leaf setting, so every field
/// mutation is independently testable and no page needs to know how
/// `UserConfiguration.copyWith` is structured.
class SettingsController extends Notifier<SettingsControllerState> {
  @override
  SettingsControllerState build() {
    Future.microtask(_load);
    return SettingsControllerState.initial();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final config = await SettingsService.load();
      state = SettingsControllerState(configuration: config, savedConfiguration: config, isLoading: false);
    } on SettingsException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  /// Re-reads the settings file from disk, discarding any in-memory
  /// draft (used by manual verification and by "Load").
  Future<void> reload() => _load();

  void _update(UserConfiguration Function(UserConfiguration current) transform) {
    state = state.copyWith(configuration: transform(state.configuration), clearError: true);
  }

  // ---- General ----------------------------------------------------
  void setLanguage(String value) => _update((c) => c.copyWith(general: c.general.copyWith(language: value)));
  void setRegion(String value) => _update((c) => c.copyWith(general: c.general.copyWith(region: value)));
  void setUnits(UnitSystem value) => _update((c) => c.copyWith(general: c.general.copyWith(units: value)));
  void setDateFormat(DateFormatPreference value) =>
      _update((c) => c.copyWith(general: c.general.copyWith(dateFormat: value)));
  void setTimeFormat(TimeFormatPreference value) =>
      _update((c) => c.copyWith(general: c.general.copyWith(timeFormat: value)));
  void setGeneralAutosave(bool value) => _update((c) => c.copyWith(general: c.general.copyWith(autosave: value)));
  void setStartupBehavior(StartupBehaviorPreference value) =>
      _update((c) => c.copyWith(general: c.general.copyWith(startupBehavior: value)));
  void setLoggingLevel(LoggingLevel value) => _update((c) => c.copyWith(general: c.general.copyWith(logging: value)));

  // ---- Appearance ---------------------------------------------------
  void setTheme(StudioThemePreference value) =>
      _update((c) => c.copyWith(appearance: c.appearance.copyWith(theme: value)));
  void setAccentColorHex(String value) =>
      _update((c) => c.copyWith(appearance: c.appearance.copyWith(accentColorHex: value)));
  void setDensity(UiDensity value) => _update((c) => c.copyWith(appearance: c.appearance.copyWith(density: value)));
  void setFontSize(double value) => _update((c) => c.copyWith(appearance: c.appearance.copyWith(fontSize: value)));
  void setIconSize(double value) => _update((c) => c.copyWith(appearance: c.appearance.copyWith(iconSize: value)));
  void setAnimationsEnabled(bool value) =>
      _update((c) => c.copyWith(appearance: c.appearance.copyWith(animationsEnabled: value)));
  void setWorkspaceScaling(double value) =>
      _update((c) => c.copyWith(appearance: c.appearance.copyWith(workspaceScaling: value)));

  // ---- Workspace ------------------------------------------------------
  void setDefaultWorkspacePath(String value) =>
      _update((c) => c.copyWith(workspace: c.workspace.copyWith(defaultWorkspacePath: value)));
  void setWindowBehavior(WindowBehaviorPreference value) =>
      _update((c) => c.copyWith(workspace: c.workspace.copyWith(windowBehavior: value)));
  void setDockingEnabled(bool value) =>
      _update((c) => c.copyWith(workspace: c.workspace.copyWith(dockingEnabled: value)));
  void setMultiMonitorAware(bool value) =>
      _update((c) => c.copyWith(workspace: c.workspace.copyWith(multiMonitorAware: value)));
  void setRestoreLayoutOnStartup(bool value) =>
      _update((c) => c.copyWith(workspace: c.workspace.copyWith(restoreLayoutOnStartup: value)));

  // ---- Repository -----------------------------------------------------
  void setDefaultRepositoryPath(String value) =>
      _update((c) => c.copyWith(repository: c.repository.copyWith(defaultRepositoryPath: value)));
  void setAutoOpenDefaultRepository(bool value) =>
      _update((c) => c.copyWith(repository: c.repository.copyWith(autoOpenDefaultRepository: value)));
  void setRepositoryBackupEnabled(bool value) =>
      _update((c) => c.copyWith(repository: c.repository.copyWith(backupEnabled: value)));
  void setRepositorySnapshotsEnabled(bool value) =>
      _update((c) => c.copyWith(repository: c.repository.copyWith(snapshotsEnabled: value)));
  void setRepositoryCacheEnabled(bool value) =>
      _update((c) => c.copyWith(repository: c.repository.copyWith(cacheEnabled: value)));
  void setValidationStrictness(ValidationStrictness value) =>
      _update((c) => c.copyWith(repository: c.repository.copyWith(validationStrictness: value)));

  // ---- Knowledge Studio --------------------------------------------
  void setKnowledgeStudioAutosave(bool value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(autosaveEnabled: value)));
  void setOcrOverlayVisibleByDefault(bool value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(ocrOverlayVisibleByDefault: value)));
  void setHighContrastEvidenceColors(bool value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(highContrastEvidenceColors: value)));
  void setDefaultZoom(double value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(defaultZoom: value)));
  void setContextDisplay(ContextDisplayMode value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(contextDisplay: value)));
  void setEntityDisplay(EntityDisplayMode value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(entityDisplay: value)));
  void setReviewSortPreference(ReviewSortPreference value) =>
      _update((c) => c.copyWith(knowledgeStudio: c.knowledgeStudio.copyWith(reviewSortPreference: value)));

  // ---- Artificial Intelligence (Work Package 018: providerId/modelId
  // now genuinely consumed by AnthropicProvider; API key lives in
  // CredentialStore (lib/core/security/), never here) --------------------
  void setAiEnabled(bool value) => _update((c) => c.copyWith(ai: c.ai.copyWith(enabled: value)));
  void setAiProviderId(String value) => _update((c) => c.copyWith(ai: c.ai.copyWith(providerId: value)));
  void setAiModelId(String value) => _update((c) => c.copyWith(ai: c.ai.copyWith(modelId: value)));
  void setAiTemperature(double value) => _update((c) => c.copyWith(ai: c.ai.copyWith(temperature: value)));
  void setAiTimeoutSeconds(int value) => _update((c) => c.copyWith(ai: c.ai.copyWith(timeoutSeconds: value)));
  void setAiContextWindowTokens(int value) =>
      _update((c) => c.copyWith(ai: c.ai.copyWith(contextWindowTokens: value)));
  void setAiMaxOutputTokens(int value) => _update((c) => c.copyWith(ai: c.ai.copyWith(maxOutputTokens: value)));
  void setAiReasoningDepth(ReasoningDepthPreference value) =>
      _update((c) => c.copyWith(ai: c.ai.copyWith(reasoningDepth: value)));
  void setAiPrivacyControlsEnabled(bool value) =>
      _update((c) => c.copyWith(ai: c.ai.copyWith(privacyControlsEnabled: value)));

  // ---- Plugins (inert — see PluginSettings) --------------------------
  void setPluginsEnabled(bool value) => _update((c) => c.copyWith(plugins: c.plugins.copyWith(pluginsEnabled: value)));

  // ---- Updates --------------------------------------------------------
  void setAutomaticUpdatesEnabled(bool value) =>
      _update((c) => c.copyWith(updates: c.updates.copyWith(automaticUpdatesEnabled: value)));
  void setUpdateChannel(UpdateChannel value) =>
      _update((c) => c.copyWith(updates: c.updates.copyWith(channel: value)));

  // ---- Diagnostics ------------------------------------------------
  void setPerformanceMonitoringEnabled(bool value) =>
      _update((c) => c.copyWith(diagnostics: c.diagnostics.copyWith(performanceMonitoringEnabled: value)));
  void setMemoryMonitoringEnabled(bool value) =>
      _update((c) => c.copyWith(diagnostics: c.diagnostics.copyWith(memoryMonitoringEnabled: value)));
  void setGpuMonitoringEnabled(bool value) =>
      _update((c) => c.copyWith(diagnostics: c.diagnostics.copyWith(gpuMonitoringEnabled: value)));

  // ---- Security -------------------------------------------------------
  void setCredentialStorageBackend(CredentialStorageBackend value) =>
      _update((c) => c.copyWith(security: c.security.copyWith(credentialStorageBackend: value)));
  void setPrivacyModeEnabled(bool value) =>
      _update((c) => c.copyWith(security: c.security.copyWith(privacyModeEnabled: value)));
  void setEncryptionAtRestEnabled(bool value) =>
      _update((c) => c.copyWith(security: c.security.copyWith(encryptionAtRestEnabled: value)));

  // ---- Persistence actions --------------------------------------------

  /// Validates and persists the current draft (STUDIO-TASK-000053
  /// "Save"). Returns `false` and records [SettingsControllerState.errorMessage]
  /// without changing [SettingsControllerState.savedConfiguration] if
  /// the draft is invalid — nothing invalid is ever written to disk.
  Future<bool> save() async {
    try {
      await SettingsService.save(state.configuration);
      state = state.copyWith(savedConfiguration: state.configuration, clearError: true);
      return true;
    } on SettingsException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return false;
    }
  }

  /// Discards the in-memory draft, reverting to [SettingsControllerState.savedConfiguration].
  void discardChanges() => state = state.copyWith(configuration: state.savedConfiguration, clearError: true);

  /// Resets to, and persists, [UserConfiguration.defaults]
  /// (STUDIO-TASK-000053 "Reset Defaults").
  Future<bool> resetToDefaults() async {
    try {
      final defaults = await SettingsService.resetToDefaults();
      state = SettingsControllerState(configuration: defaults, savedConfiguration: defaults, isLoading: false);
      return true;
    } on SettingsException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return false;
    }
  }

  /// "Export User Settings" (SDD-023 Import / Export) — never includes
  /// a secret, since no sub-model of [UserConfiguration] has one.
  String exportJson() => SettingsService.exportToJson(state.configuration);

  /// "Import User Settings". Replaces the in-memory draft only —
  /// callers decide whether to follow up with [save].
  Future<bool> importJson(String source) async {
    try {
      final imported = SettingsService.importFromJson(source);
      state = state.copyWith(configuration: imported, clearError: true);
      return true;
    } on SettingsException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return false;
    }
  }
}

final settingsControllerProvider = NotifierProvider<SettingsController, SettingsControllerState>(
  SettingsController.new,
);
