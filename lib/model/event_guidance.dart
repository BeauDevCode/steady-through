import 'app_data.dart';

/// A starter idea is copied only when selected; it never rewrites saved actions.
class StarterStep {
  const StarterStep({
    required this.id,
    required this.stage,
    required this.title,
    required this.simpleTitle,
  });

  final String id;
  final JourneyStage stage;
  final String title;
  final String simpleTitle;

  String text({required bool simpleWords}) => simpleWords ? simpleTitle : title;

  bool matchesAction(PlanAction action) {
    if (action.stage != stage) return false;
    final saved = action.title.trim().toLowerCase();
    return saved == title.trim().toLowerCase() ||
        saved == simpleTitle.trim().toLowerCase();
  }
}

/// Original optional support copy. See docs/guidance-content.md for sources
/// and limits; all copy is bundled and available without network or learning.
class EventGuidance {
  const EventGuidance._(
    this._prompts,
    this._simplePrompts, {
    required this.context,
    required this.label,
    required this.simpleLabel,
    required this.description,
    required this.simpleDescription,
    required this.helperNote,
    required this.simpleHelperNote,
    required this.starterSteps,
  });

  final GuidanceContext context;
  final String label;
  final String simpleLabel;
  final String description;
  final String simpleDescription;
  final String helperNote;
  final String simpleHelperNote;
  final List<StarterStep> starterSteps;
  final Map<JourneyStage, String> _prompts;
  final Map<JourneyStage, String> _simplePrompts;

  String stagePrompt(JourneyStage stage, {required bool simpleWords}) =>
      (simpleWords ? _simplePrompts : _prompts)[stage]!;
}

EventGuidance guideFor(GuidanceContext context) => _guides[context]!;

/// Validate the complete request before selecting any ideas. Result order is
/// the guide's stage order, independent of checkbox or caller ordering.
List<StarterStep> resolveStarterSteps(
  GuidanceContext context,
  List<String> ids,
) {
  final guide = guideFor(context);
  final available = {for (final step in guide.starterSteps) step.id};
  final selected = <String>{};
  for (final id in ids) {
    if (!available.contains(id) || !selected.add(id)) {
      throw ArgumentError.value(
        id,
        'starterStepIds',
        'Unknown or repeated starter step',
      );
    }
  }
  return List<StarterStep>.unmodifiable(
    guide.starterSteps.where((step) => selected.contains(step.id)),
  );
}

const _guides = <GuidanceContext, EventGuidance>{
  GuidanceContext.general: EventGuidance._(
    {
      JourneyStage.orient:
          'What needs your attention first? Start with what you know.',
      JourneyStage.settle: 'Pause and notice what is around you.',
      JourneyStage.support: 'Who could help with one part of this?',
      JourneyStage.plan: 'Choose one manageable next step.',
      JourneyStage.reflect: 'What helped, even a little?',
    },
    {
      JourneyStage.orient: 'What needs to happen first?',
      JourneyStage.settle: 'Look around and take a short pause.',
      JourneyStage.support: 'Who can help you?',
      JourneyStage.plan: 'What is one small thing you can do?',
      JourneyStage.reflect: 'What helped you?',
    },
    context: GuidanceContext.general,
    label: 'General',
    simpleLabel: 'General',
    description: 'A place to start with a change, a difficult day, or something on your mind.',
    simpleDescription: 'Start with something on your mind.',
    helperNote:
        'You can use this on your own or with a trusted person you choose.',
    simpleHelperNote: 'You can ask someone you trust to help.',
    starterSteps: [
      StarterStep(
        id: 'general.orient',
        stage: JourneyStage.orient,
        title: 'Notice what needs attention first',
        simpleTitle: 'Pick what needs attention',
      ),
      StarterStep(
        id: 'general.settle',
        stage: JourneyStage.settle,
        title: 'Take a short pause',
        simpleTitle: 'Take a little break',
      ),
      StarterStep(
        id: 'general.support',
        stage: JourneyStage.support,
        title: 'Choose someone to reach out to',
        simpleTitle: 'Choose someone to ask',
      ),
      StarterStep(
        id: 'general.plan',
        stage: JourneyStage.plan,
        title: 'Write one next step',
        simpleTitle: 'Pick one next thing',
      ),
      StarterStep(
        id: 'general.reflect',
        stage: JourneyStage.reflect,
        title: 'Notice what helped',
        simpleTitle: 'Think about what helped',
      ),
    ],
  ),
  GuidanceContext.schoolAndGrowing: EventGuidance._(
    {
      JourneyStage.orient:
          'Pick one part of school or growing up you want to think about.',
      JourneyStage.settle:
          'Choose a familiar game, drawing, song, or quiet break.',
      JourneyStage.support:
          'Think of a trusted adult or person you could ask for help.',
      JourneyStage.plan:
          'Pick one small step. A trusted helper can work it out with you.',
      JourneyStage.reflect: 'Notice one thing you tried. You can ask for different help next time.',
    },
    {
      JourneyStage.orient: 'What is new or tricky today?',
      JourneyStage.settle: 'Would you like to play, draw, listen, or rest?',
      JourneyStage.support: 'Who do you trust to help?',
      JourneyStage.plan: 'What is one small thing you could try?',
      JourneyStage.reflect: 'What did you try? What help would you like?',
    },
    context: GuidanceContext.schoolAndGrowing,
    label: 'School & growing up',
    simpleLabel: 'School and growing up',
    description:
        'Ideas for school, friendships, new experiences, and growing up.',
    simpleDescription: 'Help with school, friends, or new things.',
    helperNote: 'A trusted adult or helper can read this with you. You can point, draw, talk, or skip. Choose someone you feel safe with.',
    simpleHelperNote: 'Ask a grown-up or helper you trust. You can point, draw, talk, or skip.',
    starterSteps: [
      StarterStep(
        id: 'schoolAndGrowing.orient',
        stage: JourneyStage.orient,
        title: 'Choose something on your mind',
        simpleTitle: 'Pick one thing',
      ),
      StarterStep(
        id: 'schoolAndGrowing.settle',
        stage: JourneyStage.settle,
        title: 'Make room for a familiar activity',
        simpleTitle: 'Choose something familiar',
      ),
      StarterStep(
        id: 'schoolAndGrowing.support',
        stage: JourneyStage.support,
        title: 'Choose a trusted helper',
        simpleTitle: 'Pick someone you trust',
      ),
      StarterStep(
        id: 'schoolAndGrowing.plan',
        stage: JourneyStage.plan,
        title: 'Work out one small step',
        simpleTitle: 'Choose one small thing',
      ),
      StarterStep(
        id: 'schoolAndGrowing.reflect',
        stage: JourneyStage.reflect,
        title: 'Notice what you tried',
        simpleTitle: 'Think about your try',
      ),
    ],
  ),
  GuidanceContext.adultChanges: EventGuidance._(
    {
      JourneyStage.orient: 'Identify one change and one familiar part of your day you want to keep.',
      JourneyStage.settle: 'Make room for a short activity you enjoy today.',
      JourneyStage.support:
          'Think of someone who could help with a question or task.',
      JourneyStage.plan: 'Pick one manageable task and decide what can wait.',
      JourneyStage.reflect:
          'Consider whether the plan fit your day. You can adjust it.',
    },
    {
      JourneyStage.orient: 'What changed? What could stay familiar?',
      JourneyStage.settle: 'What would you like a little time for?',
      JourneyStage.support: 'Who could help with one thing?',
      JourneyStage.plan: 'What is one task you could try?',
      JourneyStage.reflect: 'Did the plan fit? What would you change?',
    },
    context: GuidanceContext.adultChanges,
    label: 'Adult life changes',
    simpleLabel: 'Adult life changes',
    description: 'Space to consider changes in work, home, relationships, responsibilities, or routine.',
    simpleDescription: 'Ideas for changes in work, home, or daily life.',
    helperNote: 'You can choose practical help, company, or time to think on your own. Share only what you want.',
    simpleHelperNote:
        'You can ask for help or think on your own. Share only what you want.',
    starterSteps: [
      StarterStep(
        id: 'adultChanges.orient',
        stage: JourneyStage.orient,
        title: 'Name a change and a familiar routine',
        simpleTitle: 'Notice what changed',
      ),
      StarterStep(
        id: 'adultChanges.settle',
        stage: JourneyStage.settle,
        title: 'Choose a brief activity you enjoy',
        simpleTitle: 'Choose something you like',
      ),
      StarterStep(
        id: 'adultChanges.support',
        stage: JourneyStage.support,
        title: 'Identify one practical source of help',
        simpleTitle: 'Choose someone to ask',
      ),
      StarterStep(
        id: 'adultChanges.plan',
        stage: JourneyStage.plan,
        title: 'Choose a manageable next task',
        simpleTitle: 'Pick one small task',
      ),
      StarterStep(
        id: 'adultChanges.reflect',
        stage: JourneyStage.reflect,
        title: 'Adjust the plan to fit your day',
        simpleTitle: 'Change what you need',
      ),
    ],
  ),
  GuidanceContext.caregiving: EventGuidance._(
    {
      JourneyStage.orient:
          'Choose one caring task and one need of your own to consider.',
      JourneyStage.settle: 'If needed care is safely covered, choose a brief break. Otherwise, consider help arranging cover.',
      JourneyStage.support:
          'Name one specific task another person might help with.',
      JourneyStage.plan: 'Choose one priority and a possible source of help.',
      JourneyStage.reflect:
          'Notice what was manageable and where more support is needed.',
    },
    {
      JourneyStage.orient: 'What needs doing? What do you need?',
      JourneyStage.settle:
          'Is care safely covered? You could pause or ask for help.',
      JourneyStage.support: 'What could someone help you do?',
      JourneyStage.plan: 'What comes next? Who might help?',
      JourneyStage.reflect: 'What fit today? Where would help be useful?',
    },
    context: GuidanceContext.caregiving,
    label: 'Caring for someone',
    simpleLabel: 'Caring for someone',
    description: 'Space for caring responsibilities, your own needs, and possible support.',
    simpleDescription: 'Think about caring tasks and what you need too.',
    helperNote: 'Your options depend on your situation. Take a break only when needed care is safely covered. You can choose another idea or ask for help arranging cover.',
    simpleHelperNote: 'Take a break only if needed care is covered safely. You can choose something else or ask for help.',
    starterSteps: [
      StarterStep(
        id: 'caregiving.orient',
        stage: JourneyStage.orient,
        title: 'Make room for your needs too',
        simpleTitle: 'Notice your needs too',
      ),
      StarterStep(
        id: 'caregiving.settle',
        stage: JourneyStage.settle,
        title: 'Consider a break when care is covered',
        simpleTitle: 'Check care is covered before a break',
      ),
      StarterStep(
        id: 'caregiving.support',
        stage: JourneyStage.support,
        title: 'Identify a task you could ask help with',
        simpleTitle: 'Pick one thing to ask about',
      ),
      StarterStep(
        id: 'caregiving.plan',
        stage: JourneyStage.plan,
        title: 'Plan one task and possible support',
        simpleTitle: 'Pick a task and possible help',
      ),
      StarterStep(
        id: 'caregiving.reflect',
        stage: JourneyStage.reflect,
        title: 'Review where support would help',
        simpleTitle: 'Notice where you want help',
      ),
    ],
  ),
  GuidanceContext.laterLife: EventGuidance._(
    {
      JourneyStage.orient:
          'Choose a change in routine, role, or loss you want to consider.',
      JourneyStage.settle:
          'Choose a familiar activity that fits your energy and preferences.',
      JourneyStage.support: 'Think of a person or community contact you would like alongside you.',
      JourneyStage.plan:
          'Make space for one useful or meaningful activity at your own pace.',
      JourneyStage.reflect:
          'Decide what you want to keep, change, or revisit another day.',
    },
    {
      JourneyStage.orient: 'What has changed in your day or life?',
      JourneyStage.settle: 'What familiar thing would suit you today?',
      JourneyStage.support: 'Who would you like company or help from?',
      JourneyStage.plan: 'What is one thing that matters to you?',
      JourneyStage.reflect: 'What would you like to keep or change?',
    },
    context: GuidanceContext.laterLife,
    label: 'Later life changes',
    simpleLabel: 'Later life changes',
    description: 'Ideas for changes in routine or roles, retirement, or loss—only if they fit your life.',
    simpleDescription:
        'Choose ideas for changes in your day or life, if they fit.',
    helperNote: 'Choose what matters to you and fits your energy and preferences. If you are grieving, there is no schedule you need to follow here.',
    simpleHelperNote:
        'Pick what suits you today. If you are grieving, take your time.',
    starterSteps: [
      StarterStep(
        id: 'laterLife.orient',
        stage: JourneyStage.orient,
        title: 'Choose a change you want to consider',
        simpleTitle: 'Pick a change to think about',
      ),
      StarterStep(
        id: 'laterLife.settle',
        stage: JourneyStage.settle,
        title: 'Spend a little time with something familiar',
        simpleTitle: 'Choose something familiar',
      ),
      StarterStep(
        id: 'laterLife.support',
        stage: JourneyStage.support,
        title: 'Choose company or practical support',
        simpleTitle: 'Think of someone you would like to ask',
      ),
      StarterStep(
        id: 'laterLife.plan',
        stage: JourneyStage.plan,
        title: 'Make room for something meaningful',
        simpleTitle: 'Choose something that matters',
      ),
      StarterStep(
        id: 'laterLife.reflect',
        stage: JourneyStage.reflect,
        title: 'Choose what to keep or revisit',
        simpleTitle: 'Keep, change, or come back later',
      ),
    ],
  ),
};
