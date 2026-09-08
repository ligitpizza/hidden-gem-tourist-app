import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../controller/itinerary_planner_controller.dart';
import '../../model/saved_itineraries_store.dart';
import '../../model/saved_itinerary.dart';
import '../itinerary_routes.dart';

/// A single saved itinerary, shown identically on the Saved tab and in
/// Profile (both display the same underlying [SavedItinerariesStore]).
/// Tapping it opens Route Optimized/Day Trip to view the plan as it was
/// saved; the overflow menu offers Edit (reopens Plan Your Route with the
/// same destinations, ready to change and regenerate) and Delete.
class SavedItineraryTile extends ConsumerWidget {
  final SavedItinerary saved;

  const SavedItineraryTile({super.key, required this.saved});

  void _view(BuildContext context, WidgetRef ref) {
    ref.read(itineraryPlannerControllerProvider).loadSavedItinerary(saved);
    context.push(ItineraryRoutes.routeOptimized);
  }

  void _edit(BuildContext context, WidgetRef ref) {
    ref.read(itineraryPlannerControllerProvider).loadSavedItinerary(saved);
    context.push(ItineraryRoutes.planRoute);
  }

  /// A short "2h ago" / "Yesterday" / "3 days ago" label — matches the
  /// relative-time style already used for Recently Viewed
  /// (RecentlyViewedPlace.relativeTimeLabel).
  String get _savedAgoLabel {
    final diff = DateTime.now().difference(saved.savedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String get _durationLabel {
    final minutes = saved.plan.estimatedMinutesNeeded;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$remainder min';
    if (remainder == 0) return '$hours hr';
    return '$hours hr $remainder min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final stopCount = saved.plan.timeline.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _view(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primaryContainerTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.map_outlined, color: colors.primaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saved.plan.destinations.map((d) => d.name).join(' → '),
                        style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _InfoChip(icon: Icons.place_outlined, label: '$stopCount stops'),
                          _InfoChip(icon: Icons.schedule_outlined, label: _durationLabel),
                          _InfoChip(icon: Icons.history, label: _savedAgoLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_SavedItineraryAction>(
                  icon: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
                  onSelected: (action) {
                    switch (action) {
                      case _SavedItineraryAction.edit:
                        _edit(context, ref);
                      case _SavedItineraryAction.delete:
                        SavedItinerariesStore.instance.remove(saved.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _SavedItineraryAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _SavedItineraryAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.bodySm),
      ],
    );
  }
}

enum _SavedItineraryAction { edit, delete }
