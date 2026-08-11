import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/theme.dart';
import '../../../core/router/shell_routes.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../shared/widgets/category_breakdown_list.dart';
import '../../../shared/widgets/check_in_history_tile.dart';
import '../../../shared/widgets/economic_impact_chart.dart';
import '../../../shared/widgets/stat_ring.dart';
import '../../auth/model/auth_repository.dart';
import '../../gamification_journal/controller/badge_controller.dart';
import '../../gamification_journal/controller/checkin_controller.dart';
import '../../gamification_journal/controller/dashboard_controller.dart';
import '../../gamification_journal/controller/journal_controller.dart';
import '../../gamification_journal/controller/quiz_controller.dart';
import '../../gamification_journal/model/journal_media_model.dart';
import '../../gamification_journal/view/journal/journal_timeline_screen.dart';
import 'widgets/profile_share_sheet.dart';

/// The Tourist's showcase page — everything worth bragging about in one
/// place: stats, achievements, and journal highlights, with a Share
/// action that exports a stripped-down card for social media. This
/// absorbs what used to be the Journal tab's Dashboard (states/check-ins/
/// badges stats, category breakdown, local economic impact, recent
/// visits) — the Journal tab itself now shows only the entries timeline.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final CheckInController _checkInController;
  late final BadgeController _badgeController;
  late final JournalController _journalController;

  @override
  void initState() {
    super.initState();

    // The bottom-nav shell keeps every tab alive in an IndexedStack, so
    // this screen's State is only created once — without this, a
    // check-in/badge/journal change made on another tab would never
    // trigger a re-aggregation here, and the stats would look stuck until
    // a manual pull-to-refresh. Listening directly to the three source
    // controllers keeps it live regardless of which tab changed.
    _checkInController = context.read<CheckInController>();
    _badgeController = context.read<BadgeController>();
    _journalController = context.read<JournalController>();
    _checkInController.addListener(_refresh);
    _badgeController.addListener(_refresh);
    _journalController.addListener(_refresh);

    // The app shell (_MainShell in app_router.dart) owns the module's
    // one-time initial data load at app start, so this just needs an
    // initial aggregation once that data starts arriving.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _checkInController.removeListener(_refresh);
    _badgeController.removeListener(_refresh);
    _journalController.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    final checkInController = context.read<CheckInController>();
    final badgeController = context.read<BadgeController>();
    final journalController = context.read<JournalController>();

    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };

    await context.read<DashboardController>().refresh(
      checkIns: checkInController.history,
      destinationsById: destinationsById,
      userBadges: badgeController.userBadges,
      allBadges: badgeController.allBadges,
      journalEntries: journalController.entries,
    );
  }

  void _openShareSheet(BuildContext context, {required String travellerName}) {
    // Gathering the share data shouldn't ever throw, but if it does, this
    // makes sure the Tourist sees *something* went wrong rather than the
    // Share button silently doing nothing.
    try {
      final stats = context.read<DashboardController>().stats;
      final badgeController = context.read<BadgeController>();
      final journalController = context.read<JournalController>();
      final checkInController = context.read<CheckInController>();

      // Badges the Tourist chose to feature take priority; if none are
      // pinned, fall back to the first 3 unlocked badges as before.
      final pinnedBadges = badgeController.pinnedBadges;
      final topBadges = pinnedBadges.isNotEmpty
          ? pinnedBadges
          : badgeController.allBadges
              .where((b) => badgeController.isUnlocked(b.id))
              .take(3)
              .toList();

      final destinationsById = {
        for (final d in checkInController.destinations) d.id: d,
      };

      // Photos only, paired with the destination they were taken at —
      // videos don't make sense as a still-image share card. Entries
      // without a matching destination (shouldn't normally happen) fall
      // back to a generic label rather than being silently dropped.
      final photos = journalController.entries
          .expand(
            (e) => e.media
                .where((m) => m.type == JournalMediaType.photo)
                .map((m) => SharePhoto(
                      url: m.url,
                      destinationName: destinationsById[e.destinationId]?.name ?? 'Hidden gem',
                    )),
          )
          .take(3)
          .toList();

      showProfileShareSheet(
        context,
        travellerName: travellerName,
        checkIns: stats.totalCheckIns,
        badgesEarned: stats.badgesEarned,
        statesExplored: stats.statesExplored,
        totalMalaysianRegions: stats.totalMalaysianRegions,
        economicImpactTotalRM: stats.economicImpactTotalRM,
        photos: photos,
        topBadges: topBadges,
      );
    } catch (e, stackTrace) {
      debugPrint('ProfileScreen: could not open share sheet: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the share preview. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Traveller';
    final colors = AppColors.of(context);
    final themeModeController = ref.watch(themeModeControllerProvider);

    final dashboardController = context.watch<DashboardController>();
    final checkInController = context.watch<CheckInController>();
    final badgeController = context.watch<BadgeController>();
    final quizController = context.watch<QuizController>();
    final journalController = context.watch<JournalController>();

    final stats = dashboardController.stats;
    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };
    final recentCheckIns = checkInController.history.take(3).toList();
    final pendingQuizzes = quizController.pendingQuizCount(
      checkInController.history.map((c) => c.destinationId).toSet(),
    );
    final journalPhotos = journalController.entries
        .expand((e) => e.media)
        .where((m) => m.type == JournalMediaType.photo)
        .take(6)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: colors.primary,
        child: dashboardController.status == DashboardStatus.loading && stats.totalCheckIns == 0
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName, style: AppTypography.headlineSm),
                            if (user?.email != null)
                              Text(
                                user!.email!,
                                style: AppTypography.bodySm.copyWith(color: colors.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _openShareSheet(context, travellerName: fullName),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: AppColors.of(context).outlineVariant),
                        ),
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text('Share to…'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Overview stats -----------------------------------
                  StatRing(
                    label: 'States Explored',
                    current: stats.statesExplored,
                    target: stats.totalMalaysianRegions,
                    size: 148,
                    strokeWidth: 10,
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _StatTile(number: '${stats.totalCheckIns}', label: 'Check-ins')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            number: '${stats.badgesEarned}/${stats.badgesAvailable}',
                            label: 'Badges',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            number: '${stats.economicImpactBreakdown.length}',
                            label: 'Categories',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Achievements ---------------------------------------
                  Text('Achievements', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AchievementCard(
                          icon: Icons.emoji_events_outlined,
                          label: 'Badges',
                          showDot: badgeController.hasUnviewedBadges,
                          onTap: () => context.push(ShellRoutes.journalBadges),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AchievementCard(
                          icon: Icons.quiz_outlined,
                          label: 'Quizzes',
                          count: pendingQuizzes,
                          onTap: () => context.push(ShellRoutes.journalQuizzes),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Journal highlights -----------------------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Journal highlights', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                      TextButton(
                        // A plain push, not context.push(ShellRoutes.journal)
                        // — that path is the Journal tab's own shell-branch
                        // root, and pushing a branch root through go_router
                        // switches the active tab instead of opening a
                        // normal page with a working back button.
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JournalTimelineScreen(isTabRoot: false),
                          ),
                        ),
                        child: const Text('View journal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (journalPhotos.isEmpty)
                    _SectionCard(
                      child: Text(
                        'Photos from your journal entries will show up here.',
                        style: AppTypography.bodySm,
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemCount: journalPhotos.length,
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.network(
                          journalPhotos[index].url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: colors.surfaceContainerHigh),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // --- Category breakdown -------------------------------
                  Text("Where you've been exploring", style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 8),
                  _SectionCard(
                    child: CategoryBreakdownList(breakdown: stats.categoryBreakdown),
                  ),
                  const SizedBox(height: 24),

                  // --- Economic impact -----------------------------------
                  Text('Local Economy Support Tracker', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 8),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stats.economicImpactBreakdown.isNotEmpty)
                          Text.rich(
                            TextSpan(
                              style: AppTypography.bodyMd,
                              children: [
                                const TextSpan(text: "You've contributed "),
                                TextSpan(
                                  text: 'RM ${stats.economicImpactTotalRM.toStringAsFixed(0)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryContainer),
                                ),
                                const TextSpan(text: ' directly to micro-businesses and rural communities.'),
                              ],
                            ),
                          ),
                        if (stats.economicImpactBreakdown.isNotEmpty) const SizedBox(height: 12),
                        EconomicImpactChart(breakdown: stats.economicImpactBreakdown),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Recently visited -----------------------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recently visited', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                      if (checkInController.history.isNotEmpty)
                        TextButton(
                          onPressed: () => context.push(ShellRoutes.journalHistory),
                          child: const Text('View all'),
                        ),
                    ],
                  ),
                  if (recentCheckIns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Your recent check-ins will show up here.',
                        style: AppTypography.bodySm,
                      ),
                    )
                  else
                    ...recentCheckIns.map(
                      (checkIn) => CheckInHistoryTile(
                        checkIn: checkIn,
                        destination: destinationsById[checkIn.destinationId],
                        onToggleHidden: () => context
                            .read<CheckInController>()
                            .setHidden(checkIn.id, !checkIn.isHidden),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // --- Settings ---------------------------------------------
                  Text(
                    'APPEARANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                    ],
                    selected: {themeModeController.themeMode},
                    onSelectionChanged: (selection) =>
                        ref.read(themeModeControllerProvider).setThemeMode(selection.first),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => AuthRepository().signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                  ),
                ],
              ),
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

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
    this.count = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final iconWidget = Icon(icon, color: colors.primaryContainer);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.primaryContainerTint,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            if (showDot)
              Badge(child: iconWidget)
            else if (count > 0)
              Badge(label: Text('$count'), child: iconWidget)
            else
              iconWidget,
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(color: colors.primaryContainer, letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}
