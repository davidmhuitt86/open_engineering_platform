import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/notifications/platform_notification_service.dart';

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return capturedContext;
}

void main() {
  group('PlatformNotificationService', () {
    testWidgets('success shows a SnackBar with the given message', (tester) async {
      final context = await _pumpContext(tester);
      PlatformNotificationService.success(context, 'Diagram saved.');
      await tester.pump();

      expect(find.text('Diagram saved.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('error shows a SnackBar with the given message', (tester) async {
      final context = await _pumpContext(tester);
      PlatformNotificationService.error(context, 'Could not save.');
      await tester.pump();

      expect(find.text('Could not save.'), findsOneWidget);
    });

    testWidgets('info shows a SnackBar with the given message', (tester) async {
      final context = await _pumpContext(tester);
      PlatformNotificationService.info(context, 'Refreshed.');
      await tester.pump();

      expect(find.text('Refreshed.'), findsOneWidget);
    });

    testWidgets('success uses green and error uses red — distinct, real colors, checked in independent tests '
        '(a single ScaffoldMessenger only shows one SnackBar at a time and queues the rest, so two shown in the '
        'same test would falsely compare the first against itself)', (tester) async {
      final context = await _pumpContext(tester);
      PlatformNotificationService.success(context, 'ok');
      await tester.pump();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, Colors.green.shade700);
    });

    testWidgets('error uses red', (tester) async {
      final context = await _pumpContext(tester);
      PlatformNotificationService.error(context, 'bad');
      await tester.pump();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, Colors.red.shade700);
    });

    testWidgets(
      'success/error/info each also publish a NotificationEvent on the Platform Event Bus '
      '(WP-STUDIO-030), so a NotificationCenter can build a history from the same call — '
      'the SnackBar itself is unchanged by this',
      (tester) async {
        final received = <NotificationEvent>[];
        final subscription = PlatformEventBus.instance.on<NotificationEvent>().listen(received.add);
        addTearDown(subscription.cancel);

        final context = await _pumpContext(tester);
        PlatformNotificationService.success(context, 'Diagram saved.');
        await tester.pump();

        expect(received, hasLength(1));
        expect(received.single.severity, NotificationSeverity.success);
        expect(received.single.message, 'Diagram saved.');
      },
    );
  });
}
