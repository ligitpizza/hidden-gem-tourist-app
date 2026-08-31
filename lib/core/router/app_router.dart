import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// provider's own Provider class collides with Riverpod's Provider<T> (used
// below for appRouterProvider) — hide it, this file only needs provider's
// context.read/context.watch extensions for the initial data load.
import 'package:provider/provider.dart' hide Provider;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/model/auth_repository.dart';
import '../../features/auth/view/auth_routes.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/signup_screen.dart';
import '../../features/culture_community/view/culture_community_home_screen.dart';
import '../../features/culture_community/view/culture_community_routes.dart';
import '../../features/culture_community/view/cultural_events_home_screen.dart';
import '../../features/culture_community/view/cultural_events_map_screen.dart';
import '../../features/culture_community/model/cultural_event.dart';
import '../../features/culture_community/view/cultural_event_detail_screen.dart';
import '../../features/culture_community/view/traditional_food_home_screen.dart';
import '../../features/culture_community/model/traditional_food.dart';
import '../../features/culture_community/view/traditional_food_detail_screen.dart';
import '../../features/culture_community/view/traditional_food_nearby_screen.dart';
import '../../features/explore/view/explore_screen.dart';
import '../../features/gamification_journal/controller/badge_controller.dart';
import '../../features/gamification_journal/controller/checkin_controller.dart';
import '../../features/gamification_journal/controller/friend_controller.dart';
import '../../features/gamification_journal/controller/journal_controller.dart';
import '../../features/gamification_journal/controller/quiz_controller.dart';
import '../../features/gamification_journal/view/badges/badge_gallery_screen.dart';
import '../../features/gamification_journal/view/checkin/checkin_history_screen.dart';
import '../../features/gamification_journal/view/friends/friends_list_screen.dart';
import '../../features/gamification_journal/view/journal/journal_timeline_screen.dart';
import '../../features/gamification_journal/view/quiz/quiz_list_screen.dart';
import '../../features/hidden_gem_recommendation/model/hidden_gem_feed_item.dart';
import '../../features/hidden_gem_recommendation/model/preference_onboarding_gate.dart';
import '../../features/hidden_gem_recommendation/view/discovery_feed_screen.dart';
import '../../features/hidden_gem_recommendation/view/hidden_gem_list_screen.dart';
import '../../features/hidden_gem_recommendation/view/hidden_gem_recommendation_routes.dart';
import '../../features/hidden_gem_recommendation/view/hidden_gem_search_screen.dart';
import '../../features/hidden_gem_recommendation/view/preference_setup_screen.dart';
import '../../features/hidden_gem_recommendation/view/score_detail_screen.dart';
import '../../features/hidden_gem_recommendation/view/travel_pulse_screen.dart';
import '../../features/hidden_gem_recommendation/view/trending_screen.dart';
import '../../features/itinerary_planning/view/day_trip_screen.dart';
import '../../features/itinerary_planning/view/itinerary_routes.dart';
import '../../features/itinerary_planning/view/plan_route_screen.dart';
import '../../features/itinerary_planning/view/route_optimized_screen.dart';
import '../../features/destination_exploration/view/comparison_routes.dart';
import '../../features/destination_exploration/view/comparison_screen.dart';
import '../../features/destination_exploration/view/destination_map_screen.dart';
import '../../features/profile/view/profile_screen.dart';
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

/// One Navigator key per shell branch, in the same order as the branches
/// list below — lets _MainShell reach directly into a branch's own
/// Navigator and pop it back to root when its tab is re-tapped, instead of
/// relying only on goBranch's initialLocation flag (which wasn't reliably
/// clearing a pushed destination-detail screen on the Map tab).
final _branchNavigatorKeys = List.generate(8, (_) => GlobalKey<NavigatorState>());

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = AuthRepository();
  // read, not watch: this Provider must build the GoRouter exactly once
  // for the app's lifetime — the gate's own notifyListeners (merged into
  // refreshListenable below) is what makes redirect() re-run, not a
  // Riverpod rebuild recreating the whole router.
  final onboardingGate = ref.read(preferenceOnboardingGateProvider);

  return GoRouter(
    initialLocation: ShellRoutes.assistant,
    // Auth-gates the whole app: signed-out users are bounced to /login;
    // signed-in users land on the Assistant tab if they try to visit
    // /login or /signup. Signed-in tourists with no saved travel
    // preference profile yet are further bounced to the mandatory
    // Define Your Travel Style screen (Module 1) before reaching the
    // shell — mirrors the "Preference Selection And Preference Update"
    // activity diagram's "Display Preference Selection Screen (Mandatory
    // on first launch)".
    refreshListenable: Listenable.merge([
      GoRouterRefreshStream(authRepository.authStateChanges),
      onboardingGate,
    ]),
    redirect: (context, state) {
      final loggedIn = authRepository.isLoggedIn;
      final onAuthScreen =
          state.matchedLocation == AuthRoutes.login ||
          state.matchedLocation == AuthRoutes.signup;

      if (!loggedIn && !onAuthScreen) return AuthRoutes.login;
      if (loggedIn && onAuthScreen) return ShellRoutes.assistant;

      if (loggedIn) {
        // Fire-and-forget: go_router's redirect must answer synchronously,
        // so this kicks off the (cached-after-first-check) Supabase read
        // and the merged Listenable above re-runs redirect once it
        // resolves and calls notifyListeners.
        unawaited(onboardingGate.refresh());
        final onSetupScreen =
            state.matchedLocation == HiddenGemRecommendationRoutes.preferenceSetup;
        if (onboardingGate.needsSetup && !onSetupScreen) {
          return HiddenGemRecommendationRoutes.preferenceSetup;
        }
      }
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
        path: HiddenGemRecommendationRoutes.preferenceSetup,
        builder: (context, state) => const PreferenceSetupScreen(mandatory: true),
      ),
      GoRoute(
        path: HiddenGemRecommendationRoutes.travelStyle,
        builder: (context, state) => const PreferenceSetupScreen(),
      ),
      GoRoute(
        path: HiddenGemRecommendationRoutes.travelPulse,
        builder: (context, state) => const TravelPulseScreen(),
      ),
      GoRoute(
        path: HiddenGemRecommendationRoutes.trending,
        builder: (context, state) => const TrendingScreen(),
      ),
      GoRoute(
        path: HiddenGemRecommendationRoutes.search,
        builder: (context, state) => const HiddenGemSearchScreen(),
      ),
      GoRoute(
        path: HiddenGemRecommendationRoutes.topMatchesList,
        builder: (context, state) => HiddenGemListScreen(
          title: 'Your Top Matches',
          items: state.extra as List<HiddenGemFeedItem>,
        ),
      ),
      GoRoute(
        path: HiddenGemRecommendationRoutes.scoreDetail,
        builder: (context, state) =>
            ScoreDetailScreen(item: state.extra as HiddenGemFeedItem),
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
            navigatorKey: _branchNavigatorKeys[0],
            routes: [
              GoRoute(
                path: ShellRoutes.map,
                builder: (context, state) => const DestinationMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchNavigatorKeys[1],
            routes: [
              GoRoute(
                path: ShellRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchNavigatorKeys[2],
            routes: [
              GoRoute(
                path: ShellRoutes.assistant,
                builder: (context, state) => const DiscoveryFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchNavigatorKeys[3],
            routes: [
              GoRoute(
                path: ShellRoutes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchNavigatorKeys[4],
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
            navigatorKey: _branchNavigatorKeys[5],
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
                  GoRoute(
                    path: 'friends',
                    builder: (context, state) => const FriendsListScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchNavigatorKeys[6],
            routes: [
              GoRoute(
                path: ShellRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          // Local Culture & Community
          StatefulShellBranch(
            navigatorKey: _branchNavigatorKeys[7],
            routes: [
              GoRoute(
                path: ShellRoutes.culture,
                builder: (context, state) => const CultureCommunityHomeScreen(),
            routes: [
              GoRoute(
                path: CultureCommunityRoutes.eventsSegment,
                builder: (context, state) => const CulturalEventsHomeScreen(),
              ),

              GoRoute(
                path: CultureCommunityRoutes.foodSegment,
                builder: (context, state) => const TraditionalFoodHomeScreen(),
              ),

              GoRoute(
                path: CultureCommunityRoutes.eventMapSegment,
                builder: (context, state) => const CulturalEventsMapScreen(),
              ),

              GoRoute(
                path: CultureCommunityRoutes.eventDetailSegment,
                builder: (context, state) {
                  final event = state.extra as CulturalEvent;
                  return CulturalEventDetailScreen(
                    event: event,
                  );
                  },
              ),
              GoRoute(
                path:
                CultureCommunityRoutes
                    .foodDetailSegment,
                builder: (context, state) {
                  final food =
                  state.extra as TraditionalFood;

                  return TraditionalFoodDetailScreen(
                    food: food,
                  );
                },
              ),
              GoRoute(
                path: CultureCommunityRoutes.foodNearbySegment,
                builder: (context, state) {
                  final food =
                  state.extra as TraditionalFood;

                  return TraditionalFoodNearbyScreen(
                    food: food,
                  );
                },
              ),
  ],
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
    final friendController = context.read<FriendController>();

    await checkInController.loadDestinations();
    await checkInController.loadHistory();
    await badgeController.loadBadges();
    await journalController.loadEntries();
    await quizController.loadDailyFact();
    await quizController.loadHistory();
    // So the More menu's pending-request dot is already correct the first
    // time it's visible, not just after the Tourist opens Friends once.
    await friendController.loadFriends();
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
        onTabSelected: (index) {
          final reselectingCurrentTab = index == widget.navigationShell.currentIndex;
          // Belt-and-braces: goBranch's initialLocation flag is supposed to
          // reset a branch to its root on its own, but re-tapping Map while
          // a destination detail screen was pushed on top of it wasn't
          // reliably clearing that screen — so pop the branch's own
          // Navigator directly first, then let goBranch do its normal work.
          if (reselectingCurrentTab) {
            _branchNavigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
          } else if (widget.navigationShell.currentIndex == 5) {
            // Leaving the Journal tab for a different one resets any
            // screen pushed from the More menu (Badges/Quizzes/History/
            // Friends, and Friends' own nested search/profile-preview
            // screens) — they're meant to be reached only via the More
            // menu, not to linger as "what Journal shows now" the next
            // time that tab becomes active again.
            _branchNavigatorKeys[5].currentState?.popUntil((route) => route.isFirst);
          }
          widget.navigationShell.goBranch(index, initialLocation: reselectingCurrentTab);
        },
      ),
    );
  }
}
