import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/home/home_screen.dart';
import 'package:steady_through/features/check_ins/check_ins_screen.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/journey_screen.dart';
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/features/tools/tools_screen.dart';
import 'package:steady_through/model/app_data.dart';

/// Callback seam for feature destinations that are implemented separately.
typedef SteadyDestinationBuilder = Widget Function(
  BuildContext context,
  AppController controller,
  VoidCallback openHelp,
);

typedef SteadyHelpBuilder = Widget Function(
  BuildContext context,
  AppController controller,
);

class SteadyThroughApp extends StatefulWidget {
  const SteadyThroughApp({
    super.key,
    required this.controller,
    this.toolsBuilder,
    this.checkInsBuilder,
    this.moreBuilder,
    this.helpBuilder,
  });

  final AppController controller;
  final SteadyDestinationBuilder? toolsBuilder;
  final SteadyDestinationBuilder? checkInsBuilder;
  final SteadyDestinationBuilder? moreBuilder;
  final SteadyHelpBuilder? helpBuilder;

  @override
  State<SteadyThroughApp> createState() => _SteadyThroughAppState();
}

class _SteadyThroughAppState extends State<SteadyThroughApp> {
  int _destination = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Path',
    ),
    NavigationDestination(
      icon: Icon(Icons.spa_outlined),
      selectedIcon: Icon(Icons.spa),
      label: 'Tools',
    ),
    NavigationDestination(
      icon: Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note),
      label: 'Check-ins',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz),
      selectedIcon: Icon(Icons.more),
      label: 'More',
    ),
  ];

  static const _railDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: Text('Path'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.spa_outlined),
      selectedIcon: Icon(Icons.spa),
      label: Text('Tools'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note),
      label: Text('Check-ins'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.more_horiz),
      selectedIcon: Icon(Icons.more),
      label: Text('More'),
    ),
  ];

  void _selectDestination(int index) => setState(() => _destination = index);

  Future<void> _openCreateEvent(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventForm(
          simpleWords:
              widget.controller.data.readingStyle == ReadingStyle.simple,
          onSave: widget.controller.createEvent,
        ),
      ),
    );
    if (saved == true && mounted) _selectDestination(1);
  }

  Future<void> _openEditEvent(BuildContext context, SupportEvent event) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventForm(
          event: event,
          simpleWords:
              widget.controller.data.readingStyle == ReadingStyle.simple,
          onSave: (title, description) =>
              widget.controller.updateEvent(event.id, title, description),
        ),
      ),
    );
  }

  void _openHelp(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) =>
            widget.helpBuilder?.call(routeContext, widget.controller) ??
            Scaffold(
              appBar: AppBar(title: const Text('Help now')),
              body: HelpScreen(
                simpleWords:
                    widget.controller.data.readingStyle == ReadingStyle.simple,
              ),
            ),
      ),
    );
  }

  void _openGrounding(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: GroundingScreen(
            controller: widget.controller,
            onOpenHelp: () => _openHelp(context),
            backLabel: 'Back to Home',
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    void openHelp() => _openHelp(context);
    void openPathFromGame() {
      Navigator.of(context).pop();
      _selectDestination(1);
    }

    switch (_destination) {
      case 0:
        return HomeScreen(
          controller: widget.controller,
          onCreateEvent: () => _openCreateEvent(context),
          onOpenPath: () => _selectDestination(1),
          onOpenGrounding: () => _openGrounding(context),
          onOpenCheckIns: () => _selectDestination(3),
        );
      case 1:
        return JourneyScreen(
          controller: widget.controller,
          onCreateEvent: () => _openCreateEvent(context),
          onEditEvent: (event) => _openEditEvent(context, event),
          onDeleted: () => _selectDestination(0),
        );
      case 2:
        return widget.toolsBuilder?.call(
              context,
              widget.controller,
              openHelp,
            ) ??
            ToolsScreen(
              controller: widget.controller,
              showHelpNow: false,
              onOpenHelp: openHelp,
              onOpenPath: openPathFromGame,
            );
      case 3:
        return widget.checkInsBuilder?.call(
              context,
              widget.controller,
              openHelp,
            ) ??
            CheckInsScreen(controller: widget.controller);
      default:
        return widget.moreBuilder?.call(context, widget.controller, openHelp) ??
            MoreScreen(controller: widget.controller);
    }
  }

  Widget _scaffold(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final titles = ['Home', 'Path', 'Tools', 'Check-ins', 'More'];
    final body = _body(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_destination],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => _openHelp(context),
            child: const Text('Help now'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _destination,
                  labelType: NavigationRailLabelType.all,
                  minWidth: 96,
                  destinations: _railDestinations,
                  onDestinationSelected: _selectDestination,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _destination,
              onDestinationSelected: _selectDestination,
              labelBehavior: largeText
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _destinations,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final choice = widget.controller.data.theme;
      return MaterialApp(
        title: 'Steady Through',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF286C71)),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF68B9BD),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: switch (choice) {
          ThemeChoice.system => ThemeMode.system,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.dark => ThemeMode.dark,
        },
        home: Builder(builder: _scaffold),
      );
    },
  );
}
