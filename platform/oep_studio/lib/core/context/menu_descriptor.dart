import 'contextual_command_descriptor.dart';

/// Presentation-neutral menu structures (Resolution spec § 9). No
/// Flutter/widget types anywhere in this file — a future UI phase
/// renders these; this phase only produces them.
class MenuItem {
  const MenuItem({
    required this.commandId,
    required this.label,
    required this.description,
    required this.enabled,
    this.disabledReason,
    this.submenu,
  });

  final String commandId;
  final String label;
  final String description;
  final bool enabled;
  final String? disabledReason;

  /// Present when this item is actually a submenu header (Resolution
  /// spec § 8) — its own [commandId] is then a placeholder, not
  /// executable directly.
  final List<MenuItem>? submenu;

  bool get isSubmenu => submenu != null;
}

class MenuSection {
  const MenuSection({required this.id, required this.label, required this.items});

  final String id;
  final String label;
  final List<MenuItem> items;
}

/// The complete resolved menu for one interaction (Resolution spec §
/// 9). [contextIdentity] is a short, human-readable label for whatever
/// the menu is about (e.g. `"WIRE W104"`, `"3 objects selected"`,
/// `"Canvas"`) — real, derived from the context that produced it, never
/// invented.
class MenuDescriptor {
  const MenuDescriptor({required this.title, required this.contextIdentity, required this.sections});

  final String title;
  final String contextIdentity;
  final List<MenuSection> sections;

  static const MenuDescriptor empty = MenuDescriptor(title: '', contextIdentity: '', sections: []);

  bool get isEmpty => sections.isEmpty;
}

/// Maps a [CommandGroup] to the section label the Resolution spec's own
/// examples use (§ 6, § 10, § 11, § 12) — one place, not a hard-coded
/// string wherever a section is built.
String labelForGroup(CommandGroup group) => switch (group) {
      CommandGroup.inspect => 'Inspect',
      CommandGroup.edit => 'Edit',
      CommandGroup.test => 'Test',
      CommandGroup.diagnose => 'Diagnose',
      CommandGroup.simulate => 'Simulate',
      CommandGroup.knowledge => 'Knowledge',
      CommandGroup.ai => 'AI',
      CommandGroup.annotate => 'Annotate',
      CommandGroup.navigate => 'Navigate',
    };
