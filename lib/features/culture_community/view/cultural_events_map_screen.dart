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

enum _EventDateFilter {
  all,
  next7Days,
  next30Days,
}

class CulturalEventsMapScreen extends ConsumerStatefulWidget {
  const CulturalEventsMapScreen({
    super.key,
  });

  @override
  ConsumerState<CulturalEventsMapScreen> createState() =>
      _CulturalEventsMapScreenState();
}

class _CulturalEventsMapScreenState
    extends ConsumerState<CulturalEventsMapScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  bool _showSearch = false;
  String _searchQuery = '';

  CulturalEventCategory? _selectedCategory;

  double? _maxDistanceKm;

  _EventDateFilter _dateFilter = _EventDateFilter.all;

  CulturalEvent? _selectedEvent;

  LatLng? _userLocation;

  bool _locatingUser = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        _tryExistingLocationPermission();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();

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
        await _locateMe(
          requestPermission: false,
          moveMap: false,
        );
      }
    } catch (_) {
      // Location is optional when the map first opens.
    }
  }

  Future<bool> _locateMe({
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
                'Location permission is required to calculate distance.',
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
                'Location permission is permanently denied. '
                    'Please enable it in app settings.',
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

      final position = await Geolocator.getCurrentPosition();

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return false;
      }

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

  double? _distanceFromUser(
      CulturalEvent event,
      ) {
    final userLocation = _userLocation;

    if (userLocation == null) {
      return null;
    }

    final metres = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      event.latitude,
      event.longitude,
    );

    return metres / 1000;
  }

  // =========================================================
  // SEARCH + FILTER
  // =========================================================

  List<CulturalEvent> _filteredEvents(
      List<CulturalEvent> events,
      ) {
    final now = DateTime.now();

    final next7Days = now.add(
      const Duration(days: 7),
    );

    final next30Days = now.add(
      const Duration(days: 30),
    );

    final query = _searchQuery.trim().toLowerCase();

    final filtered = events.where(
          (event) {
        // -----------------------------------------------------
        // SEARCH
        // -----------------------------------------------------

        if (query.isNotEmpty) {
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

          if (!searchableText.contains(query)) {
            return false;
          }
        }

        // -----------------------------------------------------
        // CATEGORY FILTER
        // -----------------------------------------------------

        if (_selectedCategory != null &&
            event.category != _selectedCategory) {
          return false;
        }

        // -----------------------------------------------------
        // DISTANCE FILTER
        // -----------------------------------------------------

        if (_maxDistanceKm != null) {
          final distance = _distanceFromUser(event);

          if (distance == null) {
            return false;
          }

          if (distance > _maxDistanceKm!) {
            return false;
          }
        }

        // -----------------------------------------------------
        // DATE FILTER
        // -----------------------------------------------------

        final eventEnd = event.endAt ?? event.startAt;

        if (_dateFilter == _EventDateFilter.next7Days) {
          if (eventEnd.isBefore(now) ||
              event.startAt.isAfter(next7Days)) {
            return false;
          }
        }

        if (_dateFilter == _EventDateFilter.next30Days) {
          if (eventEnd.isBefore(now) ||
              event.startAt.isAfter(next30Days)) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    // If GPS is available, show nearer events first.
    filtered.sort(
          (a, b) {
        final distanceA = _distanceFromUser(a);
        final distanceB = _distanceFromUser(b);

        if (distanceA != null && distanceB != null) {
          final distanceComparison = distanceA.compareTo(
            distanceB,
          );

          if (distanceComparison != 0) {
            return distanceComparison;
          }
        }

        // Otherwise sort by date.
        return a.startAt.compareTo(
          b.startAt,
        );
      },
    );

    return filtered;
  }

  // =========================================================
  // SEARCH
  // =========================================================

  void _openSearch() {
    setState(() {
      _showSearch = true;
    });

    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        _searchFocusNode.requestFocus();
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _searchQuery = '';
      _showSearch = false;
      _selectedEvent = null;
    });
  }

  void _clearSearchTextOnly() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedEvent = null;
    });

    _searchFocusNode.requestFocus();
  }

  void _submitSearch() {
    final controller = ref.read(
      culturalEventsControllerProvider,
    );

    final matches = _filteredEvents(
      controller.events,
    );

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _searchQuery.trim().isEmpty
                ? 'Enter an event, venue, city or state to search.'
                : 'No cultural events found for "$_searchQuery".',
          ),
        ),
      );

      return;
    }

    _searchFocusNode.unfocus();

    _selectEvent(
      matches.first,
    );
  }

  // =========================================================
  // EVENT SELECTION
  // =========================================================

  void _selectEvent(
      CulturalEvent event,
      ) {
    _searchFocusNode.unfocus();

    setState(() {
      _selectedEvent = event;
    });

    _mapController.move(
      LatLng(
        event.latitude,
        event.longitude,
      ),
      13,
    );
  }

  // =========================================================
  // CATEGORY FILTER
  // =========================================================

  Future<void> _showCategoryFilter() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
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
              children: [
                Text(
                  'Event Category',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(
                    Icons.apps_rounded,
                  ),
                  title: const Text(
                    'All Categories',
                  ),
                  trailing: _selectedCategory == null
                      ? const Icon(
                    Icons.check_rounded,
                  )
                      : null,
                  onTap: () {
                    Navigator.pop(
                      context,
                      -1,
                    );
                  },
                ),

                for (var i = 0;
                i < CulturalEventCategory.values.length;
                i++)
                  ListTile(
                    leading: Icon(
                      _categoryIcon(
                        CulturalEventCategory.values[i],
                      ),
                      color: _categoryColor(
                        CulturalEventCategory.values[i],
                      ),
                    ),
                    title: Text(
                      CulturalEventCategory.values[i].label,
                    ),
                    trailing: _selectedCategory ==
                        CulturalEventCategory.values[i]
                        ? const Icon(
                      Icons.check_rounded,
                    )
                        : null,
                    onTap: () {
                      Navigator.pop(
                        context,
                        i,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (result == -1) {
        _selectedCategory = null;
      } else {
        _selectedCategory =
        CulturalEventCategory.values[result];
      }

      _selectedEvent = null;
    });
  }

  // =========================================================
  // DISTANCE FILTER
  // =========================================================

  Future<void> _showDistanceFilter() async {
    if (_userLocation == null) {
      final found = await _locateMe();

      if (!found) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) {
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
              children: [
                Text(
                  'Distance From Me',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                _DistanceOption(
                  label: 'Any Distance',
                  selected: _maxDistanceKm == null,
                  onTap: () {
                    Navigator.pop(
                      context,
                      -1.0,
                    );
                  },
                ),

                _DistanceOption(
                  label: 'Within 10 km',
                  selected: _maxDistanceKm == 10,
                  onTap: () {
                    Navigator.pop(
                      context,
                      10.0,
                    );
                  },
                ),

                _DistanceOption(
                  label: 'Within 50 km',
                  selected: _maxDistanceKm == 50,
                  onTap: () {
                    Navigator.pop(
                      context,
                      50.0,
                    );
                  },
                ),

                _DistanceOption(
                  label: 'Within 200 km',
                  selected: _maxDistanceKm == 200,
                  onTap: () {
                    Navigator.pop(
                      context,
                      200.0,
                    );
                  },
                ),

                _DistanceOption(
                  label: 'Within 500 km',
                  selected: _maxDistanceKm == 500,
                  onTap: () {
                    Navigator.pop(
                      context,
                      500.0,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (result == -1.0) {
        _maxDistanceKm = null;
      } else {
        _maxDistanceKm = result;
      }

      _selectedEvent = null;
    });
  }

  // =========================================================
  // DATE FILTER
  // =========================================================

  Future<void> _showDateFilter() async {
    final result =
    await showModalBottomSheet<_EventDateFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
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
              children: [
                Text(
                  'Event Date',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                _DateOption(
                  label: 'All Events',
                  value: _EventDateFilter.all,
                  selectedValue: _dateFilter,
                ),

                _DateOption(
                  label: 'Next 7 Days',
                  value: _EventDateFilter.next7Days,
                  selectedValue: _dateFilter,
                ),

                _DateOption(
                  label: 'Next 30 Days',
                  value: _EventDateFilter.next30Days,
                  selectedValue: _dateFilter,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _dateFilter = result;
      _selectedEvent = null;
    });
  }

  // =========================================================
  // CLEAR FILTERS
  // =========================================================

  void _clearAllFilters() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _maxDistanceKm = null;
      _dateFilter = _EventDateFilter.all;
      _selectedEvent = null;
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      culturalEventsControllerProvider,
    );

    final events = _filteredEvents(
      controller.events,
    );

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _selectedEvent = null;
            });
          },
          onSubmitted: (_) {
            _submitSearch();
          },
          decoration: InputDecoration(
            hintText:
            'Search event, venue, city...',
            border: InputBorder.none,
            suffixIcon:
            _searchQuery.trim().isEmpty
                ? null
                : IconButton(
              tooltip: 'Clear',
              onPressed:
              _clearSearchTextOnly,
              icon: const Icon(
                Icons.cancel_rounded,
                size: 20,
              ),
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
            : Text(
          'Cultural Events',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!_showSearch)
            IconButton(
              tooltip: 'Search events',
              onPressed: _openSearch,
              icon: const Icon(
                Icons.search_rounded,
              ),
            )
          else
            IconButton(
              tooltip: 'Close search',
              onPressed: _clearSearch,
              icon: const Icon(
                Icons.close_rounded,
              ),
            ),
        ],
      ),

      body: _buildBody(
        controller: controller,
        events: events,
      ),
    );
  }

  Widget _buildBody({
    required CulturalEventsController controller,
    required List<CulturalEvent> events,
  }) {
    // ========================================================
    // LOADING
    // ========================================================

    if (controller.isLoading &&
        controller.events.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ========================================================
    // ERROR
    // ========================================================

    if (controller.errorMessage != null &&
        controller.events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 50,
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

    return Stack(
      children: [
        // =====================================================
        // OPENSTREETMAP
        // =====================================================

        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(
              4.2105,
              101.9758,
            ),
            initialZoom: 5.5,
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
                // ---------------------------------------------
                // EVENT MARKERS
                // ---------------------------------------------

                for (final event in events)
                  Marker(
                    point: LatLng(
                      event.latitude,
                      event.longitude,
                    ),
                    width:
                    _selectedEvent?.id == event.id
                        ? 58
                        : 48,
                    height:
                    _selectedEvent?.id == event.id
                        ? 58
                        : 48,
                    child: GestureDetector(
                      onTap: () {
                        _selectEvent(event);
                      },
                      child: _EventMapMarker(
                        category: event.category,
                        selected:
                        _selectedEvent?.id ==
                            event.id,
                      ),
                    ),
                  ),

                // ---------------------------------------------
                // USER LOCATION
                // ---------------------------------------------

                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 34,
                    height: 34,
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
                            blurRadius: 7,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons
                            .person_pin_circle_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // =====================================================
        // FILTER BAR
        // =====================================================

        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _buildFilters(),
        ),

        // =====================================================
        // SEARCH RESULTS
        // =====================================================

        if (_showSearch &&
            _searchQuery.trim().isNotEmpty)
          Positioned(
            top: 66,
            left: 12,
            right: 12,
            child: _SearchResultsPanel(
              query: _searchQuery,
              events: events,
              distanceBuilder: _distanceFromUser,
              onEventSelected: _selectEvent,
            ),
          ),

        // =====================================================
        // GPS BUTTON
        // =====================================================

        Positioned(
          right: 16,
          bottom:
          _selectedEvent == null ? 32 : 180,
          child: FloatingActionButton.small(
            heroTag: 'culture-location',
            backgroundColor:
            Theme.of(context)
                .colorScheme
                .surface,
            foregroundColor:
            Theme.of(context)
                .colorScheme
                .primary,
            onPressed: _locatingUser
                ? null
                : () {
              _locateMe();
            },
            child: _locatingUser
                ? const Padding(
              padding: EdgeInsets.all(11),
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
        // NO RESULTS
        // =====================================================

        if (events.isEmpty &&
            !(_showSearch &&
                _searchQuery.trim().isNotEmpty))
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_busy_outlined,
                      size: 38,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'No events match these filters.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: _clearAllFilters,
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
        // EVENT PREVIEW SHEET
        // =====================================================

        if (_selectedEvent != null)
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.20,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [
              0.20,
              0.55,
              0.88,
            ],
            builder: (
                context,
                scrollController,
                ) {
              return _EventDetailsSheet(
                event: _selectedEvent!,
                distanceKm: _distanceFromUser(
                  _selectedEvent!,
                ),
                scrollController:
                scrollController,

                onClose: () {
                  setState(() {
                    _selectedEvent = null;
                  });
                },

                // =============================================
                // GO TO FULL DETAILS PAGE
                // =============================================

                onViewDetails: () {
                  context.push(
                    CultureCommunityRoutes
                        .eventDetail,
                    extra: _selectedEvent!,
                  );
                },
              );
            },
          ),

        // =====================================================
        // OSM ATTRIBUTION
        // =====================================================

        Positioned(
          left: 6,
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

  // =========================================================
  // FILTER BUTTON BAR
  // =========================================================

  Widget _buildFilters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _MapFilterButton(
            label:
            _selectedCategory?.label ??
                'Category',
            active:
            _selectedCategory != null,
            icon: Icons
                .keyboard_arrow_down_rounded,
            onPressed:
            _showCategoryFilter,
          ),

          const SizedBox(width: 8),

          _MapFilterButton(
            label:
            _maxDistanceKm == null
                ? 'Distance'
                : '${_maxDistanceKm!.toInt()} km',
            active:
            _maxDistanceKm != null,
            icon: Icons
                .keyboard_arrow_down_rounded,
            onPressed:
            _showDistanceFilter,
          ),

          const SizedBox(width: 8),

          _MapFilterButton(
            label: _dateFilterLabel(),
            active:
            _dateFilter !=
                _EventDateFilter.all,
            icon:
            Icons.calendar_today_outlined,
            onPressed:
            _showDateFilter,
          ),
        ],
      ),
    );
  }

  String _dateFilterLabel() {
    switch (_dateFilter) {
      case _EventDateFilter.all:
        return 'Date';

      case _EventDateFilter.next7Days:
        return 'Next 7 Days';

      case _EventDateFilter.next30Days:
        return 'Next 30 Days';
    }
  }
}

// ===========================================================
// SEARCH RESULTS PANEL
// ===========================================================

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.query,
    required this.events,
    required this.distanceBuilder,
    required this.onEventSelected,
  });

  final String query;

  final List<CulturalEvent> events;

  final double? Function(
      CulturalEvent event,
      ) distanceBuilder;

  final ValueChanged<CulturalEvent>
  onEventSelected;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: colors.surface,
      borderRadius:
      BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300,
        ),
        child: events.isEmpty
            ? Padding(
          padding:
          const EdgeInsets.all(
            20,
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                color: colors.outline,
                size: 34,
              ),

              const SizedBox(height: 8),

              Text(
                'No events found for "$query"',
                textAlign:
                TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Try an event name, venue, city, state or category.',
                textAlign:
                TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        )
            : Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Padding(
              padding:
              const EdgeInsets
                  .fromLTRB(
                16,
                12,
                16,
                8,
              ),
              child: Row(
                children: [
                  Text(
                    '${events.length} '
                        'event${events.length == 1 ? '' : 's'} found',
                    style:
                    GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                      FontWeight
                          .w700,
                      color: colors
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Flexible(
              child:
              ListView.separated(
                padding:
                EdgeInsets.zero,
                shrinkWrap: true,
                itemCount:
                events.length,
                separatorBuilder:
                    (_, __) =>
                const Divider(
                  height: 1,
                ),
                itemBuilder:
                    (context, index) {
                  final event =
                  events[index];

                  final distance =
                  distanceBuilder(
                    event,
                  );

                  return ListTile(
                    leading:
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                      BoxDecoration(
                        color:
                        _categoryColor(
                          event.category,
                        ),
                        shape: BoxShape
                            .circle,
                      ),
                      child: Icon(
                        _categoryIcon(
                          event.category,
                        ),
                        color:
                        Colors.white,
                        size: 19,
                      ),
                    ),

                    title: Text(
                      event.name,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      GoogleFonts
                          .inter(
                        fontWeight:
                        FontWeight
                            .w700,
                        fontSize: 13,
                      ),
                    ),

                    subtitle: Text(
                      [
                        if (event.city !=
                            null &&
                            event.city!
                                .trim()
                                .isNotEmpty)
                          event.city!,
                        event.state,
                        if (distance !=
                            null)
                          '${distance.toStringAsFixed(1)} km away',
                      ].join(' • '),
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      GoogleFonts
                          .inter(
                        fontSize: 11,
                      ),
                    ),

                    trailing:
                    const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),

                    onTap: () {
                      onEventSelected(
                        event,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// MAP MARKER
// ===========================================================

class _EventMapMarker extends StatelessWidget {
  const _EventMapMarker({
    required this.category,
    required this.selected,
  });

  final CulturalEventCategory category;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color =
    _categoryColor(category);

    return AnimatedScale(
      duration: const Duration(
        milliseconds: 180,
      ),
      scale:
      selected ? 1.18 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width:
            selected ? 4 : 2.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _categoryIcon(
            category,
          ),
          color: Colors.white,
          size:
          selected ? 25 : 21,
        ),
      ),
    );
  }
}

// ===========================================================
// FILTER BUTTON
// ===========================================================

class _MapFilterButton extends StatelessWidget {
  const _MapFilterButton({
    required this.label,
    required this.active,
    required this.icon,
    required this.onPressed,
  });

  final String label;

  final bool active;

  final IconData icon;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: active
          ? colors.primary
          : colors.surface,
      elevation: 2,
      borderRadius:
      BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius:
        BorderRadius.circular(24),
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              24,
            ),
            border: Border.all(
              color: active
                  ? colors.primary
                  : colors
                  .outlineVariant,
            ),
          ),
          child: Row(
            children: [
              ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth: 150,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                    color: active
                        ? colors
                        .onPrimary
                        : colors
                        .onSurface,
                  ),
                ),
              ),

              const SizedBox(width: 5),

              Icon(
                icon,
                size: 18,
                color: active
                    ? colors.onPrimary
                    : colors.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// EVENT PREVIEW SHEET
// ===========================================================

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({
    required this.event,
    required this.distanceKm,
    required this.scrollController,
    required this.onClose,
    required this.onViewDetails,
  });

  final CulturalEvent event;

  final double? distanceKm;

  final ScrollController
  scrollController;

  final VoidCallback onClose;

  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 16,
      borderRadius:
      const BorderRadius.vertical(
        top: Radius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ===================================================
          // DRAG HANDLE
          // ===================================================

          Padding(
            padding:
            const EdgeInsets.only(
              top: 10,
              bottom: 8,
            ),
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

          Expanded(
            child: ListView(
              controller:
              scrollController,
              padding:
              const EdgeInsets
                  .fromLTRB(
                16,
                4,
                16,
                32,
              ),
              children: [
                // =============================================
                // IMAGE
                // =============================================

                Stack(
                  children: [
                    SizedBox(
                      width:
                      double.infinity,
                      height: 190,
                      child: ClipRRect(
                        borderRadius:
                        BorderRadius
                            .circular(
                          18,
                        ),
                        child:
                        _EventImage(
                          imageUrl:
                          event
                              .imageUrl,
                          category:
                          event
                              .category,
                        ),
                      ),
                    ),

                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal:
                          10,
                          vertical: 6,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          _categoryColor(
                            event
                                .category,
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
                              color:
                              Colors
                                  .white,
                              size: 14,
                            ),

                            const SizedBox(
                              width: 5,
                            ),

                            Text(
                              event
                                  .category
                                  .label
                                  .toUpperCase(),
                              style:
                              GoogleFonts
                                  .inter(
                                color: Colors
                                    .white,
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

                    Positioned(
                      right: 8,
                      top: 8,
                      child:
                      IconButton
                          .filledTonal(
                        tooltip:
                        'Close',
                        onPressed:
                        onClose,
                        icon:
                        const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                // =============================================
                // EVENT NAME
                // =============================================

                Text(
                  event.name,
                  style:
                  GoogleFonts.montserrat(
                    fontSize: 25,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    colors.primary,
                    height: 1.15,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // =============================================
                // DATE + SCHEDULE
                // =============================================

                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Expanded(
                      child:
                      _EventInfoBox(
                        icon: Icons
                            .calendar_today_outlined,
                        label: 'DATE',
                        value:
                        _formatEventDateRange(
                          event.startAt,
                          event.endAt,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                      _EventInfoBox(
                        icon: Icons
                            .schedule_outlined,
                        label:
                        'SCHEDULE',
                        value:
                        event.scheduleNote ??
                            'Check organiser schedule',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                // =============================================
                // VENUE
                // =============================================

                _EventVenueBox(
                  event: event,
                  distanceKm:
                  distanceKm,
                ),

                const SizedBox(
                  height: 22,
                ),

                // =============================================
                // DESCRIPTION
                // =============================================

                Text(
                  'SIGNIFICANCE & HIGHLIGHTS',
                  style:
                  GoogleFonts.inter(
                    fontSize: 12,
                    letterSpacing:
                    0.7,
                    fontWeight:
                    FontWeight.w700,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  event.description,
                  style:
                  GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.55,
                    color: colors
                        .onSurface,
                  ),
                ),

                // =============================================
                // TAGS
                // =============================================

                if (event
                    .travelStyles
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 20,
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final style
                      in event
                          .travelStyles)
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal:
                            10,
                            vertical: 6,
                          ),
                          decoration:
                          BoxDecoration(
                            color: colors
                                .surfaceContainer,
                            borderRadius:
                            BorderRadius
                                .circular(
                              999,
                            ),
                            border:
                            Border.all(
                              color: colors
                                  .outlineVariant,
                            ),
                          ),
                          child: Text(
                            '#${_displayTravelStyle(style)}',
                            style:
                            GoogleFonts
                                .inter(
                              fontSize: 11,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(
                  height: 24,
                ),

                // =============================================
                // FULL DETAILS BUTTON
                // =============================================

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  FilledButton.icon(
                    onPressed:
                    onViewDetails,
                    icon:
                    const Icon(
                      Icons
                          .open_in_new_rounded,
                    ),
                    label:
                    const Text(
                      'View Full Details',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 30,
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
// DATE / SCHEDULE INFO BOX
// ===========================================================

class _EventInfoBox extends StatelessWidget {
  const _EventInfoBox({
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
      padding:
      const EdgeInsets.all(12),
      constraints:
      const BoxConstraints(
        minHeight: 92,
      ),
      decoration: BoxDecoration(
        color:
        colors.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color:
            const Color(0xFF735C00),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  label,
                  style:
                  GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w600,
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
                  GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
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
// VENUE BOX
// ===========================================================

class _EventVenueBox extends StatelessWidget {
  const _EventVenueBox({
    required this.event,
    required this.distanceKm,
  });

  final CulturalEvent event;

  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration: BoxDecoration(
        color:
        colors.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
          colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color:
            Color(0xFF735C00),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  'VENUE',
                  style:
                  GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w600,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  event.venueName,
                  style:
                  GoogleFonts.inter(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                if (event.address !=
                    null &&
                    event.address!
                        .trim()
                        .isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      top: 3,
                    ),
                    child: Text(
                      event.address!,
                      style:
                      GoogleFonts
                          .inter(
                        fontSize: 12,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ),

                Padding(
                  padding:
                  const EdgeInsets
                      .only(
                    top: 3,
                  ),
                  child: Text(
                    event.city != null &&
                        event.city!
                            .trim()
                            .isNotEmpty
                        ? '${event.city}, ${event.state}'
                        : event.state,
                    style:
                    GoogleFonts.inter(
                      fontSize: 12,
                      color: colors
                          .onSurfaceVariant,
                    ),
                  ),
                ),

                if (distanceKm !=
                    null)
                  Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      top: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .near_me_outlined,
                          size: 15,
                          color: colors
                              .primary,
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Flexible(
                          child: Text(
                            '${distanceKm!.toStringAsFixed(1)} km from your current location',
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
                        ),
                      ],
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
// EVENT IMAGE
// ===========================================================

class _EventImage extends StatelessWidget {
  const _EventImage({
    required this.imageUrl,
    required this.category,
  });

  final String? imageUrl;

  final CulturalEventCategory category;

  @override
  Widget build(BuildContext context) {
    final url =
    imageUrl?.trim();

    if (url == null ||
        url.isEmpty) {
      return _fallback(
        context,
      );
    }

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

  Widget _fallback(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
          Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _categoryColor(
              category,
            ).withValues(
              alpha: 0.78,
            ),
            colors
                .surfaceContainerHighest,
          ],
        ),
      ),
      alignment:
      Alignment.center,
      child: Icon(
        _categoryIcon(
          category,
        ),
        size: 58,
        color: Colors.white,
      ),
    );
  }
}

// ===========================================================
// DISTANCE OPTION
// ===========================================================

class _DistanceOption extends StatelessWidget {
  const _DistanceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
      ),
      trailing: selected
          ? const Icon(
        Icons.check_rounded,
      )
          : null,
      onTap: onTap,
    );
  }
}

// ===========================================================
// DATE OPTION
// ===========================================================

class _DateOption extends StatelessWidget {
  const _DateOption({
    required this.label,
    required this.value,
    required this.selectedValue,
  });

  final String label;

  final _EventDateFilter value;

  final _EventDateFilter selectedValue;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
      ),
      trailing: value ==
          selectedValue
          ? const Icon(
        Icons.check_rounded,
      )
          : null,
      onTap: () {
        Navigator.pop(
          context,
          value,
        );
      },
    );
  }
}

// ===========================================================
// CATEGORY COLOR
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
// CATEGORY ICON
// ===========================================================

IconData _categoryIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons
          .festival_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons
          .theater_comedy_rounded;

    case CulturalEventCategory.communityActivity:
      return Icons
          .groups_rounded;
  }
}

// ===========================================================
// DATE FORMAT
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

  return '${startDate.day} '
      '${months[startDate.month - 1]} '
      '${startDate.year} – '
      '${endDate.day} '
      '${months[endDate.month - 1]} '
      '${endDate.year}';
}

// ===========================================================
// TAG FORMAT
// ===========================================================

String _displayTravelStyle(
    String value,
    ) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() +
      value.substring(1);
}