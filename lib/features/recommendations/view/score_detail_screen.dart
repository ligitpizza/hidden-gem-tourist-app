import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../assistant/model/assistant_feed_item.dart';
import '../controller/preference_controller.dart';

/// "Hidden Gem Score Detail" / Transparency Report — shows exactly how a
/// place's composite score was built from real data (Module 1's Hidden Gem
/// Scoring Engine), instead of just asserting a percentage.
class ScoreDetailScreen extends ConsumerWidget {
  final AssistantFeedItem item;
  const ScoreDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final preferences = ref.watch(preferenceControllerProvider).selected;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.primaryContainer],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.landscape, size: 72, color: Colors.white.withAlpha(60)),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.isHiddenGem)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC9A227),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'HIDDEN GEM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            item.location,
                            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MatchScoreCard(item: item),
                const SizedBox(height: 20),
                const Text(
                  'Transparency Report',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _ScoreBar(
                  icon: Icons.star_outline,
                  label: 'Visitor Rating',
                  valueLabel: '${item.avgRating.toStringAsFixed(1)}/5',
                  fraction: item.avgRating / 5,
                  caption: 'Based on real visitor reviews of this place.',
                ),
                _ScoreBar(
                  icon: Icons.diamond_outlined,
                  label: 'Uniqueness',
                  valueLabel: _tierLabel(item.uniquenessScore),
                  fraction: item.uniquenessScore / 5,
                  caption: 'How distinctive this category/experience is versus typical spots.',
                ),
                _ScoreBar(
                  icon: Icons.accessible_outlined,
                  label: 'Accessibility',
                  valueLabel: _tierLabel(item.accessibilityScore),
                  fraction: item.accessibilityScore / 5,
                  caption: 'How easy this place is to actually reach and visit.',
                ),
                _ScoreBar(
                  icon: Icons.visibility_off_outlined,
                  label: 'Low Popularity',
                  valueLabel: item.popularity.label,
                  fraction: switch (item.popularity) {
                    GemPopularity.low => 1.0,
                    GemPopularity.medium => 0.6,
                    GemPopularity.high => 0.25,
                  },
                  caption: 'Popularity is real review volume — low means still '
                      'relatively undiscovered.',
                ),
                const SizedBox(height: 16),
                _WhyRecommendedCard(item: item, preferences: preferences),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _tierLabel(double value) {
    if (value >= 4.0) return 'High';
    if (value >= 2.5) return 'Moderate';
    return 'Low';
  }
}

class _MatchScoreCard extends StatelessWidget {
  final AssistantFeedItem item;
  const _MatchScoreCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: item.matchScore.clamp(0, 1),
                  strokeWidth: 5,
                  backgroundColor: colorScheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
                Text('${item.matchPercent}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Match Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 2),
                Text(
                  'Weighted from real rating, uniqueness, accessibility and popularity data.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueLabel;
  final double fraction;
  final String caption;

  const _ScoreBar({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.fraction,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 6,
              backgroundColor: colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(caption, style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _WhyRecommendedCard extends StatelessWidget {
  final AssistantFeedItem item;
  final Set<dynamic> preferences;
  const _WhyRecommendedCard({required this.item, required this.preferences});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reasons = <String>[];

    if (item.avgRating >= 4.5) {
      reasons.add('a strong ${item.avgRating.toStringAsFixed(1)}★ visitor rating');
    }
    if (item.uniquenessScore >= 4.0) {
      reasons.add('a distinctive, less-common experience for its category');
    }
    if (item.popularity == GemPopularity.low) {
      reasons.add('review volume showing it\'s still relatively undiscovered');
    } else if (item.popularity == GemPopularity.medium) {
      reasons.add('moderate popularity — known, but not overrun');
    }
    if (preferences.isNotEmpty) {
      reasons.add('matching your selected travel style');
    }
    if (reasons.isEmpty) {
      reasons.add('a solid balance across rating, uniqueness and accessibility');
    }

    final text = 'This place scored ${item.matchPercent}% thanks to ${reasons.join(', ')}.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Why we recommend this',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
