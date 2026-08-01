import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/models/settings_entry.dart';
import 'package:oep_studio/settings/models/settings_page_id.dart';
import 'package:oep_studio/settings/services/settings_provider.dart';
import 'package:oep_studio/settings/services/settings_registry.dart';

void main() {
  group('SettingsRegistry.defaultRegistry', () {
    test('registers all eleven core pages, in SDD-023\'s own listed order, '
        'plus Diagram Studio (WORK_PACKAGE_024) immediately after Knowledge Studio, '
        'plus Engineering Acquisition (WP-PLAT-020) immediately after Diagram Studio, '
        'plus Engineering Exchange (WP-EXC-010) immediately after Engineering Acquisition', () {
      final ids = SettingsRegistry.defaultRegistry.providers.map((provider) => provider.pageId).toList();
      expect(ids, [
        CoreSettingsPageIds.general,
        CoreSettingsPageIds.appearance,
        CoreSettingsPageIds.workspace,
        CoreSettingsPageIds.repository,
        CoreSettingsPageIds.knowledgeStudio,
        'diagram_studio',
        'engineering_acquisition',
        'engineering_exchange',
        CoreSettingsPageIds.artificialIntelligence,
        CoreSettingsPageIds.plugins,
        CoreSettingsPageIds.updates,
        CoreSettingsPageIds.diagnostics,
        CoreSettingsPageIds.security,
        CoreSettingsPageIds.about,
      ]);
    });

    test('providerFor resolves a known id and returns null for an unknown one', () {
      expect(SettingsRegistry.defaultRegistry.providerFor(CoreSettingsPageIds.general), isNotNull);
      expect(SettingsRegistry.defaultRegistry.providerFor('no.such.page'), isNull);
    });

    test('a future provider can be registered without changing the Settings Workspace', () {
      final registry = SettingsRegistry([...SettingsRegistry.defaultRegistry.providers, const _FakeFuturePlugin()]);
      expect(registry.providerFor('plugin.example'), isNotNull);
      expect(registry.providers.length, SettingsRegistry.defaultRegistry.providers.length + 1);
    });

    test('search matches name, description, and keywords, case-insensitively', () {
      final byName = SettingsRegistry.defaultRegistry.search('Accent Color');
      expect(byName, isNotEmpty);
      expect(byName.every((entry) => entry.pageId == CoreSettingsPageIds.appearance), isTrue);

      final byKeyword = SettingsRegistry.defaultRegistry.search('LOCALE');
      expect(byKeyword, isNotEmpty);

      final byDescriptionFragment = SettingsRegistry.defaultRegistry.search('mock ai provider');
      expect(byDescriptionFragment, isEmpty); // no entry describes the Mock AI Provider by that phrase
    });

    test('an empty or blank query returns no results', () {
      expect(SettingsRegistry.defaultRegistry.search(''), isEmpty);
      expect(SettingsRegistry.defaultRegistry.search('   '), isEmpty);
    });

    test('a query matching nothing returns an empty list', () {
      expect(SettingsRegistry.defaultRegistry.search('zzz_no_such_setting_zzz'), isEmpty);
    });
  });
}

class _FakeFuturePlugin implements SettingsProvider {
  const _FakeFuturePlugin();

  @override
  String get pageId => 'plugin.example';

  @override
  String get label => 'Example Plugin';

  @override
  IconData get icon => Icons.extension_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [];

  @override
  WidgetBuilder get pageBuilder => (context) => const SizedBox.shrink();
}
