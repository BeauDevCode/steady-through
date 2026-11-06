import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/pattern_engine.dart';

class AppController extends ChangeNotifier {
  AppController(this._repository, AppData initial) : _data = initial;

  final AppRepository _repository;
  AppData _data;
  Future<void> _writeQueue = Future<void>.value();
  final Random _random = Random.secure();
  String? _cleanupWarning;

  AppData get data => _data;
  String? get cleanupWarning => _cleanupWarning;

  Future<void> flush() => _writeQueue;

  Future<void> updateLearning(LearningData learning) => _mutate(
    (current) =>
        current.copyWith(learning: learning.bounded(DateTime.now().toUtc())),
  );

  Future<void> recordLearning(FeelingLabel label, SignalSnapshot snapshot) =>
      _mutate((current) {
        final now = DateTime.now().toUtc();
        final next = current.learning.record(
          LearningExample(
            id: _newId(),
            createdAt: now,
            label: label,
            snapshot: snapshot,
          ),
          now: now,
        );
        return current.copyWith(
          learning: PersonalPatternEngine().review(next, now: now).data,
        );
      });

  Future<CalibrationReport> reviewLearning() async {
    late CalibrationReport report;
    await _mutate((current) {
      final review = PersonalPatternEngine().review(
        current.learning,
        now: DateTime.now().toUtc(),
      );
      report = review.report;
      return current.copyWith(learning: review.data);
    });
    return report;
  }

  Future<void> clearLearning() => _mutate(
    (current) => current.copyWith(learning: LearningData()),
    purgeResidual: true,
  );

  Future<void> _purgeResidual() async {
    if (_repository is ResidualDataRepository) {
      try {
        await (_repository as ResidualDataRepository).purgeResidualData();
        _cleanupWarning = null;
      } catch (_) {
        // The primary save already committed. A cleanup failure must not
        // invite a form retry that would save the same record again.
        _cleanupWarning = 'Your changes are saved in the active vault. Older local copies may remain. Lock and unlock the vault to retry cleanup.';
      }
    }
  }

  Future<void> pruneLearning() {
    final bounded = _data.learning.bounded(DateTime.now().toUtc());
    if (bounded.examples.length == _data.learning.examples.length) {
      return Future.value();
    }
    return _mutate((current) => current);
  }

  SupportEvent? get activeEvent {
    for (final event in _data.events) {
      if (event.id == _data.activeEventId) return event;
    }
    return null;
  }

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  int _replacementRevision = 0;
  int get replacementRevision => _replacementRevision;

  Future<void> _mutate(
    AppData Function(AppData) change, {
    bool purgeResidual = false,
    bool replacing = false,
  }) {
    final write = _writeQueue.then((_) async {
      final changed = change(_data);
      final now = DateTime.now().toUtc();
      final retained = changed.learning.bounded(now);
      final retainedIds = retained.examples
          .map((example) => example.id)
          .toSet();
      final pruned =
          retained.examples.length < changed.learning.examples.length ||
          _data.learning.examples.any(
            (example) => !retainedIds.contains(example.id),
          );
      final next = changed.copyWith(learning: retained);
      AppData.fromJson(next.toJson());
      await _repository.save(next);
      _data = next;
      if (replacing) _replacementRevision++;
      if (pruned || purgeResidual) await _purgeResidual();
      notifyListeners();
    });
    // Keep the queue usable after a failed write while still surfacing the
    // failure to the caller of this particular operation.
    _writeQueue = write.catchError((Object _) {});
    return write;
  }

  Future<void> createEvent(String title, String description) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return Future.error(ArgumentError('Give this event a title.'));
    }
    return _mutate((current) {
      final eventId = _newId();
      final titles = <JourneyStage, String>{
        JourneyStage.orient: 'Notice what needs attention first',
        JourneyStage.settle: 'Take a short pause',
        JourneyStage.support: 'Choose someone to reach out to',
        JourneyStage.plan: 'Write one next step',
        JourneyStage.reflect: 'Notice what helped',
      };
      final actions = JourneyStage.values
          .map(
            (stage) => PlanAction(
              id: _newId(),
              stage: stage,
              title: titles[stage]!,
              done: false,
            ),
          )
          .toList();
      final event = SupportEvent(
        id: eventId,
        title: cleanTitle,
        description: description.trim(),
        createdAt: DateTime.now().toUtc(),
        completedAt: null,
        actions: actions,
      );
      return current.copyWith(
        events: [...current.events, event],
        activeEventId: eventId,
      );
    });
  }

  Future<void> selectEvent(String id) => _mutate((current) {
    _requireEvent(current, id);
    return current.copyWith(activeEventId: id);
  });

  Future<void> updateEvent(String id, String title, String description) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return Future.error(ArgumentError('Give this event a title.'));
    }
    return _editEvent(
      id,
      (event) =>
          event.copyWith(title: cleanTitle, description: description.trim()),
    );
  }

  Future<void> completeEvent(String id, bool completed) => _editEvent(
    id,
    (event) => event.copyWith(
      completedAt: completed ? DateTime.now().toUtc() : null,
      clearCompletedAt: !completed,
    ),
  );

  Future<void> deleteEvent(String id) => _mutate((current) {
    _requireEvent(current, id);
    final events = current.events.where((event) => event.id != id).toList();
    final selected = current.activeEventId == id
        ? (events.isEmpty ? null : events.last.id)
        : current.activeEventId;
    return current.copyWith(
      events: events,
      activeEventId: selected,
      clearActiveEventId: selected == null,
      checkIns: current.checkIns
          .where((checkIn) => checkIn.eventId != id)
          .toList(),
    );
  });

  Future<void> addAction(String eventId, JourneyStage stage, String title) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return Future.error(ArgumentError('Write a short action.'));
    }
    return _editEvent(
      eventId,
      (event) => event.copyWith(
        actions: [
          ...event.actions,
          PlanAction(
            id: _newId(),
            stage: stage,
            title: cleanTitle,
            done: false,
          ),
        ],
      ),
    );
  }

  Future<void> renameAction(String eventId, String actionId, String title) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return Future.error(ArgumentError('Write a short action.'));
    }
    return _editAction(
      eventId,
      actionId,
      (action) => action.copyWith(title: cleanTitle),
    );
  }

  Future<void> setActionDone(String eventId, String actionId, bool done) =>
      _editAction(eventId, actionId, (action) => action.copyWith(done: done));

  Future<void> removeAction(String eventId, String actionId) =>
      _editEvent(eventId, (event) {
        if (!event.actions.any((action) => action.id == actionId)) {
          throw ArgumentError.value(actionId, 'actionId', 'Unknown action');
        }
        return event.copyWith(
          actions: event.actions
              .where((action) => action.id != actionId)
              .toList(),
        );
      });

  Future<void> _editAction(
    String eventId,
    String actionId,
    PlanAction Function(PlanAction) change,
  ) => _editEvent(eventId, (event) {
    if (!event.actions.any((action) => action.id == actionId)) {
      throw ArgumentError.value(actionId, 'actionId', 'Unknown action');
    }
    return event.copyWith(
      actions: event.actions
          .map((action) => action.id == actionId ? change(action) : action)
          .toList(),
    );
  });

  Future<void> _editEvent(
    String id,
    SupportEvent Function(SupportEvent) change,
  ) => _mutate((current) {
    _requireEvent(current, id);
    return current.copyWith(
      events: current.events
          .map((event) => event.id == id ? change(event) : event)
          .toList(),
    );
  });

  SupportEvent _requireEvent(AppData data, String id) {
    for (final event in data.events) {
      if (event.id == id) return event;
    }
    throw ArgumentError.value(id, 'eventId', 'Unknown event');
  }

  Future<void> addPerson(String name, String phone) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return Future.error(ArgumentError('Enter a name.'));
    return _mutate(
      (current) => current.copyWith(
        people: [
          ...current.people,
          TrustedPerson(id: _newId(), name: cleanName, phone: phone.trim()),
        ],
      ),
    );
  }

  Future<void> deletePerson(String id) => _mutate((current) {
    if (!current.people.any((person) => person.id == id)) {
      throw ArgumentError.value(id, 'personId', 'Unknown person');
    }
    return current.copyWith(
      people: current.people.where((person) => person.id != id).toList(),
    );
  });

  Future<void> addCheckIn(
    String eventId, {
    required String feeling,
    int? intensity,
    required String note,
  }) {
    final cleanFeeling = feeling.trim();
    if (cleanFeeling.isEmpty) {
      return Future.error(ArgumentError('Describe how you feel.'));
    }
    if (intensity != null && (intensity < 1 || intensity > 5)) {
      return Future.error(
        ArgumentError.value(intensity, 'intensity', 'Use 1 through 5.'),
      );
    }
    return _mutate((current) {
      _requireEvent(current, eventId);
      return current.copyWith(
        checkIns: [
          ...current.checkIns,
          CheckIn(
            id: _newId(),
            eventId: eventId,
            createdAt: DateTime.now().toUtc(),
            feeling: cleanFeeling,
            intensity: intensity,
            note: note.trim(),
          ),
        ],
      );
    });
  }

  Future<void> deleteCheckIn(String id) => _mutate((current) {
    if (!current.checkIns.any((checkIn) => checkIn.id == id)) {
      throw ArgumentError.value(id, 'checkInId', 'Unknown check-in');
    }
    return current.copyWith(
      checkIns: current.checkIns.where((checkIn) => checkIn.id != id).toList(),
    );
  });

  Future<void> recordRound(GameRound round) => _mutate(
    (current) => current.copyWith(gameRounds: [...current.gameRounds, round]),
  );

  Future<void> clearGameRounds() =>
      _mutate((current) => current.copyWith(gameRounds: []));

  Future<void> setTheme(ThemeChoice choice) =>
      _mutate((current) => current.copyWith(theme: choice));

  Future<void> setReadingStyle(ReadingStyle style) =>
      _mutate((current) => current.copyWith(readingStyle: style));

  Future<void> replaceData(AppData replacement) {
    final validated = AppData.fromJson(replacement.toJson());
    // Archive ownership is not confirmation for the current device. Keep
    // historical observations, but require a fresh opt-in for native sources.
    final imported = validated.copyWith(
      learning: validated.learning.copyWith(
        enabledSources: validated.learning.enabledSources.difference({
          SignalSource.deviceUsage,
          SignalSource.motion,
        }),
        deviceOwnerConfirmed: false,
      ),
    );
    return _mutate((_) => imported, replacing: true);
  }

  Future<void> clearAll() =>
      _mutate((_) => AppData.empty(), replacing: true, purgeResidual: true);
}
