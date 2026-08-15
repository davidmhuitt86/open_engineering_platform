/// Well-known Settings page identifiers for Studio's eleven core pages
/// (Work Package 017 STUDIO-TASK-000050/000052; SDD-023 Navigation).
///
/// Deliberately plain `String` constants, not a closed `enum` — SDD-023
/// Navigation explicitly allows "Future modules may register
/// additional pages," and STUDIO-TASK-000055 requires that "The
/// Settings Workspace shall not require modification when new
/// providers are added." A closed enum could never admit a page ID a
/// future AI Provider or Plugin invents for itself; a plain string
/// mirrors `AiProviderRegistry` (Work Package 016), which keys
/// providers by a plain `String providerId` for the identical reason.
abstract final class CoreSettingsPageIds {
  static const general = 'general';
  static const appearance = 'appearance';
  static const workspace = 'workspace';
  static const repository = 'repository';
  static const knowledgeStudio = 'knowledgeStudio';
  static const artificialIntelligence = 'artificialIntelligence';
  static const plugins = 'plugins';
  static const updates = 'updates';
  static const diagnostics = 'diagnostics';
  static const security = 'security';
  static const about = 'about';
}
