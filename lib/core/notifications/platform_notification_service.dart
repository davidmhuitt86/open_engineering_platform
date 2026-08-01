import 'package:flutter/material.dart';

import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';

export '../events/platform_event.dart' show NotificationSeverity;

/// A centralized, consistent replacement for the ad hoc
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` calls
/// scattered across the app (WP-STUDIO-028) — `commit_report_dialog.dart`,
/// `ai_settings_page.dart`, `settings_workspace_page.dart`,
/// `evidence_navigation.dart`, and (before this Work Package)
/// `command_palette_dialog.dart` each built their own plain `SnackBar`
/// independently, with no shared styling. This class doesn't invent a
/// new notification mechanism — it's still exactly `ScaffoldMessenger`
/// underneath — it just gives every call site the same three-line API
/// and consistent severity coloring instead of each hand-rolling its own
/// `SnackBar`.
///
/// Only `command_palette_dialog.dart` was migrated to use this in this
/// Work Package — see `docs/tasks/WP-STUDIO-028 Platform Event &
/// Notification Framework.md` for why the other call sites (all inside
/// Knowledge Studio or Settings) were identified but deliberately left
/// as-is, rather than rewritten wholesale.
abstract final class PlatformNotificationService {
  static void success(BuildContext context, String message) => _show(context, message, NotificationSeverity.success);

  static void error(BuildContext context, String message) => _show(context, message, NotificationSeverity.error);

  static void info(BuildContext context, String message) => _show(context, message, NotificationSeverity.info);

  static void _show(BuildContext context, String message, NotificationSeverity severity) {
    final color = switch (severity) {
      NotificationSeverity.success => Colors.green.shade700,
      NotificationSeverity.error => Colors.red.shade700,
      NotificationSeverity.info => null,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
    PlatformEventBus.instance.publish(NotificationEvent(severity: severity, message: message));
  }
}
