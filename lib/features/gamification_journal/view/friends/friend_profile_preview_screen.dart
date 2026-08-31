import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/badge_card.dart';
import '../../../../shared/widgets/category_breakdown_list.dart';
import '../../../../shared/widgets/stat_ring.dart';
import '../../controller/badge_controller.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/friend_controller.dart';
import '../../model/badge_model.dart';
import '../../model/check_in_model.dart';
import '../../model/friend_model.dart';
import '../../model/user_badge_model.dart';

/// A read-only showcase of someone else's profile — reached by tapping a
/// search result or a friend row. Shows the same kind of stats
/// ProfileScreen shows about yourself, but only what that person hasn't
/// hidden (see the "Public view non-hidden ..." RLS policies), and none
/// of the account-management sections (appearance, itinerary prefs, log
/// out) that only make sense for your own profile. The "Share to…" button
/// is replaced here by whatever the relationship with this person
/// actually is — Add Friend, a pending request, or Remove Friend.
class FriendProfilePreviewScreen extends StatefulWidget {
  const FriendProfilePreviewScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  State<FriendProfilePreviewScreen> createState() => _FriendProfilePreviewScreenState();
}

class _FriendProfilePreviewScreenState extends State<FriendProfilePreviewScreen> {
  bool _loading = true;
  List<CheckInModel> _checkIns = [];
  List<UserBadgeModel> _badges = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final (checkIns, badges) =
          await context.read<FriendController>().fetchPublicActivity(widget.profile.id);
      if (!mounted) return;
      setState(() {
        _checkIns = checkIns;
        _badges = badges;
        _loading = false;
      });
    } catch (e) {
      debugPrint('FriendProfilePreviewScreen: could not load activity: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleAction(Future<bool> Function() action) async {
    final friendController = context.read<FriendController>();
    final success = await action();
    if (!mounted) return;
    if (!success && friendController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendController.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendController = context.watch<FriendController>();
    final badgeController = context.watch<BadgeController>();
    final checkInController = context.watch<CheckInController>();
    final colors = AppColors.of(context);

    final destinationsById = {for (final d in checkInController.destinations) d.id: d};
    final relationship = friendController.relationshipWith(widget.profile.id);
    final name = widget.profile.fullName.isEmpty ? 'Tourist' : widget.profile.fullName;

    final statesExplored = _checkIns
        .map((c) => destinationsById[c.destinationId]?.state)
        .whereType<String>()
        .toSet()
        .length;

    final categoryBreakdown = <String, int>{};
    for (final c in _checkIns) {
      final category = destinationsById[c.destinationId]?.category;
      if (category == null) continue;
      categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
    }

    final badgesById = {for (final b in badgeController.allBadges) b.id: b};
    final earnedBadges = _badges
        .map((ub) => badgesById[ub.badgeId])
        .whereType<BadgeModel>()
        .toList();

    return Scaffold(
      appBar: AppHeader.pushed(title: name),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Identity ---------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(Icons.person, size: 32, color: colors.onPrimaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(name, style: AppTypography.headlineSm)),
                  ],
                ),
                const SizedBox(height: 14),
                _RelationshipActions(
                  profileId: widget.profile.id,
                  relationship: relationship,
                  currentUserId: friendController.userId,
                  onAction: _handleAction,
                ),
                const SizedBox(height: 24),

                // --- Overview stats -----------------------------------
                StatRing(
                  label: 'States Explored',
                  current: statesExplored,
                  target: 13,
                  size: 148,
                  strokeWidth: 10,
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _StatTile(number: '${_checkIns.length}', label: 'Check-ins')),
                      const SizedBox(width: 10),
                      Expanded(child: _StatTile(number: '${earnedBadges.length}', label: 'Badges')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(number: '${categoryBreakdown.length}', label: 'Categories'),
                      ),
                    ],
                  ),
                ),

                if (earnedBadges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Badges', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final b in earnedBadges) _BadgeChip(badge: b)],
                  ),
                ],

                const SizedBox(height: 24),
                Text("Where they've been exploring", style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                const SizedBox(height: 8),
                _SectionCard(child: CategoryBreakdownList(breakdown: categoryBreakdown)),

                const SizedBox(height: 24),
                Text('Recently visited', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                const SizedBox(height: 8),
                if (_checkIns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nothing to show yet.',
                      style: AppTypography.bodySm.copyWith(color: colors.onSurfaceVariant),
                    ),
                  )
                else
                  for (final checkIn in _checkIns.take(3))
                    _RecentVisitRow(
                      destinationName: destinationsById[checkIn.destinationId]?.name ?? 'A hidden gem',
                      timestamp: checkIn.timestamp,
                    ),
              ],
            ),
    );
  }
}

class _RelationshipActions extends StatelessWidget {
  const _RelationshipActions({
    required this.profileId,
    required this.relationship,
    required this.currentUserId,
    required this.onAction,
  });

  final String profileId;
  final FriendshipModel? relationship;
  final String currentUserId;
  final Future<void> Function(Future<bool> Function() action) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = context.read<FriendController>();

    if (relationship == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('Add Friend'),
          onPressed: () => onAction(() => controller.sendRequest(profileId)),
        ),
      );
    }

    if (relationship!.status == FriendshipStatus.accepted) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          label: const Text('Remove Friend'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Remove friend?'),
              content: const Text('You will no longer be able to see each other\'s activity.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onAction(() => controller.removeFriend(relationship!.id));
                  },
                  child: Text('Remove', style: TextStyle(color: colors.error)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Pending — this user sent the request themselves.
    if (relationship!.requesterId == currentUserId) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => onAction(() => controller.declineRequest(relationship!.id)),
          child: const Text('Cancel Request'),
        ),
      );
    }

    // Pending — the other person sent this user a request.
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () => onAction(() => controller.acceptRequest(relationship!.id)),
            child: const Text('Accept'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
            onPressed: () => onAction(() => controller.declineRequest(relationship!.id)),
            child: const Text('Decline'),
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final BadgeModel badge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForBadge(badge), size: 12, color: colors.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            badge.name,
            style: AppTypography.labelSm.copyWith(fontSize: 10, color: colors.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

class _RecentVisitRow extends StatelessWidget {
  const _RecentVisitRow({required this.destinationName, required this.timestamp});

  final String destinationName;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(destinationName, style: AppTypography.bodySm, overflow: TextOverflow.ellipsis),
          ),
          Text(
            '${timestamp.day}/${timestamp.month}/${timestamp.year}',
            style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(number, style: AppTypography.headlineSm),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: AppTypography.bodySm.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}
