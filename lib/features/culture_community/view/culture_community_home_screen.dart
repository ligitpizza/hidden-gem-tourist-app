import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../controller/cultural_events_controller.dart';
import '../controller/traditional_food_controller.dart';
import '../model/cultural_event.dart';
import '../model/traditional_food.dart';
import 'culture_community_routes.dart';

class CultureCommunityHomeScreen
    extends ConsumerStatefulWidget {
  const CultureCommunityHomeScreen({
    super.key,
  });

  @override
  ConsumerState<
      CultureCommunityHomeScreen>
  createState() =>
      _CultureCommunityHomeScreenState();
}

class _CultureCommunityHomeScreenState
    extends ConsumerState<
        CultureCommunityHomeScreen> {
  final TextEditingController
  _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // REFRESH BOTH EVENT + FOOD
  // =========================================================

  Future<void> _refresh() async {
    await Future.wait(
      [
        ref
            .read(
          culturalEventsControllerProvider,
        )
            .refresh(),

        ref
            .read(
          traditionalFoodControllerProvider,
        )
            .refresh(),
      ],
    );
  }

  // =========================================================
  // FILTER EVENTS
  // =========================================================

  List<CulturalEvent> _filterEvents(
      List<CulturalEvent> events,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return events;
    }

    return events.where(
          (event) {
        final searchable = [
          event.name,
          event.description,
          event.category.label,
          event.venueName,
          event.city ?? '',
          event.state,
          event.address ?? '',
          ...event.travelStyles,
        ].join(' ').toLowerCase();

        return searchable.contains(query);
      },
    ).toList();
  }

  // =========================================================
  // FILTER FOODS
  // =========================================================

  List<TraditionalFood> _filterFoods(
      List<TraditionalFood> foods,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return foods;
    }

    return foods.where(
          (food) {
        final searchable = [
          food.name,
          food.description,
          food.culturalHistory,
          food.state,
          food.region ?? '',
          food.culturalCategory,
          ...food.ingredients,
          ...food.dietaryTags,
          ...food.travelStyles,
        ].join(' ').toLowerCase();

        return searchable.contains(query);
      },
    ).toList();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final eventController =
    ref.watch(
      culturalEventsControllerProvider,
    );

    final foodController =
    ref.watch(
      traditionalFoodControllerProvider,
    );

    final events = _filterEvents(
      eventController.events,
    );

    final foods = _filterFoods(
      foodController.foods,
    );

    return Scaffold(
      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: Text(
          'Culture & Community',
          style:
          GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),

        actions: [
          // ===================================================
          // SAVED CULTURE BUTTON
          // ===================================================

          IconButton(
            tooltip: 'Saved Culture',
            onPressed: () {
              context.push(
                CultureCommunityRoutes.saved,
              );
            },
            icon: const Icon(
              Icons.bookmark_outline_rounded,
            ),
          ),
        ],
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            40,
          ),
          children: [
            // =================================================
            // INTRO
            // =================================================

            Text(
              'Discover Malaysia',
              style:
              GoogleFonts.montserrat(
                fontSize: 27,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Explore cultural events, local communities and traditional Malaysian food.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color:
                Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // SEARCH
            // =================================================

            TextField(
              controller:
              _searchController,

              onChanged: (
                  value,
                  ) {
                setState(() {
                  _searchQuery = value;
                });
              },

              decoration: InputDecoration(
                hintText:
                'Search events or food...',

                prefixIcon:
                const Icon(
                  Icons.search_rounded,
                ),

                suffixIcon:
                _searchQuery.isEmpty
                    ? null
                    : IconButton(
                  tooltip:
                  'Clear Search',
                  onPressed:
                      () {
                    _searchController
                        .clear();

                    setState(() {
                      _searchQuery =
                      '';
                    });
                  },
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
                  ),
                ),

                filled: true,

                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 26),

            // =================================================
            // QUICK ACCESS
            // =================================================

            Row(
              children: [
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons
                        .celebration_rounded,
                    title:
                    'Cultural Events',
                    subtitle:
                    'Festivals & activities',
                    onTap: () {
                      context.push(
                        CultureCommunityRoutes
                            .events,
                      );
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons
                        .restaurant_menu_rounded,
                    title:
                    'Traditional Food',
                    subtitle:
                    'Local flavours',
                    onTap: () {
                      context.push(
                        CultureCommunityRoutes
                            .food,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // =================================================
            // EVENT SECTION HEADER
            // =================================================

            _SectionHeader(
              title:
              'Cultural Events Near Me',
              subtitle:
              'Explore upcoming Malaysian cultural events',
              actionLabel:
              'View Map',
              onAction: () {
                context.push(
                  CultureCommunityRoutes
                      .eventMap,
                );
              },
            ),

            const SizedBox(height: 14),

            // =================================================
            // EVENT LOADING
            // =================================================

            if (eventController.isLoading &&
                eventController
                    .events.isEmpty)
              const Center(
                child:
                CircularProgressIndicator(),
              )

            // =================================================
            // EVENT ERROR
            // =================================================

            else if (eventController
                .errorMessage !=
                null &&
                eventController
                    .events.isEmpty)
              _ErrorCard(
                message:
                eventController
                    .errorMessage!,
                onRetry:
                eventController.refresh,
              )

            // =================================================
            // EVENT EMPTY
            // =================================================

            else if (events.isEmpty)
                const _EmptyCard(
                  icon:
                  Icons.event_busy_outlined,
                  message:
                  'No cultural events found.',
                )

              // =================================================
              // EVENT CONTENT
              // =================================================

              else ...[
                  _MiniEventMap(
                    events:
                    events.take(6).toList(),
                  ),

                  const SizedBox(height: 16),

                  for (final event
                  in events.take(3)) ...[
                    _EventPreviewCard(
                      event: event,
                      onTap: () {
                        context.push(
                          CultureCommunityRoutes
                              .eventDetail,
                          extra: event,
                        );
                      },
                    ),

                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child:
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push(
                          CultureCommunityRoutes
                              .events,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .calendar_month_outlined,
                      ),
                      label: const Text(
                        'View All Events',
                      ),
                    ),
                  ),
                ],

            const SizedBox(height: 34),

            // =================================================
            // FOOD HEADER
            // =================================================

            _SectionHeader(
              title:
              'Traditional Food Guide',
              subtitle:
              'Discover Malaysian dishes and their cultural stories',
              actionLabel:
              'See All',
              onAction: () {
                context.push(
                  CultureCommunityRoutes
                      .food,
                );
              },
            ),

            const SizedBox(height: 14),

            // =================================================
            // FOOD LOADING
            // =================================================

            if (foodController.isLoading &&
                foodController
                    .foods.isEmpty)
              const Center(
                child:
                CircularProgressIndicator(),
              )

            // =================================================
            // FOOD ERROR
            // =================================================

            else if (foodController
                .errorMessage !=
                null &&
                foodController
                    .foods.isEmpty)
              _ErrorCard(
                message:
                foodController
                    .errorMessage!,
                onRetry:
                foodController.refresh,
              )

            // =================================================
            // FOOD EMPTY
            // =================================================

            else if (foods.isEmpty)
                const _EmptyCard(
                  icon:
                  Icons.no_food_outlined,
                  message:
                  'No traditional foods found.',
                )

              // =================================================
              // FOOD CONTENT
              // =================================================

              else ...[
                  for (final food
                  in foods.take(4)) ...[
                    _FoodPreviewCard(
                      food: food,
                      onTap: () {
                        context.push(
                          CultureCommunityRoutes
                              .foodDetail,
                          extra: food,
                        );
                      },
                    ),

                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child:
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push(
                          CultureCommunityRoutes
                              .food,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .restaurant_menu_rounded,
                      ),
                      label: const Text(
                        'Explore Traditional Food',
                      ),
                    ),
                  ),
                ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// QUICK ACCESS
// ===========================================================

class _QuickAccessCard
    extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color:
      colors.surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(18),
        child: Padding(
          padding:
          const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                  colors.primaryContainer,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: colors
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                style:
                GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colors
                      .onSurfaceVariant,
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
// SECTION HEADER
// ===========================================================

class _SectionHeader
    extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color:
                  Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// MINI EVENT MAP
// ===========================================================

class _MiniEventMap
    extends StatelessWidget {
  const _MiniEventMap({
    required this.events,
  });

  final List<CulturalEvent> events;

  @override
  Widget build(BuildContext context) {
    final center =
    _averageCenter(events);

    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom:
              events.length == 1
                  ? 12
                  : 5.5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                'com.collab.app',
              ),

              MarkerLayer(
                markers: [
                  for (final event
                  in events)
                    Marker(
                      point: LatLng(
                        event.latitude,
                        event.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                          _categoryColor(
                            event.category,
                          ),
                          shape:
                          BoxShape.circle,
                          border: Border.all(
                            color:
                            Colors.white,
                            width: 2.5,
                          ),
                        ),
                        child: Icon(
                          _categoryIcon(
                            event.category,
                          ),
                          size: 18,
                          color:
                          Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            left: 5,
            bottom: 4,
            child: Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .surface
                  .withValues(
                alpha: 0.85,
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _averageCenter(
      List<CulturalEvent> events,
      ) {
    var latitude = 0.0;
    var longitude = 0.0;

    for (final event in events) {
      latitude += event.latitude;
      longitude += event.longitude;
    }

    return LatLng(
      latitude / events.length,
      longitude / events.length,
    );
  }
}

// ===========================================================
// EVENT PREVIEW
// ===========================================================

class _EventPreviewCard
    extends StatelessWidget {
  const _EventPreviewCard({
    required this.event,
    required this.onTap,
  });

  final CulturalEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                _categoryColor(
                  event.category,
                ),
                child: Icon(
                  _categoryIcon(
                    event.category,
                  ),
                  color:
                  Colors.white,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      GoogleFonts.inter(
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
                        fontSize: 10,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      [
                        if (event.city !=
                            null &&
                            event.city!
                                .trim()
                                .isNotEmpty)
                          event.city!,
                        event.state,
                      ].join(', '),
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

              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// FOOD PREVIEW
// ===========================================================

class _FoodPreviewCard
    extends StatelessWidget {
  const _FoodPreviewCard({
    required this.food,
    required this.onTap,
  });

  final TraditionalFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 115,
          child: Row(
            children: [
              SizedBox(
                width: 115,
                height: 115,
                child:
                _FoodThumbnail(
                  food: food,
                ),
              ),

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                    children: [
                      Text(
                        food.name,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        food.description,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        GoogleFonts.inter(
                          fontSize: 10,
                          height: 1.35,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      Row(
                        children: [
                          Icon(
                            Icons
                                .location_on_outlined,
                            size: 14,
                            color:
                            colors.primary,
                          ),

                          const SizedBox(
                            width: 3,
                          ),

                          Expanded(
                            child: Text(
                              food.state,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              GoogleFonts
                                  .inter(
                                fontSize:
                                10,
                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding:
                EdgeInsets.only(
                  right: 8,
                ),
                child: Icon(
                  Icons
                      .chevron_right_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodThumbnail
    extends StatelessWidget {
  const _FoodThumbnail({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
    food.imageUrl?.trim();

    if (imageUrl == null ||
        imageUrl.isEmpty) {
      return Container(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer,
        child: Icon(
          Icons.restaurant_rounded,
          size: 40,
          color: Theme.of(context)
              .colorScheme
              .onSecondaryContainer,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (
          context,
          error,
          stackTrace,
          ) {
        return Container(
          color: Theme.of(context)
              .colorScheme
              .secondaryContainer,
          child: Icon(
            Icons.restaurant_rounded,
            color: Theme.of(context)
                .colorScheme
                .onSecondaryContainer,
          ),
        );
      },
    );
  }
}

// ===========================================================
// EMPTY
// ===========================================================

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color:
            Theme.of(context)
                .colorScheme
                .outline,
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// ERROR
// ===========================================================

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function()
  onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          OutlinedButton(
            onPressed: () {
              onRetry();
            },
            child:
            const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// EVENT HELPERS
// ===========================================================

Color _categoryColor(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return const Color(
        0xFF1B4332,
      );

    case CulturalEventCategory.culturalShow:
      return const Color(
        0xFFD1A51E,
      );

    case CulturalEventCategory.communityActivity:
      return const Color(
        0xFF6B5435,
      );
  }
}

IconData _categoryIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons.festival_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons.theater_comedy_rounded;

    case CulturalEventCategory.communityActivity:
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
    return _formatDate(start);
  }

  final sameDay =
      start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;

  if (sameDay) {
    return _formatDate(start);
  }

  return '${_formatDate(start)} - '
      '${_formatDate(end)}';
}