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

class TraditionalFoodDetailScreen
    extends ConsumerWidget {
  const TraditionalFoodDetailScreen({
    super.key,
    required this.food,
  });

  final TraditionalFood food;

  // =========================================================
  // OPEN FIND NEARBY PAGE
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
          'Food Details',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // =======================================================
      // BODY
      // =======================================================

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
            // HERO
            // =================================================

            _FoodHero(
              food: food,
            ),

            // =================================================
            // CONTENT
            // =================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                22,
                16,
                32,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // ===========================================
                  // ORIGIN + CULTURE
                  // ===========================================

                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon:
                          Icons.location_on_outlined,
                          label: 'ORIGIN',
                          value: food.region != null &&
                              food.region!
                                  .trim()
                                  .isNotEmpty
                              ? '${food.state}\n${food.region}'
                              : food.state,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _InfoCard(
                          icon: Icons.groups_outlined,
                          label: 'CULTURE',
                          value:
                          food.culturalCategory,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ===========================================
                  // ABOUT
                  // ===========================================

                  const _SectionTitle(
                    icon: Icons.menu_book_outlined,
                    title: 'About This Dish',
                  ),

                  const SizedBox(height: 10),

                  Text(
                    food.description.trim().isEmpty
                        ? 'Description is not available.'
                        : food.description,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.55,
                      color:
                      colors.onSurfaceVariant,
                    ),
                  ),

                  // ===========================================
                  // CULTURAL STORY
                  // ===========================================

                  if (food.culturalHistory
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 28),

                    _CulturalStoryCard(
                      text:
                      food.culturalHistory,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ===========================================
                  // INGREDIENTS
                  // ===========================================

                  _IngredientsCard(
                    ingredients:
                    food.ingredients,
                  ),

                  // ===========================================
                  // DIETARY INFORMATION
                  // ===========================================

                  if (food.dietaryTags
                      .isNotEmpty ||
                      food.allergens
                          .isNotEmpty ||
                      (food.allergyNotes !=
                          null &&
                          food.allergyNotes!
                              .trim()
                              .isNotEmpty)) ...[
                    const SizedBox(height: 24),

                    _DietaryCard(
                      food: food,
                    ),
                  ],

                  // ===========================================
                  // TRAVEL STYLES
                  // ===========================================

                  if (food.travelStyles
                      .isNotEmpty) ...[
                    const SizedBox(height: 26),

                    const _SectionTitle(
                      icon: Icons.explore_outlined,
                      title: 'Experience',
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final style
                        in food.travelStyles)
                          Chip(
                            label: Text(
                              '#${_displayValue(style)}',
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ===========================================
                  // WHERE TO FIND IT
                  // ===========================================

                  Row(
                    children: [
                      const Expanded(
                        child: _SectionTitle(
                          icon:
                          Icons.restaurant_outlined,
                          title:
                          'Where to Find It',
                        ),
                      ),

                      if (controller
                          .places.isNotEmpty)
                        Text(
                          '${controller.places.length} '
                              'location${controller.places.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ===========================================
                  // LOADING LOCATIONS
                  // ===========================================

                  if (controller.isLoading &&
                      controller.places.isEmpty)
                    const Center(
                      child: Padding(
                        padding:
                        EdgeInsets.all(30),
                        child:
                        CircularProgressIndicator(),
                      ),
                    )

                  // ===========================================
                  // NO LOCATIONS
                  // ===========================================

                  else if (controller
                      .places.isEmpty)
                    _NoLocationCard(
                      foodName: food.name,
                    )

                  // ===========================================
                  // LOCATIONS EXIST
                  // ===========================================

                  else ...[
                      _FoodLocationMap(
                        places:
                        controller.places,
                      ),

                      const SizedBox(height: 14),

                      for (final place
                      in controller.places
                          .take(3)) ...[
                        _FoodLocationCard(
                          place: place,
                        ),

                        const SizedBox(height: 9),
                      ],

                      const SizedBox(height: 3),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _openNearby(
                              context,
                            );
                          },
                          icon: const Icon(
                            Icons.map_outlined,
                          ),
                          label: Text(
                            controller.places.length >
                                3
                                ? 'View All ${controller.places.length} Locations'
                                : 'View Locations on Map',
                          ),
                        ),
                      ),
                    ],

                  // ===========================================
                  // ERROR
                  // ===========================================

                  if (controller.errorMessage !=
                      null) ...[
                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.all(
                        13,
                      ),
                      decoration: BoxDecoration(
                        color:
                        colors.errorContainer,
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons
                                .error_outline_rounded,
                            color: colors
                                .onErrorContainer,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              controller
                                  .errorMessage!,
                              style: TextStyle(
                                color: colors
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
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
      // ACTION BAR
      // =======================================================

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            12,
            9,
            12,
            9,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color:
                colors.outlineVariant,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(
                  0,
                  -2,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              // ===============================================
              // SAVE FAVORITE
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

                    if (!context
                        .mounted) {
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
                                'Could not update Favorite.',
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
                          controller
                              .isFavourite
                              ? '${food.name} saved to Favorites.'
                              : '${food.name} removed from Favorites.',
                        ),
                      ),
                    );
                  },
                  icon: controller
                      .isSavingFavourite
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
                        ? Icons
                        .favorite_rounded
                        : Icons
                        .favorite_border_rounded,
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
                  // Disable only when there are no known
                  // locations serving this food.
                  onPressed:
                  controller.places.isEmpty
                      ? null
                      : () {
                    _openNearby(
                      context,
                    );
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
// FOOD HERO
// ===========================================================

class _FoodHero extends StatelessWidget {
  const _FoodHero({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _FoodImage(
            food: food,
          ),

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
                stops: [
                  0.35,
                  1,
                ],
              ),
            ),
          ),

          Positioned(
            left: 18,
            right: 18,
            bottom: 23,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _HeroTag(
                      text:
                      food.culturalCategory,
                    ),

                    for (final tag
                    in food.dietaryTags
                        .take(2))
                      _HeroTag(
                        text:
                        _displayValue(
                          tag,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 11),

                Text(
                  food.name,
                  style:
                  GoogleFonts.montserrat(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight:
                    FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .location_on_outlined,
                      size: 18,
                      color: Colors.white,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        food.region != null &&
                            food.region!
                                .trim()
                                .isNotEmpty
                            ? '${food.state} • ${food.region}'
                            : food.state,
                        style:
                        GoogleFonts.inter(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// HERO TAG
// ===========================================================

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFED65B,
        ),
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: const Color(
            0xFF574500,
          ),
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
    final imageUrl =
    food.imageUrl?.trim();

    if (imageUrl != null &&
        imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return _fallback(
            context,
          );
        },
      );
    }

    return _fallback(
      context,
    );
  }

  Widget _fallback(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            const Color(
              0xFF1B4332,
            ),
            colors
                .surfaceContainerHighest,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        size: 76,
        color: Colors.white70,
      ),
    );
  }
}

// ===========================================================
// INFO CARD
// ===========================================================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 95,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
        colors.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
              colors.secondaryContainer,
              borderRadius:
              BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 19,
              color: colors
                  .onSecondaryContainer,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w600,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          size: 21,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            title,
            style:
            GoogleFonts.montserrat(
              fontSize: 19,
              fontWeight:
              FontWeight.w700,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// CULTURAL STORY
// ===========================================================

class _CulturalStoryCard
    extends StatelessWidget {
  const _CulturalStoryCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        colors.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_edu,
                color: colors.secondary,
              ),

              const SizedBox(width: 7),

              Text(
                'Cultural Story',
                style:
                GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.55,
              color:
              colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// INGREDIENTS
// ===========================================================

class _IngredientsCard
    extends StatelessWidget {
  const _IngredientsCard({
    required this.ingredients,
  });

  final List<String> ingredients;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon:
            Icons.restaurant_menu_rounded,
            title: 'Main Ingredients',
          ),

          const SizedBox(height: 14),

          if (ingredients.isEmpty)
            Text(
              'Ingredient information is not available.',
              style: GoogleFonts.inter(
                color:
                colors.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final ingredient
                in ingredients)
                  Chip(
                    label:
                    Text(ingredient),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ===========================================================
// DIETARY INFORMATION
// ===========================================================

class _DietaryCard extends StatelessWidget {
  const _DietaryCard({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color:
        colors.surfaceContainerHigh,
        borderRadius:
        BorderRadius.circular(17),
        border: Border(
          left: BorderSide(
            width: 4,
            color: colors.secondary,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Dietary Information',
            style: GoogleFonts.montserrat(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          if (food.dietaryTags
              .isNotEmpty) ...[
            const SizedBox(height: 11),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final tag
                in food.dietaryTags)
                  Chip(
                    avatar: const Icon(
                      Icons
                          .check_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _displayValue(tag),
                    ),
                  ),
              ],
            ),
          ],

          if (food.allergens
              .isNotEmpty) ...[
            const SizedBox(height: 14),

            Text(
              'Allergens',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final allergen
                in food.allergens)
                  Chip(
                    avatar: const Icon(
                      Icons
                          .warning_amber_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _displayValue(
                        allergen,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (food.allergyNotes != null &&
              food.allergyNotes!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(height: 10),

            Text(
              food.allergyNotes!,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 13),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color: colors.primary,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  'Halal status is shown for each food location because certification and preparation may differ between restaurants.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.4,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// MAP PREVIEW
// ===========================================================

class _FoodLocationMap extends StatelessWidget {
  const _FoodLocationMap({
    required this.places,
  });

  final List<TraditionalFoodPlace> places;

  LatLng get _center {
    var latitude = 0.0;
    var longitude = 0.0;

    for (final place in places) {
      latitude += place.latitude;
      longitude += place.longitude;
    }

    return LatLng(
      latitude / places.length,
      longitude / places.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(17),
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
              initialCenter: _center,
              initialZoom: 11,
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
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                          _halalColor(
                            place.halalStatus,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                            Colors.white,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color:
                              Colors.black26,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons
                              .restaurant_rounded,
                          color: Colors.white,
                          size: 19,
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
            child: IgnorePointer(
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
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// LOCATION CARD
// ===========================================================

class _FoodLocationCard
    extends StatelessWidget {
  const _FoodLocationCard({
    required this.place,
  });

  final TraditionalFoodPlace place;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
        colors.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
            _halalColor(
              place.halalStatus,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
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
                    fontSize: 13,
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
                    fontSize: 10,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 6),

                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _SmallTag(
                      text: _halalLabel(
                        place.halalStatus,
                      ),
                    ),

                    _SmallTag(
                      text: _displayValue(
                        place.category,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// NO LOCATION
// ===========================================================

class _NoLocationCard
    extends StatelessWidget {
  const _NoLocationCard({
    required this.foodName,
  });

  final String foodName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            Icons.location_off_outlined,
            size: 42,
            color: Theme.of(context)
                .colorScheme
                .outline,
          ),

          const SizedBox(height: 10),

          Text(
            'No verified locations serving $foodName have been added yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
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

Color _halalColor(
    String value,
    ) {
  switch (value) {
    case 'certified':
      return const Color(
        0xFF1B4332,
      );

    case 'muslim_friendly':
      return const Color(
        0xFF3F6653,
      );

    case 'non_halal':
      return const Color(
        0xFF8A3A32,
      );

    default:
      return const Color(
        0xFF6B7280,
      );
  }
}

String _displayValue(
    String value,
    ) {
  if (value.trim().isEmpty) {
    return value;
  }

  final normalized = value
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();

  return normalized
      .split(' ')
      .where(
        (word) => word.isNotEmpty,
  )
      .map(
        (word) =>
    word[0].toUpperCase() +
        word.substring(1),
  )
      .join(' ');
}