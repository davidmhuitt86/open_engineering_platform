import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Repository (SDD-023; STUDIO-TASK-000052). User
/// Configuration-scoped defaults only — see `RepositorySettings`.
class RepositorySettingsProvider implements SettingsProvider {
  const RepositorySettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.repository;

  @override
  String get label => 'Repository';

  @override
  IconData get icon => Icons.folder_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.repository,
      name: 'Default Repository',
      description: 'The repository Studio opens automatically.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.repository, name: 'Auto-open', description: 'Open it on startup.'),
    SettingsEntry(pageId: CoreSettingsPageIds.repository, name: 'Backup', description: 'Automatic backups.'),
    SettingsEntry(pageId: CoreSettingsPageIds.repository, name: 'Snapshots', description: 'Repository snapshots.'),
    SettingsEntry(pageId: CoreSettingsPageIds.repository, name: 'Cache', description: 'Repository data caching.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.repository,
      name: 'Validation Defaults',
      description: 'How strict repository validation is.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const RepositorySettingsPage();
}

class RepositorySettingsPage extends ConsumerWidget {
  const RepositorySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final repository = ref.watch(settingsControllerProvider.select((state) => state.configuration.repository));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Default Repository',
          children: [
            SettingsTextRow(
              label: 'Default Repository Path',
              value: repository.defaultRepositoryPath,
              hintText: 'None set',
              onChanged: controller.setDefaultRepositoryPath,
            ),
            SettingsSwitchRow(
              label: 'Auto-open on Startup',
              value: repository.autoOpenDefaultRepository,
              onChanged: controller.setAutoOpenDefaultRepository,
            ),
          ],
        ),
        SettingsSection(
          title: 'Backup & Cache',
          children: [
            SettingsSwitchRow(
              label: 'Backup',
              helper: 'Not yet implemented.',
              value: repository.backupEnabled,
              onChanged: controller.setRepositoryBackupEnabled,
            ),
            SettingsSwitchRow(
              label: 'Snapshots',
              helper: 'Not yet implemented.',
              value: repository.snapshotsEnabled,
              onChanged: controller.setRepositorySnapshotsEnabled,
            ),
            SettingsSwitchRow(
              label: 'Cache',
              value: repository.cacheEnabled,
              onChanged: controller.setRepositoryCacheEnabled,
            ),
          ],
        ),
        SettingsSection(
          title: 'Validation',
          children: [
            SettingsDropdownRow<ValidationStrictness>(
              label: 'Validation Defaults',
              value: repository.validationStrictness,
              items: const [
                DropdownMenuItem(value: ValidationStrictness.lenient, child: Text('Lenient')),
                DropdownMenuItem(value: ValidationStrictness.standard, child: Text('Standard')),
                DropdownMenuItem(value: ValidationStrictness.strict, child: Text('Strict')),
              ],
              onChanged: (value) {
                if (value != null) controller.setValidationStrictness(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
