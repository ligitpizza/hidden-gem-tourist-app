// Verifies the Journal module's integration into the real app without
// needing to sign in through Supabase auth (the full app_router.dart is
// auth-gated). Covers two things the user can't click-test yet because the
// check-in entry point still depends on a teammate's in-progress map:
//   1. The routes wired into ShellRoutes actually render the right screens.
//   2. The mock data chain a check-in triggers — journal draft creation and
//      badge evaluation — still works end to end.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:collab/core/router/shell_routes.dart';
import 'package:collab/features/gamification_journal/controller/badge_controller.dart';
import 'package:collab/features/gamification_journal/controller/checkin_controller.dart';
import 'package:collab/features/gamification_journal/controller/dashboard_controller.dart';
import 'package:collab/features/gamification_journal/controller/journal_controller.dart';
import 'package:collab/features/gamification_journal/controller/quiz_controller.dart';
import 'package:collab/features/gamification_journal/model/badge_model.dart';
import 'package:collab/features/gamification_journal/model/destination_model.dart';
import 'package:collab/features/gamification_journal/services/mock/mock_badge_service.dart';
import 'package:collab/features/gamification_journal/services/mock/mock_checkin_service.dart';
import 'package:collab/features/gamification_journal/services/mock/mock_journal_service.dart';
import 'package:collab/features/gamification_journal/services/mock/mock_quiz_service.dart';
import 'package:collab/features/gamification_journal/view/badges/badge_gallery_screen.dart';
import 'package:collab/features/gamification_journal/view/dashboard/dashboard_screen.dart';
import 'package:collab/features/gamification_journal/view/journal/journal_timeline_screen.dart';
import 'package:collab/features/gamification_journal/view/quiz/quiz_list_screen.dart';

/// Mirrors just the Journal branch's routes from app_router.dart, flat
/// instead of nested in the auth-gated StatefulShellRoute — same paths,
/// same screens, no sign-in required.
final _testDestination = DestinationModel(
  id: 'test-d001',
  name: 'Test Destination',
  state: 'Penang',
  category: 'Nature',
  latitude: 5.4,
  longitude: 100.3,
  description: 'A test destination.',
  imageUrl: 'https://example.com/image.jpg',
);

CheckInController _seededCheckInController() => CheckInController(
      userId: 'test-user',
      service: MockCheckInService(
        seedDestinations: [_testDestination],
        seedCheckIns: const [],
      ),
    );

/// Mirrors the "First Steps" badge from the real journal_badges seed data
/// (see supabase/migrations) without needing a live Supabase call in tests.
final _testBadgeCatalogue = [
  BadgeModel(
    id: 'checkins_1',
    name: 'First Steps',
    description: 'Complete your first check-in.',
    iconFilename: 'badge_checkins_1.png',
    criteriaType: BadgeCriteriaType.totalCheckIns,
    threshold: 1,
  ),
];

BadgeController _seededBadgeController() => BadgeController(
      userId: 'test-user',
      service: MockBadgeService(
        seedCatalogue: _testBadgeCatalogue,
        seedUserBadges: const [],
      ),
    );

/// Real app_router.dart's _MainShell loads every controller once at app
/// start; this test uses its own flat router with no such shell, so the
/// test body has to trigger the same loads itself — otherwise screens like
/// BadgeGalleryScreen sit on an infinite loading spinner (allBadges never
/// populates) and pumpAndSettle() hangs. Loads must fire *after* the
/// widget is pumped, not before: this test runs inside flutter_test's
/// FakeAsync zone, which only advances its clock while a pump is in
/// progress, so awaiting a mock service's Future.delayed() before the
/// first pumpWidget() would hang forever with no pump ever running to
/// resolve it.
Widget _testApp({
  required CheckInController checkInController,
  required BadgeController badgeController,
  required JournalController journalController,
  required QuizController quizController,
}) {
  const testRoot = '/journal';
  final router = GoRouter(
    initialLocation: testRoot,
    routes: [
      GoRoute(path: testRoot, builder: (c, s) => const DashboardScreen()),
      GoRoute(path: ShellRoutes.journalBadges, builder: (c, s) => const BadgeGalleryScreen()),
      GoRoute(path: ShellRoutes.journalEntries, builder: (c, s) => const JournalTimelineScreen(isTabRoot: false)),
      GoRoute(path: ShellRoutes.journalQuizzes, builder: (c, s) => const QuizListScreen()),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: checkInController),
      ChangeNotifierProvider.value(value: badgeController),
      ChangeNotifierProvider.value(value: journalController),
      ChangeNotifierProvider.value(value: quizController),
      ChangeNotifierProvider(create: (_) => DashboardController()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('Dashboard loads and its quick links reach Badges, Journal and Quizzes', (
    tester,
  ) async {
    final checkInController = _seededCheckInController();
    final badgeController = _seededBadgeController();
    final journalController = JournalController(
      userId: 'test-user',
      service: MockJournalService(seedEntries: const []),
    );
    final quizController = QuizController(
      userId: 'test-user',
      service: MockQuizService(seedAttempts: const []),
    );

    await tester.pumpWidget(
      _testApp(
        checkInController: checkInController,
        badgeController: badgeController,
        journalController: journalController,
        quizController: quizController,
      ),
    );

    // Fire the loads _MainShell normally triggers at app start — not
    // awaited directly (see _testApp's doc comment above).
    unawaited(checkInController.loadDestinations());
    unawaited(checkInController.loadHistory());
    unawaited(badgeController.loadBadges());
    unawaited(journalController.loadEntries());
    unawaited(quizController.loadDailyFact());
    unawaited(quizController.loadHistory());

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboardQuickLinkBadges')));
    await tester.pumpAndSettle();
    expect(find.byType(BadgeGalleryScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboardQuickLinkJournal')));
    await tester.pumpAndSettle();
    expect(find.byType(JournalTimelineScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboardQuickLinkQuizzes')));
    await tester.pumpAndSettle();
    expect(find.byType(QuizListScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('A check-in still creates a journal draft and unlocks the right badge', () async {
    final checkInController = _seededCheckInController();
    final journalController = JournalController(
      userId: 'test-user',
      service: MockJournalService(seedEntries: const []),
    );
    final badgeController = _seededBadgeController();

    await checkInController.loadDestinations();
    expect(checkInController.destinations, isNotEmpty);
    final destination = checkInController.destinations.first;

    await checkInController.checkIn(
      destinationId: destination.id,
      userLat: destination.latitude,
      userLng: destination.longitude,
    );
    expect(checkInController.status, CheckInStatus.success);
    expect(checkInController.history, hasLength(1));

    final entry = await journalController.createFromCheckIn(checkInController.history.first);
    expect(journalController.entries, contains(entry));
    expect(entry.destinationId, destination.id);

    final destinationsById = {for (final d in checkInController.destinations) d.id: d};
    await badgeController.evaluateAfterCheckIn(
      checkIns: checkInController.history,
      destinationsById: destinationsById,
    );
    expect(badgeController.newlyEarned.map((b) => b.name), contains('First Steps'));

    final dashboardController = DashboardController();
    await dashboardController.refresh(
      checkIns: checkInController.history,
      destinationsById: destinationsById,
      userBadges: badgeController.userBadges,
      allBadges: badgeController.allBadges,
      journalEntries: journalController.entries,
    );
    expect(dashboardController.stats.totalCheckIns, 1);
    expect(dashboardController.stats.badgesEarned, 1);
  });
}
