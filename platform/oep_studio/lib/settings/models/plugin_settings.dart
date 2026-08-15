/// Settings > Plugins (SDD-023): "Installed Plugins, Enable, Disable,
/// Permissions, Updates, Marketplace." Per this work package's explicit
/// instruction ("Do not implement Plugins"), this model is entirely
/// inert: `installedPluginIds` is always empty (no install mechanism
/// exists) and `pluginsEnabled` is an unwired master-toggle placeholder.
/// Real plugins register their own settings pages with the
/// `SettingsRegistry` in a future work package (SDD-023 Plugin
/// Registration) — this model does not change when that happens.
class PluginSettings {
  const PluginSettings({required this.pluginsEnabled, required this.installedPluginIds});

  factory PluginSettings.defaults() => const PluginSettings(pluginsEnabled: false, installedPluginIds: []);

  final bool pluginsEnabled;
  final List<String> installedPluginIds;

  PluginSettings copyWith({bool? pluginsEnabled, List<String>? installedPluginIds}) {
    return PluginSettings(
      pluginsEnabled: pluginsEnabled ?? this.pluginsEnabled,
      installedPluginIds: installedPluginIds ?? this.installedPluginIds,
    );
  }

  Map<String, dynamic> toJson() => {'pluginsEnabled': pluginsEnabled, 'installedPluginIds': installedPluginIds};

  factory PluginSettings.fromJson(Map<String, dynamic> json) {
    final defaults = PluginSettings.defaults();
    return PluginSettings(
      pluginsEnabled: json['pluginsEnabled'] as bool? ?? defaults.pluginsEnabled,
      installedPluginIds:
          (json['installedPluginIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          defaults.installedPluginIds,
    );
  }
}
