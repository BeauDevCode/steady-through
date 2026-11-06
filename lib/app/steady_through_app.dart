import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/home/home_screen.dart';
import 'package:steady_through/features/check_ins/check_ins_screen.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/journey_screen.dart';
import 'package:steady_through/features/journey/focused_action_screen.dart';
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/features/tools/tools_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/next_action_target.dart';
import 'package:steady_through/ui/steady_theme.dart';
import 'package:steady_through/features/insights/insights_screen.dart';
import 'package:steady_through/learning/learning_session.dart';

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
    this.learningSession,
    this.onLock,
    this.storageWarning,
  });

  final AppController controller;
  final SteadyDestinationBuilder? toolsBuilder;
  final SteadyDestinationBuilder? checkInsBuilder;
  final SteadyDestinationBuilder? moreBuilder;
  final SteadyHelpBuilder? helpBuilder;
  final LearningSession? learningSession;
  final Future<void> Function()? onLock;
  final String? storageWarning;

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

  void _selectDestination(int index) {
    if (_destination != index) widget.learningSession?.recordNavigation();
    setState(() => _destination = index);
  }

  void _openInsights(BuildContext context) {
    final learning = widget.learningSession;
    if (learning == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: const Text('Insights'),
            actions: [
              TextButton(
                onPressed: () => _openHelp(routeContext),
                child: const Text('Help now'),
              ),
            ],
          ),
          body: InsightsScreen(
            session: learning,
            onOpenHelp: () => _openHelp(routeContext),
            onOpenPath: () {
              Navigator.of(routeContext).pop();
              _selectDestination(1);
            },
            onGrounding: () => Navigator.of(routeContext).push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: GroundingScreen(
                    controller: widget.controller,
                    safetySession: widget.learningSession,
                    onOpenHelp: () => _openHelp(routeContext),
                    backLabel: 'Back to Insights',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateEvent(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventForm(
          simpleWords:
              widget.controller.data.readingStyle == ReadingStyle.simple,
          onSave: (submission) => widget.controller.createEvent(
            submission.title,
            submission.description,
            guidanceContext: submission.guidanceContext,
            starterStepIds: submission.starterStepIds,
          ),
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
          onSave: (submission) => widget.controller.updateEvent(
            event.id,
            submission.title,
            submission.description,
            guidanceContext: submission.guidanceContext,
          ),
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
                controller: widget.controller,
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
            safetySession: widget.learningSession,
            onOpenHelp: () => _openHelp(context),
            backLabel: 'Back to Home',
          ),
        ),
      ),
    );
  }

  void _openNextAction(BuildContext context, NextActionTarget target) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => FocusedActionScreen(
          controller: widget.controller,
          target: target,
          onOpenHelp: () => _openHelp(routeContext),
          onOpenPath: () {
            Navigator.of(routeContext).pop();
            _selectDestination(1);
          },
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
          onOpenNextAction: (target) => _openNextAction(context, target),
          onOpenGrounding: () => _openGrounding(context),
          onOpenCheckIns: () => _selectDestination(3),
          onOpenInsights: widget.learningSession == null
              ? null
              : () => _openInsights(context),
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
              safetySession: widget.learningSession,
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
            MoreScreen(
              controller: widget.controller,
              onOpenInsights: widget.learningSession == null
                  ? null
                  : () => _openInsights(context),
              onLock: widget.onLock,
            );
    }
  }

  Widget _scaffold(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final expanded = width >= 1180 && !largeText;
    final body = _body(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: Row(
                children: [
                  Icon(Icons.route_rounded, color: colors.primary, size: 23),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Steady Through',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                if (largeText && width < 600)
                  IconButton(
                    onPressed: () => _openHelp(context),
                    tooltip: 'Help now',
                    icon: const Icon(Icons.support_agent_rounded),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _openHelp(context),
                    icon: const Icon(Icons.support_agent_rounded, size: 20),
                    label: const Text('Help now'),
                  ),
                const SizedBox(width: 16),
              ],
            ),
      body: Column(
        children: [
          if (widget.storageWarning != null)
            MaterialBanner(
              content: Text(widget.storageWarning!),
              actions: [
                TextButton(
                  onPressed: widget.onLock,
                  child: const Text('Lock vault'),
                ),
              ],
            ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _destination,
                        extended: expanded,
                        labelType: expanded
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        minWidth: 88,
                        minExtendedWidth: 220,
                        groupAlignment: -1,
                        leading: Padding(
                          padding: EdgeInsets.fromLTRB(
                            expanded ? 20 : 8,
                            24,
                            expanded ? 20 : 8,
                            30,
                          ),
                          child: expanded
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: colors.primaryContainer,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.route_rounded,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Steady\nThrough',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(height: 1.2),
                                    ),
                                  ],
                                )
                              : Icon(
                                  Icons.route_rounded,
                                  color: colors.primary,
                                  size: 30,
                                ),
                        ),
                        destinations: _railDestinations,
                        onDestinationSelected: _selectDestination,
                      ),
                      VerticalDivider(width: 1, color: colors.outlineVariant),
                      Expanded(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 76,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: TextButton.icon(
                                    onPressed: () => _openHelp(context),
                                    icon: const Icon(
                                      Icons.support_agent_rounded,
                                      size: 20,
                                    ),
                                    label: const Text('Help now'),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(child: body),
                          ],
                        ),
                      ),
                    ],
                  )
                : body,
          ),
        ],
      ),
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
        theme: steadyTheme(Brightness.light),
        darkTheme: steadyTheme(Brightness.dark),
        themeMode: switch (choice) {
          ThemeChoice.system => ThemeMode.system,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.dark => ThemeMode.dark,
        },
        builder: (context, child) => Listener(
          onPointerDown: (_) => widget.learningSession?.recordTap(),
          child: Column(
            children: [
              if (widget.controller.cleanupWarning case final warning?)
                Material(
                  child: SafeArea(
                    bottom: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .4,
                      ),
                      child: SingleChildScrollView(
                        child: Semantics(
                          liveRegion: true,
                          child: MaterialBanner(
                            content: Text(warning),
                            forceActionsBelow: true,
                            actions: [
                              TextButton(
                                onPressed: widget.onLock,
                                child: const Text('Lock vault'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
        home: Builder(builder: _scaffold),
      );
    },
  );
}
