import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

import 'person_card.dart';
import 'person_form_dialog.dart';
import 'phone_actions.dart';

// Preserve the original public handoff seam for existing clients and tests.
export 'phone_actions.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({
    super.key,
    required this.controller,
    this.phoneActions = const UrlLauncherPhoneActions(),
  });
  final AppController controller;
  final PhoneActions phoneActions;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final people = controller.data.people;
      final simple = controller.data.readingStyle == ReadingStyle.simple;
      final colors = Theme.of(context).colorScheme;
      return SteadyPage(
        maxWidth: 1040,
        children: [
          const Eyebrow('Your support'),
          const SizedBox(height: 12),
          SectionHeading(
            title: 'People',
            subtitle: simple
                ? 'Save people you trust. Their numbers stay on this device.'
                : 'Keep the names and phone numbers of people you trust. Numbers are entered by you and stay on this device.',
            action: FilledButton.icon(
              onPressed: () => showPersonForm(context, controller),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add person'),
            ),
          ),
          const SizedBox(height: 28),
          if (people.isEmpty)
            SurfaceCard(
              color: colors.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    icon: Icons.people_outline,
                    color: colors.surface,
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A place for your people',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No people saved yet. Add someone you would feel comfortable contacting.',
                  ),
                ],
              ),
            )
          else ...[
            Text('Saved people', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ResponsiveColumns(
              minWidth: 280,
              children: [
                for (final person in people)
                  PersonCard(
                    key: ValueKey(person.id),
                    controller: controller,
                    person: person,
                    phoneActions: phoneActions,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  simple ? 'You choose who to save and when to reach out.' : 'You choose who belongs here and when you want to reach out.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
