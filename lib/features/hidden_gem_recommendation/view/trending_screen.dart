import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controller/trending_controller.dart';
import 'hidden_gem_recommendation_routes.dart';
import 'widgets/hidden_gem_list_tile.dart';

/// "View Trending Destination" use case — the full trending list reached
/// via "View All" from the discovery feed's "Trending Now" section.
class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(trendingControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Trending Now'),
            const SizedBox(width: 6),
            Icon(Icons.trending_up, color: colorScheme.error, size: 20),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(trendingControllerProvider).load(),
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.items.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Text(
                          'A1: Nothing trending right now — check back soon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.items.length,
                    itemBuilder: (context, index) {
                      final item = controller.items[index];
                      return HiddenGemListTile(
                        item: item,
                        onTap: () =>
                            context.push(HiddenGemRecommendationRoutes.scoreDetail, extra: item),
                      );
                    },
                  ),
      ),
    );
  }
}
