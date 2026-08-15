import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Knowledge Studio (SDD-023; STUDIO-TASK-000052).
class KnowledgeStudioSettingsProvider implements SettingsProvider {
  const KnowledgeStudioSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.knowledgeStudio;

  @override
  String get label => 'Knowledge Studio';

  @override
  IconData get icon => Icons.auto_awesome_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'Autosave',
      description: 'Autosave Knowledge Sessions.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'OCR Overlay',
      description: 'Default OCR word-box overlay visibility.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'Evidence Colors',
      description: 'Evidence Region color scheme.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'Default Zoom',
      description: 'Default PDF Source Viewer zoom.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'Context Display',
      description: 'Engineering Context tree or flat display.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'Entity Display',
      description: 'Engineering Entity grouped or flat display.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.knowledgeStudio,
      name: 'Review Preferences',
      description: 'Default review sort order.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const KnowledgeStudioSettingsPage();
}

class KnowledgeStudioSettingsPage extends ConsumerWidget {
  const KnowledgeStudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final ks = ref.watch(settingsControllerProvider.select((state) => state.configuration.knowledgeStudio));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Sessions',
          children: [
            SettingsSwitchRow(
              label: 'Autosave',
              helper: 'Knowledge Sessions already autosave unconditionally; this preference is not yet consumed.',
              value: ks.autosaveEnabled,
              onChanged: controller.setKnowledgeStudioAutosave,
            ),
          ],
        ),
        SettingsSection(
          title: 'Evidence & Viewing',
          children: [
            SettingsSwitchRow(
              label: 'OCR Overlay Visible by Default',
              value: ks.ocrOverlayVisibleByDefault,
              onChanged: controller.setOcrOverlayVisibleByDefault,
            ),
            SettingsSwitchRow(
              label: 'High-Contrast Evidence Colors',
              value: ks.highContrastEvidenceColors,
              onChanged: controller.setHighContrastEvidenceColors,
            ),
            SettingsSliderRow(
              label: 'Default Zoom',
              value: ks.defaultZoom,
              min: 0.25,
              max: 5.0,
              divisions: 19,
              onChanged: controller.setDefaultZoom,
            ),
          ],
        ),
        SettingsSection(
          title: 'Review',
          children: [
            SettingsDropdownRow<ContextDisplayMode>(
              label: 'Context Display',
              value: ks.contextDisplay,
              items: const [
                DropdownMenuItem(value: ContextDisplayMode.tree, child: Text('Tree')),
                DropdownMenuItem(value: ContextDisplayMode.flat, child: Text('Flat')),
              ],
              onChanged: (value) {
                if (value != null) controller.setContextDisplay(value);
              },
            ),
            SettingsDropdownRow<EntityDisplayMode>(
              label: 'Entity Display',
              value: ks.entityDisplay,
              items: const [
                DropdownMenuItem(value: EntityDisplayMode.grouped, child: Text('Grouped')),
                DropdownMenuItem(value: EntityDisplayMode.flat, child: Text('Flat')),
              ],
              onChanged: (value) {
                if (value != null) controller.setEntityDisplay(value);
              },
            ),
            SettingsDropdownRow<ReviewSortPreference>(
              label: 'Review Preferences',
              value: ks.reviewSortPreference,
              items: const [
                DropdownMenuItem(value: ReviewSortPreference.newestFirst, child: Text('Newest First')),
                DropdownMenuItem(value: ReviewSortPreference.oldestFirst, child: Text('Oldest First')),
              ],
              onChanged: (value) {
                if (value != null) controller.setReviewSortPreference(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
