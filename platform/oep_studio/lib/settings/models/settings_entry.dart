/// One searchable setting (Work Package 017 STUDIO-TASK-000054; SDD-023
/// Settings Search: "Search shall include: Setting Name, Description,
/// Keywords. Selecting a search result navigates directly to the
/// setting.").
///
/// Built at runtime by each [SettingsProvider] — never persisted, never
/// constructed by a widget (the Settings Workspace only ever reads
/// entries back from the [SettingsRegistry], mirroring Work Package
/// 016's "widgets never construct prompts" boundary: here, widgets
/// never construct settings entries).
class SettingsEntry {
  const SettingsEntry({
    required this.pageId,
    required this.name,
    required this.description,
    this.keywords = const [],
  });

  /// A [CoreSettingsPageIds] constant, or a future provider's own id.
  final String pageId;
  final String name;
  final String description;
  final List<String> keywords;

  /// Case-insensitive match against [query] across name, description,
  /// and keywords (SDD-023's own three named search fields).
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return false;
    if (name.toLowerCase().contains(needle)) return true;
    if (description.toLowerCase().contains(needle)) return true;
    return keywords.any((keyword) => keyword.toLowerCase().contains(needle));
  }
}
