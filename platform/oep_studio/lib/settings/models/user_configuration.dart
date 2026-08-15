import 'ai_settings.dart';
import 'appearance_settings.dart';
import 'diagnostics_settings.dart';
import 'general_settings.dart';
import 'knowledge_studio_settings.dart';
import 'plugin_settings.dart';
import 'repository_settings.dart';
import 'security_settings.dart';
import 'update_settings.dart';
import 'workspace_settings.dart';

/// The root of Studio's **User Configuration** (Work Package 017
/// STUDIO-TASK-000053; SDD-023 Configuration Scope: "Applies to the
/// current user across every repository"). Repository Configuration,
/// Knowledge Session Configuration, and Runtime Configuration are
/// separate SDD-023 scopes with their own homes — Repository
/// Configuration would be stored with the repository (out of scope:
/// Foundation has no such API yet), Knowledge Session Configuration
/// already lives on `KnowledgeSessionRecord`, and Runtime Configuration
/// is `FoundationRuntimeState`'s own ephemeral fields. Only User
/// Configuration is persisted by this work package's `SettingsService`.
///
/// [schemaVersion] is written on every save and checked on every load —
/// see `SettingsMigrationService` for the migration engine this
/// enables.
class UserConfiguration {
  const UserConfiguration({
    required this.schemaVersion,
    required this.general,
    required this.appearance,
    required this.workspace,
    required this.repository,
    required this.knowledgeStudio,
    required this.ai,
    required this.plugins,
    required this.updates,
    required this.diagnostics,
    required this.security,
  });

  /// The schema version this build of Studio writes. Bump this, and add
  /// a corresponding step to `SettingsMigrationService`, whenever a
  /// field is added, renamed, or removed below.
  ///
  /// Version 2 (Work Package 018): added `AiSettings.maxOutputTokens`.
  static const currentSchemaVersion = 2;

  factory UserConfiguration.defaults() => UserConfiguration(
    schemaVersion: currentSchemaVersion,
    general: GeneralSettings.defaults(),
    appearance: AppearanceSettings.defaults(),
    workspace: WorkspaceSettings.defaults(),
    repository: RepositorySettings.defaults(),
    knowledgeStudio: KnowledgeStudioSettings.defaults(),
    ai: AiSettings.defaults(),
    plugins: PluginSettings.defaults(),
    updates: UpdateSettings.defaults(),
    diagnostics: DiagnosticsSettings.defaults(),
    security: SecuritySettings.defaults(),
  );

  final int schemaVersion;
  final GeneralSettings general;
  final AppearanceSettings appearance;
  final WorkspaceSettings workspace;
  final RepositorySettings repository;
  final KnowledgeStudioSettings knowledgeStudio;
  final AiSettings ai;
  final PluginSettings plugins;
  final UpdateSettings updates;
  final DiagnosticsSettings diagnostics;
  final SecuritySettings security;

  UserConfiguration copyWith({
    GeneralSettings? general,
    AppearanceSettings? appearance,
    WorkspaceSettings? workspace,
    RepositorySettings? repository,
    KnowledgeStudioSettings? knowledgeStudio,
    AiSettings? ai,
    PluginSettings? plugins,
    UpdateSettings? updates,
    DiagnosticsSettings? diagnostics,
    SecuritySettings? security,
  }) {
    return UserConfiguration(
      schemaVersion: currentSchemaVersion,
      general: general ?? this.general,
      appearance: appearance ?? this.appearance,
      workspace: workspace ?? this.workspace,
      repository: repository ?? this.repository,
      knowledgeStudio: knowledgeStudio ?? this.knowledgeStudio,
      ai: ai ?? this.ai,
      plugins: plugins ?? this.plugins,
      updates: updates ?? this.updates,
      diagnostics: diagnostics ?? this.diagnostics,
      security: security ?? this.security,
    );
  }

  /// The full, internal JSON representation — includes [schemaVersion].
  /// Never includes a secret: no sub-model above has a credential
  /// field, per SDD-023 Security.
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'general': general.toJson(),
    'appearance': appearance.toJson(),
    'workspace': workspace.toJson(),
    'repository': repository.toJson(),
    'knowledgeStudio': knowledgeStudio.toJson(),
    'ai': ai.toJson(),
    'plugins': plugins.toJson(),
    'updates': updates.toJson(),
    'diagnostics': diagnostics.toJson(),
    'security': security.toJson(),
  };

  /// Parses an **already-migrated** (current schema version) JSON map.
  /// Callers loading from disk must run [json] through
  /// `SettingsMigrationService.migrate` first — this factory does not
  /// migrate, it only tolerates individually missing fields by falling
  /// back to defaults, the same defensive style every other `fromJson`
  /// in this codebase already uses.
  factory UserConfiguration.fromJson(Map<String, dynamic> json) {
    final defaults = UserConfiguration.defaults();
    return UserConfiguration(
      schemaVersion: currentSchemaVersion,
      general: json['general'] == null
          ? defaults.general
          : GeneralSettings.fromJson(json['general'] as Map<String, dynamic>),
      appearance: json['appearance'] == null
          ? defaults.appearance
          : AppearanceSettings.fromJson(json['appearance'] as Map<String, dynamic>),
      workspace: json['workspace'] == null
          ? defaults.workspace
          : WorkspaceSettings.fromJson(json['workspace'] as Map<String, dynamic>),
      repository: json['repository'] == null
          ? defaults.repository
          : RepositorySettings.fromJson(json['repository'] as Map<String, dynamic>),
      knowledgeStudio: json['knowledgeStudio'] == null
          ? defaults.knowledgeStudio
          : KnowledgeStudioSettings.fromJson(json['knowledgeStudio'] as Map<String, dynamic>),
      ai: json['ai'] == null ? defaults.ai : AiSettings.fromJson(json['ai'] as Map<String, dynamic>),
      plugins: json['plugins'] == null
          ? defaults.plugins
          : PluginSettings.fromJson(json['plugins'] as Map<String, dynamic>),
      updates: json['updates'] == null
          ? defaults.updates
          : UpdateSettings.fromJson(json['updates'] as Map<String, dynamic>),
      diagnostics: json['diagnostics'] == null
          ? defaults.diagnostics
          : DiagnosticsSettings.fromJson(json['diagnostics'] as Map<String, dynamic>),
      security: json['security'] == null
          ? defaults.security
          : SecuritySettings.fromJson(json['security'] as Map<String, dynamic>),
    );
  }
}
