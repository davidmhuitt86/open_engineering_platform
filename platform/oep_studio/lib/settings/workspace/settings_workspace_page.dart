import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../services/settings_registry.dart';

/// The Settings Workspace (Work Package 017 STUDIO-TASK-000050; SDD-023
/// Settings Workspace: "Settings shall exist as a dedicated Studio
/// Workspace. Settings are not implemented as modal dialogs. Navigation
/// shall appear on the left. Settings content shall appear on the
/// right."). Registers as a normal Studio Workspace like every other
/// navigation destination — same `StudioShell`, Navigation Rail, and
/// Property Inspector as `KnowledgeStudioPage`/`ObjectsPage`/etc.
///
/// Supports deep-link navigation via an optional `?page=` query
/// parameter on `/settings` (STUDIO-TASK-000050 "Support deep-link
/// navigation") — see `lib/core/routing/app_router.dart`.
class SettingsWorkspacePage extends ConsumerStatefulWidget {
  const SettingsWorkspacePage({this.initialPageId, super.key});

  final String? initialPageId;

  @override
  ConsumerState<SettingsWorkspacePage> createState() => _SettingsWorkspacePageState();
}

class _SettingsWorkspacePageState extends ConsumerState<SettingsWorkspacePage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
      final current = ref.read(foundationRuntimeServiceProvider).currentSettingsPageId;
      final target = widget.initialPageId ?? current ?? SettingsRegistry.defaultRegistry.providers.first.pageId;
      if (target != current) notifier.setCurrentSettingsPage(target);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportSettings(BuildContext context, SettingsController controller) async {
    final location = await getSaveLocation(
      suggestedName: 'oep_studio_settings.json',
      acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
    );
    if (location == null) return;
    await File(location.path).writeAsString(controller.exportJson());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings exported.')));
  }

  Future<void> _importSettings(BuildContext context, SettingsController controller) async {
    final picked = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])]);
    if (picked == null) return;
    final contents = await File(picked.path).readAsString();
    final ok = await controller.importJson(contents);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Settings imported. Review, then Save.' : (ref.read(settingsControllerProvider).errorMessage ?? 'Import failed.'),
        ),
      ),
    );
  }

  Future<void> _resetToDefaults(BuildContext context, SettingsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Reset Settings to Defaults?'),
        content: const Text('Every setting on this page and every other Settings page will revert to its default value.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.resetToDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings reset to defaults.')));
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final registry = SettingsRegistry.defaultRegistry;
    final pageId = foundation.currentSettingsPageId ?? registry.providers.first.pageId;
    final provider = registry.providerFor(pageId) ?? registry.providers.first;
    final controller = ref.read(settingsControllerProvider.notifier);
    final controllerState = ref.watch(settingsControllerProvider);

    ref.listen<SettingsControllerState>(settingsControllerProvider, (previous, next) {
      if (previous?.isModified != next.isModified) {
        notifier.setSettingsModified(next.isModified);
      }
    });

    final searchQuery = foundation.settingsSearchQuery;
    final searchResults = registry.search(searchQuery);

    return Column(
      children: [
        _SettingsActionBar(
          isModified: controllerState.isModified,
          isLoading: controllerState.isLoading,
          errorMessage: controllerState.errorMessage,
          onSave: () async {
            final ok = await controller.save();
            if (!context.mounted) return;
            final message = ok ? 'Settings saved.' : (ref.read(settingsControllerProvider).errorMessage ?? 'Save failed.');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          },
          onDiscard: controller.discardChanges,
          onResetDefaults: () => _resetToDefaults(context, controller),
          onExport: () => _exportSettings(context, controller),
          onImport: () => _importSettings(context, controller),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 260,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _searchController,
                          onChanged: notifier.setSettingsSearchQuery,
                          style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 16),
                            hintText: 'Search settings…',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: searchQuery.trim().isEmpty
                          ? ListView(
                              children: [
                                for (final navProvider in registry.providers)
                                  _NavItem(
                                    label: navProvider.label,
                                    icon: navProvider.icon,
                                    selected: navProvider.pageId == pageId,
                                    onTap: () => notifier.setCurrentSettingsPage(navProvider.pageId),
                                  ),
                              ],
                            )
                          : _SearchResultsList(
                              results: searchResults,
                              onSelect: (entry) {
                                notifier
                                  ..setCurrentSettingsPage(entry.pageId)
                                  ..setSettingsSearchQuery('');
                                _searchController.clear();
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Builder(builder: provider.pageBuilder)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsActionBar extends StatelessWidget {
  const _SettingsActionBar({
    required this.isModified,
    required this.isLoading,
    required this.errorMessage,
    required this.onSave,
    required this.onDiscard,
    required this.onResetDefaults,
    required this.onExport,
    required this.onImport,
  });

  final bool isModified;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onResetDefaults;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.settings_outlined, size: 18, color: StudioColors.textSecondary),
          const SizedBox(width: 10),
          const Text(
            'Settings',
            style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          if (errorMessage != null)
            Flexible(
              child: Text(
                errorMessage!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: StudioColors.error, fontSize: 11.5),
              ),
            )
          else if (isModified)
            const Text('Unsaved changes', style: TextStyle(color: StudioColors.warning, fontSize: 11.5)),
          const SizedBox(width: 12),
          if (isLoading) const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Import'),
                  ),
                  TextButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export'),
                  ),
                  TextButton.icon(
                    onPressed: onResetDefaults,
                    icon: const Icon(Icons.restore_outlined, size: 16),
                    label: const Text('Reset Defaults'),
                  ),
                  if (isModified) ...[
                    TextButton(onPressed: onDiscard, child: const Text('Discard')),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? StudioColors.selection.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: selected ? StudioColors.selection : StudioColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? StudioColors.textPrimary : StudioColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.onSelect});

  final List<SettingsEntry> results;
  final ValueChanged<SettingsEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No matching settings.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(entry),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
