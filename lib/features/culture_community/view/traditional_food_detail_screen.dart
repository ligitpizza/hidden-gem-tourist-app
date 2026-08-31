import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../controller/traditional_food_detail_controller.dart';
import '../model/traditional_food.dart';
import '../model/traditional_food_place.dart';
import 'culture_community_routes.dart';

class TraditionalFoodDetailScreen
    extends ConsumerStatefulWidget {
  const TraditionalFoodDetailScreen({
    super.key,
    required this.food,
  });

  final TraditionalFood food;

  @override
  ConsumerState<TraditionalFoodDetailScreen>
  createState() =>
      _TraditionalFoodDetailScreenState();
}

class _TraditionalFoodDetailScreenState
    extends ConsumerState<TraditionalFoodDetailScreen> {
  LatLng? _userLocation;

  bool _locatingUser = false;

  TraditionalFood get food => widget.food;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        _tryExistingLocationPermission();
      },
    );
  }

  // =========================================================
  // LOCATION
  // =========================================================

  Future<void>
  _tryExistingLocationPermission() async {
    try {
      final permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.always ||
          permission ==
              LocationPermission.whileInUse) {
        await _locateUser(
          requestPermission: false,
        );
      }
    } catch (_) {
      // User location is optional.
    }
  }

  Future<bool> _locateUser({
    bool requestPermission = true,
  }) async {
    if (_locatingUser) {
      return false;
    }

    if (mounted) {
      setState(() {
        _locatingUser = true;
      });
    }

    try {
      final serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        return false;
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied &&
          requestPermission) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        return false;
      }

      final position =
      await Geolocator.getCurrentPosition();

      if (!mounted) {
        return false;
      }

      setState(() {
        _userLocation = LatLng(
          position.latitude,
          position.longitude,
        );
      });

      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _locatingUser = false;
        });
      }
    }
  }

  // =========================================================
  // DISTANCE
  // =========================================================

  double? _distanceToPlace(
      TraditionalFoodPlace place,
      ) {
    final userLocation = _userLocation;

    if (userLocation == null) {
      return null;
    }

    final metres =
    Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      place.latitude,
      place.longitude,
    );

    return metres / 1000;
  }

  // =========================================================
  // SORT LOCATIONS
  // =========================================================

  List<TraditionalFoodPlace> _sortPlaces(
      List<TraditionalFoodPlace> places,
      ) {
    final result =
    List<TraditionalFoodPlace>.from(
      places,
    );

    result.sort(
          (a, b) {
        final distanceA =
        _distanceToPlace(a);

        final distanceB =
        _distanceToPlace(b);

        if (distanceA != null &&
            distanceB != null) {
          final comparison =
          distanceA.compareTo(
            distanceB,
          );

          if (comparison != 0) {
            return comparison;
          }
        }

        return a.name
            .toLowerCase()
            .compareTo(
          b.name.toLowerCase(),
        );
      },
    );

    return result;
  }

  // =========================================================
  // OPEN NEARBY RESTAURANTS PAGE
  // =========================================================

  void _openNearbyRestaurants() {
    context.push(
      CultureCommunityRoutes.foodNearby,
      extra: food,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final controller = ref.watch(
      traditionalFoodDetailControllerProvider(
        food.id,
      ),
    );

    final places = _sortPlaces(
      controller.places,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Food Details',
          style:
          GoogleFonts.montserrat(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: RefreshIndicator(
        onRefresh:
        controller.refresh,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.only(
            bottom: 120,
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
              padding:
              const EdgeInsets.fromLTRB(
                16,
                24,
                16,
                36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(
                    maxWidth: 1000,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      // =======================================
                      // ORIGIN + CULTURE
                      // =======================================

                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Expanded(
                            child:
                            _InfoCard(
                              icon: Icons
                                  .location_on_outlined,
                              label:
                              'ORIGIN',
                              value:
                              food.region !=
                                  null &&
                                  food.region!
                                      .trim()
                                      .isNotEmpty
                                  ? '${food.state}\n${food.region}'
                                  : food
                                  .state,
                            ),
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child:
                            _InfoCard(
                              icon: Icons
                                  .groups_outlined,
                              label:
                              'CULTURE',
                              value: food
                                  .culturalCategory,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 30,
                      ),

                      // =======================================
                      // ABOUT
                      // =======================================

                      const _SectionTitle(
                        icon: Icons
                            .menu_book_outlined,
                        title:
                        'About This Dish',
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Text(
                        food.description
                            .trim()
                            .isEmpty
                            ? 'Description is not available for this dish.'
                            : food
                            .description,
                        style:
                        GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.6,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),

                      // =======================================
                      // CULTURAL HISTORY
                      // =======================================

                      if (food.culturalHistory
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 30,
                        ),

                        _CulturalHistoryCard(
                          history: food
                              .culturalHistory,
                        ),
                      ],

                      const SizedBox(
                        height: 30,
                      ),

                      // =======================================
                      // INGREDIENTS
                      // =======================================

                      _IngredientsCard(
                        ingredients:
                        food.ingredients,
                      ),

                      // =======================================
                      // DIETARY INFORMATION
                      // =======================================

                      if (food.dietaryTags
                          .isNotEmpty ||
                          food.allergens
                              .isNotEmpty ||
                          (food.allergyNotes !=
                              null &&
                              food.allergyNotes!
                                  .trim()
                                  .isNotEmpty)) ...[
                        const SizedBox(
                          height: 26,
                        ),

                        _DietaryCard(
                          food: food,
                        ),
                      ],

                      // =======================================
                      // EXPERIENCE TAGS
                      // =======================================

                      if (food.travelStyles
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 28,
                        ),

                        const _SectionTitle(
                          icon: Icons
                              .explore_outlined,
                          title:
                          'Experience',
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final style
                            in food
                                .travelStyles)
                              Chip(
                                label: Text(
                                  '#${_displayTag(style)}',
                                ),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(
                        height: 32,
                      ),

                      // =======================================
                      // WHERE TO FIND IT HEADER
                      // =======================================

                      Row(
                        children: [
                          const Expanded(
                            child:
                            _SectionTitle(
                              icon: Icons
                                  .restaurant_outlined,
                              title:
                              'Where to Find It',
                            ),
                          ),

                          if (controller
                              .places
                              .isNotEmpty)
                            Text(
                              '${controller.places.length} '
                                  'location${controller.places.length == 1 ? '' : 's'}',
                              style:
                              GoogleFonts
                                  .inter(
                                fontSize:
                                12,
                                color: colors
                                    .onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // =======================================
                      // LOCATION LOADING
                      // =======================================

                      if (controller
                          .isLoading &&
                          controller
                              .places
                              .isEmpty)
                        const Center(
                          child: Padding(
                            padding:
                            EdgeInsets.all(
                              30,
                            ),
                            child:
                            CircularProgressIndicator(),
                          ),
                        )

                      // =======================================
                      // NO RESTAURANTS
                      // =======================================

                      else if (places
                          .isEmpty)
                        _NoPlaceCard(
                          foodName:
                          food.name,
                        )

                      // =======================================
                      // RESTAURANTS EXIST
                      // =======================================

                      else ...[
                          // -------------------------------------
                          // MAP PREVIEW
                          // -------------------------------------

                          _FoodPlacesMap(
                            places:
                            places,
                            userLocation:
                            _userLocation,
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // -------------------------------------
                          // FIRST 3 RESTAURANTS
                          // -------------------------------------

                          for (final place
                          in places
                              .take(3)) ...[
                            _NearbyPlaceTile(
                              place:
                              place,
                              distanceKm:
                              _distanceToPlace(
                                place,
                              ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),
                          ],

                          // -------------------------------------
                          // VIEW ALL / FIND NEARBY
                          // -------------------------------------

                          Align(
                            alignment:
                            Alignment
                                .centerRight,
                            child:
                            TextButton.icon(
                              onPressed:
                              _openNearbyRestaurants,
                              icon:
                              const Icon(
                                Icons
                                    .near_me_outlined,
                                size: 18,
                              ),
                              label:
                              Text(
                                places.length >
                                    3
                                    ? 'View All ${places.length} Locations'
                                    : 'View Nearby Restaurants',
                              ),
                            ),
                          ),
                        ],

                      // =======================================
                      // ERROR
                      // =======================================

                      if (controller
                          .errorMessage !=
                          null) ...[
                        const SizedBox(
                          height: 20,
                        ),

                        Container(
                          width:
                          double.infinity,
                          padding:
                          const EdgeInsets
                              .all(
                            14,
                          ),
                          decoration:
                          BoxDecoration(
                            color: colors
                                .errorContainer,
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Icon(
                                Icons
                                    .error_outline_rounded,
                                color: colors
                                    .onErrorContainer,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child:
                                Text(
                                  controller
                                      .errorMessage!,
                                  style:
                                  TextStyle(
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
              ),
            ),
          ],
        ),
      ),

      // =======================================================
      // BOTTOM ACTION BAR
      // =======================================================

      bottomNavigationBar:
      SafeArea(
        top: false,
        child: Container(
          padding:
          const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            10,
          ),
          decoration:
          BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors
                    .outlineVariant,
              ),
            ),
            boxShadow:
            const [
              BoxShadow(
                color:
                Colors.black12,
                blurRadius: 12,
                offset:
                Offset(
                  0,
                  -3,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              // ===============================================
              // SAVE TO FAVORITES
              // ===============================================

              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed: controller
                      .isSavingFavourite
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
                          content:
                          Text(
                            controller
                                .errorMessage ??
                                'Could not save this food.',
                          ),
                        ),
                      );

                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content:
                        Text(
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
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                    ),
                  )
                      : Icon(
                    controller
                        .isFavourite
                        ? Icons
                        .favorite_rounded
                        : Icons
                        .favorite_border_rounded,
                  ),

                  label: Text(
                    controller
                        .isFavourite
                        ? 'Saved'
                        : 'Save',
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              // ===============================================
              // FIND NEARBY
              //
              // IMPORTANT:
              // This now opens the dedicated nearby restaurant
              // map page instead of showing a bottom sheet.
              // ===============================================

              Expanded(
                flex: 2,
                child:
                FilledButton.icon(
                  onPressed: controller
                      .places
                      .isEmpty
                      ? null
                      : _openNearbyRestaurants,

                  icon:
                  const Icon(
                    Icons
                        .near_me_outlined,
                  ),

                  label:
                  const Text(
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
      height: 390,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _FoodImage(
            food: food,
          ),

          const DecoratedBox(
            decoration:
            BoxDecoration(
              gradient:
              LinearGradient(
                begin: Alignment
                    .topCenter,
                end: Alignment
                    .bottomCenter,
                colors: [
                  Colors
                      .transparent,
                  Colors
                      .black87,
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
            bottom: 24,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _HeroTag(
                      label: food
                          .culturalCategory,
                    ),

                    for (final tag
                    in food
                        .dietaryTags
                        .take(2))
                      _HeroTag(
                        label:
                        _displayTag(
                          tag,
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  food.name,
                  style:
                  GoogleFonts
                      .montserrat(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight:
                    FontWeight
                        .w700,
                    color:
                    Colors.white,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .location_on_outlined,
                      color:
                      Colors.white,
                      size: 19,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Expanded(
                      child: Text(
                        food.region !=
                            null &&
                            food.region!
                                .trim()
                                .isNotEmpty
                            ? '${food.state} • ${food.region}'
                            : food
                            .state,
                        style:
                        GoogleFonts
                            .inter(
                          color:
                          Colors.white,
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
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFFED65B,
        ),
        borderRadius:
        BorderRadius
            .circular(
          999,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style:
        GoogleFonts.inter(
          color:
          const Color(
            0xFF574500,
          ),
          fontSize: 10,
          letterSpacing: 0.4,
          fontWeight:
          FontWeight.w700,
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
        fit: BoxFit.cover,
        errorBuilder:
            (_, _, _) {
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
        Theme.of(context)
            .colorScheme;

    return Container(
      decoration:
      BoxDecoration(
        gradient:
        LinearGradient(
          begin: Alignment
              .topLeft,
          end: Alignment
              .bottomRight,
          colors: [
            const Color(
              0xFF1B4332,
            ),
            colors
                .surfaceContainerHighest,
          ],
        ),
      ),
      alignment:
      Alignment.center,
      child:
      const Icon(
        Icons
            .restaurant_rounded,
        size: 80,
        color:
        Colors.white70,
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
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      constraints:
      const BoxConstraints(
        minHeight: 100,
      ),
      decoration:
      BoxDecoration(
        color: colors
            .surfaceContainerLow,
        borderRadius:
        BorderRadius
            .circular(
          16,
        ),
        border:
        Border.all(
          color: colors
              .outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Container(
            padding:
            const EdgeInsets
                .all(
              8,
            ),
            decoration:
            BoxDecoration(
              color: colors
                  .secondaryContainer,
              borderRadius:
              BorderRadius
                  .circular(
                10,
              ),
            ),
            child:
            Icon(
              icon,
              color: colors
                  .onSecondaryContainer,
              size: 20,
            ),
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  label,
                  style:
                  GoogleFonts
                      .inter(
                    fontSize:
                    10,
                    fontWeight:
                    FontWeight
                        .w600,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,
                  style:
                  GoogleFonts
                      .inter(
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight
                        .w700,
                    color:
                    colors
                        .primary,
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
          color:
          Theme.of(context)
              .colorScheme
              .primary,
          size: 22,
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: Text(
            title,
            style:
            GoogleFonts
                .montserrat(
              fontSize: 21,
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
        ),
      ],
    );
  }
}

// ===========================================================
// CULTURAL HISTORY
// ===========================================================

class _CulturalHistoryCard
    extends StatelessWidget {
  const _CulturalHistoryCard({
    required this.history,
  });

  final String history;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        color: colors
            .surfaceContainerLow,
        borderRadius:
        BorderRadius
            .circular(
          18,
        ),
        border:
        Border.all(
          color: colors
              .outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .history_edu,
                color:
                colors
                    .secondary,
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child:
                Text(
                  'Cultural Story',
                  style:
                  GoogleFonts
                      .montserrat(
                    fontSize:
                    19,
                    fontWeight:
                    FontWeight
                        .w700,
                    color:
                    colors
                        .primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            history,
            style:
            GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: colors
                  .onSurfaceVariant,
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
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        color: colors.surface,
        borderRadius:
        BorderRadius
            .circular(
          18,
        ),
        border:
        Border.all(
          color: colors
              .outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          const _SectionTitle(
            icon: Icons
                .restaurant_menu_rounded,
            title:
            'Main Ingredients',
          ),

          const SizedBox(
            height: 16,
          ),

          if (ingredients
              .isEmpty)
            Text(
              'Ingredient information is not available.',
              style:
              GoogleFonts
                  .inter(
                color: colors
                    .onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ingredient
                in ingredients)
                  Chip(
                    avatar:
                    const Icon(
                      Icons
                          .restaurant_menu_rounded,
                      size: 17,
                    ),
                    label:
                    Text(
                      ingredient,
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
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      BoxDecoration(
        color: colors
            .surfaceContainerHigh,
        borderRadius:
        BorderRadius
            .circular(
          18,
        ),
        border: Border(
          left:
          BorderSide(
            color: colors
                .secondary,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .info_outline_rounded,
                color: colors
                    .secondary,
              ),

              const SizedBox(
                width: 7,
              ),

              Expanded(
                child:
                Text(
                  'Dietary Information',
                  style:
                  GoogleFonts
                      .montserrat(
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ),
            ],
          ),

          // =============================================
          // DIETARY TAGS
          // =============================================

          if (food
              .dietaryTags
              .isNotEmpty) ...[
            const SizedBox(
              height: 12,
            ),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final tag
                in food
                    .dietaryTags)
                  Chip(
                    avatar:
                    const Icon(
                      Icons
                          .check_circle_outline_rounded,
                      size: 16,
                    ),
                    label:
                    Text(
                      _displayTag(
                        tag,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // =============================================
          // ALLERGENS
          // =============================================

          if (food
              .allergens
              .isNotEmpty) ...[
            const SizedBox(
              height: 14,
            ),

            Text(
              'Allergens',
              style:
              GoogleFonts
                  .inter(
                fontSize: 12,
                fontWeight:
                FontWeight
                    .w700,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final allergen
                in food
                    .allergens)
                  Chip(
                    avatar:
                    const Icon(
                      Icons
                          .warning_amber_rounded,
                      size: 16,
                    ),
                    label:
                    Text(
                      _displayTag(
                        allergen,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // =============================================
          // ALLERGY NOTES
          // =============================================

          if (food.allergyNotes !=
              null &&
              food.allergyNotes!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height: 12,
            ),

            Text(
              food.allergyNotes!,
              style:
              GoogleFonts
                  .inter(
                fontSize: 12,
                height: 1.45,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(
            height: 14,
          ),

          // =============================================
          // HALAL NOTE
          // =============================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Icon(
                Icons
                    .restaurant_outlined,
                size: 17,
                color:
                colors.primary,
              ),

              const SizedBox(
                width: 7,
              ),

              Expanded(
                child: Text(
                  'Halal status is shown per food location because preparation and certification can differ between restaurants.',
                  style:
                  GoogleFonts
                      .inter(
                    fontSize: 11,
                    height: 1.45,
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
// FOOD LOCATION MAP PREVIEW
// ===========================================================

class _FoodPlacesMap extends StatelessWidget {
  const _FoodPlacesMap({
    required this.places,
    required this.userLocation,
  });

  final List<TraditionalFoodPlace> places;

  final LatLng? userLocation;

  LatLng get _center {
    if (places.isEmpty) {
      return const LatLng(
        4.2105,
        101.9758,
      );
    }

    var latitude = 0.0;
    var longitude = 0.0;

    for (final place
    in places) {
      latitude +=
          place.latitude;

      longitude +=
          place.longitude;
    }

    return LatLng(
      latitude /
          places.length,
      longitude /
          places.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius
            .circular(
          18,
        ),
        border:
        Border.all(
          color:
          Theme.of(
            context,
          )
              .colorScheme
              .outlineVariant,
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options:
            MapOptions(
              initialCenter:
              _center,
              initialZoom:
              11,
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
                  // ===========================================
                  // RESTAURANT MARKERS
                  // ===========================================

                  for (final place
                  in places)
                    Marker(
                      point:
                      LatLng(
                        place.latitude,
                        place.longitude,
                      ),
                      width: 44,
                      height:
                      44,
                      child:
                      Container(
                        decoration:
                        BoxDecoration(
                          color:
                          _halalStatusColor(
                            place.halalStatus,
                          ),
                          shape:
                          BoxShape.circle,
                          border:
                          Border.all(
                            color:
                            Colors.white,
                            width:
                            3,
                          ),
                          boxShadow:
                          const [
                            BoxShadow(
                              color:
                              Colors.black26,
                              blurRadius:
                              6,
                            ),
                          ],
                        ),
                        child:
                        const Icon(
                          Icons
                              .restaurant_rounded,
                          color:
                          Colors.white,
                          size:
                          19,
                        ),
                      ),
                    ),

                  // ===========================================
                  // USER LOCATION
                  // ===========================================

                  if (userLocation !=
                      null)
                    Marker(
                      point:
                      userLocation!,
                      width:
                      34,
                      height:
                      34,
                      child:
                      Container(
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.blue,
                          shape:
                          BoxShape.circle,
                          border:
                          Border.all(
                            color:
                            Colors.white,
                            width:
                            3,
                          ),
                        ),
                        child:
                        const Icon(
                          Icons
                              .person_pin_circle_rounded,
                          color:
                          Colors.white,
                          size:
                          19,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // =============================================
          // OSM ATTRIBUTION
          // =============================================

          Positioned(
            left: 5,
            bottom: 4,
            child:
            IgnorePointer(
              child:
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  5,
                  vertical:
                  2,
                ),
                color:
                Theme.of(
                  context,
                )
                    .colorScheme
                    .surface
                    .withValues(
                  alpha:
                  0.85,
                ),
                child:
                const Text(
                  '© OpenStreetMap contributors',
                  style:
                  TextStyle(
                    fontSize:
                    8,
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
// NEARBY RESTAURANT PREVIEW
// ===========================================================

class _NearbyPlaceTile extends StatelessWidget {
  const _NearbyPlaceTile({
    required this.place,
    required this.distanceKm,
  });

  final TraditionalFoodPlace place;

  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        color: colors
            .surfaceContainerLow,
        borderRadius:
        BorderRadius
            .circular(
          14,
        ),
        border:
        Border.all(
          color: colors
              .outlineVariant,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
            _halalStatusColor(
              place.halalStatus,
            ),
            child:
            const Icon(
              Icons
                  .restaurant_rounded,
              color:
              Colors.white,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  place.name,
                  style:
                  GoogleFonts
                      .inter(
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  [
                    if (place.city !=
                        null &&
                        place.city!
                            .trim()
                            .isNotEmpty)
                      place.city!,
                    if (place.state
                        .trim()
                        .isNotEmpty)
                      place.state,
                  ].join(', '),
                  style:
                  GoogleFonts
                      .inter(
                    fontSize:
                    11,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing:
                  5,
                  children: [
                    _SmallTag(
                      text:
                      _halalStatusLabel(
                        place.halalStatus,
                      ),
                    ),

                    if (distanceKm !=
                        null)
                      _SmallTag(
                        text:
                        '${distanceKm!.toStringAsFixed(1)} km away',
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
      const EdgeInsets
          .symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration:
      BoxDecoration(
        color:
        Theme.of(
          context,
        )
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius
            .circular(
          999,
        ),
      ),
      child: Text(
        text,
        style:
        GoogleFonts.inter(
          fontSize: 9,
          fontWeight:
          FontWeight
              .w600,
        ),
      ),
    );
  }
}

// ===========================================================
// NO LOCATION
// ===========================================================

class _NoPlaceCard extends StatelessWidget {
  const _NoPlaceCard({
    required this.foodName,
  });

  final String foodName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        24,
      ),
      decoration:
      BoxDecoration(
        color:
        Theme.of(
          context,
        )
            .colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius
            .circular(
          16,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .location_off_outlined,
            size: 42,
            color:
            Theme.of(
              context,
            )
                .colorScheme
                .outline,
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            'No food locations for $foodName have been added yet.',
            textAlign:
            TextAlign.center,
            style:
            GoogleFonts.inter(
              fontSize: 13,
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
    );
  }
}

// ===========================================================
// HALAL STATUS LABEL
// ===========================================================

String _halalStatusLabel(
    String value,
    ) {
  switch (value) {
    case 'certified':
      return 'Halal Certified';

    case 'muslim_friendly':
      return 'Muslim-Friendly';

    case 'non_halal':
      return 'Non-Halal';

    case 'unknown':
    default:
      return 'Status Unknown';
  }
}

// ===========================================================
// HALAL STATUS COLOR
// ===========================================================

Color _halalStatusColor(
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

// ===========================================================
// DISPLAY TAG
// ===========================================================

String _displayTag(
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