import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

import 'people_screen.dart';
import 'person_card.dart';
import 'person_form_dialog.dart';

class TrustedPeopleSection extends StatelessWidget {
  const TrustedPeopleSection({
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your trusted people',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              simple ? 'You choose who to contact and when.' : 'People you saved, in your saved order. Choose whether and when to reach out.',
            ),
            const SizedBox(height: 16),
            if (people.isEmpty)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No people saved yet. Add someone you would feel comfortable contacting.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => showPersonForm(context, controller),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add person'),
                    ),
                  ],
                ),
              )
            else ...[
              ResponsiveColumns(
                minWidth: 240,
                children: [
                  for (final person in people.take(3))
                    PersonCard(
                      key: ValueKey(person.id),
                      controller: controller,
                      person: person,
                      phoneActions: phoneActions,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Your saved people')),
                      body: PeopleScreen(
                        controller: controller,
                        phoneActions: phoneActions,
                      ),
                    ),
                  ),
                ),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.people_outline),
                label: const Text('View all saved people'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
