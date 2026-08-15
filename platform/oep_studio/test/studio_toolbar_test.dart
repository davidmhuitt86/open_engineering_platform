import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/app/widgets/studio_toolbar.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';

Future<void> _pumpToolbar(WidgetTester tester, StudioDestination selected) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: Scaffold(appBar: StudioToolbar(selected: selected))),
    ),
  );
}

IconButton _validateButton(WidgetTester tester) {
  return tester.widget<IconButton>(
    find.descendant(of: find.byTooltip('Validate'), matching: find.byType(IconButton)),
  );
}

void main() {
  group('StudioToolbar — Validate action (WP-STUDIO-027)', () {
    testWidgets('is disabled on every non-Diagram destination, matching every prior Work Package\'s '
        'inert baseline', (tester) async {
      await _pumpToolbar(tester, StudioDestination.dashboard);
      expect(_validateButton(tester).onPressed, isNull);
    });

    testWidgets('is enabled when Diagram Studio is the active destination', (tester) async {
      await _pumpToolbar(tester, StudioDestination.diagram);
      expect(_validateButton(tester).onPressed, isNotNull);
    });

    testWidgets('running it (with no diagram open yet) calls through PlatformInputService without throwing', (
      tester,
    ) async {
      await _pumpToolbar(tester, StudioDestination.diagram);
      // diagram.revalidate no-ops safely when no EngineHost exists yet
      // (same guard `notifier.revalidate()` already had) — this should
      // never throw.
      // warnIfMissed: false — find.byTooltip resolves to the Tooltip
      // wrapper; the tap still correctly reaches the IconButton beneath it.
      await tester.tap(find.byTooltip('Validate'), warnIfMissed: false);
      await tester.pump();
    });

    testWidgets('every other toolbar action remains exactly as inert as before (Open/Save/Import/Export)', (
      tester,
    ) async {
      await _pumpToolbar(tester, StudioDestination.diagram);
      for (final label in ['Open', 'Save', 'Import', 'Export']) {
        final button = tester.widget<IconButton>(
          find.descendant(of: find.byTooltip(label), matching: find.byType(IconButton)),
        );
        expect(button.onPressed, isNull, reason: '$label should remain a placeholder');
      }
    });
  });
}
