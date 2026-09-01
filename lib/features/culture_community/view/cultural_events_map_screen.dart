import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../controller/cultural_events_controller.dart';
import '../model/cultural_event.dart';
import 'culture_community_routes.dart';
import 'google_maps_navigation.dart';

enum _EventDateFilter {
  all,
  today,
  next7Days,
  next30Days,
}

extension _EventDateFilterX on _EventDateFilter {
  String get label {
    switch (this) {
      case _EventDateFilter.all:
        return 'All Dates';

      case _EventDateFilter.today:
        return 'Today';

      case _EventDateFilter.next7Days:
        return 'Next 7 Days';

      case _EventDateFilter.next30Days:
        return 'Next 30 Days';
    }
  }
}

class CulturalEventsMapScreen
    extends ConsumerStatefulWidget {
  const CulturalEventsMapScreen({
    super.key,
  });

  @override
  ConsumerState<CulturalEventsMapScreen>
  createState() =>
      _CulturalEventsMapScreenState();
}

class _CulturalEventsMapScreenState
    extends ConsumerState<CulturalEventsMapScreen> {
  final MapController _mapController =
  MapController();

  final TextEditingController _searchController =
  TextEditingController();

  LatLng? _userLocation;

  bool _locatingUser = false;

  String _searchQuery = '';

  final Set<CulturalEventCategory>
  _selectedCategories = {};

  double? _maxDistanceKm;

  _EventDateFilter _dateFilter =
      _EventDateFilter.all;

  CulturalEvent? _selectedEvent;

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
  // LOCATION
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
          ScaffoldMessenger.of(context).showSnackBar(
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

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required for nearby event distance.',
              ),
            ),
          );
        }

        return false;
      }

      if (permission ==
          LocationPermission.deniedForever) {
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
          12,
        );
      }

      return true;
    } catch (error) {
      debugPrint(
        'Cultural event location error: $error',
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
  // EVENT DISTANCE
  // =========================================================

  double? _distanceToEvent(
      CulturalEvent event,
      ) {
    final userLocation = _userLocation;

    if (userLocation == null) {
      return null;
    }

    final metres =
    Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      event.latitude,
      event.longitude,
    );

    return metres / 1000;
  }

  // =========================================================
  // GOOGLE MAPS NAVIGATION
  // =========================================================

  Future<void> _navigateToEvent(
      CulturalEvent event,
      ) async {
    await openGoogleMapsNavigation(
      context: context,
      latitude: event.latitude,
      longitude: event.longitude,
    );
  }

  // =========================================================
  // DATE FILTER
  // =========================================================

  bool _matchesDateFilter(
      CulturalEvent event,
      ) {
    if (_dateFilter ==
        _EventDateFilter.all) {
      return true;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final eventStart =
    event.startAt.toLocal();

    final eventEnd =
        event.endAt?.toLocal() ??
            eventStart;

    switch (_dateFilter) {
      case _EventDateFilter.all:
        return true;

      case _EventDateFilter.today:
        final tomorrow =
        today.add(
          const Duration(days: 1),
        );

        return eventEnd.isAfter(today) &&
            eventStart.isBefore(tomorrow);

      case _EventDateFilter.next7Days:
        final limit =
        today.add(
          const Duration(days: 7),
        );

        return eventEnd.isAfter(today) &&
            eventStart.isBefore(limit);

      case _EventDateFilter.next30Days:
        final limit =
        today.add(
          const Duration(days: 30),
        );

        return eventEnd.isAfter(today) &&
            eventStart.isBefore(limit);
    }
  }

  // =========================================================
  // FILTER
  // =========================================================

  List<CulturalEvent> _filteredEvents(
      List<CulturalEvent> events,
      ) {
    final query =
    _searchQuery.trim().toLowerCase();

    final now = DateTime.now();

    final result = events.where(
          (event) {
        // Extra protection against expired events.
        final endAt =
            event.endAt ??
                event.startAt;

        if (endAt.isBefore(now)) {
          return false;
        }

        if (query.isNotEmpty) {
          final searchable = [
            event.name,
            event.description,
            event.venueName,
            event.state,
            event.city ?? '',
            event.address ?? '',
            event.category.label,
          ].join(' ').toLowerCase();

          if (!searchable.contains(query)) {
            return false;
          }
        }

        if (_selectedCategories
            .isNotEmpty &&
            !_selectedCategories.contains(
              event.category,
            )) {
          return false;
        }

        if (!_matchesDateFilter(event)) {
          return false;
        }

        if (_maxDistanceKm != null) {
          final distance =
          _distanceToEvent(event);

          if (distance == null ||
              distance > _maxDistanceKm!) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    // Nearby first when GPS exists.
    result.sort(
          (a, b) {
        final distanceA =
        _distanceToEvent(a);

        final distanceB =
        _distanceToEvent(b);

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

        return a.startAt.compareTo(
          b.startAt,
        );
      },
    );

    return result;
  }

  // =========================================================
  // SELECT EVENT
  // =========================================================

  void _selectEvent(
      CulturalEvent event,
      ) {
    setState(() {
      _selectedEvent = event;
    });

    _mapController.move(
      LatLng(
        event.latitude,
        event.longitude,
      ),
      14,
    );
  }

  // =========================================================
  // FILTER SHEET
  // =========================================================

  Future<void> _showFilters() async {
    final temporaryCategories =
    Set<CulturalEventCategory>.from(
      _selectedCategories,
    );

    var temporaryDate = _dateFilter;

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
                  26,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Event Filters',
                            style:
                            GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),

                        TextButton(
                          onPressed: () {
                            setSheetState(
                                  () {
                                temporaryCategories
                                    .clear();

                                temporaryDate =
                                    _EventDateFilter
                                        .all;

                                temporaryDistance =
                                null;
                              },
                            );
                          },
                          child: const Text(
                            'Reset',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Category',
                      style:
                      GoogleFonts.montserrat(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category
                        in CulturalEventCategory
                            .values)
                          FilterChip(
                            label: Text(
                              category.label,
                            ),
                            selected:
                            temporaryCategories
                                .contains(
                              category,
                            ),
                            onSelected: (
                                selected,
                                ) {
                              setSheetState(
                                    () {
                                  if (selected) {
                                    temporaryCategories
                                        .add(
                                      category,
                                    );
                                  } else {
                                    temporaryCategories
                                        .remove(
                                      category,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Date',
                      style:
                      GoogleFonts.montserrat(
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
                        in _EventDateFilter.values)
                          ChoiceChip(
                            label: Text(
                              filter.label,
                            ),
                            selected:
                            temporaryDate ==
                                filter,
                            onSelected: (_) {
                              setSheetState(
                                    () {
                                  temporaryDate =
                                      filter;
                                },
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Distance From Me',
                      style:
                      GoogleFonts.montserrat(
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
                          10,
                          25,
                          50,
                          100,
                          300,
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

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(
                            bottomSheetContext,
                          );

                          if (temporaryDistance !=
                              null &&
                              _userLocation == null) {
                            final success =
                            await _locateUser(
                              moveMap: false,
                            );

                            if (!success ||
                                !mounted) {
                              return;
                            }
                          }

                          setState(() {
                            _selectedCategories
                              ..clear()
                              ..addAll(
                                temporaryCategories,
                              );

                            _dateFilter =
                                temporaryDate;

                            _maxDistanceKm =
                                temporaryDistance;

                            _selectedEvent = null;
                          });
                        },
                        icon: const Icon(
                          Icons.filter_alt_rounded,
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

  int get _filterCount {
    var count =
        _selectedCategories.length;

    if (_dateFilter !=
        _EventDateFilter.all) {
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
      culturalEventsControllerProvider,
    );

    if (controller.isLoading &&
        controller.events.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cultural Events Map',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final events =
    _filteredEvents(
      controller.events,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cultural Events Map',
          style:
          GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(
                4.2105,
                101.9758,
              ),
              initialZoom: 6,
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
                  for (final event in events)
                    Marker(
                      point: LatLng(
                        event.latitude,
                        event.longitude,
                      ),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          _selectEvent(
                            event,
                          );
                        },
                        child: _EventMarker(
                          event: event,
                          selected:
                          _selectedEvent?.id ==
                              event.id,
                        ),
                      ),
                    ),

                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ===================================================
          // SEARCH BAR
          // ===================================================

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
                    BorderRadius.circular(
                      16,
                    ),
                    child: TextField(
                      controller:
                      _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _selectedEvent = null;
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                        'Search cultural events...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
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

                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FloatingActionButton.small(
                      heroTag:
                      'event-filter-button',
                      onPressed: _showFilters,
                      child: const Icon(
                        Icons.tune_rounded,
                      ),
                    ),

                    if (_filterCount > 0)
                      Positioned(
                        right: -3,
                        top: -5,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor:
                          Theme.of(context)
                              .colorScheme
                              .error,
                          child: Text(
                            '$_filterCount',
                            style:
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ===================================================
          // GPS BUTTON
          // ===================================================

          Positioned(
            right: 15,
            bottom:
            _selectedEvent == null
                ? 210
                : 320,
            child: FloatingActionButton.small(
              heroTag:
              'event-current-location',
              onPressed: _locatingUser
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

          // ===================================================
          // EVENT LIST
          // ===================================================

          if (_selectedEvent == null)
            DraggableScrollableSheet(
              initialChildSize: 0.30,
              minChildSize: 0.18,
              maxChildSize: 0.65,
              builder: (
                  context,
                  scrollController,
                  ) {
                return _EventListSheet(
                  events: events,
                  scrollController:
                  scrollController,
                  distanceBuilder:
                  _distanceToEvent,
                  onSelected:
                  _selectEvent,
                );
              },
            ),

          // ===================================================
          // SELECTED EVENT
          // ===================================================

          if (_selectedEvent != null)
            DraggableScrollableSheet(
              initialChildSize: 0.44,
              minChildSize: 0.30,
              maxChildSize: 0.68,
              builder: (
                  context,
                  scrollController,
                  ) {
                return _SelectedEventSheet(
                  event: _selectedEvent!,
                  distanceKm:
                  _distanceToEvent(
                    _selectedEvent!,
                  ),
                  scrollController:
                  scrollController,
                  onClose: () {
                    setState(() {
                      _selectedEvent = null;
                    });
                  },

                  // Google Maps.
                  onNavigate: () {
                    _navigateToEvent(
                      _selectedEvent!,
                    );
                  },

                  // Event Details.
                  onDetails: () {
                    context.push(
                      CultureCommunityRoutes
                          .eventDetail,
                      extra:
                      _selectedEvent!,
                    );
                  },
                );
              },
            ),

          if (events.isEmpty)
            Positioned(
              top: 90,
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
                        Icons.event_busy_rounded,
                        size: 40,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'No upcoming events match your filters.',
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
// EVENT MARKER
// ===========================================================

class _EventMarker extends StatelessWidget {
  const _EventMarker({
    required this.event,
    required this.selected,
  });

  final CulturalEvent event;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration:
      const Duration(milliseconds: 150),
      scale: selected ? 1.18 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _categoryColor(
            event.category,
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
        child: Icon(
          _categoryIcon(
            event.category,
          ),
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

// ===========================================================
// EVENT LIST
// ===========================================================

class _EventListSheet extends StatelessWidget {
  const _EventListSheet({
    required this.events,
    required this.scrollController,
    required this.distanceBuilder,
    required this.onSelected,
  });

  final List<CulturalEvent> events;

  final ScrollController scrollController;

  final double? Function(
      CulturalEvent,
      ) distanceBuilder;

  final ValueChanged<CulturalEvent>
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
      child: Column(
        children: [
          const SizedBox(height: 9),

          Container(
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
                    'Upcoming Events',
                    style:
                    GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                Text(
                  '${events.length}',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView.separated(
              controller:
              scrollController,
              padding:
              const EdgeInsets.all(10),
              itemCount: events.length,
              separatorBuilder:
                  (_, _) =>
              const SizedBox(
                height: 8,
              ),
              itemBuilder: (
                  context,
                  index,
                  ) {
                final event =
                events[index];

                final distance =
                distanceBuilder(
                  event,
                );

                return ListTile(
                  onTap: () {
                    onSelected(event);
                  },
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  tileColor: colors
                      .surfaceContainerLow,
                  leading: CircleAvatar(
                    backgroundColor:
                    _categoryColor(
                      event.category,
                    ),
                    child: Icon(
                      _categoryIcon(
                        event.category,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    event.name,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    [
                      _formatDate(
                        event.startAt,
                      ),
                      event.state,
                      if (distance != null)
                        '${distance.toStringAsFixed(1)} km',
                    ].join(' • '),
                  ),
                  trailing: const Icon(
                    Icons
                        .chevron_right_rounded,
                  ),
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
// SELECTED EVENT
// ===========================================================

class _SelectedEventSheet
    extends StatelessWidget {
  const _SelectedEventSheet({
    required this.event,
    required this.distanceKm,
    required this.scrollController,
    required this.onClose,
    required this.onNavigate,
    required this.onDetails,
  });

  final CulturalEvent event;

  final double? distanceKm;

  final ScrollController scrollController;

  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onDetails;

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
                color:
                colors.outlineVariant,
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
              CircleAvatar(
                radius: 25,
                backgroundColor:
                _categoryColor(
                  event.category,
                ),
                child: Icon(
                  _categoryIcon(
                    event.category,
                  ),
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
                      event.name,
                      style:
                      GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      event.category.label,
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

          const SizedBox(height: 15),

          _InfoRow(
            icon: Icons
                .calendar_today_outlined,
            text: _formatEventDateRange(
              event,
            ),
          ),

          const SizedBox(height: 10),

          _InfoRow(
            icon:
            Icons.location_on_outlined,
            text: [
              event.venueName,
              if (event.city != null)
                event.city!,
              event.state,
            ].join(', '),
          ),

          if (distanceKm != null) ...[
            const SizedBox(height: 10),

            _InfoRow(
              icon:
              Icons.near_me_outlined,
              text:
              '${distanceKm!.toStringAsFixed(1)} km from your location',
            ),
          ],

          if (event.description
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 15),

            Text(
              event.description,
              maxLines: 4,
              overflow:
              TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                height: 1.45,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ===================================================
          // GOOGLE MAPS
          // ===================================================

          FilledButton.icon(
            onPressed: onNavigate,
            icon: const Icon(
              Icons.navigation_rounded,
            ),
            label: const Text(
              'Navigate with Google Maps',
            ),
          ),

          const SizedBox(height: 9),

          // ===================================================
          // FULL EVENT DETAILS
          // ===================================================

          OutlinedButton.icon(
            onPressed: onDetails,
            icon: const Icon(
              Icons.info_outline_rounded,
            ),
            label: const Text(
              'View Full Details',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
          size: 18,
          color:
          Theme.of(context)
              .colorScheme
              .primary,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// EVENT CATEGORY HELPERS
// ===========================================================

Color _categoryColor(
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

    case CulturalEventCategory.communityActivity:
      return const Color(
        0xFF1B7F5C,
      );
  }
}

IconData _categoryIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons.celebration_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons.theater_comedy_rounded;

    case CulturalEventCategory.communityActivity:
      return Icons.groups_rounded;
  }
}

// ===========================================================
// DATE HELPERS
// ===========================================================

String _formatDate(
    DateTime date,
    ) {
  final local = date.toLocal();

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
  final start = event.startAt.toLocal();

  final end = event.endAt?.toLocal();

  if (end == null) {
    return _formatDate(start);
  }

  final sameDate =
      start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;

  if (sameDate) {
    return _formatDate(start);
  }

  return '${_formatDate(start)} - '
      '${_formatDate(end)}';
}