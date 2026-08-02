import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/destination.dart';
import '../../recommendations/view/recommendations_routes.dart';
import '../controller/assistant_controller.dart';
import '../model/assistant_feed_item.dart';

/// View-layer icon mapping for a category — kept out of the shared
/// [DestinationCategory] model, which has no Flutter dependency by design.
IconData _iconForCategory(DestinationCategory category) {
  switch (category) {
    case DestinationCategory.attraction:
      return Icons.explore_outlined;
    case DestinationCategory.heritageSite:
      return Icons.account_balance_outlined;
    case DestinationCategory.museum:
      return Icons.museum_outlined;
    case DestinationCategory.viewpoint:
      return Icons.landscape_outlined;
    case DestinationCategory.park:
      return Icons.park_outlined;
    case DestinationCategory.beach:
      return Icons.beach_access_outlined;
    case DestinationCategory.waterfall:
      return Icons.water_outlined;
    case DestinationCategory.cafe:
      return Icons.local_cafe_outlined;
    case DestinationCategory.restaurant:
      return Icons.restaurant_outlined;
    case DestinationCategory.craft:
      return Icons.brush_outlined;
    case DestinationCategory.art:
      return Icons.palette_outlined;
  }
}

/// The Assistant tab's landing feed — personalized hidden-gem matches and
/// trending places (Module 1), with the itinerary planner (Module 3)
/// reachable via the "Plan a Trip" action from here.
class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(assistantControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SearchBar(onTunePressed: () => context.push(RecommendationsRoutes.travelStyle)),
              const SizedBox(height: 10),
              _TravelPulseLink(onTap: () => context.push(RecommendationsRoutes.travelPulse)),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Your Top Matches',
                actionLabel: 'View All',
                onAction: () => _showComingSoon(context, 'Full match list'),
              ),
              const SizedBox(height: 12),
              if (controller.isLoading)
                const _FeedLoadingCard()
              else if (controller.topMatches.isEmpty)
                const _EmptyFeedCard(message: 'No matches yet — check back soon.')
              else
                _TopMatchCard(
                  item: controller.topMatches.first,
                  onExplore: () => context.push(
                    RecommendationsRoutes.scoreDetail,
                    extra: controller.topMatches.first,
                  ),
                ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Trending Now',
                titleIcon: Icons.trending_up,
                iconColor: colorScheme.error,
              ),
              const SizedBox(height: 12),
              if (controller.isLoading)
                const SizedBox(height: 210, child: _FeedLoadingCard())
              else if (controller.trending.isEmpty)
                const _EmptyFeedCard(message: 'Nothing trending right now.')
              else
                SizedBox(
                  height: 232,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.trending.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = controller.trending[index];
                      return _TrendingCard(
                        item: item,
                        onTap: () => context.push(RecommendationsRoutes.scoreDetail, extra: item),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — full details page coming soon')),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTunePressed;
  const _SearchBar({required this.onTunePressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Discover your next hidden gem.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Refresh your interests',
            color: colorScheme.onSurfaceVariant,
            onPressed: onTunePressed,
          ),
        ],
      ),
    );
  }
}

class _TravelPulseLink extends StatelessWidget {
  final VoidCallback onTap;
  const _TravelPulseLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.monitor_heart_outlined, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'View your Travel Pulse',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.titleIcon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (titleIcon != null) ...[
          const SizedBox(width: 6),
          Icon(titleIcon, size: 18, color: iconColor ?? colorScheme.primary),
        ],
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

/// Dark gradient placeholder used in place of a real photo — the same
/// convention already used elsewhere in this app (destination/timeline
/// image placeholders) since places don't have photo assets.
class _PlaceholderBackdrop extends StatelessWidget {
  final IconData icon;
  const _PlaceholderBackdrop({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primary, colorScheme.primaryContainer],
          ),
        ),
        child: Align(
          alignment: Alignment.center,
          child: Icon(icon, size: 64, color: Colors.white.withAlpha(46)),
        ),
      ),
    );
  }
}

class _TopMatchCard extends StatelessWidget {
  final AssistantFeedItem item;
  final VoidCallback onExplore;

  const _TopMatchCard({required this.item, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            _PlaceholderBackdrop(icon: _iconForCategory(item.category)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(20), Colors.black.withAlpha(150)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 14,
              child: Row(
                children: [
                  _Badge(label: '${item.matchPercent}% Match', color: Colors.black.withAlpha(140)),
                  if (item.isHiddenGem) ...[
                    const SizedBox(width: 8),
                    _Badge(label: 'Hidden Gem', color: const Color(0xFFC9A227)),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.category.label.toUpperCase()} • ${item.location.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFFE8D9A0),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: onExplore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: const Text('Explore Entry'),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bookmark_border, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final AssistantFeedItem item;
  final VoidCallback onTap;

  const _TrendingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 168,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(
                  children: [
                    _PlaceholderBackdrop(icon: _iconForCategory(item.category)),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _Badge(label: 'TRENDING', color: Colors.black.withAlpha(150), small: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                Text(
                  '+${item.trendPercent}%',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              '${item.category.label} • ${item.location}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const _Badge({required this.label, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9.5 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeedLoadingCard extends StatelessWidget {
  const _FeedLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  final String message;
  const _EmptyFeedCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
    );
  }
}
