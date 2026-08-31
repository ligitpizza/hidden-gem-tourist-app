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
  ConsumerState<TraditionalFoodNearbyScreen> createState() =>
      _TraditionalFoodNearbyScreenState();
}

class _TraditionalFoodNearbyScreenState
    extends ConsumerState<TraditionalFoodNearbyScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _searchController =
  TextEditingController();

  LatLng? _userLocation;

  bool _locatingUser = false;

  String _searchQuery = '';

  double? _maxDistanceKm;

  _HalalFilter _halalFilter = _HalalFilter.all;

  TraditionalFoodPlace? _selectedPlace;

  TraditionalFood get food => widget.food;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryExistingLocationPermission();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // LOCATION
  // =========================================================

  Future<void> _tryExistingLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await _locateUser(
          requestPermission: false,
          moveMap: false,
        );
      }
    } catch (_) {
      // GPS is optional when the page first opens.
    }
  }

  Future<bool> _locateUser({
    bool requestPermission = true,
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
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please turn on location services first.',
              ),
            ),
          );
        }

        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied &&
          requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to calculate nearby restaurants.',
              ),
            ),
          );
        }

        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not determine your current location.',
            ),
          ),
        );
      }

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

    final metres = Geolocator.distanceBetween(
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

  List<TraditionalFoodPlace> _filteredPlaces(
      List<TraditionalFoodPlace> places,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    final filtered = places.where(
          (place) {
        // Search
        if (query.isNotEmpty) {
          final searchableText = [
            place.name,
            place.category,
            place.city ?? '',
            place.state,
            _halalStatusLabel(
              place.halalStatus,
            ),
          ].join(' ').toLowerCase();

          if (!searchableText.contains(query)) {
            return false;
          }
        }

        // Halal status
        switch (_halalFilter) {
          case _HalalFilter.all:
            break;

          case _HalalFilter.certified:
            if (place.halalStatus != 'certified') {
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
            if (place.halalStatus != 'non_halal') {
              return false;
            }
            break;

          case _HalalFilter.unknown:
            if (place.halalStatus != 'unknown') {
              return false;
            }
            break;
        }

        // Distance
        if (_maxDistanceKm != null) {
          final distance =
          _distanceToPlace(place);

          if (distance == null ||
              distance > _maxDistanceKm!) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    // Nearest first when GPS is available.
    filtered.sort(
          (a, b) {
        final distanceA = _distanceToPlace(a);
        final distanceB = _distanceToPlace(b);

        if (distanceA != null &&
            distanceB != null) {
          final result =
          distanceA.compareTo(distanceB);

          if (result != 0) {
            return result;
          }
        }

        return a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        );
      },
    );

    return filtered;
  }

  // =========================================================
  // SELECT RESTAURANT
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
  // EXTERNAL MAP
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

    final success = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the map application.',
          ),
        ),
      );
    }
  }

  // =========================================================
  // FILTER SHEET
  // =========================================================

  Future<void> _showFilters() async {
    var temporaryHalal = _halalFilter;

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Restaurant Filters',
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
                            setSheetState(() {
                              temporaryHalal =
                                  _HalalFilter.all;

                              temporaryDistance =
                              null;
                            });
                          },
                          child: const Text(
                            'Reset',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

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
                              setSheetState(() {
                                temporaryHalal =
                                    filter;
                              });
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
                          label: const Text(
                            'Any Distance',
                          ),
                          selected:
                          temporaryDistance ==
                              null,
                          onSelected: (_) {
                            setSheetState(() {
                              temporaryDistance =
                              null;
                            });
                          },
                        ),
                        for (final distance
                        in <double>[
                          5,
                          10,
                          25,
                          50,
                        ])
                          ChoiceChip(
                            label: Text(
                              'Within ${distance.toInt()} km',
                            ),
                            selected:
                            temporaryDistance ==
                                distance,
                            onSelected: (_) {
                              setSheetState(() {
                                temporaryDistance =
                                    distance;
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () async {
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
                        icon: const Icon(
                          Icons
                              .filter_alt_rounded,
                        ),
                        label: const Text(
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
  // ACTIVE FILTER COUNT
  // =========================================================

  int get _activeFilterCount {
    var count = 0;

    if (_halalFilter != _HalalFilter.all) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${food.name} Nearby',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(
        controller: controller,
        places: places,
      ),
    );
  }

  Widget _buildBody({
    required TraditionalFoodDetailController controller,
    required List<TraditionalFoodPlace> places,
  }) {
    if (controller.isLoading &&
        controller.places.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.errorMessage != null &&
        controller.places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.refresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.places.isEmpty) {
      return _NoRestaurants(
        foodName: food.name,
      );
    }

    final mapCenter = _initialCenter(
      controller.places,
    );

    return Stack(
      children: [
        // =====================================================
        // MAP
        // =====================================================

        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
            _userLocation ?? mapCenter,
            initialZoom:
            _userLocation == null ? 11 : 13,
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
                    width:
                    _selectedPlace?.placeId ==
                        place.placeId
                        ? 52
                        : 44,
                    height:
                    _selectedPlace?.placeId ==
                        place.placeId
                        ? 52
                        : 44,
                    child: GestureDetector(
                      onTap: () {
                        _selectPlace(
                          place,
                        );
                      },
                      child: _RestaurantMarker(
                        selected:
                        _selectedPlace?.placeId ==
                            place.placeId,
                        halalStatus:
                        place.halalStatus,
                      ),
                    ),
                  ),

                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons
                            .person_pin_circle_rounded,
                        color: Colors.white,
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
                child: Material(
                  elevation: 4,
                  borderRadius:
                  BorderRadius.circular(16),
                  child: TextField(
                    controller:
                    _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _selectedPlace = null;
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                      'Search restaurant...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                      ),
                      suffixIcon:
                      _searchQuery.trim().isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          _searchController
                              .clear();

                          setState(() {
                            _searchQuery = '';
                            _selectedPlace =
                            null;
                          });
                        },
                        icon: const Icon(
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

              const SizedBox(width: 9),

              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child:
                      FloatingActionButton.small(
                        heroTag:
                        'food-nearby-filter',
                        onPressed:
                        _showFilters,
                        child: const Icon(
                          Icons.tune_rounded,
                        ),
                      ),
                    ),

                    if (_activeFilterCount > 0)
                      Positioned(
                        right: -3,
                        top: -4,
                        child: Container(
                          width: 21,
                          height: 21,
                          alignment:
                          Alignment.center,
                          decoration:
                          BoxDecoration(
                            color:
                            Theme.of(context)
                                .colorScheme
                                .error,
                            shape:
                            BoxShape.circle,
                            border:
                            Border.all(
                              color:
                              Theme.of(context)
                                  .colorScheme
                                  .surface,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$_activeFilterCount',
                            style:
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
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
        // RESULT COUNT
        // =====================================================

        Positioned(
          top: 76,
          left: 12,
          child: Material(
            elevation: 2,
            borderRadius:
            BorderRadius.circular(999),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              child: Text(
                '${places.length} restaurant${places.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),

        // =====================================================
        // GPS
        // =====================================================

        Positioned(
          right: 15,
          bottom:
          _selectedPlace == null ? 210 : 275,
          child: FloatingActionButton.small(
            heroTag: 'food-nearby-location',
            onPressed:
            _locatingUser
                ? null
                : () {
              _locateUser();
            },
            child: _locatingUser
                ? const Padding(
              padding:
              EdgeInsets.all(10),
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.my_location_rounded,
            ),
          ),
        ),

        // =====================================================
        // RESTAURANT LIST
        // =====================================================

        if (_selectedPlace == null)
          DraggableScrollableSheet(
            initialChildSize: 0.26,
            minChildSize: 0.18,
            maxChildSize: 0.62,
            snap: true,
            snapSizes: const [
              0.18,
              0.26,
              0.62,
            ],
            builder: (
                context,
                scrollController,
                ) {
              return _RestaurantListSheet(
                foodName: food.name,
                places: places,
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
        // SELECTED RESTAURANT
        // =====================================================

        if (_selectedPlace != null)
          DraggableScrollableSheet(
            initialChildSize: 0.31,
            minChildSize: 0.22,
            maxChildSize: 0.46,
            snap: true,
            builder: (
                context,
                scrollController,
                ) {
              return _SelectedRestaurantSheet(
                place: _selectedPlace!,
                distanceKm:
                _distanceToPlace(
                  _selectedPlace!,
                ),
                scrollController:
                scrollController,
                onClose: () {
                  setState(() {
                    _selectedPlace = null;
                  });
                },
                onOpenLocation: () {
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
            controller.places.isNotEmpty)
          Positioned(
            top: 120,
            left: 24,
            right: 24,
            child: Card(
              child: Padding(
                padding:
                const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons
                          .restaurant_menu_outlined,
                      size: 38,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No restaurants match your filters.',
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchController
                            .clear();

                        setState(() {
                          _searchQuery = '';
                          _halalFilter =
                              _HalalFilter.all;
                          _maxDistanceKm = null;
                          _selectedPlace = null;
                        });
                      },
                      child: const Text(
                        'Clear Filters',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // =====================================================
        // OSM ATTRIBUTION
        // =====================================================

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
    );
  }

  LatLng _initialCenter(
      List<TraditionalFoodPlace> places,
      ) {
    if (places.isEmpty) {
      return const LatLng(
        4.2105,
        101.9758,
      );
    }

    var lat = 0.0;
    var lng = 0.0;

    for (final place in places) {
      lat += place.latitude;
      lng += place.longitude;
    }

    return LatLng(
      lat / places.length,
      lng / places.length,
    );
  }
}

// ===========================================================
// RESTAURANT MARKER
// ===========================================================

class _RestaurantMarker extends StatelessWidget {
  const _RestaurantMarker({
    required this.selected,
    required this.halalStatus,
  });

  final bool selected;
  final String halalStatus;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration:
      const Duration(milliseconds: 160),
      scale: selected ? 1.17 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _halalMarkerColor(
            halalStatus,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: selected ? 4 : 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 7,
            ),
          ],
        ),
        child: const Icon(
          Icons.restaurant_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

// ===========================================================
// RESTAURANT LIST SHEET
// ===========================================================

class _RestaurantListSheet
    extends StatelessWidget {
  const _RestaurantListSheet({
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

  final ValueChanged<TraditionalFoodPlace>
  onSelected;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      elevation: 16,
      color: colors.surface,
      borderRadius:
      const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 9),

          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius:
              BorderRadius.circular(999),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Where to Find $foodName',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${places.length}',
                  style: GoogleFonts.inter(
                    fontWeight:
                    FontWeight.w700,
                    color:
                    colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: places.isEmpty
                ? const Center(
              child: Text(
                'No restaurants found.',
              ),
            )
                : ListView.separated(
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
                  (context, index) {
                final place =
                places[index];

                return _RestaurantListTile(
                  place: place,
                  distanceKm:
                  distanceBuilder(
                    place,
                  ),
                  onTap: () {
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
// RESTAURANT LIST TILE
// ===========================================================

class _RestaurantListTile extends StatelessWidget {
  const _RestaurantListTile({
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
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(14),
        child: Padding(
          padding:
          const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _halalMarkerColor(
                    place.halalStatus,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 20,
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
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      GoogleFonts.inter(
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
                        if (place.state
                            .trim()
                            .isNotEmpty)
                          place.state,
                      ].join(', '),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      GoogleFonts.inter(
                        fontSize: 10,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _RestaurantTag(
                          label:
                          _halalStatusLabel(
                            place.halalStatus,
                          ),
                        ),
                        if (distanceKm !=
                            null)
                          _RestaurantTag(
                            label:
                            '${distanceKm!.toStringAsFixed(1)} km',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// SELECTED RESTAURANT
// ===========================================================

class _SelectedRestaurantSheet
    extends StatelessWidget {
  const _SelectedRestaurantSheet({
    required this.place,
    required this.distanceKm,
    required this.scrollController,
    required this.onClose,
    required this.onOpenLocation,
  });

  final TraditionalFoodPlace place;
  final double? distanceKm;

  final ScrollController scrollController;

  final VoidCallback onClose;
  final VoidCallback onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      elevation: 16,
      color: colors.surface,
      borderRadius:
      const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      child: ListView(
        controller: scrollController,
        padding:
        const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          24,
        ),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius:
                BorderRadius.circular(
                  999,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _halalMarkerColor(
                    place.halalStatus,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style:
                      GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      [
                        if (place.city != null &&
                            place.city!
                                .trim()
                                .isNotEmpty)
                          place.city!,
                        place.state,
                      ].join(', '),
                      style:
                      GoogleFonts.inter(
                        fontSize: 12,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _RestaurantTag(
                label: _halalStatusLabel(
                  place.halalStatus,
                ),
              ),

              if (place.category
                  .trim()
                  .isNotEmpty)
                _RestaurantTag(
                  label: place.category,
                ),

              if (distanceKm != null)
                _RestaurantTag(
                  label:
                  '${distanceKm!.toStringAsFixed(1)} km away',
                ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenLocation,
              icon: const Icon(
                Icons.map_outlined,
              ),
              label: const Text(
                'Open Location',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// TAG
// ===========================================================

class _RestaurantTag extends StatelessWidget {
  const _RestaurantTag({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
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
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }
}

// ===========================================================
// NO RESTAURANTS
// ===========================================================

class _NoRestaurants extends StatelessWidget {
  const _NoRestaurants({
    required this.foodName,
  });

  final String foodName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .location_off_outlined,
              size: 55,
              color: Theme.of(context)
                  .colorScheme
                  .outline,
            ),
            const SizedBox(height: 14),
            Text(
              'No restaurants for $foodName have been added yet.',
              textAlign:
              TextAlign.center,
              style:
              GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Restaurant locations will appear here once they are linked to this traditional food.',
              textAlign:
              TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
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

    default:
      return 'Status Unknown';
  }
}

// ===========================================================
// MARKER COLOR
// ===========================================================

Color _halalMarkerColor(
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