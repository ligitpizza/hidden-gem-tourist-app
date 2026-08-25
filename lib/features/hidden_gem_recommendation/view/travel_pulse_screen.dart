import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/destination.dart';
import '../controller/recommendation_controller.dart';
import '../controller/travel_pulse_controller.dart';
import '../model/travel_style.dart';
import 'hidden_gem_recommendation_routes.dart';
import 'widgets/radar_chart.dart';

/// "Your Travel Pulse" (FR3) — real recency-weighted category affinity
/// from [TravelPulseController], including the "cooling off" score-decay
/// callout the mockup calls for when a category has gone quiet.
class TravelPulseScreen extends ConsumerWidget {
  const TravelPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseController = ref.watch(travelPulseControllerProvider);
    final recommendationController = ref.watch(recommendationControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final axes = [
      for (final pulse in pulseController.pulses)
        RadarAxis(label: pulse.style.label, value: pulse.weight),
    ];
    final coolingOff = pulseController.pulses.where((p) => p.isCoolingOff).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Your Travel Pulse')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(travelPulseControllerProvider).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Real-time analysis of your exploration DNA.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: pulseController.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : axes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Text(
                            "You haven't picked any travel styles yet — set some to see "
                            'your pulse.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      : Center(
                          child: RadarChart(
                            axes: axes,
                            color: colorScheme.primary,
                            gridColor: colorScheme.outlineVariant,
                            labelColor: colorScheme.onSurface,
                          ),
                        ),
            ),
            for (final pulse in coolingOff) ...[
              const SizedBox(height: 16),
              _CoolingOffCard(styleLabel: pulse.style.label),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.push(HiddenGemRecommendationRoutes.travelStyle),
              icon: const Icon(Icons.settings_suggest_outlined),
              label: const Text('Recalibrate Profile'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Top Matches Right Now',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (recommendationController.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (recommendationController.topMatches.isEmpty)
              Text('No matches yet.', style: TextStyle(color: colorScheme.onSurfaceVariant))
            else
              for (final item in recommendationController.topMatches.take(5))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text('${item.personalizedPercent}'),
                    ),
                    title: Text(item.name),
                    subtitle: Text('${item.category.label} • ${item.location}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CoolingOffCard extends StatelessWidget {
  final String styleLabel;
  const _CoolingOffCard({required this.styleLabel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_down, color: colorScheme.error, size: 18),
              const SizedBox(width: 8),
              Text(
                'SCORE DECAY',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your interest in $styleLabel is cooling off.',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 4),
          Text(
            "You haven't interacted with a $styleLabel spot in a while — explore more to "
            'keep your pulse active.',
            style: TextStyle(fontSize: 12.5, color: colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
