import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../models/settings_entry.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > About (SDD-023; STUDIO-TASK-000052). Entirely read-only.
/// `studioVersion` mirrors `pubspec.yaml`'s own `version:` field — kept
/// as a plain constant rather than a new dependency (no
/// `package_info_plus` in `pubspec.yaml` today).
class AboutSettingsProvider implements SettingsProvider {
  const AboutSettingsProvider();

  static const studioVersion = '0.1.0';

  @override
  String get pageId => CoreSettingsPageIds.about;

  @override
  String get label => 'About';

  @override
  IconData get icon => Icons.info_outline;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(pageId: CoreSettingsPageIds.about, name: 'Studio Version', description: 'The installed Studio version.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.about,
      name: 'Foundation Version',
      description: 'The connected Foundation version.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.about, name: 'License', description: 'License information.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.about,
      name: 'Third-party Notices',
      description: 'Open-source dependencies used by Studio.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const AboutSettingsPage();
}

class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SettingsSection(
          title: 'Version',
          children: [SettingsInfoRow(label: 'Studio Version', value: AboutSettingsProvider.studioVersion)],
        ),
        SettingsSection(
          title: 'Foundation',
          children: [
            SettingsInfoRow(label: 'Foundation Version', value: foundation.foundationVersion ?? 'Not connected'),
            SettingsInfoRow(label: 'Public API Version', value: foundation.apiVersion?.toString() ?? '—'),
            SettingsInfoRow(label: 'ABI Version', value: foundation.abiVersion?.toString() ?? '—'),
          ],
        ),
        const SettingsSection(
          title: 'License & Notices',
          children: [
            SettingsInfoRow(label: 'License', value: 'Unpublished — internal project'),
            SettingsInfoRow(
              label: 'Third-party Notices',
              value: 'go_router, flutter_riverpod, ffi, file_selector, pdfrx, crypto',
            ),
          ],
        ),
      ],
    );
  }
}
