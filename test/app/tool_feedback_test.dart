import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';

class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  AppData? backup;
  bool failSave = false, failCleanup = false;
  Completer<void>? barrier;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    await barrier?.future;
    if (failSave) throw StateError('disk');
    backup = value;
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    if (failCleanup) throw StateError('cleanup');
    backup = null;
  }
}

void main() {
  late _Repository repository;
  late AppController controller;
  var disposed = false;
  setUp(() {
    repository = _Repository(AppData.empty());
    controller = AppController(repository, repository.value);
    disposed = false;
  });
  tearDown(() async {
    await controller.flush();
    if (!disposed) controller.dispose();
  });
  Future<ToolFeedback> rate([
    SupportTool tool = SupportTool.grounding,
    ToolRating rating = ToolRating.helpful,
  ]) => controller.recordToolFeedback(
    tool,
    rating,
    expectedRevision: controller.replacementRevision,
  );

  test(
    'explicit source-off rating persists alone and returns its exact receipt',
    () async {
      final receipt = await rate();
      expect(controller.data.toolFeedback.ratings.single, same(receipt));
      expect(repository.value.toolFeedback.ratings.single, same(receipt));
      expect(controller.data.learning.enabledSources, isEmpty);
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.gameRounds, isEmpty);
      expect(
        AppData.fromJson(repository.value.toJson()).toolFeedback.ratings.single
            .toJson(),
        receipt.toJson(),
      );
    },
  );
  test('correction purges old opinion and preserves id/time/tool', () async {
    final r = await rate();
    await controller.correctToolFeedback(
      r.id,
      ToolRating.notThisTime,
      expected: r,
      expectedRevision: 0,
    );
    final changed = controller.data.toolFeedback.ratings.single;
    expect(changed.id, r.id);
    expect(changed.createdAt, r.createdAt);
    expect(changed.tool, r.tool);
    expect(changed.rating, ToolRating.notThisTime);
    expect(repository.backup, isNull);
  });
  test(
    'wrong id or stale instance cannot correct/delete another record',
    () async {
      final a = await rate();
      final b = await rate(SupportTool.breathing);
      await expectLater(
        controller.deleteToolFeedback(a.id, expected: b, expectedRevision: 0),
        throwsStateError,
      );
      await controller.correctToolFeedback(
        a.id,
        ToolRating.notThisTime,
        expected: a,
        expectedRevision: 0,
      );
      await expectLater(
        controller.deleteToolFeedback(a.id, expected: a, expectedRevision: 0),
        throwsStateError,
      );
      expect(controller.data.toolFeedback.ratings, hasLength(2));
    },
  );
  test('primary failure does not commit, cleanup failure commits once with warning', () async {
    repository.failSave = true;
    await expectLater(rate(), throwsStateError);
    expect(controller.data.toolFeedback.ratings, isEmpty);
    repository.failSave = false;
    final r = await rate();
    repository.failCleanup = true;
    await controller.correctToolFeedback(
      r.id,
      ToolRating.notThisTime,
      expected: r,
      expectedRevision: 0,
    );
    expect(
      controller.data.toolFeedback.ratings.single.rating,
      ToolRating.notThisTime,
    );
    expect(controller.cleanupWarning, isNotNull);
  });
  test('queued feedback and unrelated changes both survive', () async {
    final saving = rate();
    final theme = controller.setTheme(ThemeChoice.dark);
    await saving;
    await theme;
    expect(controller.data.theme, ThemeChoice.dark);
    expect(controller.data.toolFeedback.ratings, hasLength(1));
  });
  test('a replacement already queued prevents a stale rating write', () async {
    final replacing = controller.replaceData(AppData.empty());
    final saving = controller.recordToolFeedback(
      SupportTool.grounding,
      ToolRating.helpful,
      expectedRevision: 0,
    );
    await expectLater(saving, throwsStateError);
    await replacing;
    expect(controller.data.toolFeedback.ratings, isEmpty);
  });
  test(
    'foreground guard is checked inside the queue, not when called',
    () async {
      repository.barrier = Completer<void>();
      var active = true;
      final first = controller.setTheme(ThemeChoice.dark);
      final pending = controller.recordToolFeedback(
        SupportTool.breathing,
        ToolRating.helpful,
        expectedRevision: 0,
        isActive: () => active,
      );
      final rejected = expectLater(pending, throwsStateError);
      active = false;
      repository.barrier!.complete();
      await first;
      await rejected;
      expect(controller.data.toolFeedback.ratings, isEmpty);
      expect(controller.data.theme, ThemeChoice.dark);
    },
  );
  test('clear ratings preserves settings, learning and game scopes', () async {
    await rate();
    await controller.updateToolFeedbackOptions(
      showPrompts: false,
      useSuggestions: false,
      expectedRevision: 0,
    );
    await controller.createEvent('Keep my plan', '');
    await controller.clearLearning();
    await controller.clearGameRounds();
    expect(controller.data.toolFeedback.ratings, hasLength(1));
    await controller.clearToolFeedback(expectedRevision: 0);
    expect(controller.data.toolFeedback.ratings, isEmpty);
    expect(controller.data.toolFeedback.showPrompts, isFalse);
    expect(controller.data.toolFeedback.useSuggestions, isFalse);
    expect(controller.data.events.single.title, 'Keep my plan');
    expect(repository.backup, isNull);
  });
  test(
    'retention on unrelated write purges expired recovery ratings',
    () async {
      final old = ToolFeedback(
        id: 'old',
        createdAt: DateTime.now().toUtc().subtract(const Duration(days: 181)),
        tool: SupportTool.pathGame,
        rating: ToolRating.helpful,
      );
      final initial = AppData(toolFeedback: ToolFeedbackData(ratings: [old]));
      final localRepo = _Repository(initial);
      final local = AppController(localRepo, initial);
      addTearDown(local.dispose);
      await local.setTheme(ThemeChoice.dark);
      expect(local.data.toolFeedback.ratings, isEmpty);
      expect(localRepo.backup, isNull);
    },
  );
  test(
    'captured receipt survives a queued clear without recreating ratings',
    () async {
      final saving = rate();
      final clear = controller.clearToolFeedback(expectedRevision: 0);
      final r = await saving;
      await clear;
      expect(r.rating, ToolRating.helpful);
      expect(controller.data.toolFeedback.ratings, isEmpty);
    },
  );
  test('closed controller rejects late feedback calls', () async {
    controller.dispose();
    disposed = true;
    await expectLater(rate(), throwsStateError);
    expect(repository.value.toolFeedback.ratings, isEmpty);
  });
}
