import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();

  @override
  Future<void> save(AppData value) async {}
}

void main() {
  testWidgets('consented in-app taps include a pushed event form route', (
    tester,
  ) async {
    final controller = AppController(
      _MemoryRepository(),
      AppData(learning: LearningData(enabledSources: {SignalSource.inApp})),
    );
    final session = LearningSession(controller);
    addTearDown(() async {
      await session.close();
      controller.dispose();
    });

    await tester.pumpWidget(
      SteadyThroughApp(controller: controller, learningSession: session),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
    await tester.pumpAndSettle();
    expect(session.snapshot.features['tapCount'], 1);

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    expect(session.snapshot.features['tapCount'], 2);
  });
}
