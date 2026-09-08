import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/badge_card.dart';
import '../../../destination_exploration/view/widgets/ratings_section.dart' show relativeTime;
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

class _FriendsListScreenState extends State<FriendsListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<FriendController>();
      await controller.loadFriends();
      await controller.acknowledgeNewFriends();
      if (!mounted) return;
      final destinationsById = {
        for (final d in context.read<CheckInController>().destinations) d.id: d,
      };
      await Future.wait([
        controller.loadLeaderboard(destinationsById),
        controller.loadActivityFeed(),
      ]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurfaceVariant,
              indicatorColor: colors.primary,
              tabs: const [
                Tab(text: 'Friends'),
                Tab(text: 'Leaderboard'),
                Tab(text: 'Activity'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_FriendsTab(), _LeaderboardTab(), _ActivityFeedTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

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

    return RefreshIndicator(
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
    );
  }
}

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  LeaderboardMetric _metric = LeaderboardMetric.checkIns;

  Future<void> _refresh(BuildContext context) {
    final destinationsById = {
      for (final d in context.read<CheckInController>().destinations) d.id: d,
    };
    return context.read<FriendController>().loadLeaderboard(destinationsById);
  }

  @override
  Widget build(BuildContext context) {
    final friendController = context.watch<FriendController>();
    final colors = AppColors.of(context);
    final leaderboard = friendController.leaderboard;

    if (friendController.isLoadingLeaderboard && leaderboard.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Just the current user, no friends yet to compare against.
    if (leaderboard.length < 2) {
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [_NoLeaderboardYet()],
        ),
      );
    }

    final sorted = List.of(leaderboard)
      ..sort((a, b) => b.valueFor(_metric).compareTo(a.valueFor(_metric)));

    // Ties share a rank instead of an arbitrary order deciding who's ahead.
    final ranks = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      ranks.add(
        i > 0 && sorted[i].valueFor(_metric) == sorted[i - 1].valueFor(_metric)
            ? ranks[i - 1]
            : i + 1,
      );
    }

    final top3 = sorted.take(3).toList();
    final rest = sorted.skip(3).toList();

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      color: colors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              for (final metric in LeaderboardMetric.values) ...[
                Expanded(
                  child: ChoiceChip(
                    label: Text(metric.label),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() => _metric = metric),
                    showCheckmark: false,
                    backgroundColor: colors.surfaceContainerHigh,
                    selectedColor: colors.primary,
                    labelStyle: AppTypography.labelMd.copyWith(
                      color: _metric == metric ? colors.onPrimary : colors.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  ),
                ),
                if (metric != LeaderboardMetric.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _Podium(top3: top3, metric: _metric),
          const SizedBox(height: 24),
          for (var i = 0; i < rest.length; i++)
            _LeaderboardRow(entry: rest[i], rank: ranks[i + 3], metric: _metric),
        ],
      ),
    );
  }
}

class _NoLeaderboardYet extends StatelessWidget {
  const _NoLeaderboardYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_outlined, size: 48, color: AppColors.of(context).primaryContainer),
            const SizedBox(height: 12),
            Text('Nothing to rank yet', style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              'Add a friend to see how your check-ins, badges and states explored compare.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.metric});

  final List<LeaderboardEntry> top3;
  final LeaderboardMetric metric;

  @override
  Widget build(BuildContext context) {
    // Visual left-to-right order is 2nd, 1st, 3rd — skip a slot if there
    // aren't enough friends yet to fill it.
    const order = [1, 0, 2];
    final slots = [
      for (final rankIndex in order)
        if (rankIndex < top3.length) (place: rankIndex + 1, entry: top3[rankIndex]),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          _PodiumSlot(entry: slots[i].entry, place: slots[i].place, metric: metric),
        ],
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.entry, required this.place, required this.metric});

  final LeaderboardEntry entry;
  final int place;
  final LeaderboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = entry.isCurrentUser
        ? 'You'
        : entry.profile.fullName.isEmpty
            ? 'Someone'
            : entry.profile.fullName;
    final initial = entry.profile.fullName.trim().isNotEmpty
        ? entry.profile.fullName.trim()[0].toUpperCase()
        : '?';

    final (avatarSize, barHeight, bg, fg) = switch (place) {
      1 => (56.0, 46.0, colors.secondaryContainer, colors.onSecondaryContainer),
      2 => (46.0, 32.0, colors.surfaceContainerHighest, colors.onSurfaceVariant),
      _ => (42.0, 20.0, colors.primaryContainerTint, colors.primaryContainer),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (place == 1) ...[
          Icon(Icons.workspace_premium, color: fg, size: 16),
          const SizedBox(height: 2),
        ],
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: entry.isCurrentUser ? Border.all(color: colors.primary, width: 2) : null,
          ),
          child: Text(initial, style: AppTypography.headlineSm.copyWith(color: fg)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: avatarSize + 12,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(
              color: colors.onSurface,
              fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text('${entry.valueFor(metric)}', style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          width: avatarSize,
          height: barHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.center,
          child: Text('$place', style: AppTypography.bodySm.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.rank, required this.metric});

  final LeaderboardEntry entry;
  final int rank;
  final LeaderboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = entry.isCurrentUser
        ? 'You'
        : entry.profile.fullName.isEmpty
            ? 'Someone'
            : entry.profile.fullName;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? colors.primaryContainerTint : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          _Avatar(name: entry.profile.fullName),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: AppTypography.bodySm.copyWith(
                fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${entry.valueFor(metric)} ${metric.label.toLowerCase()}',
            style: AppTypography.bodySm.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
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

class _ActivityFeedTab extends StatelessWidget {
  const _ActivityFeedTab();

  @override
  Widget build(BuildContext context) {
    final friendController = context.watch<FriendController>();
    final badgeController = context.watch<BadgeController>();
    final checkInController = context.watch<CheckInController>();
    final colors = AppColors.of(context);

    final badgesById = {for (final b in badgeController.allBadges) b.id: b};
    final destinationsById = {for (final d in checkInController.destinations) d.id: d};
    final feed = friendController.activityFeed;

    if (friendController.isLoadingActivityFeed && feed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => context.read<FriendController>().loadActivityFeed(),
      color: colors.primary,
      child: feed.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [_NoActivityYet()],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feed.length,
              itemBuilder: (context, index) {
                final entry = feed[index];
                final badge = entry.badgeId == null ? null : badgesById[entry.badgeId];
                return _ActivityFeedRow(
                  entry: entry,
                  badgeName: badge?.name,
                  badgeIcon: badge == null ? null : iconForBadge(badge),
                  destinationName: entry.destinationId == null
                      ? null
                      : destinationsById[entry.destinationId]?.name,
                );
              },
            ),
    );
  }
}

class _NoActivityYet extends StatelessWidget {
  const _NoActivityYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dynamic_feed_outlined, size: 48, color: AppColors.of(context).primaryContainer),
            const SizedBox(height: 12),
            Text('No activity yet', style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              "Check-ins and badges from you and your friends will show up here.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFeedRow extends StatelessWidget {
  const _ActivityFeedRow({
    required this.entry,
    this.badgeName,
    this.badgeIcon,
    this.destinationName,
  });

  final ActivityFeedEntry entry;
  final String? badgeName;
  final IconData? badgeIcon;
  final String? destinationName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = entry.isCurrentUser
        ? 'You'
        : entry.profile.fullName.isEmpty
            ? 'Someone'
            : entry.profile.fullName;

    final String description;
    final IconData icon;
    if (entry.badgeId != null) {
      description = "earned '${badgeName ?? 'a badge'}'";
      icon = badgeIcon ?? Icons.emoji_events_outlined;
    } else {
      description = 'checked in at ${destinationName ?? 'a hidden gem'}';
      icon = Icons.location_on_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: entry.profile.fullName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(icon, size: 13, color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: AppTypography.bodySm.copyWith(color: colors.onSurface),
                          children: [
                            TextSpan(
                              text: name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' $description'),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  relativeTime(entry.at),
                  style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (entry.checkInId != null) ...[
            const SizedBox(width: 8),
            _ReactionButton(checkInId: entry.checkInId!),
          ],
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.checkInId});

  final String checkInId;

  @override
  Widget build(BuildContext context) {
    final friendController = context.watch<FriendController>();
    final colors = AppColors.of(context);
    final count = friendController.reactionCounts[checkInId] ?? 0;
    final reacted = friendController.myReactedCheckInIds.contains(checkInId);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: () => context.read<FriendController>().toggleReaction(checkInId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reacted ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: reacted ? colors.error : colors.onSurfaceVariant,
            ),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Text('$count', style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
