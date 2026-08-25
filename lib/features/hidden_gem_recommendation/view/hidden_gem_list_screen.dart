import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/hidden_gem_feed_item.dart';
import 'hidden_gem_recommendation_routes.dart';
import 'widgets/hidden_gem_list_tile.dart';

/// A plain "here's the full ranked list" screen — backs "View All" from
/// the discovery feed's "Your Top Matches" section. Takes an
/// already-loaded list rather than fetching its own, since the caller
/// already has it from [RecommendationController].
class HiddenGemListScreen extends StatelessWidget {
  final String title;
  final List<HiddenGemFeedItem> items;

  const HiddenGemListScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: items.isEmpty
          ? const Center(child: Text('Nothing to show yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return HiddenGemListTile(
                  item: item,
                  onTap: () => context.push(HiddenGemRecommendationRoutes.scoreDetail, extra: item),
                );
              },
            ),
    );
  }
}
