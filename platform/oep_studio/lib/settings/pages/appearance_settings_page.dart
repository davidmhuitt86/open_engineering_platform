import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Appearance (SDD-023; STUDIO-TASK-000052). Values here are
/// stored, validated, and versioned but do not yet change Studio's
/// rendered theme — see `docs/STUDIO_SETTINGS.md`.
class AppearanceSettingsProvider implements SettingsProvider {
  const AppearanceSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.appearance;

  @override
  String get label => 'Appearance';

  @override
  IconData get icon => Icons.palette_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(pageId: CoreSettingsPageIds.appearance, name: 'Theme', description: 'Light, dark, or system.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.appearance,
      name: 'Accent Color',
      description: 'The selection/highlight color.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.appearance,
      name: 'Density',
      description: 'How compact the interface is.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.appearance, name: 'Font Size', description: 'Text size across Studio.'),
    SettingsEntry(pageId: CoreSettingsPageIds.appearance, name: 'Icon Size', description: 'Icon size across Studio.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.appearance,
      name: 'Animations',
      description: 'Enable interface animations.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.appearance,
      name: 'Workspace Scaling',
      description: 'Overall UI scale factor.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const AppearanceSettingsPage();
}

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final appearance = ref.watch(settingsControllerProvider.select((state) => state.configuration.appearance));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Theme',
          description: 'Studio currently ships one ratified dark theme; other choices are stored but not yet applied.',
          children: [
            SettingsDropdownRow<StudioThemePreference>(
              label: 'Theme',
              value: appearance.theme,
              items: const [
                DropdownMenuItem(value: StudioThemePreference.dark, child: Text('Dark')),
                DropdownMenuItem(value: StudioThemePreference.light, child: Text('Light (not yet applied)')),
                DropdownMenuItem(value: StudioThemePreference.system, child: Text('System (not yet applied)')),
              ],
              onChanged: (value) {
                if (value != null) controller.setTheme(value);
              },
            ),
            SettingsTextRow(
              label: 'Accent Color',
              value: appearance.accentColorHex,
              hintText: '#3B82F6',
              helper: '6-digit hex color.',
              onChanged: controller.setAccentColorHex,
            ),
            SettingsDropdownRow<UiDensity>(
              label: 'Density',
              value: appearance.density,
              items: const [
                DropdownMenuItem(value: UiDensity.comfortable, child: Text('Comfortable')),
                DropdownMenuItem(value: UiDensity.compact, child: Text('Compact')),
              ],
              onChanged: (value) {
                if (value != null) controller.setDensity(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: 'Text & Icons',
          children: [
            SettingsSliderRow(
              label: 'Font Size',
              value: appearance.fontSize,
              min: 8,
              max: 32,
              divisions: 24,
              onChanged: controller.setFontSize,
            ),
            SettingsSliderRow(
              label: 'Icon Size',
              value: appearance.iconSize,
              min: 12,
              max: 40,
              divisions: 28,
              onChanged: controller.setIconSize,
            ),
          ],
        ),
        SettingsSection(
          title: 'Motion & Scale',
          children: [
            SettingsSwitchRow(
              label: 'Animations',
              value: appearance.animationsEnabled,
              onChanged: controller.setAnimationsEnabled,
            ),
            SettingsSliderRow(
              label: 'Workspace Scaling',
              value: appearance.workspaceScaling,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              onChanged: controller.setWorkspaceScaling,
            ),
          ],
        ),
      ],
    );
  }
}
