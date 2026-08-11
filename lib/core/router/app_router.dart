import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// provider's own Provider class collides with Riverpod's Provider<T> (used
// below for appRouterProvider) — hide it, this file only needs provider's
// context.read/context.watch extensions for the initial data load.
import 'package:provider/provider.dart' hide Provider;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/assistant/view/assistant_screen.dart';
import '../../features/auth/model/auth_repository.dart';
import '../../features/auth/view/auth_routes.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/signup_screen.dart';
import '../../features/explore/view/explore_screen.dart';
import '../../features/gamification_journal/controller/badge_controller.dart';
import '../../features/gamification_journal/controller/checkin_controller.dart';
import '../../features/gamification_journal/controller/journal_controller.dart';
import '../../features/gamification_journal/controller/quiz_controller.dart';
import '../../features/gamification_journal/view/badges/badge_gallery_screen.dart';
import '../../features/gamification_journal/view/checkin/checkin_history_screen.dart';
import '../../features/gamification_journal/view/journal/journal_timeline_screen.dart';
import '../../features/gamification_journal/view/quiz/quiz_list_screen.dart';
import '../../features/itinerary_planning/view/day_trip_screen.dart';
import '../../features/itinerary_planning/view/itinerary_routes.dart';
import '../../features/itinerary_planning/view/plan_route_screen.dart';
import '../../features/itinerary_planning/view/route_optimized_screen.dart';
import '../../features/assistant/model/assistant_feed_item.dart';
import '../../features/destination_exploration/view/comparison_routes.dart';
import '../../features/destination_exploration/view/comparison_screen.dart';
import '../../features/destination_exploration/view/destination_map_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/recommendations/view/recommendations_routes.dart';
import '../../features/recommendations/view/score_detail_screen.dart';
import '../../features/recommendations/view/travel_pulse_screen.dart';
import '../../features/recommendations/view/travel_style_screen.dart';
import '../../features/saved/view/saved_screen.dart';
import '../../features/travel_prep/view/travel_prep_screens.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'shell_routes.dart';

/// The bottom-nav branches, in on-screen order: Map | Explore | Assistant |
/// Saved | Travel Prep | Journal | Profile. The Journal tab shows the
/// entries timeline directly; its satellite screens (badges, quizzes,
/// check-in history) are pushed routes reached via the More menu instead
/// of living on the tab itself.
const _assistantTabIndex = 2;

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = AuthRepository();

  return GoRouter(
    initialLocation: ShellRoutes.assistant,
    // Auth-gates the whole app: signed-out users are bounced to /login;
    // signed-in users land on the Assistant tab if they try to visit
    // /login or /signup.
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    redirect: (context, state) {
      final loggedIn = authRepository.isLoggedIn;
      final onAuthScreen =
          state.matchedLocation == AuthRoutes.login ||
          state.matchedLocation == AuthRoutes.signup;

      if (!loggedIn && !onAuthScreen) return AuthRoutes.login;
      if (loggedIn && onAuthScreen) return ShellRoutes.assistant;
      return null;
    },
    routes: [
      GoRoute(
        path: AuthRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AuthRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      // Full-screen flows that intentionally hide the bottom nav — they
      // live outside the shell below.
      GoRoute(
        path: ItineraryRoutes.planRoute,
        builder: (context, state) => const PlanRouteScreen(),
      ),
      GoRoute(
        path: ItineraryRoutes.routeOptimized,
        builder: (context, state) => const RouteOptimizedScreen(),
      ),
      GoRoute(
        path: ItineraryRoutes.dayTrip,
        builder: (context, state) => const DayTripScreen(),
      ),
      GoRoute(
        path: RecommendationsRoutes.travelStyle,
        builder: (context, state) => const TravelStyleScreen(),
      ),
      GoRoute(
        path: RecommendationsRoutes.travelPulse,
        builder: (context, state) => const TravelPulseScreen(),
      ),
      GoRoute(
        path: RecommendationsRoutes.scoreDetail,
        builder: (context, state) =>
            ScoreDetailScreen(item: state.extra as AssistantFeedItem),
      ),
      GoRoute(
        path: ComparisonRoutes.compare,
        builder: (context, state) =>
            ComparisonScreen(destinationIds: state.extra as List<String>),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.map,
                builder: (context, state) => const DestinationMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.assistant,
                builder: (context, state) => const AssistantScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.travelPrep,
                builder: (context, state) => const TravelPrepDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'checklist',
                    builder: (context, state) => const ReadyToWanderScreen(),
                  ),
                  GoRoute(
                    path: 'eco-partners',
                    builder: (context, state) => const EcoPartnersScreen(),
                  ),
                  GoRoute(
                    path: 'document-vault',
                    builder: (context, state) => const DocumentVaultScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.journal,
                builder: (context, state) => const JournalTimelineScreen(),
                routes: [
                  GoRoute(
                    path: 'badges',
                    builder: (context, state) => const BadgeGalleryScreen(),
                  ),
                  GoRoute(
                    path: 'quizzes',
                    builder: (context, state) => const QuizListScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const CheckInHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges a [Stream] (Supabase's auth state changes) into a
/// [Listenable] so go_router's `redirect` re-evaluates whenever the user
/// logs in or out, instead of only on navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Scaffold shared by the bottom-nav tabs: swaps [navigationShell]'s
/// current branch and shows the flat bottom nav bar — the
/// itinerary-planning flow and auth screens are pushed outside this shell
/// so they hide the bottom nav.
///
/// Also owns the Journal module's one-time initial data load (destinations,
/// check-in history, badge catalogue, journal entries, daily fact) — this
/// used to happen in DashboardScreen's initState, but Badges/Quizzes/
/// History are now reachable straight from the More menu on any tab
/// (not just Journal), so the load has to fire at app start instead of
/// waiting for a specific tab visit.
class _MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const _MainShell({required this.navigationShell});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      floatingActionButton: widget.navigationShell.currentIndex == _assistantTabIndex
          ? FloatingActionButton.extended(
              onPressed: () => context.push(ItineraryRoutes.planRoute),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Plan a Trip'),
            )
          : null,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTabSelected: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
      ),
    );
  }
}
