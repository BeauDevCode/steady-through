import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/tool_feedback_summary.dart';
import 'package:steady_through/ui/steady_ui.dart';

import 'feedback_display.dart';
import 'tool_feedback_dialog.dart';
import 'what_helps_card.dart';

class ToolFeedbackHistory extends StatelessWidget {
  const ToolFeedbackHistory({
    super.key,
    required this.controller,
    this.safetySession,
  });
  final AppController controller;
  final LearningSession? safetySession;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?safetySession]),
    builder: (context, _) {
      final ratings = ToolFeedbackSummary.fromData(controller.data.toolFeedback)
          .ratings;
      final vehicle = safetySession?.snapshot.possibleVehicle ?? false;
      return Scaffold(
        appBar: AppBar(title: const Text('Your tool ratings')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: ratings.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading(
                          title: 'Your answers, your choice',
                          subtitle: 'Only explicit answers appear here. Skipping or stopping a tool records no rating.',
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ratings stay for up to 180 days, with the latest 1,000 kept. Deleting here cannot remove copies you exported separately.',
                        ),
                        FeedbackOptions(
                          controller: controller,
                          safetySession: safetySession,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: vehicle
                                  ? null
                                  : () => showToolRatingDialog(
                                      context,
                                      controller,
                                      safetySession: safetySession,
                                    ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add a rating'),
                            ),
                            OutlinedButton(
                              onPressed: vehicle || ratings.isEmpty
                                  ? null
                                  : () => showClearToolFeedbackDialog(
                                      context,
                                      controller,
                                      safetySession: safetySession,
                                    ),
                              child: const Text('Clear ratings'),
                            ),
                          ],
                        ),
                        if (vehicle)
                          const Text(
                            'Return to your ratings when safely stopped.',
                          ),
                        if (ratings.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No saved tool ratings. All tools are still available.',
                            ),
                          ),
                        if (controller.cleanupWarning != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(controller.cleanupWarning!),
                          ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  final rating = ratings[index - 1];
                  return SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconBadge(icon: toolIcon(rating.tool)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    toolName(rating.tool),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Text(feedbackDate(context, rating.createdAt)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ratingName(rating.rating),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: vehicle
                                  ? null
                                  : () => showToolRatingDialog(
                                      context,
                                      controller,
                                      expected: rating,
                                      safetySession: safetySession,
                                    ),
                              child: const Text('Change'),
                            ),
                            TextButton(
                              onPressed: vehicle
                                  ? null
                                  : () => showDeleteToolFeedbackDialog(
                                      context,
                                      controller,
                                      rating,
                                      safetySession: safetySession,
                                    ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
