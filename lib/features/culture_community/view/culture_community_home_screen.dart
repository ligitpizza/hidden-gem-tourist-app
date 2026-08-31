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
  ConsumerState<CultureCommunityHomeScreen>
  createState() =>
      _CultureCommunityHomeScreenState();
}

class _CultureCommunityHomeScreenState
    extends ConsumerState<CultureCommunityHomeScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // EVENT SEARCH
  // =========================================================

  List<CulturalEvent> _filterEvents(
      List<CulturalEvent> events,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    final filtered = events.where((event) {
      if (query.isEmpty) {
        return true;
      }

      final searchableText = [
        event.name,
        event.description,
        event.category.label,
        event.venueName,
        event.address ?? '',
        event.city ?? '',
        event.state,
        ...event.travelStyles,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();

    // Show earlier events first.
    filtered.sort(
          (a, b) => a.startAt.compareTo(
        b.startAt,
      ),
    );

    return filtered;
  }

  // =========================================================
  // FOOD SEARCH
  // =========================================================

  List<TraditionalFood> _filterFoods(
      List<TraditionalFood> foods,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return foods;
    }

    return foods.where((food) {
      final searchableText = [
        food.name,
        food.description,
        food.culturalCategory,
        food.state,
        food.region ?? '',
        ...food.dietaryTags,
        ...food.ingredients,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  // =========================================================
  // QUICK SEARCH
  // =========================================================

  void _applyQuickSearch(
      String value,
      ) {
    _searchController.text = value;

    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final eventController = ref.watch(
      culturalEventsControllerProvider,
    );

    final foodController = ref.watch(
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
      // IMPORTANT:
      //
      // Culture is now a StatefulShellRoute branch.
      // We do not want a back button on the Culture Home page.
      //
      // The team's _MainShell will display the bottom nav.
      // =======================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Culture & Community',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            eventController.refresh(),
            foodController.refresh(),
          ]);
        },
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            40,
          ),
          children: [
            // =================================================
            // INTRODUCTION
            // =================================================

            Text(
              'Experience Local Malaysia',
              style: GoogleFonts.montserrat(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Discover cultural events, local communities and traditional Malaysian food.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // SEARCH
            // =================================================

            TextField(
              controller: _searchController,
              textInputAction:
              TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText:
                'Search festivals, culture or food...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon:
                _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                  tooltip:
                  'Clear search',
                  onPressed:
                  _clearSearch,
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // QUICK SEARCH CHIPS
            // =================================================

            SingleChildScrollView(
              scrollDirection:
              Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons
                          .festival_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      '#Festival',
                    ),
                    onPressed: () {
                      _applyQuickSearch(
                        'festival',
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  ActionChip(
                    avatar: const Icon(
                      Icons.place_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      '#Sarawak',
                    ),
                    onPressed: () {
                      _applyQuickSearch(
                        'sarawak',
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  ActionChip(
                    avatar: const Icon(
                      Icons
                          .restaurant_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      '#LocalFood',
                    ),
                    onPressed: () {
                      _applyQuickSearch(
                        'food',
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  ActionChip(
                    avatar: const Icon(
                      Icons
                          .account_balance_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      '#Culture',
                    ),
                    onPressed: () {
                      _applyQuickSearch(
                        'culture',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 34),

            // =================================================
            // CULTURAL EVENTS HEADER
            // =================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Cultural Events',
                        style: GoogleFonts
                            .montserrat(
                          fontSize: 22,
                          fontWeight:
                          FontWeight
                              .w700,
                          color:
                          Theme.of(
                            context,
                          )
                              .colorScheme
                              .primary,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Discover cultural experiences across Malaysia',
                        style:
                        GoogleFonts.inter(
                          fontSize: 12,
                          color:
                          Theme.of(
                            context,
                          )
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =================================================
            // VIEW ALL EVENTS + VIEW MAP
            // =================================================

            Row(
              children: [
                Expanded(
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
                          .format_list_bulleted_rounded,
                    ),
                    label: const Text(
                      'View All Events',
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      context.push(
                        CultureCommunityRoutes
                            .eventMap,
                      );
                    },
                    icon: const Icon(
                      Icons.map_outlined,
                    ),
                    label: const Text(
                      'View Map',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // =================================================
            // EVENT LOADING
            // =================================================

            if (eventController.isLoading &&
                eventController.events.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              )

            // =================================================
            // EVENT ERROR
            // =================================================

            else if (eventController
                .errorMessage !=
                null &&
                eventController.events.isEmpty)
              _HomeErrorState(
                message: eventController
                    .errorMessage!,
                onRetry:
                eventController.refresh,
              )

            // =================================================
            // NO EVENT
            // =================================================

            else if (events.isEmpty)
                _NoEventState(
                  searching:
                  _searchQuery
                      .trim()
                      .isNotEmpty,
                )

              // =================================================
              // EVENTS EXIST
              // =================================================

              else ...[
                  // ===============================================
                  // MINI MAP
                  // ===============================================

                  _HomeMiniMap(
                    events:
                    events.take(6).toList(),
                    onMarkerTap: (event) {
                      context.push(
                        CultureCommunityRoutes
                            .eventDetail,
                        extra: event,
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ===============================================
                  // LEGEND
                  // ===============================================

                  const _EventLegend(),

                  const SizedBox(height: 22),

                  // ===============================================
                  // EVENT PREVIEW TITLE
                  // ===============================================

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _searchQuery
                              .trim()
                              .isEmpty
                              ? 'Upcoming Events'
                              : 'Event Results',
                          style: GoogleFonts
                              .montserrat(
                            fontSize: 18,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ),

                      Text(
                        '${events.length} found',
                        style:
                        GoogleFonts.inter(
                          fontSize: 12,
                          color:
                          Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ===============================================
                  // HORIZONTAL EVENT CARDS
                  // ===============================================

                  SizedBox(
                    height: 305,
                    child:
                    ListView.separated(
                      scrollDirection:
                      Axis.horizontal,

                      itemCount:
                      events.length > 5
                          ? 5
                          : events.length,

                      separatorBuilder:
                          (_, __) =>
                      const SizedBox(
                        width: 14,
                      ),

                      itemBuilder:
                          (context, index) {
                        final event =
                        events[index];

                        return SizedBox(
                          width: 270,
                          child:
                          _HomeEventCard(
                            event: event,

                            // =====================================
                            // CLICK ANYWHERE ON EVENT CARD
                            // → EVENT DETAILS PAGE
                            // =====================================

                            onTap: () {
                              context.push(
                                CultureCommunityRoutes
                                    .eventDetail,
                                extra: event,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Show another View All link after cards.
                  if (events.length > 1) ...[
                    const SizedBox(height: 8),

                    Align(
                      alignment:
                      Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          context.push(
                            CultureCommunityRoutes
                                .events,
                          );
                        },
                        label: const Text(
                          'View All Events',
                        ),
                        icon: const Icon(
                          Icons
                              .arrow_forward_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],

            const SizedBox(height: 32),

            // =================================================
            // TRADITIONAL FOOD HEADER
            // =================================================

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Traditional Food Guide',
                        style: GoogleFonts
                            .montserrat(
                          fontSize: 22,
                          fontWeight:
                          FontWeight
                              .w700,
                          color:
                          Theme.of(
                            context,
                          )
                              .colorScheme
                              .primary,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Discover Malaysia through its traditional flavours',
                        style:
                        GoogleFonts.inter(
                          fontSize: 12,
                          color:
                          Theme.of(
                            context,
                          )
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                TextButton(
                  onPressed: () {
                    context.push(
                      CultureCommunityRoutes
                          .food,
                    );
                  },
                  child: const Text(
                    'See All',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =================================================
            // FOOD LOADING
            // =================================================

            if (foodController.isLoading &&
                foodController.foods.isEmpty)
              const Padding(
                padding:
                EdgeInsets.all(30),
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              )

            // =================================================
            // FOOD ERROR
            // =================================================

            else if (foodController
                .errorMessage !=
                null &&
                foodController.foods.isEmpty)
              _HomeErrorState(
                message: foodController
                    .errorMessage!,
                onRetry:
                foodController.refresh,
              )

            // =================================================
            // NO FOOD
            // =================================================

            else if (foods.isEmpty)
                Padding(
                  padding:
                  const EdgeInsets.all(
                    24,
                  ),
                  child: Center(
                    child: Text(
                      _searchQuery
                          .trim()
                          .isEmpty
                          ? 'No traditional food available.'
                          : 'No traditional food matches your search.',
                      textAlign:
                      TextAlign.center,
                    ),
                  ),
                )

              // =================================================
              // FOOD PREVIEW
              // =================================================

              else
                for (final food
                in foods.take(3)) ...[
                  _FoodPreviewCard(
                    food: food,
                    onTap: () {
                      context.push(
                        CultureCommunityRoutes
                            .food,
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// HOME MINI MAP
// ===========================================================

class _HomeMiniMap extends StatelessWidget {
  const _HomeMiniMap({
    required this.events,
    required this.onMarkerTap,
  });

  final List<CulturalEvent> events;

  final ValueChanged<CulturalEvent>
  onMarkerTap;

  LatLng get _mapCenter {
    if (events.isEmpty) {
      return const LatLng(
        4.2105,
        101.9758,
      );
    }

    double totalLatitude = 0;
    double totalLongitude = 0;

    for (final event in events) {
      totalLatitude +=
          event.latitude;

      totalLongitude +=
          event.longitude;
    }

    return LatLng(
      totalLatitude / events.length,
      totalLongitude / events.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 5.4,
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
                      width: 46,
                      height: 46,
                      child:
                      GestureDetector(
                        onTap: () {
                          onMarkerTap(
                            event,
                          );
                        },
                        child:
                        _MiniEventMarker(
                          event: event,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // OSM attribution
          Positioned(
            left: 5,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                padding:
                const EdgeInsets
                    .symmetric(
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
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// MINI EVENT MARKER
// ===========================================================

class _MiniEventMarker extends StatelessWidget {
  const _MiniEventMarker({
    required this.event,
  });

  final CulturalEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
        _categoryColor(
          event.category,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _categoryIcon(
          event.category,
        ),
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

// ===========================================================
// EVENT LEGEND
// ===========================================================

class _EventLegend extends StatelessWidget {
  const _EventLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(
          color: Color(0xFF1B4332),
          label: 'Festival',
        ),
        _LegendItem(
          color: Color(0xFFD1A51E),
          label: 'Cultural Show',
        ),
        _LegendItem(
          color: Color(0xFF6B5435),
          label: 'Community Activity',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 5),

        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color:
            Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// HOME EVENT CARD
// ===========================================================

class _HomeEventCard extends StatelessWidget {
  const _HomeEventCard({
    required this.event,
    required this.onTap,
  });

  final CulturalEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius:
      BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color:
              colors.outlineVariant,
            ),
          ),
          clipBehavior:
          Clip.antiAlias,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // ===============================================
              // EVENT IMAGE
              // ===============================================

              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _EventPreviewImage(
                      event: event,
                    ),

                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          _categoryColor(
                            event.category,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            999,
                          ),
                        ),
                        child: Row(
                          mainAxisSize:
                          MainAxisSize
                              .min,
                          children: [
                            Icon(
                              _categoryIcon(
                                event
                                    .category,
                              ),
                              size: 13,
                              color:
                              Colors.white,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              event.category
                                  .label,
                              style:
                              GoogleFonts
                                  .inter(
                                color:
                                Colors.white,
                                fontSize:
                                10,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ===============================================
              // EVENT INFORMATION
              // ===============================================

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        event.name,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: GoogleFonts
                            .montserrat(
                          fontSize: 16,
                          fontWeight:
                          FontWeight
                              .w700,
                          color:
                          colors.primary,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      _SmallInfoRow(
                        icon: Icons
                            .calendar_today_outlined,
                        text:
                        _formatEventDateRange(
                          event.startAt,
                          event.endAt,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      _SmallInfoRow(
                        icon: Icons
                            .location_on_outlined,
                        text:
                        event.city !=
                            null &&
                            event.city!
                                .trim()
                                .isNotEmpty
                            ? '${event.city}, ${event.state}'
                            : event.state,
                      ),

                      const Spacer(),

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .end,
                        children: [
                          Text(
                            'View Details',
                            style:
                            GoogleFonts
                                .inter(
                              fontSize: 12,
                              fontWeight:
                              FontWeight
                                  .w700,
                              color: colors
                                  .primary,
                            ),
                          ),

                          const SizedBox(
                            width: 3,
                          ),

                          Icon(
                            Icons
                                .arrow_forward_rounded,
                            size: 16,
                            color:
                            colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
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
// EVENT PREVIEW IMAGE
// ===========================================================

class _EventPreviewImage extends StatelessWidget {
  const _EventPreviewImage({
    required this.event,
  });

  final CulturalEvent event;

  @override
  Widget build(BuildContext context) {
    final url =
    event.imageUrl?.trim();

    if (url != null &&
        url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return _fallback(
            context,
          );
        },
      );
    }

    return _fallback(context);
  }

  Widget _fallback(
      BuildContext context,
      ) {
    return Container(
      decoration:
      BoxDecoration(
        gradient: LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            _categoryColor(
              event.category,
            ).withValues(
              alpha: 0.85,
            ),
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        _categoryIcon(
          event.category,
        ),
        size: 50,
        color: Colors.white,
      ),
    );
  }
}

// ===========================================================
// SMALL INFORMATION ROW
// ===========================================================

class _SmallInfoRow extends StatelessWidget {
  const _SmallInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color:
          Theme.of(context)
              .colorScheme
              .onSurfaceVariant,
        ),

        const SizedBox(width: 5),

        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color:
              Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// FOOD PREVIEW CARD
// ===========================================================

class _FoodPreviewCard extends StatelessWidget {
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

    return Material(
      color:
      colors.surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(16),
        child: Container(
          height: 135,
          decoration:
          BoxDecoration(
            border: Border.all(
              color:
              colors.outlineVariant,
            ),
            borderRadius:
            BorderRadius.circular(
              16,
            ),
          ),
          clipBehavior:
          Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 115,
                height:
                double.infinity,
                child: _FoodImage(
                  food: food,
                ),
              ),

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        food.name,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: GoogleFonts
                            .montserrat(
                          fontSize: 16,
                          fontWeight:
                          FontWeight
                              .w700,
                          color:
                          colors.primary,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Expanded(
                        child: Text(
                          food.description,
                          maxLines: 3,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          GoogleFonts
                              .inter(
                            fontSize: 12,
                            height: 1.35,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ),

                      Row(
                        children: [
                          Text(
                            food.state,
                            style:
                            GoogleFonts
                                .inter(
                              fontSize: 11,
                              fontWeight:
                              FontWeight
                                  .w600,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),

                          const Spacer(),

                          Text(
                            'Learn More',
                            style:
                            GoogleFonts
                                .inter(
                              fontSize: 11,
                              fontWeight:
                              FontWeight
                                  .w700,
                              color: colors
                                  .primary,
                            ),
                          ),

                          const SizedBox(
                            width: 3,
                          ),

                          Icon(
                            Icons
                                .arrow_forward_rounded,
                            size: 15,
                            color:
                            colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
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
// FOOD IMAGE
// ===========================================================

class _FoodImage extends StatelessWidget {
  const _FoodImage({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final url =
    food.imageUrl?.trim();

    if (url != null &&
        url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return _fallback(
            context,
          );
        },
      );
    }

    return _fallback(context);
  }

  Widget _fallback(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      color:
      colors.secondaryContainer,
      alignment:
      Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        size: 38,
        color: colors
            .onSecondaryContainer,
      ),
    );
  }
}

// ===========================================================
// ERROR STATE
// ===========================================================

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({
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
      const EdgeInsets.all(
        24,
      ),
      decoration: BoxDecoration(
        color:
        Theme.of(context)
            .colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign:
            TextAlign.center,
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: () {
              onRetry();
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'Try Again',
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// NO EVENT STATE
// ===========================================================

class _NoEventState extends StatelessWidget {
  const _NoEventState({
    required this.searching,
  });

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        28,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 44,
            color:
            Theme.of(context)
                .colorScheme
                .outline,
          ),

          const SizedBox(height: 10),

          Text(
            searching
                ? 'No cultural events match your search.'
                : 'No cultural events are available.',
            textAlign:
            TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// EVENT CATEGORY COLOR
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

// ===========================================================
// EVENT CATEGORY ICON
// ===========================================================

IconData _categoryIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons.festival_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons
          .theater_comedy_rounded;

    case CulturalEventCategory.communityActivity:
      return Icons.groups_rounded;
  }
}

// ===========================================================
// EVENT DATE FORMAT
// ===========================================================

String _formatEventDateRange(
    DateTime start,
    DateTime? end,
    ) {
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

  final startDate =
  start.toLocal();

  if (end == null) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  final endDate =
  end.toLocal();

  // Same day
  if (startDate.year ==
      endDate.year &&
      startDate.month ==
          endDate.month &&
      startDate.day ==
          endDate.day) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  // Same month
  if (startDate.year ==
      endDate.year &&
      startDate.month ==
          endDate.month) {
    return '${startDate.day}–${endDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  // Same year
  if (startDate.year ==
      endDate.year) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} – '
        '${endDate.day} '
        '${months[endDate.month - 1]} '
        '${startDate.year}';
  }

  // Different years
  return '${startDate.day} '
      '${months[startDate.month - 1]} '
      '${startDate.year} – '
      '${endDate.day} '
      '${months[endDate.month - 1]} '
      '${endDate.year}';
}