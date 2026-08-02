import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/assistant/view/assistant_screen.dart';
import '../../features/auth/model/auth_repository.dart';
import '../../features/auth/view/auth_routes.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/signup_screen.dart';
import '../../features/explore/view/explore_screen.dart';
import '../../features/itinerary_planning/view/day_trip_screen.dart';
import '../../features/itinerary_planning/view/itinerary_routes.dart';
import '../../features/itinerary_planning/view/plan_route_screen.dart';
import '../../features/itinerary_planning/view/route_optimized_screen.dart';
import '../../features/assistant/model/assistant_feed_item.dart';
import '../../features/map/view/map_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/recommendations/view/recommendations_routes.dart';
import '../../features/recommendations/view/score_detail_screen.dart';
import '../../features/recommendations/view/travel_pulse_screen.dart';
import '../../features/recommendations/view/travel_style_screen.dart';
import '../../features/saved/view/saved_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'shell_routes.dart';

/// The 5 bottom-nav branches, in on-screen order: Map | Explore | Assistant
/// | Saved | Profile (matches the team's mockups).
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
          state.matchedLocation == AuthRoutes.login || state.matchedLocation == AuthRoutes.signup;

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
        builder: (context, state) => ScoreDetailScreen(item: state.extra as AssistantFeedItem),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: ShellRoutes.map, builder: (context, state) => const MapScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: ShellRoutes.explore, builder: (context, state) => const ExploreScreen()),
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
            routes: [GoRoute(path: ShellRoutes.saved, builder: (context, state) => const SavedScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: ShellRoutes.profile, builder: (context, state) => const ProfileScreen()),
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

/// Scaffold shared by the 5 bottom-nav tabs: swaps [navigationShell]'s
/// current branch and shows the flat 5-tab bottom nav bar — the
/// itinerary-planning flow and auth screens are pushed outside this shell
/// so they hide the bottom nav.
class _MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _MainShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: navigationShell.currentIndex == _assistantTabIndex
          ? FloatingActionButton.extended(
              onPressed: () => context.push(ItineraryRoutes.planRoute),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Plan a Trip'),
            )
          : null,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTabSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
