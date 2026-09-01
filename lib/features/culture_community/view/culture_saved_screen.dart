import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controller/culture_saved_controller.dart';
import '../model/cultural_event.dart';
import '../model/traditional_food.dart';
import '../model/traditional_food_place.dart';
import 'culture_community_routes.dart';
import 'google_maps_navigation.dart';

class CultureSavedScreen
    extends ConsumerWidget {
  const CultureSavedScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final controller = ref.watch(
      cultureSavedControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Culture',
          style:
          GoogleFonts.montserrat(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(
        context,
        controller,
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      CultureSavedController controller,
      ) {
    // =======================================================
    // LOADING
    // =======================================================

    if (controller.isLoading &&
        controller.favouriteEvents.isEmpty &&
        controller.favouriteFoods.isEmpty &&
        controller.favouritePlaces.isEmpty) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    // =======================================================
    // NOT SIGNED IN
    // =======================================================

    if (!controller.isSignedIn) {
      return const _EmptyState(
        icon:
        Icons.lock_outline_rounded,
        title:
        'Sign In Required',
        message:
        'Please sign in to view your saved cultural events, traditional foods and restaurants.',
      );
    }

    // =======================================================
    // ERROR
    // =======================================================

    if (controller.errorMessage != null &&
        controller.favouriteEvents.isEmpty &&
        controller.favouriteFoods.isEmpty &&
        controller.favouritePlaces.isEmpty) {
      return _ErrorState(
        message:
        controller.errorMessage!,
        onRetry:
        controller.refresh,
      );
    }

    // =======================================================
    // EMPTY
    // =======================================================

    if (controller.favouriteEvents.isEmpty &&
        controller.favouriteFoods.isEmpty &&
        controller.favouritePlaces.isEmpty) {
      return const _EmptyState(
        icon:
        Icons.bookmark_border_rounded,
        title:
        'Nothing Saved Yet',
        message:
        'Save cultural events, traditional foods or restaurants and they will appear here.',
      );
    }

    // =======================================================
    // CONTENT
    // =======================================================

    return RefreshIndicator(
      onRefresh:
      controller.refresh,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(16),
        children: [
          // =================================================
          // EVENTS
          // =================================================

          if (controller
              .favouriteEvents
              .isNotEmpty) ...[
            _SectionHeader(
              icon:
              Icons.celebration_outlined,
              title:
              'Cultural Events',
              count: controller
                  .favouriteEvents.length,
            ),

            const SizedBox(height: 10),

            for (final event
            in controller
                .favouriteEvents) ...[
              _SavedEventCard(
                event: event,

                onOpen: () async {
                  await context.push(
                    CultureCommunityRoutes
                        .eventDetail,
                    extra: event,
                  );

                  await controller
                      .refresh();
                },

                onRemove: () async {
                  final success =
                  await controller
                      .removeEventFavourite(
                    event.id,
                  );

                  if (!context.mounted) {
                    return;
                  }

                  _showResult(
                    context,
                    success: success,
                    successMessage:
                    '${event.name} removed from saved.',
                    errorMessage:
                    controller.errorMessage ??
                        'Could not remove saved event.',
                  );
                },
              ),

              const SizedBox(height: 9),
            ],
          ],

          // =================================================
          // FOODS
          // =================================================

          if (controller
              .favouriteFoods
              .isNotEmpty) ...[
            if (controller
                .favouriteEvents
                .isNotEmpty)
              const SizedBox(
                height: 25,
              ),

            _SectionHeader(
              icon:
              Icons.restaurant_menu_rounded,
              title:
              'Traditional Foods',
              count: controller
                  .favouriteFoods.length,
            ),

            const SizedBox(height: 10),

            for (final food
            in controller
                .favouriteFoods) ...[
              _SavedFoodCard(
                food: food,

                onOpen: () async {
                  await context.push(
                    CultureCommunityRoutes
                        .foodDetail,
                    extra: food,
                  );

                  await controller
                      .refresh();
                },

                onRemove: () async {
                  final success =
                  await controller
                      .removeFoodFavourite(
                    food.id,
                  );

                  if (!context.mounted) {
                    return;
                  }

                  _showResult(
                    context,
                    success: success,
                    successMessage:
                    '${food.name} removed from saved.',
                    errorMessage:
                    controller.errorMessage ??
                        'Could not remove saved food.',
                  );
                },
              ),

              const SizedBox(height: 9),
            ],
          ],

          // =================================================
          // RESTAURANTS
          // =================================================

          if (controller
              .favouritePlaces
              .isNotEmpty) ...[
            if (controller
                .favouriteEvents
                .isNotEmpty ||
                controller
                    .favouriteFoods
                    .isNotEmpty)
              const SizedBox(
                height: 25,
              ),

            _SectionHeader(
              icon:
              Icons.storefront_outlined,
              title:
              'Saved Restaurants',
              count: controller
                  .favouritePlaces.length,
            ),

            const SizedBox(height: 10),

            for (final place
            in controller
                .favouritePlaces) ...[
              _SavedPlaceCard(
                place: place,

                onNavigate: () async {
                  await openGoogleMapsNavigation(
                    context: context,
                    latitude:
                    place.latitude,
                    longitude:
                    place.longitude,
                  );
                },

                onRemove: () async {
                  final success =
                  await controller
                      .removePlaceFavourite(
                    place.id,
                  );

                  if (!context.mounted) {
                    return;
                  }

                  _showResult(
                    context,
                    success: success,
                    successMessage:
                    '${place.name} removed from saved.',
                    errorMessage:
                    controller.errorMessage ??
                        'Could not remove saved restaurant.',
                  );
                },
              ),

              const SizedBox(height: 9),
            ],
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showResult(
      BuildContext context, {
        required bool success,
        required String successMessage,
        required String errorMessage,
      }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          success
              ? successMessage
              : errorMessage,
        ),
      ),
    );
  }
}

// ===========================================================
// EVENT CARD
// ===========================================================

class _SavedEventCard
    extends StatelessWidget {
  const _SavedEventCard({
    required this.event,
    required this.onOpen,
    required this.onRemove,
  });

  final CulturalEvent event;

  final VoidCallback onOpen;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding:
          const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                _eventCategoryColor(
                  event.category,
                ),
                child: Icon(
                  _eventCategoryIcon(
                    event.category,
                  ),
                  color:
                  Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style:
                      GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _formatEventDateRange(
                        event,
                      ),
                      style:
                      GoogleFonts.inter(
                        fontSize: 11,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _eventLocation(
                        event,
                      ),
                      style:
                      GoogleFonts.inter(
                        fontSize: 10,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip:
                'Remove from saved',
                onPressed:
                onRemove,
                icon: Icon(
                  Icons.bookmark_rounded,
                  color:
                  colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// FOOD CARD
// ===========================================================

class _SavedFoodCard
    extends StatelessWidget {
  const _SavedFoodCard({
    required this.food,
    required this.onOpen,
    required this.onRemove,
  });

  final TraditionalFood food;

  final VoidCallback onOpen;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding:
          const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                colors
                    .secondaryContainer,
                child: Icon(
                  Icons.restaurant_rounded,
                  color: colors
                      .onSecondaryContainer,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style:
                      GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      food.state,
                      style:
                      GoogleFonts.inter(
                        fontSize: 11,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      food.culturalCategory,
                      style:
                      GoogleFonts.inter(
                        fontSize: 10,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip:
                'Remove from saved',
                onPressed:
                onRemove,
                icon: Icon(
                  Icons.bookmark_rounded,
                  color:
                  colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// RESTAURANT CARD
// ===========================================================

class _SavedPlaceCard
    extends StatelessWidget {
  const _SavedPlaceCard({
    required this.place,
    required this.onNavigate,
    required this.onRemove,
  });

  final TraditionalFoodPlace place;

  final VoidCallback onNavigate;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  colors
                      .secondaryContainer,
                  child: Icon(
                    Icons
                        .restaurant_rounded,
                    color: colors
                        .onSecondaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        place.name,
                        style:
                        GoogleFonts.inter(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        _placeLocation(
                          place,
                        ),
                        style:
                        GoogleFonts.inter(
                          fontSize: 10,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip:
                  'Remove from saved',
                  onPressed:
                  onRemove,
                  icon: Icon(
                    Icons
                        .bookmark_rounded,
                    color:
                    colors.primary,
                  ),
                ),
              ],
            ),

            if (place.address != null &&
                place.address!
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 9),

              Text(
                place.address!,
                style:
                GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.4,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SmallTag(
                  text:
                  _displayValue(
                    place.category,
                  ),
                ),

                _SmallTag(
                  text:
                  _halalLabel(
                    place.halalStatus,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            SizedBox(
              width: double.infinity,
              child:
              OutlinedButton.icon(
                onPressed:
                onNavigate,
                icon: const Icon(
                  Icons.navigation_rounded,
                ),
                label: const Text(
                  'Navigate with Google Maps',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// SECTION HEADER
// ===========================================================

class _SectionHeader
    extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;

  final String title;

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          color:
          colors.primary,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            title,
            style:
            GoogleFonts.montserrat(
              fontSize: 17,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color:
            colors.secondaryContainer,
            borderRadius:
            BorderRadius.circular(
              999,
            ),
          ),
          child: Text(
            '$count',
            style:
            GoogleFonts.inter(
              fontSize: 10,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// EMPTY
// ===========================================================

class _EmptyState
    extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;

  final String title;

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 58,
              color:
              colors.outline,
            ),

            const SizedBox(height: 14),

            Text(
              title,
              textAlign:
              TextAlign.center,
              style:
              GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              message,
              textAlign:
              TextAlign.center,
              style:
              GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// ERROR
// ===========================================================

class _ErrorState
    extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;

  final Future<void> Function()
  onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 50,
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign:
              TextAlign.center,
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () {
                onRetry();
              },
              child:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// SMALL TAG
// ===========================================================

class _SmallTag
    extends StatelessWidget {
  const _SmallTag({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
      child: Text(
        text,
        style:
        GoogleFonts.inter(
          fontSize: 9,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }
}

// ===========================================================
// HELPERS
// ===========================================================

Color _eventCategoryColor(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return const Color(
        0xFFE67E22,
      );

    case CulturalEventCategory.culturalShow:
      return const Color(
        0xFF7B2CBF,
      );

    case CulturalEventCategory
        .communityActivity:
      return const Color(
        0xFF1B7F5C,
      );
  }
}

IconData _eventCategoryIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons
          .celebration_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons
          .theater_comedy_rounded;

    case CulturalEventCategory
        .communityActivity:
      return Icons.groups_rounded;
  }
}

String _formatDate(
    DateTime date,
    ) {
  final local =
  date.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${local.day} '
      '${months[local.month - 1]} '
      '${local.year}';
}

String _formatEventDateRange(
    CulturalEvent event,
    ) {
  final start =
  event.startAt.toLocal();

  final end =
  event.endAt?.toLocal();

  if (end == null) {
    return _formatDate(
      start,
    );
  }

  final sameDay =
      start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;

  if (sameDay) {
    return _formatDate(
      start,
    );
  }

  return '${_formatDate(start)} - '
      '${_formatDate(end)}';
}

String _eventLocation(
    CulturalEvent event,
    ) {
  return [
    if (event.city != null &&
        event.city!
            .trim()
            .isNotEmpty)
      event.city!,
    event.state,
  ].join(', ');
}

String _placeLocation(
    TraditionalFoodPlace place,
    ) {
  return [
    if (place.city != null &&
        place.city!
            .trim()
            .isNotEmpty)
      place.city!,
    place.state,
  ].join(', ');
}

String _halalLabel(
    String value,
    ) {
  switch (value) {
    case 'certified':
      return 'Halal Certified';

    case 'muslim_friendly':
      return 'Muslim-Friendly';

    case 'non_halal':
      return 'Non-Halal';

    default:
      return 'Status Unknown';
  }
}

String _displayValue(
    String value,
    ) {
  final normalized = value
      .replaceAll(
    '_',
    ' ',
  )
      .replaceAll(
    '-',
    ' ',
  )
      .trim();

  if (normalized.isEmpty) {
    return value;
  }

  return normalized
      .split(' ')
      .where(
        (word) =>
    word.isNotEmpty,
  )
      .map(
        (word) =>
    '${word[0].toUpperCase()}'
        '${word.substring(1)}',
  )
      .join(' ');
}