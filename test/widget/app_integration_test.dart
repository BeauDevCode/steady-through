import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/check_ins/check_ins_screen.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/features/tools/tools_screen.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();

  @override
  Future<void> save(AppData value) async {}
}

Future<void> _select(WidgetTester tester, String label) async {
  final navigation = find.byType(NavigationBar).evaluate().isNotEmpty
      ? find.byType(NavigationBar)
      : find.byType(NavigationRail);
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  late AppController controller;

  setUp(() {
    controller = AppController(_MemoryRepository(), AppData.empty());
  });
  tearDown(() => controller.dispose());

  testWidgets('all main destinations show their implemented screens', (
    tester,
  ) async {
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    await _select(tester, 'Tools');
    expect(find.byType(ToolsScreen), findsOneWidget);
    await _select(tester, 'Check-ins');
    expect(find.byType(CheckInsScreen), findsOneWidget);
    await _select(tester, 'More');
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.textContaining('temporary'), findsNothing);
  });

  testWidgets('global Help now opens the implemented help screen', (
    tester,
  ) async {
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    await tester.tap(find.text('Help now'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpScreen), findsOneWidget);
  });
}
