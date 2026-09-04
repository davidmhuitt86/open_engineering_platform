import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/app/widgets/command_palette_dialog.dart';
import 'package:oep_studio/app/studio_app.dart';
import 'package:oep_studio/core/commands/command_registry.dart';
import 'package:oep_studio/core/input/platform_input_service.dart';

/// A minimal host so the palette can be opened without booting the
/// whole app — most of these tests exercise the dialog in isolation;
/// the last test confirms the real Platform entry point (Ctrl+K, bound
/// in `StudioShell`) actually opens it.
class _PaletteHarness extends StatelessWidget {
  const _PaletteHarness({this.inputService});

  final PlatformInputService? inputService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPaletteDialog(context, inputService: inputService),
              child: const Text('Open Palette'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openPalette(WidgetTester tester, {PlatformInputService? inputService}) async {
  await tester.pumpWidget(ProviderScope(child: _PaletteHarness(inputService: inputService)));
  await tester.tap(find.text('Open Palette'));
  await tester.pumpAndSettle();
}

void main() {
  group('CommandPaletteDialog — discovery (Phase 1/2)', () {
    testWidgets('shows the Commands header and search field', (tester) async {
      await _openPalette(tester);
      expect(find.text('Commands'), findsOneWidget);
      expect(find.text('Search commands…'), findsOneWidget);
    });

    testWidgets('every registered command is reachable in the list, in registration order', (tester) async {
      await _openPalette(tester);

      final commands = CommandRegistry.defaultRegistry.commands;
      expect(commands, hasLength(22),
          reason: 'WP-STUDIO-023 registered 13 (Diagram/Acquisition); WP-STUDIO-025 added 5 more (Knowledge); '
              'WP-EXC-010 added 3 more (Exchange); AP-EK-020 added 1 more (diagram.analyze).');

      final listFinder = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
      // First-registered (Diagram) and last-registered (Acquisition)
      // commands both resolve, proving the palette walks the full,
      // real registry rather than a truncated or reordered copy.
      await tester.scrollUntilVisible(find.text('New Diagram'), 50, scrollable: listFinder);
      expect(find.text('New Diagram'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Publish to Reference Vault'), 200, scrollable: listFinder);
      expect(find.text('Publish to Reference Vault'), findsOneWidget);
    });

    testWidgets('each row shows command name, Studio name, capability name, and description — '
        'all read live from the registries, none hardcoded', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'Revalidate');
      await tester.pumpAndSettle();

      expect(find.text('Revalidate Diagram'), findsOneWidget);
      expect(find.text('Diagram Studio'), findsOneWidget);
      expect(find.text('Diagram Validation'), findsOneWidget);
      expect(
        find.text('Forces a fresh validation pass over the active diagram graph.'),
        findsOneWidget,
      );
    });
  });

  group('CommandPaletteDialog — search (Phase 3)', () {
    testWidgets('filters to a single command by name substring, case-insensitively', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'vault');
      await tester.pumpAndSettle();

      expect(find.text('Publish to Reference Vault'), findsOneWidget);
      expect(find.text('New Diagram'), findsNothing);
    });

    testWidgets('filters by Studio name', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'Engineering Acquisition');
      await tester.pumpAndSettle();

      expect(find.text('New Diagram'), findsNothing);
      // 5 Acquisition commands match — "Publish to Reference Vault" is
      // registered last, so it may be below the fold; scroll to it.
      await tester.scrollUntilVisible(
        find.text('Publish to Reference Vault'),
        100,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
      );
      expect(find.text('Publish to Reference Vault'), findsOneWidget);
    });

    testWidgets('discovers Knowledge Studio commands (WP-STUDIO-025) by Studio name, '
        'with no palette code changes required', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'Knowledge Studio');
      await tester.pumpAndSettle();

      expect(find.text('Accept Knowledge Candidate'), findsOneWidget);
      expect(find.text('New Diagram'), findsNothing);
    });

    testWidgets('filters by capability name', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'Acquisition Job Orchestration');
      await tester.pumpAndSettle();

      expect(find.text('Execute Acquisition Job'), findsOneWidget);
      expect(find.text('Cancel Acquisition Job'), findsOneWidget);
      expect(find.text('Publish to Reference Vault'), findsNothing);
    });

    testWidgets('filters by description substring', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'SHA-256');
      await tester.pumpAndSettle();

      expect(find.text('Verify Download'), findsOneWidget);
      expect(find.text('New Diagram'), findsNothing);
    });
  });

  group('CommandPaletteDialog — empty states (Phase 5)', () {
    testWidgets('shows "no results" when the query matches nothing', (tester) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'zzz_no_such_command_zzz');
      await tester.pumpAndSettle();

      expect(find.text('No commands match "zzz_no_such_command_zzz".'), findsOneWidget);
    });

    testWidgets('shows "no commands registered" when the underlying CommandRegistry is empty', (tester) async {
      await _openPalette(tester, inputService: PlatformInputService(commandRegistry: CommandRegistry(const [])));
      expect(find.text('No commands are registered yet.'), findsOneWidget);
    });
  });

  group('CommandPaletteDialog — execution (Phase 4)', () {
    testWidgets('a no-argument command executes through PlatformInputService.runCommand and closes the palette', (
      tester,
    ) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'Undo');
      await tester.pumpAndSettle();

      // find.text('Undo') is ambiguous once the search field itself
      // contains the text "Undo" — target the row's InkWell instead.
      await tester.tap(find.widgetWithText(InkWell, 'Undo'));
      await tester.pumpAndSettle();

      // Success closes the dialog and surfaces a SnackBar — no Studio
      // method was called by this test; only PlatformInputService.runCommand
      // (which forwards to CommandRegistry.execute) was.
      expect(find.text('Commands'), findsNothing);
      expect(find.text('Undo completed.'), findsOneWidget);
    });

    testWidgets('a requiresArgument command prompts before executing, and Cancel leaves the palette open', (
      tester,
    ) async {
      await _openPalette(tester);
      await tester.enterText(find.byType(TextField).first, 'Open Diagram');
      await tester.pumpAndSettle();

      // Same ambiguity as above: the search field itself now contains
      // the text "Open Diagram" too.
      await tester.tap(find.widgetWithText(InkWell, 'Open Diagram'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a value'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The prompt closed but the palette itself is still open — no
      // execution happened.
      expect(find.text('Commands'), findsOneWidget);
    });
  });

  group('Platform integration (Phase 6)', () {
    testWidgets('Ctrl+K opens the Command Palette from anywhere in the app (WP-STUDIO-027)', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: StudioApp()));
      await tester.pumpAndSettle();

      expect(find.text('Search commands…'), findsNothing, reason: 'the palette should not already be open');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('Search commands…'), findsOneWidget);
    });
  });
}
