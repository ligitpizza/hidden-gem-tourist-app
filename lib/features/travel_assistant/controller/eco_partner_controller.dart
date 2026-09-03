import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../model/eco_partner.dart';
import '../model/eco_partner_repository.dart';

enum EcoPartnerLayout { list, grid2, grid4 }

enum EcoPartnerSort { recommended, nameAscending, nameDescending }

enum EcoPartnerHomeSection { recommended, hotel, dining, transport, ev }

typedef EcoCurrentLocationLoader = Future<EcoDestination> Function();

/// Coordinates Eco Partner searches and exposes presentation-ready state.
class EcoPartnerController extends ChangeNotifier {
  EcoPartnerController({
    EcoPartnerRepositoryContract? repository,
    EcoCurrentLocationLoader? currentLocationLoader,
  }) : _repository = repository ?? EcoPartnerRepository(),
       _currentLocationLoader =
           currentLocationLoader ?? _loadDeviceCurrentLocation;

  final EcoPartnerRepositoryContract _repository;
  final EcoCurrentLocationLoader _currentLocationLoader;

  EcoPartnerSearchResult? result;
  String filter = 'All';
  EcoPartnerAreaMode areaMode = EcoPartnerAreaMode.nearby;
  String stateFilter = 'All Malaysia';
  EcoPartnerSort sort = EcoPartnerSort.recommended;
  double radiusSelection = 10;
  String? error;
  bool isLoading = false;
  bool isLoadingImages = false;
  EcoPartnerLayout layout = EcoPartnerLayout.list;
  int currentPage = 0;
  int _requestId = 0;
  EcoPartnerSearchResult? _initialResult;
  List<EcoPartner> _suggestionCatalog = const [];
  EcoDestination? _userLocation;
  _EcoPartnerBrowseSnapshot? _browseSnapshot;
  EcoPartnerSearchResult? _latestBrowseResult;
  bool _isExplicitSearch = false;
  String activeSearchTerm = '';
  static const standardPageSize = 10;
  static const compactPageSize = 8;
  static const suggestionLimit = 6;
  static const homeSectionLimit = 8;

  int get effectivePageSize =>
      layout == EcoPartnerLayout.grid4 ? compactPageSize : standardPageSize;

  EcoPartnerSearchScope get searchScope => switch (areaMode) {
    EcoPartnerAreaMode.nearby => EcoPartnerSearchScope.nearby(radiusSelection),
    EcoPartnerAreaMode.statewide when stateFilter == 'All Malaysia' =>
      const EcoPartnerSearchScope.nationwide(),
    EcoPartnerAreaMode.statewide => EcoPartnerSearchScope.state(stateFilter),
  };
  bool get isExplicitSearch => _isExplicitSearch;
  bool get isUsingCurrentLocation =>
      !_isExplicitSearch && result?.destination.label == 'Current location';
  bool get hasUserLocation => _userLocation != null;
  bool get showsUserDistance =>
      _userLocation != null && (_isExplicitSearch || isUsingCurrentLocation);
  double? get activeNearbyRadius {
    final mode = _browseSnapshot?.areaMode ?? areaMode;
    if (mode != EcoPartnerAreaMode.nearby) return null;
    return _browseSnapshot?.radiusSelection ?? radiusSelection;
  }

  bool isOutsideBrowseRadius(EcoPartner partner) {
    final radius = activeNearbyRadius;
    return _isExplicitSearch &&
        _userLocation != null &&
        radius != null &&
        partner.distanceKm > radius;
  }

  String get scopeLabel => _isExplicitSearch
      ? 'across Malaysia'
      : switch (searchScope.type) {
          EcoPartnerSearchScopeType.nearby =>
            'within ${radiusSelection.round()} km',
          EcoPartnerSearchScopeType.state => 'in $stateFilter',
          EcoPartnerSearchScopeType.nationwide => 'across Malaysia',
        };

  static const malaysiaStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Kuala Lumpur',
    'Labuan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Penang',
    'Perak',
    'Perlis',
    'Putrajaya',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
  ];

  List<String> get availableStates => malaysiaStates;

  List<EcoPartner> get filteredPartners {
    final values = (result?.partners ?? const <EcoPartner>[])
        .where(_matchesActiveSearch)
        .where((partner) => _isExplicitSearch || _matchesFilter(partner))
        .toList();
    switch (sort) {
      case EcoPartnerSort.recommended:
        break;
      case EcoPartnerSort.nameAscending:
        values.sort(
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        );
        break;
      case EcoPartnerSort.nameDescending:
        values.sort(
          (first, second) =>
              second.name.toLowerCase().compareTo(first.name.toLowerCase()),
        );
        break;
    }
    return values;
  }

  List<EcoPartner> get visiblePartners {
    final values = filteredPartners;
    final start = currentPage * effectivePageSize;
    if (start >= values.length) return const [];
    final end = start + effectivePageSize > values.length
        ? values.length
        : start + effectivePageSize;
    return values.sublist(start, end);
  }

  int get totalPages => (filteredPartners.length / effectivePageSize).ceil();

  bool get showSectionedHome =>
      !_isExplicitSearch && activeSearchTerm.trim().isEmpty && filter == 'All';

  List<EcoPartner> partnersForHomeSection(EcoPartnerHomeSection section) {
    final ranked = result?.partners ?? const <EcoPartner>[];
    if (section == EcoPartnerHomeSection.recommended) {
      return _diversifiedRecommendations(ranked);
    }
    final partners = ranked.where((partner) {
      return switch (section) {
        EcoPartnerHomeSection.hotel =>
          partner.category == EcoPartnerCategory.stay,
        EcoPartnerHomeSection.dining =>
          partner.category == EcoPartnerCategory.dining,
        EcoPartnerHomeSection.transport =>
          partner.category == EcoPartnerCategory.transport &&
              partner.subtype != 'EV charging',
        EcoPartnerHomeSection.ev =>
          partner.category == EcoPartnerCategory.transport &&
              partner.subtype == 'EV charging',
        EcoPartnerHomeSection.recommended => false,
      };
    }).toList();
    _sortBySelection(partners);
    return partners.take(homeSectionLimit).toList();
  }

  void showAllForHomeSection(EcoPartnerHomeSection section) {
    final targetFilter = switch (section) {
      EcoPartnerHomeSection.hotel => 'Stay',
      EcoPartnerHomeSection.dining => 'Dining',
      EcoPartnerHomeSection.transport => 'Public Transport',
      EcoPartnerHomeSection.ev => 'EV Charging',
      EcoPartnerHomeSection.recommended => null,
    };
    if (targetFilter != null) selectFilter(targetFilter);
  }

  List<EcoPartner> _diversifiedRecommendations(List<EcoPartner> ranked) {
    final recommendations = <EcoPartner>[];
    final addedIds = <String>{};
    void addFirst(bool Function(EcoPartner partner) matches) {
      final partner = ranked.where(matches).firstOrNull;
      if (partner != null && addedIds.add(partner.id)) {
        recommendations.add(partner);
      }
    }

    addFirst((partner) => partner.category == EcoPartnerCategory.stay);
    addFirst((partner) => partner.category == EcoPartnerCategory.dining);
    addFirst(
      (partner) =>
          partner.category == EcoPartnerCategory.transport &&
          partner.subtype != 'EV charging',
    );
    addFirst(
      (partner) =>
          partner.category == EcoPartnerCategory.transport &&
          partner.subtype == 'EV charging',
    );
    for (final partner in ranked) {
      if (recommendations.length == homeSectionLimit) break;
      if (addedIds.add(partner.id)) recommendations.add(partner);
    }
    return recommendations;
  }

  void _sortBySelection(List<EcoPartner> partners) {
    switch (sort) {
      case EcoPartnerSort.recommended:
        break;
      case EcoPartnerSort.nameAscending:
        partners.sort(
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        );
      case EcoPartnerSort.nameDescending:
        partners.sort(
          (first, second) =>
              second.name.toLowerCase().compareTo(first.name.toLowerCase()),
        );
    }
  }

  bool _matchesActiveSearch(EcoPartner partner) {
    final query = _normalize(activeSearchTerm);
    return query.isEmpty || _normalize(partner.name).contains(query);
  }

  bool _matchesFilter(EcoPartner partner) => switch (filter) {
    'Stay' => partner.category == EcoPartnerCategory.stay,
    'Dining' => partner.category == EcoPartnerCategory.dining,
    'Public Transport' =>
      partner.category == EcoPartnerCategory.transport &&
          partner.subtype != 'EV charging',
    'EV Charging' =>
      partner.category == EcoPartnerCategory.transport &&
          partner.subtype == 'EV charging',
    _ => true,
  };

  List<EcoPartner> suggestionsFor(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.length < 2) return const [];
    final unique = <String, EcoPartner>{};
    for (final partner in _suggestionCatalog) {
      final normalizedName = _normalize(partner.name);
      if (normalizedName.contains(normalizedQuery)) {
        unique.putIfAbsent(normalizedName, () => partner);
      }
    }
    final suggestions = unique.values.toList()
      ..sort((first, second) {
        final firstName = _normalize(first.name);
        final secondName = _normalize(second.name);
        final firstStarts = firstName.startsWith(normalizedQuery);
        final secondStarts = secondName.startsWith(normalizedQuery);
        if (firstStarts != secondStarts) return firstStarts ? -1 : 1;
        return firstName.compareTo(secondName);
      });
    return suggestions.take(suggestionLimit).toList();
  }

  Future<void> loadInitialRecommendations({bool refresh = false}) async {
    final requestId = ++_requestId;
    activeSearchTerm = '';
    _isExplicitSearch = false;
    _browseSnapshot = null;
    areaMode = EcoPartnerAreaMode.statewide;
    stateFilter = 'All Malaysia';
    currentPage = 0;
    result = null;
    _beginRequest();
    try {
      final initial = await _repository.searchCoordinates(
        const EcoDestination('Malaysia', 4.2105, 101.9758),
        refresh: refresh,
        scope: const EcoPartnerSearchScope.nationwide(),
        includeImages: false,
      );
      result = initial;
      _initialResult = initial;
      _latestBrowseResult = initial;
      _suggestionCatalog = List.unmodifiable(initial.partners);
      _finishRequest();
      _loadImages(requestId, cacheAsInitial: true);
    } on EcoSearchException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Could not load Eco Partner recommendations. Please retry.';
    } finally {
      if (isLoading) _finishRequest();
    }
  }

  Future<void> search(String query, {bool refresh = false}) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      await clearSearch();
      return;
    }
    final exactSuggestion = suggestionsFor(clean)
        .where((partner) => _normalize(partner.name) == _normalize(clean))
        .firstOrNull;
    if (exactSuggestion != null) {
      await searchSuggestion(exactSuggestion, query: clean, refresh: refresh);
      return;
    }
    _saveBrowseSnapshot();
    final requestId = ++_requestId;
    _isExplicitSearch = true;
    activeSearchTerm = clean;
    currentPage = 0;
    _beginRequest();
    try {
      final catalogResult = await _nationwideCatalogForSearch(refresh: refresh);
      if (requestId != _requestId) return;
      final normalizedQuery = _normalize(clean);
      final matches = catalogResult.partners
          .where(
            (partner) => _normalize(partner.name).contains(normalizedQuery),
          )
          .toList();
      result = EcoPartnerSearchResult(
        destination: const EcoDestination(
          'Eco Partner name search',
          4.2105,
          101.9758,
        ),
        partners: _withUserDistances(matches),
        warnings: catalogResult.warnings,
      );
      currentPage = 0;
      _finishRequest();
    } on EcoSearchException catch (exception) {
      if (requestId != _requestId) return;
      _restoreBrowseSnapshot();
      error = exception.message;
    } catch (_) {
      if (requestId != _requestId) return;
      _restoreBrowseSnapshot();
      error = 'Search failed. Check your connection and retry.';
    } finally {
      if (isLoading) _finishRequest();
    }
  }

  Future<void> searchSuggestion(
    EcoPartner partner, {
    String? query,
    bool refresh = false,
  }) async {
    _saveBrowseSnapshot();
    ++_requestId;
    _isExplicitSearch = true;
    activeSearchTerm = (query ?? partner.name).trim();
    currentPage = 0;
    _beginRequest();
    result = EcoPartnerSearchResult(
      destination: const EcoDestination(
        'Eco Partner name search',
        4.2105,
        101.9758,
      ),
      partners: _withUserDistances([partner]),
    );
    _finishRequest();
  }

  Future<void> clearSearch() async {
    ++_requestId;
    activeSearchTerm = '';
    error = null;
    if (_browseSnapshot != null) {
      _restoreBrowseSnapshot();
      isLoading = false;
      isLoadingImages = false;
      notifyListeners();
      return;
    }
    _isExplicitSearch = false;
    currentPage = 0;
    final cachedBrowse = _latestBrowseResult ?? _initialResult;
    if (cachedBrowse == null) {
      await loadInitialRecommendations();
      return;
    }
    result = cachedBrowse;
    isLoading = false;
    isLoadingImages = false;
    notifyListeners();
  }

  Future<bool> useCurrentLocation({bool silentPermissionDenial = false}) async {
    final requestId = ++_requestId;
    _beginRequest();
    try {
      final userLocation = await _currentLocationLoader();
      final locationResult = await _repository.searchCoordinates(
        userLocation,
        scope: searchScope,
        includeImages: false,
      );
      _userLocation = userLocation;
      _isExplicitSearch = false;
      _browseSnapshot = null;
      result = locationResult;
      _latestBrowseResult = locationResult;
      activeSearchTerm = '';
      currentPage = 0;
      _finishRequest();
      _loadImages(requestId);
      return true;
    } on EcoSearchException catch (exception) {
      error = silentPermissionDenial ? null : exception.message;
      return false;
    } catch (_) {
      error = silentPermissionDenial
          ? null
          : 'Could not retrieve your current location.';
      return false;
    } finally {
      if (isLoading) _finishRequest();
    }
  }

  Future<void> retry({String fallbackQuery = ''}) async {
    if (_isExplicitSearch) {
      await search(activeSearchTerm, refresh: true);
      return;
    }
    final destination = result?.destination;
    if (destination == null) {
      await search(fallbackQuery, refresh: true);
      return;
    }
    final requestId = ++_requestId;
    _beginRequest();
    try {
      final refreshed = await _repository.searchCoordinates(
        destination,
        refresh: true,
        scope: searchScope,
        includeImages: false,
      );
      result = refreshed;
      _latestBrowseResult = refreshed;
      currentPage = 0;
      _finishRequest();
      _loadImages(requestId);
    } catch (_) {
      error = 'Retry failed. Check your connection.';
    } finally {
      if (isLoading) _finishRequest();
    }
  }

  void selectFilter(String value) {
    if (filter == value) return;
    filter = value;
    currentPage = 0;
    notifyListeners();
  }

  void selectState(String value) {
    if (stateFilter == value) return;
    stateFilter = value;
    currentPage = 0;
    notifyListeners();
  }

  void selectSort(EcoPartnerSort value) {
    if (sort == value) return;
    sort = value;
    currentPage = 0;
    notifyListeners();
  }

  void selectLayout(EcoPartnerLayout value) {
    if (layout == value) return;
    layout = value;
    currentPage = 0;
    notifyListeners();
  }

  void goToPage(int value) {
    if (value < 0 || value >= totalPages || value == currentPage) return;
    currentPage = value;
    notifyListeners();
  }

  Future<void> selectRadius(
    double value, {
    String fallbackQuery = '',
    bool reload = true,
  }) async {
    if (_isExplicitSearch) await clearSearch();
    if (radiusSelection == value) return;
    radiusSelection = value;
    notifyListeners();
    if (reload && result != null) {
      await retry(fallbackQuery: fallbackQuery);
    }
  }

  Future<void> applySearchArea({
    required EcoPartnerAreaMode mode,
    required double radius,
    required String state,
    String fallbackQuery = '',
    bool useCurrentLocation = false,
  }) async {
    if (_isExplicitSearch) await clearSearch();
    final previousMode = areaMode;
    final previousRadius = radiusSelection;
    final previousState = stateFilter;
    final previousPage = currentPage;
    final changed =
        areaMode != mode || radiusSelection != radius || stateFilter != state;
    areaMode = mode;
    radiusSelection = radius;
    stateFilter = state;
    if (changed) {
      currentPage = 0;
      notifyListeners();
    }
    if (useCurrentLocation) {
      final succeeded = await this.useCurrentLocation();
      if (!succeeded) {
        areaMode = previousMode;
        radiusSelection = previousRadius;
        stateFilter = previousState;
        currentPage = previousPage;
        notifyListeners();
      }
    } else if (changed && result != null) {
      await retry(fallbackQuery: fallbackQuery);
    }
  }

  void _saveBrowseSnapshot() {
    if (_browseSnapshot != null || _isExplicitSearch) return;
    _browseSnapshot = _EcoPartnerBrowseSnapshot(
      result: result ?? _latestBrowseResult,
      filter: filter,
      areaMode: areaMode,
      stateFilter: stateFilter,
      sort: sort,
      radiusSelection: radiusSelection,
      layout: layout,
      currentPage: currentPage,
    );
  }

  void _restoreBrowseSnapshot() {
    final snapshot = _browseSnapshot;
    _browseSnapshot = null;
    _isExplicitSearch = false;
    activeSearchTerm = '';
    if (snapshot == null) {
      result = _latestBrowseResult ?? _initialResult;
      currentPage = 0;
      return;
    }
    result = snapshot.result ?? _latestBrowseResult ?? _initialResult;
    filter = snapshot.filter;
    areaMode = snapshot.areaMode;
    stateFilter = snapshot.stateFilter;
    sort = snapshot.sort;
    radiusSelection = snapshot.radiusSelection;
    layout = snapshot.layout;
    currentPage = snapshot.currentPage;
  }

  Future<EcoPartnerSearchResult> _nationwideCatalogForSearch({
    required bool refresh,
  }) async {
    if (_suggestionCatalog.isNotEmpty && !refresh) {
      return EcoPartnerSearchResult(
        destination: const EcoDestination('Malaysia', 4.2105, 101.9758),
        partners: _suggestionCatalog,
        warnings: _initialResult?.warnings ?? const [],
      );
    }
    final cachedCatalog = _suggestionCatalog;
    try {
      final nationwide = await _repository.searchCoordinates(
        const EcoDestination('Malaysia', 4.2105, 101.9758),
        refresh: refresh,
        scope: const EcoPartnerSearchScope.nationwide(),
        includeImages: false,
      );
      if (nationwide.partners.isNotEmpty || cachedCatalog.isEmpty) {
        _suggestionCatalog = List.unmodifiable(nationwide.partners);
        _initialResult = nationwide;
        return nationwide;
      }
    } catch (_) {
      if (cachedCatalog.isEmpty) rethrow;
    }
    return EcoPartnerSearchResult(
      destination: const EcoDestination('Malaysia', 4.2105, 101.9758),
      partners: cachedCatalog,
      warnings: _initialResult?.warnings ?? const [],
    );
  }

  List<EcoPartner> _withUserDistances(Iterable<EcoPartner> partners) {
    final origin = _userLocation;
    if (origin == null) return List.unmodifiable(partners);
    return partners
        .map(
          (partner) => partner.withDistance(
            EcoPartnerRepository.distanceKm(
              origin.latitude,
              origin.longitude,
              partner.latitude,
              partner.longitude,
            ),
          ),
        )
        .toList(growable: false);
  }

  void _beginRequest() {
    isLoading = true;
    isLoadingImages = false;
    error = null;
    notifyListeners();
  }

  void _finishRequest() {
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadImages(int requestId, {bool cacheAsInitial = false}) async {
    final current = result;
    if (current == null || requestId != _requestId) return;
    isLoadingImages = true;
    notifyListeners();
    final enriched = await _repository.enrichResult(
      current,
      scope: searchScope,
    );
    if (requestId != _requestId) return;
    result = enriched;
    if (cacheAsInitial) {
      _initialResult = enriched;
      _suggestionCatalog = List.unmodifiable(enriched.partners);
    }
    if (!_isExplicitSearch) _latestBrowseResult = enriched;
    isLoadingImages = false;
    notifyListeners();
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static Future<EcoDestination> _loadDeviceCurrentLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const EcoSearchException('Location permission is required.');
    }
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw const EcoSearchException(
        'Could not determine your current location. Please try again.',
      );
    }
    return EcoDestination(
      'Current location',
      position.latitude,
      position.longitude,
    );
  }
}

class _EcoPartnerBrowseSnapshot {
  const _EcoPartnerBrowseSnapshot({
    required this.result,
    required this.filter,
    required this.areaMode,
    required this.stateFilter,
    required this.sort,
    required this.radiusSelection,
    required this.layout,
    required this.currentPage,
  });

  final EcoPartnerSearchResult? result;
  final String filter;
  final EcoPartnerAreaMode areaMode;
  final String stateFilter;
  final EcoPartnerSort sort;
  final double radiusSelection;
  final EcoPartnerLayout layout;
  final int currentPage;
}
