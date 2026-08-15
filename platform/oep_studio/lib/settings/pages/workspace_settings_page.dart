import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Workspace (SDD-023; STUDIO-TASK-000052).
class WorkspaceSettingsProvider implements SettingsProvider {
  const WorkspaceSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.workspace;

  @override
  String get label => 'Workspace';

  @override
  IconData get icon => Icons.dashboard_customize_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.workspace,
      name: 'Default Workspace',
      description: 'Which workspace Studio opens to.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.workspace,
      name: 'Recent Workspaces',
      description: 'Recently visited workspaces.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.workspace,
      name: 'Window Behavior',
      description: 'How the window size is remembered.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.workspace, name: 'Docking', description: 'Panel docking.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.workspace,
      name: 'Multi-monitor',
      description: 'Multi-monitor awareness.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.workspace,
      name: 'Restore Layout',
      description: 'Restore the previous layout on startup.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const WorkspaceSettingsPage();
}

class WorkspaceSettingsPage extends ConsumerWidget {
  const WorkspaceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final workspace = ref.watch(settingsControllerProvider.select((state) => state.configuration.workspace));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Default Workspace',
          children: [
            SettingsTextRow(
              label: 'Default Workspace Path',
              value: workspace.defaultWorkspacePath,
              hintText: '/',
              onChanged: controller.setDefaultWorkspacePath,
            ),
            const SettingsPlaceholderRow(
              label: 'Recent Workspaces',
              helper: 'Not yet tracked.',
            ),
          ],
        ),
        SettingsSection(
          title: 'Window',
          children: [
            SettingsDropdownRow<WindowBehaviorPreference>(
              label: 'Window Behavior',
              value: workspace.windowBehavior,
              items: const [
                DropdownMenuItem(value: WindowBehaviorPreference.rememberSize, child: Text('Remember Size')),
                DropdownMenuItem(value: WindowBehaviorPreference.alwaysMaximized, child: Text('Always Maximized')),
              ],
              onChanged: (value) {
                if (value != null) controller.setWindowBehavior(value);
              },
            ),
            SettingsSwitchRow(
              label: 'Restore Layout on Startup',
              value: workspace.restoreLayoutOnStartup,
              onChanged: controller.setRestoreLayoutOnStartup,
            ),
            const SettingsPlaceholderRow(label: 'Docking', helper: 'No docking system exists yet.'),
            const SettingsPlaceholderRow(label: 'Multi-monitor', helper: 'Not yet implemented.'),
          ],
        ),
      ],
    );
  }
}
