import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_colors.dart';
import 'package:oep_studio/workbench/theme/workbench_theme_manager.dart';

void main() {
  group('WorkbenchThemeManager', () {
    const manager = WorkbenchThemeManager();

    test('every color forwards to the matching StudioColors constant', () {
      expect(manager.background, StudioColors.background);
      expect(manager.surface, StudioColors.surface);
      expect(manager.surfaceRaised, StudioColors.surfaceRaised);
      expect(manager.surfaceSunken, StudioColors.surfaceSunken);
      expect(manager.border, StudioColors.border);
      expect(manager.borderSubtle, StudioColors.borderSubtle);
      expect(manager.textPrimary, StudioColors.textPrimary);
      expect(manager.textSecondary, StudioColors.textSecondary);
      expect(manager.textDisabled, StudioColors.textDisabled);
      expect(manager.selection, StudioColors.selection);
      expect(manager.success, StudioColors.success);
      expect(manager.warning, StudioColors.warning);
      expect(manager.error, StudioColors.error);
      expect(manager.info, StudioColors.info);
      expect(manager.inactive, StudioColors.inactive);
    });

    test('colorsFor returns itself for any perspective id (no override exists yet)', () {
      expect(manager.colorsFor('diagram'), same(manager));
      expect(manager.colorsFor('unknown-perspective'), same(manager));
    });

    test('instance is a usable const singleton', () {
      expect(WorkbenchThemeManager.instance.background, StudioColors.background);
    });
  });
}
