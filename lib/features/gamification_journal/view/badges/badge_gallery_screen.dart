import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/badge_controller.dart';
import '../../model/badge_model.dart';
import '../../model/user_badge_model.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/badge_card.dart';

String _filterTagFor(BadgeModel badge) {
  switch (badge.criteriaType) {
    case BadgeCriteriaType.totalCheckIns:
      return 'Milestones';
    case BadgeCriteriaType.categoryCount:
      return badge.targetValue ?? 'Category';
    case BadgeCriteriaType.stateVisit:
      return 'Regional';
    case BadgeCriteriaType.quizzesCompleted:
      return 'Quiz';
  }
}

class BadgeGalleryScreen extends StatefulWidget {
  const BadgeGalleryScreen({super.key});

  @override
  State<BadgeGalleryScreen> createState() => _BadgeGalleryScreenState();
}

class _BadgeGalleryScreenState extends State<BadgeGalleryScreen> {
  String _selectedFilter = 'All';

  void _showBadgeDetail(
    BuildContext context, {
    required BadgeModel badge,
    required bool isUnlocked,
    UserBadgeModel? userBadge,
    BadgeProgressModel? progress,
  }) {
    final badgeController = context.read<BadgeController>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isUnlocked ? AppColors.secondaryContainer : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnlocked ? Icons.workspace_premium : Icons.lock_outline,
                      size: 36,
                      color: isUnlocked ? AppColors.onSecondaryContainer : AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(badge.name, style: AppTypography.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    isUnlocked ? 'ACHIEVEMENT UNLOCKED' : 'IN PROGRESS',
                    style: AppTypography.labelMd.copyWith(
                      color: isUnlocked ? AppColors.secondary : AppColors.onSurfaceVariant,
                      letterSpacing: 0.08 * 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  if (!isUnlocked && progress != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Progress: ${progress.current} of ${progress.target}',
                      style: AppTypography.bodySm,
                    ),
                  ] else if (userBadge != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Earned on ${userBadge.earnedAt.day}/${userBadge.earnedAt.month}/${userBadge.earnedAt.year}',
                      style: AppTypography.bodySm,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (isUnlocked) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share Achievement'),
                        // TODO(phase1): wire up share_plus once media capture
                        // (RepaintBoundary -> PNG) is implemented for the badge card.
                        onPressed: () {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Sharing will be available once media export is wired up.'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      if (isUnlocked)
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              userBadge!.isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 16,
                            ),
                            label: Text(userBadge.isHidden ? 'Unhide' : 'Hide', overflow: TextOverflow.ellipsis),
                            onPressed: () async {
                              await badgeController.setHidden(badge.id, !userBadge.isHidden);
                              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                            },
                          ),
                        ),
                      if (isUnlocked) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Wiki Info', overflow: TextOverflow.ellipsis),
                          onPressed: () => showDialog<void>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(badge.name),
                              content: Text(
                                '${badge.description}\n\nCriteria: ${progress?.target ?? badge.threshold} ${_filterTagFor(badge).toLowerCase()}.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeController = context.watch<BadgeController>();
    final progressByBadgeId = {
      for (final p in badgeController.progress) p.badgeId: p,
    };
    final userBadgeByBadgeId = {
      for (final ub in badgeController.userBadges) ub.badgeId: ub,
    };

    final filters = [
      'All',
      ...{for (final b in badgeController.allBadges) _filterTagFor(b)},
    ];
    final visibleBadges = _selectedFilter == 'All'
        ? badgeController.allBadges
        : badgeController.allBadges.where((b) => _filterTagFor(b) == _selectedFilter).toList();
    final unlockedBadges = visibleBadges.where((b) => badgeController.isUnlocked(b.id)).toList();
    final lockedBadges = visibleBadges.where((b) => !badgeController.isUnlocked(b.id)).toList();

    return Scaffold(
      appBar: const AppHeader.tabRoot(title: 'Badges'),
      body: badgeController.allBadges.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Hero summary -----------------------------------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Achievements',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "You've unlocked ${badgeController.userBadges.length} of ${badgeController.allBadges.length} explorer badges. Keep journaling to earn more!",
                        style: AppTypography.bodySm.copyWith(color: AppColors.primaryFixedDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- Filters -------------------------------------------------
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      final selected = filter == _selectedFilter;
                      return ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        showCheckmark: false,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        selectedColor: AppColors.primary,
                        labelStyle: AppTypography.labelMd.copyWith(
                          color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // --- Unlocked ------------------------------------------------
                if (unlockedBadges.isNotEmpty) ...[
                  Text('Unlocked', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 10),
                  _BadgeGrid(
                    badges: unlockedBadges,
                    badgeController: badgeController,
                    progressByBadgeId: progressByBadgeId,
                    userBadgeByBadgeId: userBadgeByBadgeId,
                    onTapBadge: (badge, isUnlocked) => _showBadgeDetail(
                      context,
                      badge: badge,
                      isUnlocked: isUnlocked,
                      userBadge: userBadgeByBadgeId[badge.id],
                      progress: progressByBadgeId[badge.id],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // --- Locked ----------------------------------------------------
                if (lockedBadges.isNotEmpty) ...[
                  Text('Locked', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(height: 10),
                  _BadgeGrid(
                    badges: lockedBadges,
                    badgeController: badgeController,
                    progressByBadgeId: progressByBadgeId,
                    userBadgeByBadgeId: userBadgeByBadgeId,
                    onTapBadge: (badge, isUnlocked) => _showBadgeDetail(
                      context,
                      badge: badge,
                      isUnlocked: isUnlocked,
                      userBadge: userBadgeByBadgeId[badge.id],
                      progress: progressByBadgeId[badge.id],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({
    required this.badges,
    required this.badgeController,
    required this.progressByBadgeId,
    required this.userBadgeByBadgeId,
    required this.onTapBadge,
  });

  final List<BadgeModel> badges;
  final BadgeController badgeController;
  final Map<String, BadgeProgressModel> progressByBadgeId;
  final Map<String, UserBadgeModel> userBadgeByBadgeId;
  final void Function(BadgeModel badge, bool isUnlocked) onTapBadge;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isUnlocked = badgeController.isUnlocked(badge.id);

        return BadgeCard(
          badge: badge,
          isUnlocked: isUnlocked,
          progress: progressByBadgeId[badge.id],
          onTap: () => onTapBadge(badge, isUnlocked),
        );
      },
    );
  }
}
