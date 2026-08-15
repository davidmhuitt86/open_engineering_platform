import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Security (SDD-023; STUDIO-TASK-000052).
class SecuritySettingsProvider implements SettingsProvider {
  const SecuritySettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.security;

  @override
  String get label => 'Security';

  @override
  IconData get icon => Icons.security_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.security,
      name: 'Credential Storage',
      description: 'Where credentials would be stored.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.security,
      name: 'Certificate Management',
      description: 'Manage trusted certificates.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.security, name: 'Privacy', description: 'Privacy safeguards.'),
    SettingsEntry(pageId: CoreSettingsPageIds.security, name: 'Encryption', description: 'Encryption at rest.'),
    SettingsEntry(pageId: CoreSettingsPageIds.security, name: 'Secure Storage', description: 'Secure storage backend.'),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const SecuritySettingsPage();
}

class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final security = ref.watch(settingsControllerProvider.select((state) => state.configuration.security));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Secrets',
          description:
              'No credentials exist anywhere in Studio today — Work Package 016\'s AI infrastructure ships only a '
              'no-credential Mock Provider. Nothing secret is stored in Repository, Knowledge Session, or Commit '
              'Report data (SDD-023 Security).',
          children: [
            SettingsDropdownRow<CredentialStorageBackend>(
              label: 'Credential Storage',
              value: security.credentialStorageBackend,
              items: const [
                DropdownMenuItem(value: CredentialStorageBackend.operatingSystem, child: Text('Operating System')),
                DropdownMenuItem(value: CredentialStorageBackend.none, child: Text('None')),
              ],
              onChanged: (value) {
                if (value != null) controller.setCredentialStorageBackend(value);
              },
            ),
            const SettingsPlaceholderRow(label: 'Certificate Management'),
          ],
        ),
        SettingsSection(
          title: 'Privacy & Encryption',
          children: [
            SettingsSwitchRow(
              label: 'Privacy Mode',
              value: security.privacyModeEnabled,
              onChanged: controller.setPrivacyModeEnabled,
            ),
            SettingsSwitchRow(
              label: 'Encryption at Rest',
              helper: 'Not yet implemented.',
              value: security.encryptionAtRestEnabled,
              onChanged: controller.setEncryptionAtRestEnabled,
            ),
          ],
        ),
      ],
    );
  }
}
