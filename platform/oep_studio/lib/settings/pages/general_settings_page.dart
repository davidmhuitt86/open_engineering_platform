import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > General (SDD-023; STUDIO-TASK-000052).
class GeneralSettingsProvider implements SettingsProvider {
  const GeneralSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.general;

  @override
  String get label => 'General';

  @override
  IconData get icon => Icons.tune_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.general,
      name: 'Language',
      description: 'The language Studio displays text in.',
      keywords: ['locale', 'i18n'],
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.general, name: 'Region', description: 'Your regional locale.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.general,
      name: 'Units',
      description: 'Metric or imperial units.',
      keywords: ['metric', 'imperial'],
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.general, name: 'Date Format', description: 'How dates are displayed.'),
    SettingsEntry(pageId: CoreSettingsPageIds.general, name: 'Time Format', description: '12-hour or 24-hour time.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.general,
      name: 'Autosave',
      description: 'Automatically save Knowledge Session changes.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.general,
      name: 'Startup Behavior',
      description: 'What Studio shows when it launches.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.general,
      name: 'Logging',
      description: 'The verbosity of Studio\'s logs.',
      keywords: ['diagnostics', 'verbosity'],
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const GeneralSettingsPage();
}

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final general = ref.watch(settingsControllerProvider.select((state) => state.configuration.general));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Localization',
          children: [
            SettingsDropdownRow<String>(
              label: 'Language',
              value: general.language,
              items: const [
                DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
                DropdownMenuItem(value: 'de-DE', child: Text('Deutsch')),
                DropdownMenuItem(value: 'fr-FR', child: Text('Français')),
                DropdownMenuItem(value: 'ja-JP', child: Text('日本語')),
              ],
              onChanged: (value) {
                if (value != null) controller.setLanguage(value);
              },
            ),
            SettingsDropdownRow<String>(
              label: 'Region',
              value: general.region,
              items: const [
                DropdownMenuItem(value: 'US', child: Text('United States')),
                DropdownMenuItem(value: 'GB', child: Text('United Kingdom')),
                DropdownMenuItem(value: 'DE', child: Text('Germany')),
                DropdownMenuItem(value: 'FR', child: Text('France')),
                DropdownMenuItem(value: 'JP', child: Text('Japan')),
              ],
              onChanged: (value) {
                if (value != null) controller.setRegion(value);
              },
            ),
            SettingsDropdownRow<UnitSystem>(
              label: 'Units',
              value: general.units,
              items: const [
                DropdownMenuItem(value: UnitSystem.metric, child: Text('Metric')),
                DropdownMenuItem(value: UnitSystem.imperial, child: Text('Imperial')),
              ],
              onChanged: (value) {
                if (value != null) controller.setUnits(value);
              },
            ),
            SettingsDropdownRow<DateFormatPreference>(
              label: 'Date Format',
              value: general.dateFormat,
              items: const [
                DropdownMenuItem(value: DateFormatPreference.iso8601, child: Text('2026-07-12 (ISO 8601)')),
                DropdownMenuItem(value: DateFormatPreference.us, child: Text('07/12/2026 (US)')),
                DropdownMenuItem(value: DateFormatPreference.eu, child: Text('12/07/2026 (EU)')),
              ],
              onChanged: (value) {
                if (value != null) controller.setDateFormat(value);
              },
            ),
            SettingsDropdownRow<TimeFormatPreference>(
              label: 'Time Format',
              value: general.timeFormat,
              items: const [
                DropdownMenuItem(value: TimeFormatPreference.h24, child: Text('24-hour')),
                DropdownMenuItem(value: TimeFormatPreference.h12, child: Text('12-hour')),
              ],
              onChanged: (value) {
                if (value != null) controller.setTimeFormat(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: 'Behavior',
          children: [
            SettingsSwitchRow(
              label: 'Autosave',
              helper: 'Knowledge Sessions already autosave unconditionally; this toggle is not yet wired to that behavior.',
              value: general.autosave,
              onChanged: controller.setGeneralAutosave,
            ),
            SettingsDropdownRow<StartupBehaviorPreference>(
              label: 'Startup Behavior',
              value: general.startupBehavior,
              items: const [
                DropdownMenuItem(value: StartupBehaviorPreference.showDashboard, child: Text('Show Dashboard')),
                DropdownMenuItem(
                  value: StartupBehaviorPreference.resumeLastWorkspace,
                  child: Text('Resume Last Workspace'),
                ),
              ],
              onChanged: (value) {
                if (value != null) controller.setStartupBehavior(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: 'Logging',
          children: [
            SettingsDropdownRow<LoggingLevel>(
              label: 'Logging Level',
              value: general.logging,
              items: const [
                DropdownMenuItem(value: LoggingLevel.error, child: Text('Error')),
                DropdownMenuItem(value: LoggingLevel.warning, child: Text('Warning')),
                DropdownMenuItem(value: LoggingLevel.info, child: Text('Info')),
                DropdownMenuItem(value: LoggingLevel.debug, child: Text('Debug')),
                DropdownMenuItem(value: LoggingLevel.trace, child: Text('Trace')),
              ],
              onChanged: (value) {
                if (value != null) controller.setLoggingLevel(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
