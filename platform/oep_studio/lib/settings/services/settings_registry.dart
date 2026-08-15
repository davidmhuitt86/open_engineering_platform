import '../../core/routing/studio_registry.dart';
import '../models/settings_entry.dart';
import '../pages/about_settings_page.dart';
import '../pages/ai_settings_page.dart';
import '../pages/appearance_settings_page.dart';
import '../pages/diagnostics_settings_page.dart';
import '../pages/general_settings_page.dart';
import '../pages/plugins_settings_page.dart';
import '../pages/repository_settings_page.dart';
import '../pages/security_settings_page.dart';
import '../pages/updates_settings_page.dart';
import '../pages/workspace_settings_page.dart';
import 'settings_provider.dart';

/// Holds every registered [SettingsProvider] (Work Package 017
/// STUDIO-TASK-000051/000055; SDD-023 Provider Registration).
/// Structurally identical to `AiProviderRegistry` (Work Package 016):
/// an ordered list, wrapped once at construction, keyed by each
/// provider's own id. [defaultRegistry] is seeded with the eleven core
/// pages in SDD-023's own listed order; future AI Providers and
/// Plugins register by constructing a new [SettingsRegistry] (or a
/// future "extend" helper) with their own [SettingsProvider] appended —
/// the Settings Workspace itself never changes.
///
/// The three Studio-owned pages (Knowledge/Diagram/Acquisition) are no
/// longer constructed here directly (WP-STUDIO-021) — they're read from
/// [StudioRegistry.defaultRegistry], which is now the one place each
/// Studio's [SettingsProvider] is registered.
class SettingsRegistry {
  SettingsRegistry(List<SettingsProvider> providers) : _providers = List.unmodifiable(providers);

  final List<SettingsProvider> _providers;

  /// In registration order — the order the left navigation renders.
  List<SettingsProvider> get providers => _providers;

  SettingsProvider? providerFor(String pageId) {
    for (final provider in _providers) {
      if (provider.pageId == pageId) return provider;
    }
    return null;
  }

  /// Every entry every registered provider contributes.
  List<SettingsEntry> get allEntries => [for (final provider in _providers) ...provider.searchEntries];

  /// Case-insensitive search across every registered provider's
  /// entries (STUDIO-TASK-000054).
  List<SettingsEntry> search(String query) {
    if (query.trim().isEmpty) return const [];
    return allEntries.where((entry) => entry.matches(query)).toList();
  }

  static final SettingsRegistry defaultRegistry = SettingsRegistry([
    const GeneralSettingsProvider(),
    const AppearanceSettingsProvider(),
    const WorkspaceSettingsProvider(),
    const RepositorySettingsProvider(),
    ...StudioRegistry.defaultRegistry.settingsProviders,
    const AiSettingsProvider(),
    const PluginsSettingsProvider(),
    const UpdatesSettingsProvider(),
    const DiagnosticsSettingsProvider(),
    const SecuritySettingsProvider(),
    const AboutSettingsProvider(),
  ]);
}
