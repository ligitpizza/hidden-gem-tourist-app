import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/destination.dart';
import '../../assistant/controller/assistant_controller.dart';
import '../controller/preference_controller.dart';
import '../model/travel_style.dart';
import 'recommendations_routes.dart';
import 'widgets/radar_chart.dart';

/// "Your Travel Pulse" — visualises how the traveller's selected interests
/// currently weight their recommendations. The weights themselves are an
/// even split across whatever categories are selected (real, persisted
/// selection) — the team's "Smart Preference Learning" spec calls for
/// weights that auto-adjust from browsing/save/search behaviour over time,
/// but that needs an interaction-tracking table that doesn't exist yet, so
/// this screen doesn't fabricate that part.
class TravelPulseScreen extends ConsumerWidget {
  const TravelPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferenceController = ref.watch(preferenceControllerProvider);
    final assistantController = ref.watch(assistantControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final styles = preferenceController.selected.toList();
    final shown = styles.length > 6 ? styles.sublist(0, 6) : styles;
    final weight = shown.isEmpty ? 0.0 : 1.0 / shown.length;
    final axes = [for (final s in shown) RadarAxis(label: s.label, value: weight)];

    return Scaffold(
      appBar: AppBar(title: const Text('Your Travel Pulse')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Real-time view of your recommendation weighting.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: axes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Text(
                      "You haven't picked any travel styles yet — set some to see "
                      'your pulse.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Center(child: RadarChart(axes: axes, color: colorScheme.primary)),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push(RecommendationsRoutes.travelStyle),
            icon: const Icon(Icons.settings_suggest_outlined),
            label: const Text('Recalibrate Profile'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Top Matches Right Now',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (assistantController.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (assistantController.topMatches.isEmpty)
            Text('No matches yet.', style: TextStyle(color: colorScheme.onSurfaceVariant))
          else
            for (final item in assistantController.topMatches.take(5))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text('${item.matchPercent}'),
                  ),
                  title: Text(item.name),
                  subtitle: Text('${item.category.label} • ${item.location}'),
                ),
              ),
        ],
      ),
    );
  }
}
