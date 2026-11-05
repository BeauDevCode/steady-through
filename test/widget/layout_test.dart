import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();
  @override
  Future<void> save(AppData value) async {}
}

Future<void> _inspectScroll(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  final scroll = find.byType(Scrollable).last;
  for (var pass = 0; pass < 5; pass++) {
    await tester.drag(scroll, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  for (final size in [const Size(320, 740), const Size(1200, 800)]) {
    testWidgets(
      'long entries fit every destination at ${size.width} width and 200% text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final event = SupportEvent(
          id: 'event',
          title: 'A very long name for a big life change that takes time to work through',
          createdAt: DateTime.utc(2026, 11, 5),
          actions: [
            for (final stage in JourneyStage.values)
              PlanAction(
                id: stage.name,
                stage: stage,
                title: 'Choose one small and manageable action with someone I trust',
              ),
          ],
        );
        final controller = AppController(
          _MemoryRepository(),
          AppData(
            events: [event],
            activeEventId: event.id,
            people: [
              TrustedPerson(
                id: 'person',
                name: 'A trusted person with a long name',
                phone: '+1 555 010 1234',
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(SteadyThroughApp(controller: controller));
        await tester.pumpAndSettle();
        for (var index = 0; index < 5; index++) {
          if (find.byType(NavigationRail).evaluate().isNotEmpty) {
            tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .onDestinationSelected!(index);
          } else {
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .onDestinationSelected!(index);
          }
          await tester.pumpAndSettle();
          await _inspectScroll(tester);
        }
        // The More destinations are embedded within the same accessible shell.
        await tester.ensureVisible(find.text('People').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('People').last);
        await tester.pumpAndSettle();
        await _inspectScroll(tester);
        await tester.ensureVisible(find.text('Back to More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back to More'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Settings'), 250);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        await _inspectScroll(tester);
      },
    );
  }
}
