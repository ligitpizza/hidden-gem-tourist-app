import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/badge_card.dart';
import '../../controller/badge_controller.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/friend_controller.dart';
import 'friend_profile_preview_screen.dart';
import 'friend_search_screen.dart';

/// Runs a FriendController action and, if it failed, shows the
/// controller's errorMessage as a SnackBar instead of failing silently.
Future<void> _runFriendAction(BuildContext context, Future<bool> Function() action) async {
  final friendController = context.read<FriendController>();
  final success = await action();
  if (!context.mounted || success) return;
  final message = friendController.errorMessage;
  if (message != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<FriendController>();
      await controller.loadFriends();
      await controller.acknowledgeNewFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendController = context.watch<FriendController>();
    final badgeController = context.watch<BadgeController>();
    final checkInController = context.watch<CheckInController>();

    final badgesById = {for (final b in badgeController.allBadges) b.id: b};
    final destinationsById = {for (final d in checkInController.destinations) d.id: d};

    final hasAnything = friendController.friends.isNotEmpty ||
        friendController.incomingRequests.isNotEmpty ||
        friendController.outgoingRequests.isNotEmpty;

    return Scaffold(
      appBar: AppHeader.pushed(
        title: 'Friends',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Add friend',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendSearchScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<FriendController>().loadFriends(),
        color: AppColors.of(context).primary,
        child: friendController.isLoading && !hasAnything
          ? const Center(child: CircularProgressIndicator())
          : !hasAnything
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (friendController.incomingRequests.isNotEmpty) ...[
                      Text('Friend requests', style: AppTypography.headlineSm),
                      const SizedBox(height: 8),
                      for (final request in friendController.incomingRequests)
                        _RequestTile(request: request),
                      const SizedBox(height: 20),
                    ],
                    if (friendController.outgoingRequests.isNotEmpty) ...[
                      Text('Requests sent', style: AppTypography.headlineSm),
                      const SizedBox(height: 8),
                      for (final request in friendController.outgoingRequests)
                        _OutgoingRequestTile(request: request),
                      const SizedBox(height: 20),
                    ],
                    if (friendController.friends.isNotEmpty) ...[
                      Text('Friends', style: AppTypography.headlineSm),
                      const SizedBox(height: 8),
                      for (final friend in friendController.friends)
                        _FriendTile(
                          friend: friend,
                          badgeName: friend.activity?.badgeId != null
                              ? badgesById[friend.activity!.badgeId]?.name
                              : null,
                          badgeIcon: friend.activity?.badgeId != null
                              ? badgesById[friend.activity!.badgeId] == null
                                  ? null
                                  : iconForBadge(badgesById[friend.activity!.badgeId]!)
                              : null,
                          destinationName: friend.activity?.destinationId != null
                              ? destinationsById[friend.activity!.destinationId]?.name
                              : null,
                        ),
                    ],
                  ],
                ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final FriendRequestEntry request;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FriendProfilePreviewScreen(profile: request.profile)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              _Avatar(name: request.profile.fullName),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  request.profile.fullName.isEmpty ? 'Someone' : request.profile.fullName,
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.check_circle, color: colors.primary),
                tooltip: 'Accept',
                onPressed: () => _runFriendAction(
                  context,
                  () => context.read<FriendController>().acceptRequest(request.friendshipId),
                ),
              ),
              IconButton(
                icon: Icon(Icons.cancel_outlined, color: colors.error),
                tooltip: 'Decline',
                onPressed: () => _runFriendAction(
                  context,
                  () => context.read<FriendController>().declineRequest(request.friendshipId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A request this user sent that's still waiting on the other person —
/// previously only visible by re-searching their name and reopening their
/// preview; shown here directly with a way to cancel it.
class _OutgoingRequestTile extends StatelessWidget {
  const _OutgoingRequestTile({required this.request});

  final FriendRequestEntry request;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FriendProfilePreviewScreen(profile: request.profile)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              _Avatar(name: request.profile.fullName),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  request.profile.fullName.isEmpty ? 'Someone' : request.profile.fullName,
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text('Pending', style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
                tooltip: 'Cancel request',
                onPressed: () => _runFriendAction(
                  context,
                  () => context.read<FriendController>().declineRequest(request.friendshipId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    this.badgeName,
    this.badgeIcon,
    this.destinationName,
  });

  final FriendEntry friend;
  final String? badgeName;
  final IconData? badgeIcon;
  final String? destinationName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = friend.profile.fullName.isEmpty ? 'Someone' : friend.profile.fullName;

    String? announcement;
    IconData announcementIcon = Icons.explore_outlined;
    if (badgeName != null) {
      announcement = "Earned '$badgeName'";
      announcementIcon = badgeIcon ?? Icons.emoji_events_outlined;
    } else if (destinationName != null) {
      announcement = 'Checked in at $destinationName';
      announcementIcon = Icons.location_on_outlined;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FriendProfilePreviewScreen(profile: friend.profile)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              _Avatar(name: friend.profile.fullName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    if (announcement != null)
                      Row(
                        children: [
                          Icon(announcementIcon, size: 13, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              announcement,
                              style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'No activity yet',
                        style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.person_remove_outlined, size: 18, color: colors.onSurfaceVariant),
                tooltip: 'Remove friend',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Remove friend?'),
                    content: Text('$name will no longer be able to see your activity, or you theirs.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _runFriendAction(
                            context,
                            () => context.read<FriendController>().removeFriend(friend.friendshipId),
                          );
                        },
                        child: Text('Remove', style: TextStyle(color: AppColors.of(context).error)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: colors.primaryContainerTint,
      child: Text(
        initial,
        style: AppTypography.headlineSm.copyWith(color: colors.primaryContainer),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: AppColors.of(context).primaryContainer),
            const SizedBox(height: 12),
            Text('No friends yet', style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              'Search for other Tourists by name and add them to see what they\'ve explored.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Find friends'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendSearchScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
