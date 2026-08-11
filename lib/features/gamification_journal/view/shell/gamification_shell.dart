import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/badge_controller.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/journal_controller.dart';
import '../../controller/quiz_controller.dart';

/// Bottom-nav shell for the module's five tabs. Also owns the one-time
/// initial data load — every controller exposes a `load*()` method but
/// nothing was calling them, so every screen used to show its empty state
/// forever regardless of the mock data available.
class GamificationShell extends StatefulWidget {
  const GamificationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<GamificationShell> createState() => _GamificationShellState();
}

class _GamificationShellState extends State<GamificationShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final checkInController = context.read<CheckInController>();
    final badgeController = context.read<BadgeController>();
    final journalController = context.read<JournalController>();
    final quizController = context.read<QuizController>();

    await checkInController.loadDestinations();
    await checkInController.loadHistory();
    await badgeController.loadBadges();
    await journalController.loadEntries();
    await quizController.loadDailyFact();
    await quizController.loadHistory();
  }

  static const _destinations = [
    (icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Explore'),
    (icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book, label: 'Journal'),
    (icon: Icons.emoji_events_outlined, selectedIcon: Icons.emoji_events, label: 'Badges'),
    (icon: Icons.quiz_outlined, selectedIcon: Icons.quiz, label: 'Quiz'),
    (icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Dashboard'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.of(context).outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) => widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}
