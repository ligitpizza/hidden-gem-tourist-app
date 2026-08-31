import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/traditional_food_detail_controller.dart';
import '../model/traditional_food.dart';
import '../model/traditional_food_place.dart';

enum _HalalFilter {
  all,
  certified,
  muslimFriendly,
  nonHalal,
  unknown,
}

extension _HalalFilterX on _HalalFilter {
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
  ConsumerState<TraditionalFoodNearbyScreen>
  createState() =>
      _TraditionalFoodNearbyScreenState();
}

class _TraditionalFoodNearbyScreenState
    extends ConsumerState<
        TraditionalFoodNearbyScreen> {
  final MapController _mapController =
  MapController();

  final TextEditingController _searchController =
  TextEditingController();

  LatLng? _userLocation;

  bool _locatingUser = false;

  String _searchQuery = '';

  double? _maxDistanceKm;

  _HalalFilter _halalFilter =
      _HalalFilter.all;

  TraditionalFoodPlace? _selectedPlace;

  TraditionalFood get food =>
      widget.food;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
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
      final enabled =
      await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
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
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to calculate nearby food locations.',
              ),
            ),
          );
        }

        return false;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission is permanently denied.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  Geolocator.openAppSettings();
                },
              ),
            ),
          );
        }

        return false;
      }

      final position =
      await Geolocator.getCurrentPosition();

      if (!mounted) {
        return false;
      }

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _userLocation = location;
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
    if (_userLocation == null) {
      return null;
    }

    final metres =
    Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      place.latitude,
      place.longitude,
    );

    return metres / 1000;
  }

  // =========================================================
  // FILTER LOCATIONS
  // =========================================================

  List<TraditionalFoodPlace>
  _filteredPlaces(
      List<TraditionalFoodPlace> places,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    final result = places.where(
          (place) {
        // Search.
        if (query.isNotEmpty) {
          final searchable = [
            place.name,
            place.category,
            place.state,
            place.city ?? '',
            place.address ?? '',
            place.description ?? '',
          ].join(' ').toLowerCase();

          if (!searchable.contains(query)) {
            return false;
          }
        }

        // Halal filter.
        switch (_halalFilter) {
          case _HalalFilter.all:
            break;

          case _HalalFilter.certified:
            if (place.halalStatus !=
                'certified') {
              return false;
            }
            break;

          case _HalalFilter.muslimFriendly:
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

        // Distance filter.
        if (_maxDistanceKm != null) {
          final distance =
          _distanceToPlace(place);

          if (distance == null ||
              distance >
                  _maxDistanceKm!) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    // Nearest first.
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
  // SELECT LOCATION
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
  // OPEN EXTERNAL OSM
  // =========================================================

  Future<void> _openLocation(
      TraditionalFoodPlace place,
      ) async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/'
          '?mlat=${place.latitude}'
          '&mlon=${place.longitude}'
          '#map=17/${place.latitude}/${place.longitude}',
    );

    final opened = await launchUrl(
      uri,
      mode:
      LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this location.',
          ),
        ),
      );
    }
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
      isScrollControlled: true,
      builder: (
          bottomSheetContext,
          ) {
        return StatefulBuilder(
          builder: (
              context,
              setSheetState,
              ) {
            return SafeArea(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Location Filters',
                            style:
                            GoogleFonts.montserrat(
                              fontSize: 21,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(
                                  () {
                                temporaryHalal =
                                    _HalalFilter.all;

                                temporaryDistance =
                                null;
                              },
                            );
                          },
                          child:
                          const Text(
                            'Reset',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Halal Status',
                      style:
                      GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter
                        in _HalalFilter.values)
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

                    const SizedBox(height: 26),

                    Text(
                      'Distance From Me',
                      style:
                      GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

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
                        in const <double>[
                          5,
                          10,
                          25,
                          50,
                          100,
                        ])
                          ChoiceChip(
                            label: Text(
                              'Within ${distance.toInt()} km',
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

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child:
                      FilledButton.icon(
                        onPressed: () async {
                          // Distance needs GPS.
                          if (temporaryDistance !=
                              null &&
                              _userLocation ==
                                  null) {
                            Navigator.pop(
                              bottomSheetContext,
                            );

                            final found =
                            await _locateUser();

                            if (!found ||
                                !mounted) {
                              return;
                            }

                            setState(() {
                              _halalFilter =
                                  temporaryHalal;

                              _maxDistanceKm =
                                  temporaryDistance;

                              _selectedPlace =
                              null;
                            });

                            return;
                          }

                          setState(() {
                            _halalFilter =
                                temporaryHalal;

                            _maxDistanceKm =
                                temporaryDistance;

                            _selectedPlace =
                            null;
                          });

                          Navigator.pop(
                            bottomSheetContext,
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .filter_alt_rounded,
                        ),
                        label:
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
  // FILTER COUNT
  // =========================================================

  int get _filterCount {
    var count = 0;

    if (_halalFilter !=
        _HalalFilter.all) {
      count++;
    }

    if (_maxDistanceKm != null) {
      count++;
    }

    return count;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      traditionalFoodDetailControllerProvider(
        food.id,
      ),
    );

    final places = _filteredPlaces(
      controller.places,
    );

    if (controller.isLoading &&
        controller.places.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Find Nearby',
          ),
        ),
        body: const Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${food.name} Nearby',
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style:
          GoogleFonts.montserrat(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: controller.places.isEmpty
          ? _NoLocations(
        foodName:
        food.name,
      )
          : _buildMap(
        controller.places,
        places,
      ),
    );
  }

  // =========================================================
  // MAP
  // =========================================================

  Widget _buildMap(
      List<TraditionalFoodPlace> allPlaces,
      List<TraditionalFoodPlace> places,
      ) {
    final center =
    _averageCenter(
      allPlaces,
    );

    return Stack(
      children: [
        FlutterMap(
          mapController:
          _mapController,
          options:
          MapOptions(
            initialCenter:
            center,
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
                for (final place
                in places)
                  Marker(
                    point:
                    LatLng(
                      place.latitude,
                      place.longitude,
                    ),
                    width:
                    _selectedPlace?.id ==
                        place.id
                        ? 54
                        : 46,
                    height:
                    _selectedPlace?.id ==
                        place.id
                        ? 54
                        : 46,
                    child:
                    GestureDetector(
                      onTap: () {
                        _selectPlace(
                          place,
                        );
                      },
                      child:
                      _LocationMarker(
                        selected:
                        _selectedPlace?.id ==
                            place.id,
                        halalStatus:
                        place.halalStatus,
                      ),
                    ),
                  ),

                if (_userLocation !=
                    null)
                  Marker(
                    point:
                    _userLocation!,
                    width: 36,
                    height: 36,
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
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // =====================================================
        // SEARCH + FILTER
        // =====================================================

        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            children: [
              Expanded(
                child:
                Material(
                  elevation: 4,
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                  child:
                  TextField(
                    controller:
                    _searchController,
                    onChanged:
                        (value) {
                      setState(() {
                        _searchQuery =
                            value;

                        _selectedPlace =
                        null;
                      });
                    },
                    decoration:
                    InputDecoration(
                      hintText:
                      'Search location...',
                      prefixIcon:
                      const Icon(
                        Icons
                            .search_rounded,
                      ),
                      suffixIcon:
                      _searchQuery
                          .trim()
                          .isEmpty
                          ? null
                          : IconButton(
                        onPressed:
                            () {
                          _searchController
                              .clear();

                          setState(
                                () {
                              _searchQuery =
                              '';

                              _selectedPlace =
                              null;
                            },
                          );
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
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: 52,
                height: 52,
                child:
                Stack(
                  clipBehavior:
                  Clip.none,
                  children: [
                    Positioned.fill(
                      child:
                      FloatingActionButton
                          .small(
                        heroTag:
                        'food-filter',
                        onPressed:
                        _showFilters,
                        child:
                        const Icon(
                          Icons
                              .tune_rounded,
                        ),
                      ),
                    ),

                    if (_filterCount >
                        0)
                      Positioned(
                        right: -3,
                        top: -4,
                        child:
                        Container(
                          width:
                          21,
                          height:
                          21,
                          alignment:
                          Alignment.center,
                          decoration:
                          BoxDecoration(
                            color:
                            Theme.of(
                              context,
                            )
                                .colorScheme
                                .error,
                            shape:
                            BoxShape.circle,
                          ),
                          child:
                          Text(
                            '$_filterCount',
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontSize:
                              10,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // =====================================================
        // GPS BUTTON
        // =====================================================

        Positioned(
          right: 15,
          bottom:
          _selectedPlace ==
              null
              ? 200
              : 275,
          child:
          FloatingActionButton
              .small(
            heroTag:
            'food-location',
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
              EdgeInsets.all(
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
                  .my_location_rounded,
            ),
          ),
        ),

        // =====================================================
        // LIST
        // =====================================================

        if (_selectedPlace == null)
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
              return _LocationsSheet(
                foodName:
                food.name,
                places:
                places,
                scrollController:
                scrollController,
                distanceBuilder:
                _distanceToPlace,
                onSelected:
                _selectPlace,
              );
            },
          ),

        // =====================================================
        // SELECTED LOCATION
        // =====================================================

        if (_selectedPlace != null)
          DraggableScrollableSheet(
            initialChildSize:
            0.36,
            minChildSize:
            0.24,
            maxChildSize:
            0.55,
            builder: (
                context,
                scrollController,
                ) {
              return _SelectedLocationSheet(
                place:
                _selectedPlace!,
                distanceKm:
                _distanceToPlace(
                  _selectedPlace!,
                ),
                scrollController:
                scrollController,
                onClose: () {
                  setState(() {
                    _selectedPlace =
                    null;
                  });
                },
                onOpen: () {
                  _openLocation(
                    _selectedPlace!,
                  );
                },
              );
            },
          ),

        // =====================================================
        // NO FILTER RESULTS
        // =====================================================

        if (places.isEmpty &&
            allPlaces.isNotEmpty)
          Positioned(
            top: 90,
            left: 25,
            right: 25,
            child:
            Card(
              child:
              Padding(
                padding:
                const EdgeInsets.all(
                  20,
                ),
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons
                          .search_off_rounded,
                      size: 38,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      'No locations match your filters.',
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          left: 5,
          bottom: 4,
          child:
          IgnorePointer(
            child:
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
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
                  fontSize: 8,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LatLng _averageCenter(
      List<TraditionalFoodPlace> places,
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
      latitude /
          places.length,
      longitude /
          places.length,
    );
  }
}

// ===========================================================
// LOCATION MARKER
// ===========================================================

class _LocationMarker
    extends StatelessWidget {
  const _LocationMarker({
    required this.selected,
    required this.halalStatus,
  });

  final bool selected;
  final String halalStatus;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration:
      const Duration(
        milliseconds: 160,
      ),
      scale:
      selected ? 1.18 : 1,
      child:
      Container(
        decoration:
        BoxDecoration(
          color:
          _halalColor(
            halalStatus,
          ),
          shape:
          BoxShape.circle,
          border:
          Border.all(
            color:
            Colors.white,
            width:
            selected
                ? 4
                : 3,
          ),
          boxShadow:
          const [
            BoxShadow(
              color:
              Colors.black26,
              blurRadius:
              7,
            ),
          ],
        ),
        child:
        const Icon(
          Icons
              .restaurant_rounded,
          color:
          Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

// ===========================================================
// LOCATION LIST
// ===========================================================

class _LocationsSheet
    extends StatelessWidget {
  const _LocationsSheet({
    required this.foodName,
    required this.places,
    required this.scrollController,
    required this.distanceBuilder,
    required this.onSelected,
  });

  final String foodName;

  final List<TraditionalFoodPlace> places;

  final ScrollController scrollController;

  final double? Function(
      TraditionalFoodPlace place,
      ) distanceBuilder;

  final ValueChanged<
      TraditionalFoodPlace> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 16,
      color:
      colors.surface,
      borderRadius:
      const BorderRadius.vertical(
        top:
        Radius.circular(
          24,
        ),
      ),
      child:
      Column(
        children: [
          const SizedBox(
            height: 9,
          ),

          Container(
            width: 38,
            height: 4,
            decoration:
            BoxDecoration(
              color:
              colors.outlineVariant,
              borderRadius:
              BorderRadius.circular(
                999,
              ),
            ),
          ),

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child:
            Row(
              children: [
                Expanded(
                  child:
                  Text(
                    'Places Serving $foodName',
                    maxLines:
                    1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    GoogleFonts.montserrat(
                      fontSize:
                      17,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                Text(
                  '${places.length}',
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          Expanded(
            child:
            ListView.separated(
              controller:
              scrollController,
              padding:
              const EdgeInsets.all(
                10,
              ),
              itemCount:
              places.length,
              separatorBuilder:
                  (_, _) =>
              const SizedBox(
                height: 8,
              ),
              itemBuilder:
                  (
                  context,
                  index,
                  ) {
                final place =
                places[index];

                return _LocationTile(
                  place:
                  place,
                  distanceKm:
                  distanceBuilder(
                    place,
                  ),
                  onTap:
                      () {
                    onSelected(
                      place,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// LOCATION TILE
// ===========================================================

class _LocationTile
    extends StatelessWidget {
  const _LocationTile({
    required this.place,
    required this.distanceKm,
    required this.onTap,
  });

  final TraditionalFoodPlace place;

  final double? distanceKm;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      color:
      colors.surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      child:
      InkWell(
        onTap:
        onTap,
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        child:
        Padding(
          padding:
          const EdgeInsets.all(
            12,
          ),
          child:
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                _halalColor(
                  place
                      .halalStatus,
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
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      place
                          .name,
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
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
                      [
                        if (place.city !=
                            null &&
                            place.city!
                                .trim()
                                .isNotEmpty)
                          place
                              .city!,
                        place
                            .state,
                      ].join(
                        ', ',
                      ),
                      style:
                      GoogleFonts.inter(
                        fontSize:
                        10,
                        color:
                        colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Wrap(
                      spacing:
                      6,
                      runSpacing:
                      5,
                      children: [
                        _Tag(
                          text:
                          _halalLabel(
                            place
                                .halalStatus,
                          ),
                        ),

                        if (distanceKm !=
                            null)
                          _Tag(
                            text:
                            '${distanceKm!.toStringAsFixed(1)} km away',
                          ),
                      ],
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
// SELECTED LOCATION
// ===========================================================

class _SelectedLocationSheet
    extends StatelessWidget {
  const _SelectedLocationSheet({
    required this.place,
    required this.distanceKm,
    required this.scrollController,
    required this.onClose,
    required this.onOpen,
  });

  final TraditionalFoodPlace place;

  final double? distanceKm;

  final ScrollController scrollController;

  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 16,
      color:
      colors.surface,
      borderRadius:
      const BorderRadius.vertical(
        top:
        Radius.circular(
          24,
        ),
      ),
      child:
      ListView(
        controller:
        scrollController,
        padding:
        const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          24,
        ),
        children: [
          Center(
            child:
            Container(
              width: 38,
              height: 4,
              decoration:
              BoxDecoration(
                color:
                colors.outlineVariant,
                borderRadius:
                BorderRadius.circular(
                  999,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                _halalColor(
                  place
                      .halalStatus,
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
                width: 12,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      place
                          .name,
                      style:
                      GoogleFonts.montserrat(
                        fontSize:
                        18,
                        fontWeight:
                        FontWeight.w700,
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
                          place
                              .city!,
                        place
                            .state,
                      ].join(
                        ', ',
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed:
                onClose,
                icon:
                const Icon(
                  Icons
                      .close_rounded,
                ),
              ),
            ],
          ),

          if (place.address != null &&
              place.address!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height: 14,
            ),

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons
                      .location_on_outlined,
                  size:
                  18,
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child:
                  Text(
                    place.address!,
                  ),
                ),
              ],
            ),
          ],

          if (place.description !=
              null &&
              place.description!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height: 14,
            ),

            Text(
              place.description!,
              style:
              GoogleFonts.inter(
                fontSize: 12,
                height:
                1.45,
              ),
            ),
          ],

          const SizedBox(
            height: 14,
          ),

          Wrap(
            spacing: 7,
            runSpacing:
            7,
            children: [
              _Tag(
                text:
                _halalLabel(
                  place
                      .halalStatus,
                ),
              ),

              _Tag(
                text:
                _displayValue(
                  place
                      .category,
                ),
              ),

              if (distanceKm !=
                  null)
                _Tag(
                  text:
                  '${distanceKm!.toStringAsFixed(1)} km away',
                ),
            ],
          ),

          if (place.verificationSource !=
              null &&
              place.verificationSource!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height: 14,
            ),

            Text(
              'Verified source: ${place.verificationSource}',
              style:
              GoogleFonts.inter(
                fontSize: 10,
                color:
                colors.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(
            height: 20,
          ),

          FilledButton.icon(
            onPressed:
            onOpen,
            icon:
            const Icon(
              Icons
                  .map_outlined,
            ),
            label:
            const Text(
              'Open Location',
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// NO LOCATIONS
// ===========================================================

class _NoLocations
    extends StatelessWidget {
  const _NoLocations({
    required this.foodName,
  });

  final String foodName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          32,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .location_off_outlined,
              size:
              55,
              color:
              Theme.of(
                context,
              )
                  .colorScheme
                  .outline,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'No verified locations for $foodName have been added yet.',
              textAlign:
              TextAlign.center,
              style:
              GoogleFonts.montserrat(
                fontSize:
                17,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// TAG
// ===========================================================

class _Tag
    extends StatelessWidget {
  const _Tag({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        8,
        vertical:
        4,
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
        BorderRadius.circular(
          999,
        ),
      ),
      child:
      Text(
        text,
        style:
        GoogleFonts.inter(
          fontSize:
          9,
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
  final normalized = value
      .replaceAll(
    '_',
    ' ',
  )
      .trim();

  return normalized
      .split(' ')
      .where(
        (word) =>
    word.isNotEmpty,
  )
      .map(
        (word) =>
    word[0].toUpperCase() +
        word.substring(1),
  )
      .join(' ');
}