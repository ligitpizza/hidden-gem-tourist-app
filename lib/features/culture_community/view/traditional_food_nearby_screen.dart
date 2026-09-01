import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../controller/traditional_food_detail_controller.dart';
import '../model/traditional_food.dart';
import '../model/traditional_food_place.dart';
import 'google_maps_navigation.dart';

enum _HalalFilter {
  all,
  certified,
  muslimFriendly,
  nonHalal,
  unknown,
}

extension _HalalFilterExtension
on _HalalFilter {
  String get label {
    switch (this) {
      case _HalalFilter.all:
        return 'All';

      case _HalalFilter.certified:
        return 'Halal Certified';

      case _HalalFilter.muslimFriendly:
        return 'Muslim-Friendly';

      case _HalalFilter.nonHalal:
        return 'Non-Halal';

      case _HalalFilter.unknown:
        return 'Unknown';
    }
  }
}

class TraditionalFoodNearbyScreen
    extends ConsumerStatefulWidget {
  const TraditionalFoodNearbyScreen({
    super.key,
    required this.food,
  });

  final TraditionalFood food;

  @override
  ConsumerState<
      TraditionalFoodNearbyScreen>
  createState() =>
      _TraditionalFoodNearbyScreenState();
}

class _TraditionalFoodNearbyScreenState
    extends ConsumerState<
        TraditionalFoodNearbyScreen> {
  final MapController _mapController =
  MapController();

  final TextEditingController
  _searchController =
  TextEditingController();

  LatLng? _userLocation;

  bool _locatingUser = false;

  String _searchQuery = '';

  double? _maxDistanceKm;

  _HalalFilter _halalFilter =
      _HalalFilter.all;

  TraditionalFoodPlace?
  _selectedPlace;

  TraditionalFood get food =>
      widget.food;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        _locateUser(
          moveMap: false,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // GPS
  // =========================================================

  Future<bool> _locateUser({
    bool moveMap = true,
  }) async {
    if (_locatingUser) {
      return false;
    }

    setState(() {
      _locatingUser = true;
    });

    try {
      final serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Please turn on location services.',
              ),
            ),
          );
        }

        return false;
      }

      var permission =
      await Geolocator
          .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator
            .requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required.',
              ),
            ),
          );
        }

        return false;
      }

      if (permission ==
          LocationPermission
              .deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission is permanently denied.',
              ),
              action:
              SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  Geolocator
                      .openAppSettings();
                },
              ),
            ),
          );
        }

        return false;
      }

      final position =
      await Geolocator
          .getCurrentPosition();

      if (!mounted) {
        return false;
      }

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _userLocation =
            location;
      });

      if (moveMap) {
        _mapController.move(
          location,
          13,
        );
      }

      return true;
    } catch (error) {
      debugPrint(
        'Location error: $error',
      );

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
    final userLocation =
        _userLocation;

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
  // FILTER
  // =========================================================

  List<TraditionalFoodPlace>
  _filteredPlaces(
      List<TraditionalFoodPlace>
      places,
      ) {
    final query =
    _searchQuery
        .trim()
        .toLowerCase();

    final result =
    places.where(
          (place) {
        if (query.isNotEmpty) {
          final searchable = [
            place.name,
            place.category,
            place.state,
            place.city ?? '',
            place.address ?? '',
          ].join(' ').toLowerCase();

          if (!searchable.contains(
            query,
          )) {
            return false;
          }
        }

        switch (_halalFilter) {
          case _HalalFilter.all:
            break;

          case _HalalFilter.certified:
            if (place.halalStatus !=
                'certified') {
              return false;
            }
            break;

          case _HalalFilter
              .muslimFriendly:
            if (place.halalStatus !=
                'muslim_friendly') {
              return false;
            }
            break;

          case _HalalFilter.nonHalal:
            if (place.halalStatus !=
                'non_halal') {
              return false;
            }
            break;

          case _HalalFilter.unknown:
            if (place.halalStatus !=
                'unknown') {
              return false;
            }
            break;
        }

        if (_maxDistanceKm != null) {
          final distance =
          _distanceToPlace(
            place,
          );

          if (distance == null ||
              distance >
                  _maxDistanceKm!) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    result.sort(
          (a, b) {
        final aDistance =
        _distanceToPlace(a);

        final bDistance =
        _distanceToPlace(b);

        if (aDistance != null &&
            bDistance != null) {
          return aDistance
              .compareTo(
            bDistance,
          );
        }

        return a.name
            .compareTo(
          b.name,
        );
      },
    );

    return result;
  }

  // =========================================================
  // SELECT
  // =========================================================

  void _selectPlace(
      TraditionalFoodPlace place,
      ) {
    setState(() {
      _selectedPlace = place;
    });

    _mapController.move(
      LatLng(
        place.latitude,
        place.longitude,
      ),
      15,
    );
  }

  // =========================================================
  // NAVIGATE
  // =========================================================

  Future<void> _navigate(
      TraditionalFoodPlace place,
      ) async {
    await openGoogleMapsNavigation(
      context: context,
      latitude:
      place.latitude,
      longitude:
      place.longitude,
    );
  }

  // =========================================================
  // FILTER SHEET
  // =========================================================

  Future<void> _showFilters() async {
    var temporaryHalal =
        _halalFilter;

    double? temporaryDistance =
        _maxDistanceKm;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
          bottomSheetContext,
          ) {
        return StatefulBuilder(
          builder: (
              context,
              setSheetState,
              ) {
            return SafeArea(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'Restaurant Filters',
                      style: GoogleFonts
                          .montserrat(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    Text(
                      'Halal Status',
                      style: GoogleFonts
                          .montserrat(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter
                        in _HalalFilter
                            .values)
                          ChoiceChip(
                            label: Text(
                              filter.label,
                            ),
                            selected:
                            temporaryHalal ==
                                filter,
                            onSelected: (_) {
                              setSheetState(
                                    () {
                                  temporaryHalal =
                                      filter;
                                },
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    Text(
                      'Distance',
                      style: GoogleFonts
                          .montserrat(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label:
                          const Text(
                            'Any Distance',
                          ),
                          selected:
                          temporaryDistance ==
                              null,
                          onSelected: (_) {
                            setSheetState(
                                  () {
                                temporaryDistance =
                                null;
                              },
                            );
                          },
                        ),

                        for (final distance
                        in const <
                            double>[
                          5,
                          10,
                          25,
                          50,
                          100,
                        ])
                          ChoiceChip(
                            label: Text(
                              '${distance.toInt()} km',
                            ),
                            selected:
                            temporaryDistance ==
                                distance,
                            onSelected: (_) {
                              setSheetState(
                                    () {
                                  temporaryDistance =
                                      distance;
                                },
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      FilledButton(
                        onPressed:
                            () async {
                          Navigator.pop(
                            bottomSheetContext,
                          );

                          if (temporaryDistance !=
                              null &&
                              _userLocation ==
                                  null) {
                            final success =
                            await _locateUser(
                              moveMap:
                              false,
                            );

                            if (!success ||
                                !mounted) {
                              return;
                            }
                          }

                          setState(() {
                            _halalFilter =
                                temporaryHalal;

                            _maxDistanceKm =
                                temporaryDistance;

                            _selectedPlace =
                            null;
                          });
                        },
                        child:
                        const Text(
                          'Apply Filters',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final controller =
    ref.watch(
      traditionalFoodDetailControllerProvider(
        food.id,
      ),
    );

    if (controller.isLoading &&
        controller.places.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${food.name} Nearby',
          ),
        ),
        body: const Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    final places =
    _filteredPlaces(
      controller.places,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${food.name} Nearby',
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController:
            _mapController,
            options: MapOptions(
              initialCenter:
              controller
                  .places
                  .isEmpty
                  ? const LatLng(
                4.2105,
                101.9758,
              )
                  : _averageCenter(
                controller
                    .places,
              ),
              initialZoom:
              controller
                  .places
                  .isEmpty
                  ? 6
                  : 10,
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
                  for (final place
                  in places)
                    Marker(
                      point: LatLng(
                        place.latitude,
                        place.longitude,
                      ),
                      width: 48,
                      height: 48,
                      child:
                      GestureDetector(
                        onTap: () {
                          _selectPlace(
                            place,
                          );
                        },
                        child: Container(
                          decoration:
                          BoxDecoration(
                            color:
                            Theme.of(
                              context,
                            )
                                .colorScheme
                                .primary,
                            shape:
                            BoxShape
                                .circle,
                            border:
                            Border.all(
                              color:
                              Colors
                                  .white,
                              width: 3,
                            ),
                          ),
                          child:
                          const Icon(
                            Icons
                                .restaurant_rounded,
                            color:
                            Colors.white,
                          ),
                        ),
                      ),
                    ),

                  if (_userLocation !=
                      null)
                    Marker(
                      point:
                      _userLocation!,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.blue,
                          shape:
                          BoxShape
                              .circle,
                          border:
                          Border.all(
                            color:
                            Colors.white,
                            width: 3,
                          ),
                        ),
                        child:
                        const Icon(
                          Icons.person,
                          color:
                          Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // =================================================
          // SEARCH
          // =================================================

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 4,
                    borderRadius:
                    BorderRadius
                        .circular(
                      16,
                    ),
                    child: TextField(
                      controller:
                      _searchController,
                      onChanged:
                          (value) {
                        setState(() {
                          _searchQuery =
                              value;
                        });
                      },
                      decoration:
                      InputDecoration(
                        hintText:
                        'Search restaurant...',
                        prefixIcon:
                        const Icon(
                          Icons.search,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          borderSide:
                          BorderSide
                              .none,
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                FloatingActionButton
                    .small(
                  heroTag:
                  'foodFilter',
                  onPressed:
                  _showFilters,
                  child: const Icon(
                    Icons.tune,
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // GPS
          // =================================================

          Positioned(
            right: 15,
            bottom:
            _selectedPlace ==
                null
                ? 210
                : 330,
            child:
            FloatingActionButton
                .small(
              heroTag:
              'foodLocation',
              onPressed:
              _locatingUser
                  ? null
                  : () {
                _locateUser();
              },
              child:
              _locatingUser
                  ? const Padding(
                padding:
                EdgeInsets
                    .all(
                  10,
                ),
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : const Icon(
                Icons
                    .my_location,
              ),
            ),
          ),

          // =================================================
          // LIST
          // =================================================

          if (_selectedPlace ==
              null)
            DraggableScrollableSheet(
              initialChildSize:
              0.30,
              minChildSize:
              0.18,
              maxChildSize:
              0.65,
              builder: (
                  context,
                  scrollController,
                  ) {
                return Material(
                  elevation: 16,
                  borderRadius:
                  const BorderRadius
                      .vertical(
                    top:
                    Radius.circular(
                      24,
                    ),
                  ),
                  child: ListView(
                    controller:
                    scrollController,
                    padding:
                    const EdgeInsets
                        .all(
                      12,
                    ),
                    children: [
                      Text(
                        'Places Serving ${food.name}',
                        style: GoogleFonts
                            .montserrat(
                          fontSize: 17,
                          fontWeight:
                          FontWeight
                              .w700,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      if (places
                          .isEmpty)
                        const Padding(
                          padding:
                          EdgeInsets
                              .all(
                            20,
                          ),
                          child: Text(
                            'No restaurants match your filters.',
                            textAlign:
                            TextAlign
                                .center,
                          ),
                        ),

                      for (final place
                      in places)
                        Card(
                          child:
                          ListTile(
                            onTap: () {
                              _selectPlace(
                                place,
                              );
                            },
                            leading:
                            const CircleAvatar(
                              child:
                              Icon(
                                Icons
                                    .restaurant,
                              ),
                            ),
                            title: Text(
                              place.name,
                            ),
                            subtitle:
                            Text(
                              [
                                if (place.city !=
                                    null)
                                  place.city!,
                                place.state,
                                if (_distanceToPlace(
                                  place,
                                ) !=
                                    null)
                                  '${_distanceToPlace(place)!.toStringAsFixed(1)} km',
                              ].join(
                                ' • ',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

          // =================================================
          // SELECTED RESTAURANT
          // =================================================

          if (_selectedPlace !=
              null)
            DraggableScrollableSheet(
              initialChildSize:
              0.44,
              minChildSize:
              0.31,
              maxChildSize:
              0.65,
              builder: (
                  context,
                  scrollController,
                  ) {
                final place =
                _selectedPlace!;

                final isSaved =
                controller
                    .isPlaceFavourite(
                  place.id,
                );

                final isSaving =
                controller
                    .isSavingPlace(
                  place.id,
                );

                return Material(
                  elevation: 16,
                  borderRadius:
                  const BorderRadius
                      .vertical(
                    top:
                    Radius.circular(
                      24,
                    ),
                  ),
                  child: ListView(
                    controller:
                    scrollController,
                    padding:
                    const EdgeInsets
                        .fromLTRB(
                      18,
                      12,
                      18,
                      24,
                    ),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style:
                              GoogleFonts
                                  .montserrat(
                                fontSize:
                                18,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed:
                                () {
                              setState(
                                    () {
                                  _selectedPlace =
                                  null;
                                },
                              );
                            },
                            icon:
                            const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),

                      Text(
                        [
                          if (place.city !=
                              null &&
                              place.city!
                                  .isNotEmpty)
                            place.city!,
                          place.state,
                        ].join(', '),
                      ),

                      if (place.address !=
                          null &&
                          place.address!
                              .isNotEmpty) ...[
                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          place.address!,
                        ),
                      ],

                      const SizedBox(
                        height: 12,
                      ),

                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _Tag(
                            text:
                            _halalLabel(
                              place
                                  .halalStatus,
                            ),
                          ),

                          if (_distanceToPlace(
                            place,
                          ) !=
                              null)
                            _Tag(
                              text:
                              '${_distanceToPlace(place)!.toStringAsFixed(1)} km away',
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      FilledButton.icon(
                        onPressed: () {
                          _navigate(
                            place,
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .navigation_rounded,
                        ),
                        label:
                        const Text(
                          'Navigate with Google Maps',
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      OutlinedButton.icon(
                        onPressed:
                        isSaving
                            ? null
                            : () async {
                          final success =
                          await controller
                              .togglePlaceFavourite(
                            place.id,
                          );

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
                                  controller.errorMessage ??
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
                              content:
                              Text(
                                nowSaved
                                    ? '${place.name} saved.'
                                    : '${place.name} removed from saved.',
                              ),
                            ),
                          );
                        },
                        icon:
                        isSaving
                            ? const SizedBox(
                          width:
                          18,
                          height:
                          18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                          ),
                        )
                            : Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                        label: Text(
                          isSaved
                              ? 'Saved Place'
                              : 'Save Place',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          Positioned(
            left: 5,
            bottom: 4,
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
                style:
                TextStyle(
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
      List<TraditionalFoodPlace>
      places,
      ) {
    var latitude = 0.0;
    var longitude = 0.0;

    for (final place in places) {
      latitude +=
          place.latitude;

      longitude +=
          place.longitude;
    }

    return LatLng(
      latitude / places.length,
      longitude / places.length,
    );
  }
}

// ===========================================================
// TAG
// ===========================================================

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
      BoxDecoration(
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
        const TextStyle(
          fontSize: 10,
        ),
      ),
    );
  }
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