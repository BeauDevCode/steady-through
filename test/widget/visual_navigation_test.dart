import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();
  @override
  Future<void> save(AppData value) async {}
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Active tools'));
}

Future<void> _select(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar).evaluate().isNotEmpty
          ? find.byType(NavigationBar)
          : find.byType(NavigationRail),
      matching: find.text(name),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'incoming motion settles while the outgoing tab disposes immediately',
    (tester) async {
      var disposed = 0;
      final controller = AppController(_MemoryRepository(), AppData.empty());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        SteadyThroughApp(
          controller: controller,
          toolsBuilder: (_, _, _) => _Probe(onDispose: () => disposed++),
          checkInsBuilder: (_, _, _) =>
              const Center(child: Text('Active notes')),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester, 'Tools');
      final initial = tester.getTopLeft(find.text('Active tools'));
      await tester.pump(const Duration(milliseconds: 100));
      final halfway = tester.getTopLeft(find.text('Active tools'));
      expect(halfway.dy, lessThan(initial.dy));
      await _select(tester, 'Check-ins');
      expect(disposed, 1);
      expect(find.text('Active tools'), findsNothing);
      expect(find.text('Active notes'), findsOneWidget);
      await _select(tester, 'Home');
      await _select(tester, 'Tools');
      await _select(tester, 'Check-ins');
      expect(disposed, 2);
      await tester.pumpAndSettle();
      expect(find.text('Active tools'), findsNothing);
      expect(find.text('Active notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Help stays reachable in the first frame of an incoming tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppController(_MemoryRepository(), AppData.empty());
    addTearDown(controller.dispose);
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await tester.pumpAndSettle();
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    nav.onDestinationSelected!(2);
    await tester.pump();
    await tester.tap(find.byTooltip('Help now'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
