import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/event_guidance.dart';

class GuidanceRepository implements AppRepository {
  final List<AppData> saved = [];
  bool failNext = false;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<AppData> load() async => saved.isEmpty ? AppData.empty() : saved.last;

  @override
  Future<void> save(AppData value) async {
    if (entered != null) {
      final signal = entered!;
      entered = null;
      signal.complete();
      await release!.future;
    }
    if (failNext) {
      failNext = false;
      throw StateError('Fictional storage failure');
    }
    saved.add(value);
  }
}

void main() {
  group('offline guidance catalog', () {
    test(
      'five contexts each have all stages, immutable steps and both copies',
      () {
        expect(GuidanceContext.values, hasLength(5));
        for (final context in GuidanceContext.values) {
          final guide = guideFor(context);
          expect(guide.context, context);
          for (final text in [
            guide.label,
            guide.simpleLabel,
            guide.description,
            guide.simpleDescription,
            guide.helperNote,
            guide.simpleHelperNote,
          ]) {
            expect(text.trim(), isNotEmpty);
          }
          expect(
            guide.starterSteps.map((step) => step.stage),
            JourneyStage.values,
          );
          expect(() => guide.starterSteps.clear(), throwsUnsupportedError);
          for (final step in guide.starterSteps) {
            expect(step.id, '${context.name}.${step.stage.name}');
            expect(step.text(simpleWords: false), isNotEmpty);
            expect(step.text(simpleWords: true), isNotEmpty);
            expect(
              guide.stagePrompt(step.stage, simpleWords: false),
              isNotEmpty,
            );
            expect(
              guide.stagePrompt(step.stage, simpleWords: true),
              isNotEmpty,
            );
          }
        }
      },
    );

    test('General preserves its five existing standard titles', () {
      expect(
        guideFor(GuidanceContext.general).starterSteps.map((s) => s.title),
        [
          'Notice what needs attention first',
          'Take a short pause',
          'Choose someone to reach out to',
          'Write one next step',
          'Notice what helped',
        ],
      );
    });

    test(
      'resolving validates all IDs and uses guide order, not request order',
      () {
        final guide = guideFor(GuidanceContext.caregiving);
        final steps = guide.starterSteps;
        expect(
          resolveStarterSteps(guide.context, [steps.last.id, steps.first.id]),
          [steps.first, steps.last],
        );
        expect(resolveStarterSteps(guide.context, []), isEmpty);
        for (final ids in [
          [steps.first.id, steps.first.id],
          [steps.first.id, 'caregiving.unknown'],
          [steps.first.id, 'general.settle'],
        ]) {
          expect(
            () => resolveStarterSteps(guide.context, ids),
            throwsArgumentError,
          );
        }
      },
    );

    test(
      'matches both text variants with trimmed case and same stage only',
      () {
        final step = guideFor(GuidanceContext.general).starterSteps.first;
        for (final title in [step.title, step.simpleTitle]) {
          expect(
            step.matchesAction(
              PlanAction(
                id: 'fictional-existing',
                stage: step.stage,
                title: '  ${title.toUpperCase()}  ',
                done: true,
              ),
            ),
            isTrue,
          );
          expect(
            step.matchesAction(
              PlanAction(
                id: 'fictional-other-stage',
                stage: JourneyStage.reflect,
                title: title,
              ),
            ),
            isFalse,
          );
        }
      },
    );
  });

  group('guidance controller transactions', () {
    late GuidanceRepository repository;
    late AppController controller;

    setUp(() {
      repository = GuidanceRepository();
      controller = AppController(repository, AppData.empty());
    });
    tearDown(() => controller.dispose());

    test('null chooses all selected-guide steps; empty chooses none', () async {
      await controller.createEvent(
        'Fictional school event',
        '',
        guidanceContext: GuidanceContext.schoolAndGrowing,
      );
      final first = controller.activeEvent!;
      expect(first.guidanceContext, GuidanceContext.schoolAndGrowing);
      expect(
        first.actions.map((a) => a.title),
        guideFor(first.guidanceContext).starterSteps.map((s) => s.title),
      );
      await controller.createEvent(
        'Fictional no-step event',
        '',
        guidanceContext: GuidanceContext.laterLife,
        starterStepIds: [],
      );
      expect(controller.activeEvent!.actions, isEmpty);
      expect(first.actions.map((a) => a.id).toSet(), hasLength(5));
    });

    test('subset follows stages and copies current reading style without rewriting', () async {
      await controller.createEvent('Fictional standard event', '');
      final original = controller.activeEvent!.toJson();
      await controller.setReadingStyle(ReadingStyle.simple);
      final steps = guideFor(GuidanceContext.adultChanges).starterSteps;
      await controller.createEvent(
        'Fictional selected event',
        '',
        guidanceContext: GuidanceContext.adultChanges,
        starterStepIds: [steps.last.id, steps.first.id],
      );
      expect(controller.activeEvent!.actions.map((a) => a.title), [
        steps.first.simpleTitle,
        steps.last.simpleTitle,
      ]);
      expect(controller.data.events.first.toJson(), original);
      final ids = controller.data.events
          .expand((e) => e.actions)
          .map((a) => a.id);
      expect(ids.toSet().length, ids.length);
    });

    test(
      'changing context preserves saved actions, completion and check-ins',
      () async {
        await controller.createEvent(
          'Fictional initial event',
          'Original detail',
        );
        final id = controller.activeEvent!.id;
        await controller.addAction(
          id,
          JourneyStage.plan,
          'Fictional custom step',
        );
        await controller.setActionDone(
          id,
          controller.activeEvent!.actions.first.id,
          true,
        );
        await controller.completeEvent(id, true);
        await controller.addCheckIn(
          id,
          feeling: 'Unsure',
          note: 'Fictional note',
        );
        final before = controller.activeEvent!;
        final checkIns = controller.data.checkIns
            .map((c) => c.toJson())
            .toList();
        await controller.updateEvent(
          id,
          'Fictional revised event',
          'Revised detail',
          guidanceContext: GuidanceContext.caregiving,
        );
        expect(
          controller.activeEvent!.guidanceContext,
          GuidanceContext.caregiving,
        );
        expect(
          controller.activeEvent!.actions.map((a) => a.toJson()),
          before.actions.map((a) => a.toJson()),
        );
        expect(controller.activeEvent!.createdAt, before.createdAt);
        expect(controller.activeEvent!.completedAt, before.completedAt);
        expect(controller.data.checkIns.map((c) => c.toJson()), checkIns);
        await controller.updateEvent(id, 'Fictional title only', '');
        expect(
          controller.activeEvent!.guidanceContext,
          GuidanceContext.caregiving,
        );
      },
    );

    test('adding skips done and variant matches, preserves custom same-text other-stage', () async {
      await controller.createEvent(
        'Fictional blank event',
        '',
        starterStepIds: [],
      );
      final id = controller.activeEvent!.id;
      final steps = guideFor(GuidanceContext.general).starterSteps;
      await controller.addAction(
        id,
        steps.first.stage,
        ' ${steps.first.simpleTitle.toUpperCase()} ',
      );
      await controller.setActionDone(
        id,
        controller.activeEvent!.actions.single.id,
        true,
      );
      await controller.addAction(id, JourneyStage.reflect, steps[1].title);
      final existing = controller.activeEvent!.actions
          .map((a) => a.toJson())
          .toList();
      await controller.addStarterActions(id, steps.map((s) => s.id).toList());
      expect(
        controller.activeEvent!.actions.take(2).map((a) => a.toJson()),
        existing,
      );
      expect(controller.activeEvent!.actions, hasLength(6));
      await controller.setReadingStyle(ReadingStyle.simple);
      await Future.wait([
        controller.addStarterActions(id, steps.map((s) => s.id).toList()),
        controller.addStarterActions(id, steps.map((s) => s.id).toList()),
      ]);
      expect(controller.activeEvent!.actions, hasLength(6));
    });

    test('invalid create or add batches leave state/storage unchanged and queue usable', () async {
      await controller.createEvent(
        'Fictional original event',
        '',
        starterStepIds: [],
      );
      final id = controller.activeEvent!.id;
      final before = controller.data.toJson();
      final count = repository.saved.length;
      for (final ids in [
        ['general.orient', 'general.orient'],
        ['general.orient', 'general.unknown'],
        ['general.orient', 'laterLife.settle'],
      ]) {
        await expectLater(
          controller.createEvent(
            'Fictional invalid event',
            '',
            starterStepIds: ids,
          ),
          throwsArgumentError,
        );
        await expectLater(
          controller.addStarterActions(id, ids),
          throwsArgumentError,
        );
        expect(controller.data.toJson(), before);
        expect(repository.saved, hasLength(count));
      }
      await expectLater(
        controller.addStarterActions('missing', ['general.orient']),
        throwsArgumentError,
      );
      await controller.addStarterActions(id, ['general.orient']);
      expect(controller.activeEvent!.actions, hasLength(1));
    });

    test('queued creation reads style after preceding save commits', () async {
      final entered = Completer<void>();
      repository.entered = entered;
      repository.release = Completer<void>();
      final styleChange = controller.setReadingStyle(ReadingStyle.simple);
      await entered.future;
      final create = controller.createEvent(
        'Fictional queued event',
        '',
        guidanceContext: GuidanceContext.laterLife,
      );
      expect(controller.data.events, isEmpty);
      repository.release!.complete();
      await Future.wait([styleChange, create]);
      expect(
        controller.activeEvent!.actions.map((a) => a.title),
        guideFor(GuidanceContext.laterLife).starterSteps
            .map((s) => s.simpleTitle),
      );
    });

    test(
      'queued add resolves current guide and retains preceding custom edits',
      () async {
        await controller.createEvent('Fictional event', '', starterStepIds: []);
        final id = controller.activeEvent!.id;
        final entered = Completer<void>();
        repository.entered = entered;
        repository.release = Completer<void>();
        final update = controller.updateEvent(
          id,
          'Fictional updated',
          '',
          guidanceContext: GuidanceContext.caregiving,
        );
        await entered.future;
        final add = controller.addStarterActions(id, ['caregiving.orient']);
        final custom = controller.addAction(
          id,
          JourneyStage.plan,
          'Fictional custom',
        );
        final oldGuide = controller.addStarterActions(id, ['general.settle']);
        final invalid = expectLater(oldGuide, throwsArgumentError);
        repository.release!.complete();
        await Future.wait([update, add, custom, invalid]);
        expect(controller.activeEvent!.actions.map((a) => a.title), [
          guideFor(GuidanceContext.caregiving).starterSteps.first.title,
          'Fictional custom',
        ]);
      },
    );

    test(
      'queued first-time duplicate batches add one set in current simple words',
      () async {
        await controller.createEvent('Fictional event', '', starterStepIds: []);
        final id = controller.activeEvent!.id;
        final entered = Completer<void>();
        repository.entered = entered;
        repository.release = Completer<void>();
        final style = controller.setReadingStyle(ReadingStyle.simple);
        await entered.future;
        final first = controller.addStarterActions(id, [
          'general.plan',
          'general.orient',
        ]);
        final second = controller.addStarterActions(id, [
          'general.orient',
          'general.plan',
        ]);
        repository.release!.complete();
        await Future.wait([style, first, second]);
        final steps = guideFor(GuidanceContext.general).starterSteps;
        expect(controller.activeEvent!.actions.map((a) => a.title), [
          steps.first.simpleTitle,
          steps[3].simpleTitle,
        ]);
        expect(
          controller.activeEvent!.actions.map((a) => a.id).toSet(),
          hasLength(2),
        );
      },
    );

    test(
      'failed batch save leaves state unchanged and retry creates only one set',
      () async {
        await controller.createEvent('Fictional event', '', starterStepIds: []);
        final id = controller.activeEvent!.id;
        final before = controller.data.toJson();
        final count = repository.saved.length;
        repository.failNext = true;
        await expectLater(
          controller.addStarterActions(id, ['general.orient', 'general.plan']),
          throwsStateError,
        );
        expect(controller.data.toJson(), before);
        expect(repository.saved, hasLength(count));
        await controller.addStarterActions(id, [
          'general.orient',
          'general.plan',
        ]);
        expect(controller.activeEvent!.actions, hasLength(2));
      },
    );
  });
}
