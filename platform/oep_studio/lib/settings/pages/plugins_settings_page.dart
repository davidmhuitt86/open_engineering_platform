import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Plugins (SDD-023; STUDIO-TASK-000052). Per this work
/// package's explicit instruction ("Do not implement Plugins"), this
/// page only shows a master toggle placeholder and an honest "no
/// plugins installed" state — see `PluginSettings`.
class PluginsSettingsProvider implements SettingsProvider {
  const PluginsSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.plugins;

  @override
  String get label => 'Plugins';

  @override
  IconData get icon => Icons.extension_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(pageId: CoreSettingsPageIds.plugins, name: 'Installed Plugins', description: 'Plugins installed in Studio.'),
    SettingsEntry(pageId: CoreSettingsPageIds.plugins, name: 'Marketplace', description: 'Browse available plugins.'),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const PluginsSettingsPage();
}

class PluginsSettingsPage extends ConsumerWidget {
  const PluginsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final plugins = ref.watch(settingsControllerProvider.select((state) => state.configuration.plugins));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Plugins',
          description: 'No plugin system exists yet. Plugins will register their own settings pages here.',
          children: [
            SettingsSwitchRow(label: 'Enable Plugins', value: plugins.pluginsEnabled, onChanged: controller.setPluginsEnabled),
            SettingsInfoRow(
              label: 'Installed Plugins',
              value: plugins.installedPluginIds.isEmpty ? 'None' : plugins.installedPluginIds.join(', '),
            ),
            const SettingsPlaceholderRow(label: 'Permissions'),
            const SettingsPlaceholderRow(label: 'Updates'),
            const SettingsPlaceholderRow(label: 'Marketplace'),
          ],
        ),
      ],
    );
  }
}
