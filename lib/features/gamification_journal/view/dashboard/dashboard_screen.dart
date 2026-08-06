import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/badge_controller.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/dashboard_controller.dart';
import '../../controller/journal_controller.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/category_breakdown_list.dart';
import '../../../../shared/widgets/check_in_history_tile.dart';
import '../../../../shared/widgets/economic_impact_chart.dart';
import '../../../../shared/widgets/stat_ring.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final CheckInController _checkInController;
  late final BadgeController _badgeController;
  late final JournalController _journalController;

  @override
  void initState() {
    super.initState();

    // The bottom-nav shell keeps every tab alive in an IndexedStack, so
    // this screen's State is only created once — without this, a
    // check-in/badge/journal change made on another tab would never
    // trigger a re-aggregation here, and the dashboard would look stuck
    // until a manual pull-to-refresh. Listening directly to the three
    // source controllers keeps it live regardless of which tab changed.
    _checkInController = context.read<CheckInController>();
    _badgeController = context.read<BadgeController>();
    _journalController = context.read<JournalController>();
    _checkInController.addListener(_refresh);
    _badgeController.addListener(_refresh);
    _journalController.addListener(_refresh);

    // Aggregation happens on the next frame so context.read is safe to
    // call — DashboardController doesn't own its data, it just snapshots
    // the other three controllers each time this screen is opened.
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

  @override
  Widget build(BuildContext context) {
    final dashboardController = context.watch<DashboardController>();
    final checkInController = context.watch<CheckInController>();
    final stats = dashboardController.stats;

    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };
    final recentCheckIns = checkInController.history.take(3).toList();

    return Scaffold(
      appBar: const AppHeader.tabRoot(title: 'Dashboard'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child:
            dashboardController.status == DashboardStatus.loading &&
                stats.totalCheckIns == 0
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                        Expanded(child: _StatTile(number: '${stats.badgesEarned}/${stats.badgesAvailable}', label: 'Badges')),
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

                  // --- Category breakdown -------------------------------
                  Text("Where you've been exploring", style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 8),
                  _SectionCard(
                    child: CategoryBreakdownList(breakdown: stats.categoryBreakdown),
                  ),
                  const SizedBox(height: 20),

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
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryContainer),
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
                  const SizedBox(height: 20),

                  // --- Recently visited -----------------------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recently visited', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                      if (checkInController.history.isNotEmpty)
                        TextButton(
                          onPressed: () => context.push('/dashboard/history'),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(number, style: AppTypography.headlineSm),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(fontSize: 10.5),
          ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
  }
}
