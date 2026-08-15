import 'package:flutter/material.dart';

import '../../core/context/contextual_command_resolver.dart';
import '../../core/context/engineering_interaction_context.dart';
import '../../core/context/menu_descriptor.dart';
import '../../core/notifications/platform_notification_service.dart';
import '../../core/theme/studio_colors.dart';

/// The Diagram Studio right-click contextual menu (OEP Context &
/// Capability Service — Phase 3, the first presentation surface for
/// the architecture Phase 1/2 built).
///
/// **This widget contains no engineering decision-making** (Part 27 of
/// the governing spec): it renders exactly the [MenuDescriptor] handed
/// to it and, on selection, calls [ContextualCommandResolver.execute]
/// with a *freshly rebuilt* context — never the widget's own
/// interpretation of what should be enabled, never a cached "was valid
/// when opened" assumption. There is no `if (target is Wire)` anywhere
/// in this file.
///
/// **Design-system gap**: no dedicated contextual-menu component
/// specification exists in `oep_design_system` (grepped `docs/` for
/// "Context Menu" — only incidental bullet-point mentions inside
/// unrelated component/pattern specs, no concrete layout/interaction
/// contract). This implementation reuses the same `PopupMenuButton`-
/// derived visual language `studio_menu_bar.dart` already established
/// (`StudioColors`, disabled-item `Tooltip` convention, checkbox-style
/// leading icons) rather than inventing a new one, and documents this
/// as a gap for `oep_design_system` to formalize later.
///
/// **Submenu mechanism**: Flutter's `showMenu` has no native nested-
/// submenu support. Selecting a submenu header (Resolution spec § 8 --
/// e.g. "Measure >") closes the current menu and immediately reopens a
/// second `showMenu` at the same position with that submenu's items --
/// a real, working nested-menu interaction, not a placeholder.
Future<void> showDiagramContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required MenuDescriptor menu,
  required ContextualCommandResolver resolver,
  required EngineeringInteractionContext Function() currentContext,
}) async {
  var items = _topLevelEntries(menu);
  var position = globalPosition;

  while (true) {
    if (!context.mounted) return;
    final selected = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: StudioColors.surfaceRaised,
      items: items,
    );
    if (selected == null) return;
    if (selected is List<PopupMenuEntry<Object>>) {
      items = selected;
      continue;
    }
    if (selected is String) {
      if (!context.mounted) return;
      // Revalidate-and-execute (Resolution spec § 14/§ 15, Part 18):
      // the context is rebuilt fresh right here, at selection time --
      // never the context the menu happened to resolve against when
      // it first opened.
      final result = await resolver.execute(selected, currentContext());
      if (!context.mounted) return;
      if (result.success) {
        if (result.message != null) PlatformNotificationService.success(context, result.message!);
      } else {
        PlatformNotificationService.error(context, result.message ?? 'This command is not currently available.');
      }
      return;
    }
    return;
  }
}

List<PopupMenuEntry<Object>> _topLevelEntries(MenuDescriptor menu) {
  if (menu.isEmpty) {
    return [
      PopupMenuItem<Object>(
        enabled: false,
        child: Text(menu.contextIdentity, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 12)),
      ),
    ];
  }

  final entries = <PopupMenuEntry<Object>>[
    PopupMenuItem<Object>(
      enabled: false,
      child: Text(
        menu.contextIdentity,
        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    const PopupMenuDivider(),
  ];

  for (var i = 0; i < menu.sections.length; i++) {
    if (i > 0) entries.add(const PopupMenuDivider(height: 4));
    entries.add(_sectionHeader(menu.sections[i].label));
    entries.addAll(menu.sections[i].items.map(_toPopupEntry));
  }

  return entries;
}

PopupMenuEntry<Object> _sectionHeader(String label) => PopupMenuItem<Object>(
      enabled: false,
      height: 22,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(color: StudioColors.textDisabled, fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600),
      ),
    );

PopupMenuEntry<Object> _toPopupEntry(MenuItem item) {
  if (item.isSubmenu) {
    return PopupMenuItem<Object>(
      value: item.submenu!.map(_toPopupEntry).toList(),
      enabled: item.enabled,
      child: Row(
        children: [
          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 12.5))),
          const Icon(Icons.chevron_right, size: 16, color: StudioColors.textSecondary),
        ],
      ),
    );
  }

  final child = Text(
    item.label,
    style: TextStyle(fontSize: 12.5, color: item.enabled ? StudioColors.textPrimary : StudioColors.textDisabled),
  );

  return PopupMenuItem<Object>(
    value: item.commandId,
    enabled: item.enabled,
    child: item.enabled || item.disabledReason == null
        ? child
        : Tooltip(message: item.disabledReason!, child: child),
  );
}
