import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Updates (SDD-023; STUDIO-TASK-000052).
class UpdatesSettingsProvider implements SettingsProvider {
  const UpdatesSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.updates;

  @override
  String get label => 'Updates';

  @override
  IconData get icon => Icons.system_update_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.updates,
      name: 'Automatic Updates',
      description: 'Check for and install updates automatically.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.updates,
      name: 'Update Channel',
      description: 'Stable, Preview, or Nightly.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const UpdatesSettingsPage();
}

class UpdatesSettingsPage extends ConsumerWidget {
  const UpdatesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final updates = ref.watch(settingsControllerProvider.select((state) => state.configuration.updates));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Updates',
          description: 'Studio has no updater component yet; these preferences are stored for a future release.',
          children: [
            SettingsSwitchRow(
              label: 'Automatic Updates',
              value: updates.automaticUpdatesEnabled,
              onChanged: controller.setAutomaticUpdatesEnabled,
            ),
            SettingsDropdownRow<UpdateChannel>(
              label: 'Update Channel',
              value: updates.channel,
              items: const [
                DropdownMenuItem(value: UpdateChannel.stable, child: Text('Stable')),
                DropdownMenuItem(value: UpdateChannel.preview, child: Text('Preview')),
                DropdownMenuItem(value: UpdateChannel.nightly, child: Text('Nightly')),
              ],
              onChanged: (value) {
                if (value != null) controller.setUpdateChannel(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
