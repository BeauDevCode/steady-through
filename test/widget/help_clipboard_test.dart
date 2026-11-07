import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/model/app_data.dart';

class _Repository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();
  @override
  Future<void> save(AppData value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppController controller;
  var requests = 0;
  var failCopy = false;
  Completer<void>? pending;

  setUp(() {
    requests = 0;
    failCopy = false;
    pending = null;
    controller = AppController(
      _Repository(),
      AppData(
        people: [TrustedPerson(id: 'fictional', name: 'Fictional helper')],
      ),
    );
    // Replace only the external clipboard boundary. No system clipboard writes.
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        requests++;
        expect((call.arguments as Map)['text'], '988');
        await pending?.future;
        if (failCopy) throw PlatformException(code: 'unavailable');
      }
      return null;
    });
  });
  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HelpScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Help reports clipboard failure and keeps number available', (
    tester,
  ) async {
    await mount(tester);
    failCopy = true;
    await reveal(tester, find.text('Copy 988'));
    await tester.tap(find.text('Copy 988'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Could not copy'), findsOneWidget);
    expect(find.text('Copy 988'), findsOneWidget);
    expect(find.text('988 copied.'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('Help suppresses duplicate pending copies and allows retry', (
    tester,
  ) async {
    await mount(tester);
    final gate = Completer<void>();
    pending = gate;
    await reveal(tester, find.text('Copy 988'));
    try {
      await tester.tap(find.text('Copy 988'));
      await tester.pump();
      await tester.tap(find.text('Copy 988'));
      await tester.pump();
      expect(requests, 1);
    } finally {
      gate.complete();
      await tester.pumpAndSettle();
    }
    expect(find.text('988 copied.'), findsOneWidget);
    pending = null;
    await tester.tap(find.text('Copy 988'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  for (final failure in [false, true]) {
    testWidgets(
      'Help copy has no late ${failure ? 'failure' : 'success'} over People',
      (tester) async {
        await mount(tester);
        final gate = Completer<void>();
        pending = gate;
        failCopy = failure;
        await reveal(tester, find.text('Copy 988'));
        await tester.tap(find.text('Copy 988'));
        await tester.pump();
        try {
          await reveal(tester, find.text('View all saved people'));
          await tester.tap(find.text('View all saved people'));
          await tester.pumpAndSettle();
        } finally {
          gate.complete();
          await tester.pumpAndSettle();
        }
        expect(find.text('Your saved people'), findsOneWidget);
        expect(find.text('988 copied.'), findsNothing);
        expect(find.textContaining('Could not copy'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Help copy ignores an attempt invalidated by backgrounding', (
    tester,
  ) async {
    await mount(tester);
    final gate = Completer<void>();
    pending = gate;
    await reveal(tester, find.text('Copy 988'));
    await tester.tap(find.text('Copy 988'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('988 copied.'), findsNothing);
    expect(find.textContaining('Could not copy'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
