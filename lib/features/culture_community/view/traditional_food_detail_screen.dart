import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../controller/traditional_food_detail_controller.dart';
import '../model/traditional_food.dart';
import '../model/traditional_food_place.dart';
import 'culture_community_routes.dart';
import 'google_maps_navigation.dart';

class TraditionalFoodDetailScreen extends ConsumerWidget {
  const TraditionalFoodDetailScreen({
    super.key,
    required this.food,
  });

  final TraditionalFood food;

  // =========================================================
  // OPEN NEARBY RESTAURANTS
  // =========================================================

  void _openNearby(
      BuildContext context,
      ) {
    context.push(
      CultureCommunityRoutes.foodNearby,
      extra: food,
    );
  }

  // =========================================================
  // GOOGLE MAPS
  // =========================================================

  Future<void> _navigate(
      BuildContext context,
      TraditionalFoodPlace place,
      ) async {
    await openGoogleMapsNavigation(
      context: context,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    final controller = ref.watch(
      traditionalFoodDetailControllerProvider(
        food.id,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Traditional Food',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            bottom: 110,
          ),
          children: [
            // =================================================
            // HERO IMAGE
            // =================================================

            _FoodHero(
              food: food,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                32,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // ===========================================
                  // LOCATION / CATEGORY
                  // ===========================================

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag(
                        icon:
                        Icons.location_on_outlined,
                        text: food.state,
                      ),

                      if (food.region != null &&
                          food.region!
                              .trim()
                              .isNotEmpty)
                        _Tag(
                          icon:
                          Icons.public_outlined,
                          text: food.region!,
                        ),

                      _Tag(
                        icon:
                        Icons.restaurant_menu_rounded,
                        text: food.culturalCategory,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ===========================================
                  // ABOUT
                  // ===========================================

                  const _SectionTitle(
                    icon:
                    Icons.info_outline_rounded,
                    title: 'About This Dish',
                  ),

                  const SizedBox(height: 10),

                  Text(
                    food.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.55,
                      color:
                      colors.onSurfaceVariant,
                    ),
                  ),

                  // ===========================================
                  // CULTURAL HISTORY
                  // ===========================================

                  if (food.culturalHistory
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 28),

                    const _SectionTitle(
                      icon:
                      Icons.history_edu_rounded,
                      title: 'Cultural History',
                    ),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                        colors.surfaceContainerLow,
                        borderRadius:
                        BorderRadius.circular(16),
                        border: Border.all(
                          color:
                          colors.outlineVariant,
                        ),
                      ),
                      child: Text(
                        food.culturalHistory,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],

                  // ===========================================
                  // INGREDIENTS
                  // ===========================================

                  if (food.ingredients.isNotEmpty) ...[
                    const SizedBox(height: 28),

                    const _SectionTitle(
                      icon:
                      Icons.ramen_dining_rounded,
                      title: 'Ingredients',
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ingredient
                        in food.ingredients)
                          Chip(
                            label: Text(
                              ingredient,
                            ),
                          ),
                      ],
                    ),
                  ],

                  // ===========================================
                  // DIETARY
                  // ===========================================

                  if (food.dietaryTags.isNotEmpty) ...[
                    const SizedBox(height: 28),

                    const _SectionTitle(
                      icon: Icons.eco_outlined,
                      title:
                      'Dietary Information',
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag
                        in food.dietaryTags)
                          Chip(
                            label: Text(
                              _displayValue(tag),
                            ),
                          ),
                      ],
                    ),
                  ],

                  // ===========================================
                  // ALLERGY
                  // ===========================================

                  if (food.allergens.isNotEmpty ||
                      (food.allergyNotes != null &&
                          food.allergyNotes!
                              .trim()
                              .isNotEmpty)) ...[
                    const SizedBox(height: 28),

                    const _SectionTitle(
                      icon:
                      Icons.warning_amber_rounded,
                      title:
                      'Allergy Information',
                    ),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: colors.errorContainer
                            .withValues(
                          alpha: 0.35,
                        ),
                        borderRadius:
                        BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          if (food.allergens.isNotEmpty)
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final allergen
                                in food.allergens)
                                  Chip(
                                    label: Text(
                                      _displayValue(
                                        allergen,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                          if (food.allergyNotes != null &&
                              food.allergyNotes!
                                  .trim()
                                  .isNotEmpty) ...[
                            if (food
                                .allergens.isNotEmpty)
                              const SizedBox(
                                height: 10,
                              ),

                            Text(
                              food.allergyNotes!,
                              style:
                              GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ===========================================
                  // TRAVEL STYLES
                  // ===========================================

                  if (food.travelStyles.isNotEmpty) ...[
                    const SizedBox(height: 28),

                    const _SectionTitle(
                      icon:
                      Icons.explore_outlined,
                      title: 'Recommended For',
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final style
                        in food.travelStyles)
                          Chip(
                            label: Text(
                              _displayValue(style),
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 30),

                  // ===========================================
                  // WHERE TO FIND
                  // ===========================================

                  Row(
                    children: [
                      const Expanded(
                        child: _SectionTitle(
                          icon:
                          Icons.place_outlined,
                          title: 'Where to Find It',
                        ),
                      ),

                      if (controller.places.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            _openNearby(context);
                          },
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'View Map',
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===========================================
                  // RESTAURANT LOADING
                  // ===========================================

                  if (controller.isLoading &&
                      controller.places.isEmpty)
                    const Center(
                      child:
                      CircularProgressIndicator(),
                    )

                  // ===========================================
                  // NO RESTAURANT
                  // ===========================================

                  else if (controller.places.isEmpty)
                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                        colors.surfaceContainerLow,
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 42,
                            color: colors.outline,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'No verified restaurants have been added yet.',
                            textAlign:
                            TextAlign.center,
                            style: GoogleFonts.inter(
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )

                  // ===========================================
                  // RESTAURANTS
                  // ===========================================

                  else ...[
                      _FoodPlacesMap(
                        places: controller.places,
                      ),

                      const SizedBox(height: 14),

                      for (final place
                      in controller.places.take(4)) ...[
                        _RestaurantCard(
                          place: place,

                          isSaved:
                          controller.isPlaceFavourite(
                            place.id,
                          ),

                          isSaving:
                          controller.isSavingPlace(
                            place.id,
                          ),

                          onNavigate: () {
                            _navigate(
                              context,
                              place,
                            );
                          },

                          onSave: () async {
                            final success =
                            await controller
                                .togglePlaceFavourite(
                              place.id,
                            );

                            if (!context.mounted) {
                              return;
                            }

                            if (!success) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    controller
                                        .errorMessage ??
                                        'Could not update saved restaurant.',
                                  ),
                                ),
                              );

                              return;
                            }

                            final nowSaved =
                            controller
                                .isPlaceFavourite(
                              place.id,
                            );

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  nowSaved
                                      ? '${place.name} saved.'
                                      : '${place.name} removed from saved.',
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),
                      ],

                      if (controller.places.length > 4)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _openNearby(context);
                            },
                            icon: const Icon(
                              Icons.map_outlined,
                            ),
                            label: Text(
                              'View All ${controller.places.length} Locations',
                            ),
                          ),
                        ),
                    ],

                  if (controller.errorMessage !=
                      null) ...[
                    const SizedBox(height: 18),

                    Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),

      // =======================================================
      // SAVE FOOD + FIND NEARBY
      // =======================================================

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            10,
            9,
            10,
            9,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              // ===============================================
              // SAVE FOOD
              // ===============================================

              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                  controller.isSavingFavourite
                      ? null
                      : () async {
                    final success =
                    await controller
                        .toggleFavourite();

                    if (!context.mounted) {
                      return;
                    }

                    if (!success) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            controller
                                .errorMessage ??
                                'Could not update saved food.',
                          ),
                        ),
                      );

                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.isFavourite
                              ? '${food.name} saved.'
                              : '${food.name} removed from saved.',
                        ),
                      ),
                    );
                  },
                  icon: controller.isSavingFavourite
                      ? const SizedBox(
                    width: 17,
                    height: 17,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    controller.isFavourite
                        ? Icons.bookmark_rounded
                        : Icons
                        .bookmark_border_rounded,
                  ),
                  label: Text(
                    controller.isFavourite
                        ? 'Saved'
                        : 'Save',
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ===============================================
              // FIND NEARBY
              // ===============================================

              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: controller.places.isEmpty
                      ? null
                      : () {
                    _openNearby(context);
                  },
                  icon: const Icon(
                    Icons.near_me_outlined,
                  ),
                  label: const Text(
                    'Find Nearby',
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
// HERO
// ===========================================================

class _FoodHero extends StatelessWidget {
  const _FoodHero({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
    food.imageUrl?.trim();

    return SizedBox(
      height: 310,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null &&
              imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (
                  context,
                  error,
                  stackTrace,
                  ) {
                return _fallback(context);
              },
            )
          else
            _fallback(context),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:
                Alignment.topCenter,
                end:
                Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black87,
                ],
              ),
            ),
          ),

          Positioned(
            left: 18,
            right: 18,
            bottom: 22,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    borderRadius:
                    BorderRadius.circular(999),
                  ),
                  child: Text(
                    food.culturalCategory
                        .toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  food.name,
                  style:
                  GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  food.region != null &&
                      food.region!
                          .trim()
                          .isNotEmpty
                      ? '${food.state} • ${food.region}'
                      : food.state,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(
      BuildContext context,
      ) {
    return Container(
      color: Theme.of(context)
          .colorScheme
          .primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        size: 90,
        color: Theme.of(context)
            .colorScheme
            .onPrimaryContainer,
      ),
    );
  }
}

// ===========================================================
// FOOD LOCATIONS MAP
// ===========================================================

class _FoodPlacesMap extends StatelessWidget {
  const _FoodPlacesMap({
    required this.places,
  });

  final List<TraditionalFoodPlace> places;

  @override
  Widget build(BuildContext context) {
    var latitude = 0.0;
    var longitude = 0.0;

    for (final place in places) {
      latitude += place.latitude;
      longitude += place.longitude;
    }

    final center = LatLng(
      latitude / places.length,
      longitude / places.length,
    );

    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(17),
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
              places.length == 1 ? 14 : 8,
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
                  for (final place in places)
                    Marker(
                      point: LatLng(
                        place.latitude,
                        place.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                          shape:
                          BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 18,
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
}

// ===========================================================
// RESTAURANT CARD
// ===========================================================

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.place,
    required this.isSaved,
    required this.isSaving,
    required this.onNavigate,
    required this.onSave,
  });

  final TraditionalFoodPlace place;

  final bool isSaved;

  final bool isSaving;

  final VoidCallback onNavigate;

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  colors.secondaryContainer,
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: colors
                        .onSecondaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: GoogleFonts.inter(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        [
                          if (place.city != null &&
                              place.city!
                                  .trim()
                                  .isNotEmpty)
                            place.city!,
                          place.state,
                        ].join(', '),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: isSaved
                      ? 'Remove saved place'
                      : 'Save place',
                  onPressed:
                  isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons
                        .bookmark_border_rounded,
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
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.4,
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
              child: OutlinedButton.icon(
                onPressed: onNavigate,
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
// SECTION TITLE
// ===========================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color:
          Theme.of(context)
              .colorScheme
              .primary,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// TAG
// ===========================================================

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.text,
  });

  final IconData icon;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainer,
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
          ),

          const SizedBox(width: 5),

          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// SMALL TAG
// ===========================================================

class _SmallTag extends StatelessWidget {
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
        BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ===========================================================
// HELPERS
// ===========================================================

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
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();

  if (normalized.isEmpty) {
    return value;
  }

  return normalized
      .split(' ')
      .where(
        (word) => word.isNotEmpty,
  )
      .map(
        (word) =>
    '${word[0].toUpperCase()}'
        '${word.substring(1)}',
  )
      .join(' ');
}