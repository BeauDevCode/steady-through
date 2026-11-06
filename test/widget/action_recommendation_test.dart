import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  AppData value = AppData.empty();

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async => value = next;
}

// The stage badge is the visible cue for the recommended part of Path.
Color? _stageBadgeColor(WidgetTester tester, int stage) {
  final badge = find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Stage $stage',
    ),
    matching: find.byType(Container),
  );
  return (tester.widget<Container>(badge).decoration as BoxDecoration).color;
}

void main() {
  late AppController controller;

  setUp(() {
    controller = AppController(_MemoryRepository(), AppData.empty());
  });
  tearDown(() => controller.dispose());

  Future<void> prepareLateOrientation(WidgetTester tester) async {
    await tester.runAsync(() async {
      await controller.createEvent('Moving house', '');
      final event = controller.activeEvent!;
      await controller.setActionDone(event.id, event.actions.first.id, true);
      await controller.addAction(
        event.id,
        JourneyStage.orient,
        'Check the moving date',
      );
    });
  }

  testWidgets('Home recommends late-added Orient before default Settle', (
    tester,
  ) async {
    await prepareLateOrientation(tester);
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    expect(find.text('Check the moving date'), findsOneWidget);
    expect(find.text('Take a short pause'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Path highlights Orient again when it gains a pending action', (
    tester,
  ) async {
    await prepareLateOrientation(tester);
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();

    final colors = Theme.of(tester.element(find.text('Your path'))).colorScheme;
    expect(_stageBadgeColor(tester, 1), colors.primary);
    await tester.scrollUntilVisible(find.text('Settle'), 200);
    expect(_stageBadgeColor(tester, 2), colors.surface);
    await tester.scrollUntilVisible(find.text('Get oriented'), -200);
    expect(_stageBadgeColor(tester, 1), colors.primary);
    expect(find.text('Check the moving date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
