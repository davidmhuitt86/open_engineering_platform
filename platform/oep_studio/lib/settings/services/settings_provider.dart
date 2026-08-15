import 'package:flutter/widgets.dart';

import '../models/settings_entry.dart';

/// The contract every Settings page — core or future — implements
/// (Work Package 017 STUDIO-TASK-000051/000055; SDD-023 Provider
/// Registration: "Subsystems may register settings pages. Registration
/// occurs through a Settings Provider interface. Core Studio shall not
/// contain subsystem-specific code.").
///
/// [pageBuilder] returns a [Widget] — the standard Flutter registry
/// pattern (mirroring `GoRoute.builder`'s own shape in
/// `lib/core/routing/app_router.dart`). The Settings Workspace shell
/// never inspects what a page contains; it only ever renders whatever
/// the provider hands back, so "Core Studio shall not contain
/// subsystem-specific code" holds even though this interface lives in
/// `lib/settings/services/` — see `docs/STUDIO_SETTINGS.md`
/// Architectural Observations for why a widget-builder reference on a
/// service-layer interface is not the same thing as a service
/// constructing a widget tree itself.
abstract class SettingsProvider {
  /// A [CoreSettingsPageIds] constant for the eleven core pages, or a
  /// future provider's own unique id (e.g. `'ai.openai'`,
  /// `'plugin.my_plugin'`).
  String get pageId;

  String get label;

  IconData get icon;

  /// Entries this provider contributes to Settings Search
  /// (STUDIO-TASK-000054). May be empty.
  List<SettingsEntry> get searchEntries;

  /// Builds this page's content, shown on the right when [pageId] is
  /// selected in the Settings Workspace's left navigation.
  WidgetBuilder get pageBuilder;
}
