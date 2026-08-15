import 'settings_enums.dart';

/// Settings > Workspace (SDD-023): "Default Workspace, Recent
/// Workspaces, Window Behavior, Docking, Multi-monitor, Restore
/// Layout."
///
/// `recentWorkspaces` is always empty today — nothing in Studio tracks
/// workspace visit history yet — and `dockingEnabled`/`multiMonitorAware`
/// are stored placeholders (no docking or multi-monitor system exists).
/// See `docs/STUDIO_SETTINGS.md` Architectural Observations.
class WorkspaceSettings {
  const WorkspaceSettings({
    required this.defaultWorkspacePath,
    required this.recentWorkspacePaths,
    required this.windowBehavior,
    required this.dockingEnabled,
    required this.multiMonitorAware,
    required this.restoreLayoutOnStartup,
  });

  factory WorkspaceSettings.defaults() => const WorkspaceSettings(
    defaultWorkspacePath: '/',
    recentWorkspacePaths: [],
    windowBehavior: WindowBehaviorPreference.rememberSize,
    dockingEnabled: false,
    multiMonitorAware: false,
    restoreLayoutOnStartup: true,
  );

  /// A [StudioDestination.path] — kept as a plain string here so
  /// `lib/settings/` has no dependency on `lib/core/routing/`.
  final String defaultWorkspacePath;
  final List<String> recentWorkspacePaths;
  final WindowBehaviorPreference windowBehavior;
  final bool dockingEnabled;
  final bool multiMonitorAware;
  final bool restoreLayoutOnStartup;

  WorkspaceSettings copyWith({
    String? defaultWorkspacePath,
    List<String>? recentWorkspacePaths,
    WindowBehaviorPreference? windowBehavior,
    bool? dockingEnabled,
    bool? multiMonitorAware,
    bool? restoreLayoutOnStartup,
  }) {
    return WorkspaceSettings(
      defaultWorkspacePath: defaultWorkspacePath ?? this.defaultWorkspacePath,
      recentWorkspacePaths: recentWorkspacePaths ?? this.recentWorkspacePaths,
      windowBehavior: windowBehavior ?? this.windowBehavior,
      dockingEnabled: dockingEnabled ?? this.dockingEnabled,
      multiMonitorAware: multiMonitorAware ?? this.multiMonitorAware,
      restoreLayoutOnStartup: restoreLayoutOnStartup ?? this.restoreLayoutOnStartup,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultWorkspacePath': defaultWorkspacePath,
    'recentWorkspacePaths': recentWorkspacePaths,
    'windowBehavior': windowBehavior.name,
    'dockingEnabled': dockingEnabled,
    'multiMonitorAware': multiMonitorAware,
    'restoreLayoutOnStartup': restoreLayoutOnStartup,
  };

  factory WorkspaceSettings.fromJson(Map<String, dynamic> json) {
    final defaults = WorkspaceSettings.defaults();
    return WorkspaceSettings(
      defaultWorkspacePath: json['defaultWorkspacePath'] as String? ?? defaults.defaultWorkspacePath,
      recentWorkspacePaths:
          (json['recentWorkspacePaths'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          defaults.recentWorkspacePaths,
      windowBehavior: WindowBehaviorPreference.values.firstWhere(
        (value) => value.name == json['windowBehavior'],
        orElse: () => defaults.windowBehavior,
      ),
      dockingEnabled: json['dockingEnabled'] as bool? ?? defaults.dockingEnabled,
      multiMonitorAware: json['multiMonitorAware'] as bool? ?? defaults.multiMonitorAware,
      restoreLayoutOnStartup: json['restoreLayoutOnStartup'] as bool? ?? defaults.restoreLayoutOnStartup,
    );
  }
}
