import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/workbench/engineering_workbench_page.dart';
import 'package:oep_studio/workbench/layout/workbench_layout_manager.dart';
import 'package:oep_studio/workbench/perspective/perspective.dart';
import 'package:oep_studio/workbench/perspective/perspective_manager.dart';

/// WP-DS-006: integration-style test exercising perspective switching
/// end to end inside [EngineeringWorkbenchPage], against a small fixture
/// Perspective list and real files in a temp directory (matching
/// perspective_manager_test.dart's "real files in a temp dir, no mocks"
/// convention).
///
/// **Real dart:io inside `testWidgets`**: a bare `Future.delayed`/pending
/// fire-and-forget file write does not reliably progress inside a plain
/// `testWidgets` async body — `test/session_manager_test.dart` documents
/// the same class of issue. Every place below that needs a real
/// fire-and-forget persist (`PerspectiveManager.activate`/
/// `WorkbenchLayoutManager.update`) to actually land on disk wraps BOTH
/// the triggering call and the wait inside a single `tester.runAsync(...)`
/// block — wrapping only the wait is not enough, since the write's own
/// `Future` is created in whatever zone the triggering call ran in.
void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('workbench_page_test_'));
  tearDown(() {
    if (!tempDir.existsSync()) return;
    // A fire-and-forget write can still hold the file open briefly after
    // its Future resolves (Windows file-handle release lag, sometimes
    // stretched further by real-time antivirus scanning of newly-written
    // files) — retry the recursive delete a few times, but treat cleanup
    // as best-effort rather than part of the test's pass/fail contract:
    // a leftover directory under the OS temp folder is harmless (the OS
    // reclaims it eventually), while failing an otherwise-correct test on
    // a transient OS-level file lock is not an actual regression signal.
    //
    // The wait must be a REAL, synchronous, zone-independent one:
    // `tearDown` has no `tester` in scope, so `Future.delayed` here
    // (outside any `tester.runAsync`) never progresses under the
    // fake-async test clock and hangs the test indefinitely. `dart:io`'s
    // `sleep` is a true blocking OS sleep, unaffected by FakeAsync's
    // virtual clock.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        tempDir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 4) return; // best-effort cleanup, not a test assertion
        sleep(const Duration(milliseconds: 200));
      }
    }
  });

  List<Perspective> fixtures() => [
        Perspective(
          id: 'alpha',
          title: 'Alpha',
          icon: Icons.circle,
          centerBuilder: (context) => const Text('alpha-center'),
          toolbarProvider: (context) => const Text('alpha-toolbar'),
        ),
        Perspective(
          id: 'beta',
          title: 'Beta',
          icon: Icons.square,
          centerBuilder: (context) => const Text('beta-center'),
          leftPanelProvider: (context) => const Text('beta-left'),
          defaultLayout: const PerspectiveLayout(leftVisible: true),
        ),
      ];

  // EngineeringWorkbenchPage's PerspectiveSelector uses InkWell, which
  // needs a Material ancestor — Scaffold provides one, matching how this
  // page is actually hosted in the real app (StudioShell's own Scaffold).
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('boots into the first registered perspective and renders its center content', (tester) async {
    final perspectiveManager = PerspectiveManager(file: File('${tempDir.path}/active.json'));
    final layoutManager = WorkbenchLayoutManager(directory: Directory('${tempDir.path}/layouts'));

    await tester.pumpWidget(
      harness(EngineeringWorkbenchPage(
        perspectives: fixtures(),
        perspectiveManager: perspectiveManager,
        layoutManager: layoutManager,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha-center'), findsOneWidget);
    expect(find.text('alpha-toolbar'), findsOneWidget);
    expect(find.text('beta-center'), findsNothing);
  });

  testWidgets('tapping the Perspective Selector switches the center workspace and per-perspective layout', (tester) async {
    final perspectiveManager = PerspectiveManager(file: File('${tempDir.path}/active.json'));
    final layoutManager = WorkbenchLayoutManager(directory: Directory('${tempDir.path}/layouts'));

    await tester.pumpWidget(
      harness(EngineeringWorkbenchPage(
        perspectives: fixtures(),
        perspectiveManager: perspectiveManager,
        layoutManager: layoutManager,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha-center'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(find.text('beta-center'), findsOneWidget);
    expect(find.text('alpha-center'), findsNothing);
    // Beta's defaultLayout has leftVisible: true and a real leftPanelProvider.
    expect(find.text('beta-left'), findsOneWidget);
  });

  testWidgets('restores the last-active perspective across a fresh EngineeringWorkbenchPage instance', (tester) async {
    final activeFile = File('${tempDir.path}/active.json');
    final layoutDir = Directory('${tempDir.path}/layouts');

    final firstPerspectiveManager = PerspectiveManager(file: activeFile);
    await tester.pumpWidget(
      harness(EngineeringWorkbenchPage(
        perspectives: fixtures(),
        perspectiveManager: firstPerspectiveManager,
        layoutManager: WorkbenchLayoutManager(directory: layoutDir),
      )),
    );
    await tester.pumpAndSettle();

    // The tap triggers PerspectiveManager.activate's fire-and-forget
    // write — per this file's own doc comment, the TRIGGER itself (not
    // just a trailing wait) must run inside runAsync, since the write's
    // Future is created in whatever zone the triggering call ran in.
    await tester.runAsync(() async {
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(find.text('beta-center'), findsOneWidget);

    // Fresh page, fresh managers, same underlying files.
    final secondPerspectiveManager = PerspectiveManager(file: activeFile);
    await tester.pumpWidget(
      harness(EngineeringWorkbenchPage(
        perspectives: fixtures(),
        perspectiveManager: secondPerspectiveManager,
        layoutManager: WorkbenchLayoutManager(directory: layoutDir),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('beta-center'), findsOneWidget);
    expect(find.text('alpha-center'), findsNothing);
  });

  testWidgets("changing one perspective's layout does not affect another's persisted file", (tester) async {
    final layoutDir = Directory('${tempDir.path}/layouts');
    final layoutManager = WorkbenchLayoutManager(directory: layoutDir);
    final perspectiveManager = PerspectiveManager(file: File('${tempDir.path}/active.json'));
    final all = fixtures();

    await tester.pumpWidget(
      harness(EngineeringWorkbenchPage(
        perspectives: all,
        perspectiveManager: perspectiveManager,
        layoutManager: layoutManager,
      )),
    );
    await tester.pumpAndSettle();

    // The trigger itself (layoutManager.update, which fire-and-forgets a
    // write) must run inside the same runAsync block as the wait — its
    // returned Future is created in whatever zone the call happened in,
    // and only runAsync's zone reliably progresses real dart:io.
    await tester.runAsync(() async {
      layoutManager.update(all.firstWhere((p) => p.id == 'alpha'), (l) => l.copyWith(bottomVisible: true, bottomHeight: 333));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    expect(File('${layoutDir.path}/alpha.json').existsSync(), isTrue);
    expect(File('${layoutDir.path}/beta.json').existsSync(), isFalse);
  });
}
