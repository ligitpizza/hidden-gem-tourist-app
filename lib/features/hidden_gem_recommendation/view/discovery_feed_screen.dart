import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/itinerary_planning/view/itinerary_routes.dart';
import '../../../shared/models/destination.dart';
import '../controller/recommendation_controller.dart';
import '../model/hidden_gem_feed_item.dart';
import '../model/interaction_repository.dart';
import 'hidden_gem_recommendation_routes.dart';
import 'widgets/hidden_gem_list_tile.dart';

/// The Home tab's landing feed — personalized hidden-gem matches and
/// trending places (Module 1's "View Recommended Destinations" /
/// "View Trending Destination" use cases), with the itinerary planner
/// (Module 3) reachable via the "Plan a Trip" action from here.
///
/// Owns its own "Plan a Trip" FAB (moved here from the shared shell
/// scaffold in app_router.dart) rather than the outer shell deciding
/// whether to show it based on `navigationShell.currentIndex` — that
/// tracking didn't reliably hide the FAB when navigating to a More-menu
/// entry nested under a different branch (found during pre-demo testing:
/// it kept floating over Journal's Badges/Quizzes/etc). A FAB on this
/// screen's own Scaffold has no such ambiguity: Flutter's IndexedStack
/// physically doesn't paint a non-selected branch at all, so this FAB is
/// guaranteed gone the instant Home isn't the visible tab, and covered
/// like normal whenever something is pushed on top of it within this
/// branch (Score Detail, Search, etc.) — the same as any other FAB.
class DiscoveryFeedScreen extends ConsumerWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(recommendationControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(ItineraryRoutes.planRoute),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Plan a Trip'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SearchBar(
                onSearchTap: () => context.push(HiddenGemRecommendationRoutes.search),
                onTunePressed: () => context.push(HiddenGemRecommendationRoutes.travelStyle),
              ),
              const SizedBox(height: 10),
              _TravelPulseLink(onTap: () => context.push(HiddenGemRecommendationRoutes.travelPulse)),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Your Top Matches',
                actionLabel: 'View All',
                onAction: () => context.push(
                  HiddenGemRecommendationRoutes.topMatchesList,
                  extra: controller.topMatches,
                ),
              ),
              const SizedBox(height: 12),
              if (controller.isLoading)
                const _FeedLoadingCard()
              else if (controller.topMatches.isEmpty)
                _EmptyFeedCard(
                  message: "No hidden gems match your current preferences yet — try "
                      'broadening your selected travel styles.',
                  actionLabel: 'Update Preferences',
                  onAction: () => context.push(HiddenGemRecommendationRoutes.travelStyle),
                )
              else
                _TopMatchCard(
                  item: controller.topMatches.first,
                  // "view" is logged centrally by ScoreDetailScreen itself,
                  // not here — see its doc comment.
                  onExplore: () => context.push(
                    HiddenGemRecommendationRoutes.scoreDetail,
                    extra: controller.topMatches.first,
                  ),
                ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Trending Now',
                titleIcon: Icons.trending_up,
                iconColor: colorScheme.error,
                actionLabel: 'View All',
                onAction: () => context.push(HiddenGemRecommendationRoutes.trending),
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
                        onTap: () =>
                            context.push(HiddenGemRecommendationRoutes.scoreDetail, extra: item),
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
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onTunePressed;
  const _SearchBar({required this.onSearchTap, required this.onTunePressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onSearchTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            // Icons.tune reads as a generic "search filters" control, which
            // this isn't — it's a shortcut to the preference profile
            // itself. Icons.interests names the actual concept.
            icon: const Icon(Icons.interests_outlined),
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

class _TopMatchCard extends StatefulWidget {
  final HiddenGemFeedItem item;
  final VoidCallback onExplore;

  const _TopMatchCard({required this.item, required this.onExplore});

  @override
  State<_TopMatchCard> createState() => _TopMatchCardState();
}

class _TopMatchCardState extends State<_TopMatchCard> {
  // Local, per-card bookmark state. This intentionally starts false on
  // every fresh load of the feed (not read back from Supabase) — the
  // interaction log isn't a source of "current saved state" for a place
  // in general (repeat views/searches don't un-set anything), only this
  // one card's own toggle tracks it, backed by InteractionRepository.save/
  // unsave for the actual persisted signal.
  bool _saved = false;
  final _interactionRepository = InteractionRepository();

  void _handleToggleSave() {
    final wasSaved = _saved;
    setState(() => _saved = !wasSaved);
    if (wasSaved) {
      _interactionRepository.unsave(widget.item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed'), duration: Duration(seconds: 2)),
      );
    } else {
      _interactionRepository.logSave(widget.item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your interests'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final onExplore = widget.onExplore;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            _PlaceholderBackdrop(icon: iconForHiddenGemCategory(item.category)),
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
                  _Badge(label: '${item.personalizedPercent}% Match', color: Colors.black.withAlpha(140)),
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
                      InkWell(
                        onTap: _handleToggleSave,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _saved
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withAlpha(50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _saved ? Icons.bookmark : Icons.bookmark_border,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
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
  final HiddenGemFeedItem item;
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
                    _PlaceholderBackdrop(icon: iconForHiddenGemCategory(item.category)),
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

/// E2 in "View Recommended Destinations": "system displays a message
/// suggesting the tourist broaden their selected preferences" — [onAction]
/// makes that suggestion actionable (jump straight to Preference Setup)
/// rather than just naming the fix in text; omit it for empty states that
/// aren't preference-driven (e.g. "nothing trending").
class _EmptyFeedCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyFeedCard({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
