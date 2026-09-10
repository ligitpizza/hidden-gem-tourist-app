import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../model/eco_partner.dart';
import '../model/eco_partner_cache.dart';
import '../model/eco_partner_repository.dart';

enum EcoPartnerLayout { list, grid2, grid4 }

enum EcoPartnerSort { recommended, nameAscending, nameDescending }

enum EcoPartnerHomeSection { recommended, hotel, dining, transport, ev }

typedef EcoCurrentLocationLoader = Future<EcoDestination> Function();
typedef EcoLastKnownLocationLoader = Future<EcoDestination?> Function();

/// Coordinates Eco Partner searches and exposes presentation-ready state.
class EcoPartnerController extends ChangeNotifier {
  EcoPartnerController({
    EcoPartnerRepositoryContract? repository,
    EcoCurrentLocationLoader? currentLocationLoader,
    EcoLastKnownLocationLoader? lastKnownLocationLoader,
    EcoPartnerHomeCacheContract? homeCache,
    DateTime Function()? now,
  }) : _repository = repository ?? EcoPartnerRepository(),
       _currentLocationLoader =
           currentLocationLoader ?? _loadDeviceCurrentLocation,
       _lastKnownLocationLoader =
           lastKnownLocationLoader ?? _loadDeviceLastKnownLocation,
       _homeCache = homeCache ?? SharedPreferencesEcoPartnerHomeCache(),
       _now = now ?? DateTime.now;

  final EcoPartnerRepositoryContract _repository;
  final EcoCurrentLocationLoader _currentLocationLoader;
  final EcoLastKnownLocationLoader _lastKnownLocationLoader;
  final EcoPartnerHomeCacheContract _homeCache;
  final DateTime Function() _now;

  EcoPartnerSearchResult? result;
  String filter = 'All';
  String transportType = 'All transport';
  EcoPartnerAreaMode areaMode = EcoPartnerAreaMode.nearby;
  String stateFilter = 'All Malaysia';
  EcoPartnerSort sort = EcoPartnerSort.recommended;
  double radiusSelection = 10;
  String? error;
  String? notice;
  bool isLoading = false;
  EcoPartnerLayout layout = EcoPartnerLayout.list;
  int currentPage = 0;
  int _requestId = 0;
  EcoPartnerSearchResult? _initialResult;
  List<EcoPartner> _suggestionCatalog = const [];
  EcoDestination? _userLocation;
  _EcoPartnerBrowseSnapshot? _browseSnapshot;
  _EcoPartnerBrowseSnapshot? _homeSectionSnapshot;
  EcoPartnerSearchResult? _latestBrowseResult;
  bool _isExplicitSearch = false;
  bool _serverPageActive = false;
  int _serverTotalCount = 0;
  String activeSearchTerm = '';
  static const standardPageSize = 10;
  static const compactPageSize = 8;
  static const suggestionLimit = 6;
  static const homeSectionLimit = 8;
  static const _homeCacheLifetime = Duration(hours: 24);
  static const _homeCacheOriginToleranceKm = 5.0;
  static const transportTypes = [
    'All transport',
    'Bus',
    'MRT',
    'LRT',
    'Monorail',
    'KTM',
    'Rail',
  ];

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
      !_isExplicitSearch && _userLocation != null;
  bool get hasUserLocation => _userLocation != null;
  bool get showsUserDistance =>
      _userLocation != null &&
      (result?.partners.any((partner) => partner.distanceKm != null) ?? false);
  double? get activeNearbyRadius {
    final mode = _browseSnapshot?.areaMode ?? areaMode;
    if (mode != EcoPartnerAreaMode.nearby) return null;
    return _browseSnapshot?.radiusSelection ?? radiusSelection;
  }

  bool isOutsideBrowseRadius(EcoPartner partner) {
    final radius = activeNearbyRadius;
    final distance = partner.distanceKm;
    return _isExplicitSearch &&
        _userLocation != null &&
        radius != null &&
        distance != null &&
        distance > radius;
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
    if (_serverPageActive) return values;
    final start = currentPage * effectivePageSize;
    if (start >= values.length) return const [];
    final end = start + effectivePageSize > values.length
        ? values.length
        : start + effectivePageSize;
    return values.sublist(start, end);
  }

  int get totalPages =>
      ((_serverPageActive ? _serverTotalCount : filteredPartners.length) /
              effectivePageSize)
          .ceil();

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

  Future<void> showAllForHomeSection(EcoPartnerHomeSection section) async {
    final targetFilter = switch (section) {
      EcoPartnerHomeSection.hotel => 'Stay',
      EcoPartnerHomeSection.dining => 'Dining',
      EcoPartnerHomeSection.transport => 'Public Transport',
      EcoPartnerHomeSection.ev => 'EV Charging',
      EcoPartnerHomeSection.recommended => null,
    };
    if (targetFilter == null) return;
    _homeSectionSnapshot = _EcoPartnerBrowseSnapshot(
      result: result ?? _latestBrowseResult,
      filter: filter,
      transportType: transportType,
      areaMode: areaMode,
      stateFilter: stateFilter,
      sort: sort,
      radiusSelection: radiusSelection,
      layout: layout,
      currentPage: currentPage,
    );
    filter = targetFilter;
    if (filter == 'Public Transport') transportType = 'All transport';
    currentPage = 0;
    notifyListeners();
    await _loadCatalogPage();
  }

  void returnToSectionedHome() {
    ++_requestId;
    final snapshot = _homeSectionSnapshot;
    _homeSectionSnapshot = null;
    _isExplicitSearch = false;
    activeSearchTerm = '';

    if (snapshot != null) {
      result = snapshot.result ?? _latestBrowseResult ?? _initialResult;
      areaMode = snapshot.areaMode;
      stateFilter = snapshot.stateFilter;
      sort = snapshot.sort;
      radiusSelection = snapshot.radiusSelection;
      layout = snapshot.layout;
    } else {
      result = _latestBrowseResult ?? _initialResult ?? result;
    }

    filter = 'All';
    transportType = 'All transport';
    currentPage = 0;
    _serverPageActive = false;
    _serverTotalCount = result?.totalCount ?? result?.partners.length ?? 0;
    if (result != null) {
      _latestBrowseResult = result;
      _suggestionCatalog = List.unmodifiable(result!.partners);
    }
    isLoading = false;
    error = null;
    notice = null;
    notifyListeners();
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
          partner.subtype != 'EV charging' &&
          _matchesTransportType(partner),
    'EV Charging' =>
      partner.category == EcoPartnerCategory.transport &&
          partner.subtype == 'EV charging',
    _ => true,
  };

  bool _matchesTransportType(EcoPartner partner) {
    final subtype = partner.subtype.trim().toLowerCase();
    return switch (transportType) {
      'Bus' => subtype == 'bus',
      'MRT' => subtype == 'mrt',
      'LRT' => subtype == 'lrt' || subtype == 'light rail',
      'Monorail' => subtype == 'monorail',
      'KTM' => subtype == 'ktm',
      'Rail' => subtype == 'rail',
      _ => subtype != 'ev charging',
    };
  }

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

  Future<List<EcoPartner>> loadSuggestions(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];
    final repository = _repository;
    if (repository is EcoPartnerCatalogRepositoryContract) {
      final catalogRepository =
          repository as EcoPartnerCatalogRepositoryContract;
      try {
        return await catalogRepository.suggestions(
          clean,
          limit: suggestionLimit,
        );
      } catch (_) {
        return suggestionsFor(clean);
      }
    }
    return suggestionsFor(clean);
  }

  Future<void> loadInitialRecommendations({bool refresh = false}) async {
    final requestId = ++_requestId;
    activeSearchTerm = '';
    _isExplicitSearch = false;
    _browseSnapshot = null;
    areaMode = EcoPartnerAreaMode.nearby;
    stateFilter = 'All Malaysia';
    radiusSelection = 10;
    currentPage = 0;
    if (refresh) result = null;
    _beginRequest(preserveResult: !refresh);

    final cacheFuture = refresh
        ? Future<EcoPartnerHomeCacheEntry?>.value(null)
        : _homeCache.read();
    final lastKnownFuture = _lastKnownLocationLoader();
    EcoPartnerHomeCacheEntry? cached;
    EcoDestination? lastKnown;
    try {
      cached = await cacheFuture;
      lastKnown = await lastKnownFuture;
      if (requestId != _requestId) return;
      if (_isUsableHomeCache(cached, lastKnown)) {
        _userLocation = lastKnown;
        _acceptBrowseResult(
          EcoPartnerSearchResult(
            destination: lastKnown!,
            partners: cached!.partners,
          ),
          cacheAsInitial: true,
        );
        notifyListeners();
      }

      EcoDestination currentLocation;
      try {
        currentLocation = await _currentLocationLoader();
      } catch (_) {
        if (requestId != _requestId) return;
        areaMode = EcoPartnerAreaMode.statewide;
        _userLocation = null;
        const malaysia = EcoDestination('Malaysia', 4.2105, 101.9758);
        final nationwide = await _loadHome(
          destination: malaysia,
          scope: const EcoPartnerSearchScope.nationwide(),
        );
        if (requestId != _requestId) return;
        _acceptBrowseResult(nationwide, cacheAsInitial: true);
        return;
      }

      final nearby = await _loadHome(
        destination: currentLocation,
        distanceOrigin: currentLocation,
        scope: EcoPartnerSearchScope.nearby(radiusSelection),
      );
      if (requestId != _requestId) return;
      _userLocation = currentLocation;
      _acceptBrowseResult(nearby, cacheAsInitial: true);
      try {
        await _homeCache.write(
          EcoPartnerHomeCacheEntry(
            partners: nearby.partners,
            origin: currentLocation,
            radiusKm: radiusSelection,
            fetchedAt: _now(),
          ),
        );
      } catch (_) {
        // A cache failure must never hide fresh catalogue results.
      }
    } catch (_) {
      if (requestId != _requestId) return;
      if (result != null) {
        notice =
            'Showing saved Eco Partners. Fresh results are temporarily unavailable.';
      } else {
        error =
            'We couldn’t load Eco Partner recommendations. Please try again.';
      }
    } finally {
      if (requestId == _requestId && isLoading) _finishRequest();
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
      final repository = _repository;
      final catalogResult = repository is EcoPartnerCatalogRepositoryContract
          ? await (repository as EcoPartnerCatalogRepositoryContract)
                .searchPage(
                  destination: const EcoDestination(
                    'Eco Partner name search',
                    4.2105,
                    101.9758,
                  ),
                  scope: const EcoPartnerSearchScope.nationwide(),
                  distanceOrigin: _userLocation,
                  query: clean,
                  sort: _catalogSort,
                  limit: effectivePageSize,
                )
          : await _repository.searchByName(
              clean,
              refresh: refresh,
              scope: const EcoPartnerSearchScope.nationwide(),
              includeImages: false,
            );
      if (requestId != _requestId) return;
      final normalizedQuery = _normalize(clean);
      final matches = repository is EcoPartnerCatalogRepositoryContract
          ? catalogResult.partners
          : catalogResult.partners
                .where(
                  (partner) =>
                      _normalize(partner.name).contains(normalizedQuery),
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
        totalCount: repository is EcoPartnerCatalogRepositoryContract
            ? catalogResult.totalCount
            : matches.length,
      );
      _serverPageActive = repository is EcoPartnerCatalogRepositoryContract;
      _serverTotalCount = catalogResult.totalCount;
      currentPage = 0;
      _finishRequest();
    } on EcoSearchException catch (exception) {
      if (requestId != _requestId) return;
      _restoreBrowseSnapshot();
      error = exception.message;
    } catch (_) {
      if (requestId != _requestId) return;
      _restoreBrowseSnapshot();
      error =
          'We couldn’t complete the search. Check your connection and try again.';
    } finally {
      if (requestId == _requestId && isLoading) _finishRequest();
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
      notifyListeners();
      return;
    }
    _isExplicitSearch = false;
    _serverPageActive = false;
    currentPage = 0;
    final cachedBrowse = _latestBrowseResult ?? _initialResult;
    if (cachedBrowse == null) {
      await loadInitialRecommendations();
      return;
    }
    result = cachedBrowse;
    isLoading = false;
    notifyListeners();
  }

  Future<bool> useCurrentLocation({bool silentPermissionDenial = false}) async {
    final requestId = ++_requestId;
    _beginRequest(preserveResult: true);
    try {
      final userLocation = await _currentLocationLoader();
      if (requestId != _requestId) return false;
      _userLocation = userLocation;
      _isExplicitSearch = false;
      _browseSnapshot = null;
      activeSearchTerm = '';
      currentPage = 0;
      final locationResult = await _queryBrowseView();
      if (requestId != _requestId) return false;
      _acceptBrowseResult(locationResult);
      _finishRequest();
      return true;
    } on EcoSearchException catch (exception) {
      error = silentPermissionDenial ? null : exception.message;
      return false;
    } catch (_) {
      error = silentPermissionDenial
          ? null
          : 'We couldn’t find your current location.';
      return false;
    } finally {
      if (requestId == _requestId && isLoading) _finishRequest();
    }
  }

  Future<void> retry({String fallbackQuery = ''}) async {
    if (_isExplicitSearch) {
      await search(activeSearchTerm, refresh: true);
      return;
    }
    final requestId = ++_requestId;
    _beginRequest(preserveResult: true);
    try {
      final refreshed = await _queryBrowseView(refresh: true);
      if (requestId != _requestId) return;
      _acceptBrowseResult(refreshed);
      _finishRequest();
    } catch (_) {
      if (requestId == _requestId) {
        notice =
            'Could not refresh Eco Partners. Showing the previous results.';
      }
    } finally {
      if (requestId == _requestId && isLoading) _finishRequest();
    }
  }

  void selectFilter(String value) {
    if (filter == value) return;
    filter = value;
    if (filter != 'Public Transport') transportType = 'All transport';
    currentPage = 0;
    notifyListeners();
  }

  void selectTransportType(String value) {
    if (!transportTypes.contains(value) || transportType == value) return;
    transportType = value;
    filter = 'Public Transport';
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

  Future<bool> goToPage(int value) async {
    if (isLoading || value < 0 || value >= totalPages || value == currentPage) {
      return false;
    }
    if (_serverPageActive) {
      return _loadCatalogPage(targetPage: value);
    }
    currentPage = value;
    notifyListeners();
    return true;
  }

  Future<bool> _loadCatalogPage({int? targetPage}) async {
    final repository = _repository;
    if (repository is! EcoPartnerCatalogRepositoryContract) return false;
    final catalogRepository = repository as EcoPartnerCatalogRepositoryContract;
    final requestedPage = targetPage ?? currentPage;
    final requestId = ++_requestId;
    _beginRequest(preserveResult: true);
    try {
      final destination = _isExplicitSearch
          ? const EcoDestination('Eco Partner name search', 4.2105, 101.9758)
          : result?.destination ??
                const EcoDestination('Malaysia', 4.2105, 101.9758);
      final page = await catalogRepository.searchPage(
        destination: destination,
        scope: _isExplicitSearch
            ? const EcoPartnerSearchScope.nationwide()
            : searchScope,
        distanceOrigin: _userLocation,
        query: _isExplicitSearch ? activeSearchTerm : null,
        category: _catalogCategory,
        sort: _catalogSort,
        limit: effectivePageSize,
        offset: requestedPage * effectivePageSize,
      );
      if (requestId != _requestId) return false;
      result = EcoPartnerSearchResult(
        destination: page.destination,
        partners: _withUserDistances(page.partners),
        warnings: page.warnings,
        totalCount: page.totalCount,
      );
      _serverPageActive = true;
      _serverTotalCount = page.totalCount;
      currentPage = requestedPage;
      error = null;
      notice = null;
      _finishRequest();
      return true;
    } on EcoSearchException catch (exception) {
      if (requestId == _requestId) {
        notice = '${exception.message} Your current page is still shown.';
      }
    } catch (_) {
      if (requestId == _requestId) {
        notice =
            'Could not load the next page. Your current results are still shown.';
      }
    } finally {
      if (requestId == _requestId && isLoading) _finishRequest();
    }
    return false;
  }

  String? get _catalogCategory => switch (filter) {
    'Stay' => 'stay',
    'Dining' => 'dining',
    'Public Transport' => switch (transportType) {
      'Bus' => 'transport_bus',
      'MRT' => 'transport_mrt',
      'LRT' => 'transport_lrt',
      'Monorail' => 'transport_monorail',
      'KTM' => 'transport_ktm',
      'Rail' => 'transport_rail',
      _ => 'public_transport',
    },
    'EV Charging' => 'ev',
    _ => null,
  };

  String get _catalogSort => switch (sort) {
    EcoPartnerSort.recommended => 'recommended',
    EcoPartnerSort.nameAscending => 'name_asc',
    EcoPartnerSort.nameDescending => 'name_desc',
  };

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
    final previousMode = areaMode;
    final previousRadius = radiusSelection;
    final previousState = stateFilter;
    final previousPage = currentPage;
    final succeeded = await applyFilters(
      filter: filter,
      transportType: transportType,
      areaMode: mode,
      radius: radius,
      state: state,
      sort: sort,
      useCurrentLocation: useCurrentLocation,
    );
    if (!succeeded && useCurrentLocation) {
      areaMode = previousMode;
      radiusSelection = previousRadius;
      stateFilter = previousState;
      currentPage = previousPage;
      notifyListeners();
    }
  }

  Future<bool> applyFilters({
    required String filter,
    String? transportType,
    required EcoPartnerAreaMode areaMode,
    required double radius,
    required String state,
    required EcoPartnerSort sort,
    bool useCurrentLocation = false,
  }) async {
    if (_isExplicitSearch) await clearSearch();
    this.filter = filter;
    this.transportType = filter == 'Public Transport'
        ? transportType ?? this.transportType
        : 'All transport';
    this.areaMode = areaMode;
    radiusSelection = radius;
    stateFilter = state;
    this.sort = sort;
    currentPage = 0;
    _serverPageActive =
        _repository is EcoPartnerCatalogRepositoryContract && filter != 'All';
    notifyListeners();

    if (areaMode == EcoPartnerAreaMode.nearby &&
        (useCurrentLocation || _userLocation == null)) {
      return this.useCurrentLocation();
    }
    await retry();
    return error == null;
  }

  void _saveBrowseSnapshot() {
    if (_browseSnapshot != null || _isExplicitSearch) return;
    _browseSnapshot = _EcoPartnerBrowseSnapshot(
      result: result ?? _latestBrowseResult,
      filter: filter,
      transportType: transportType,
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
    transportType = snapshot.transportType;
    areaMode = snapshot.areaMode;
    stateFilter = snapshot.stateFilter;
    sort = snapshot.sort;
    radiusSelection = snapshot.radiusSelection;
    layout = snapshot.layout;
    currentPage = snapshot.currentPage;
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

  Future<EcoPartnerSearchResult> _loadHome({
    required EcoDestination destination,
    required EcoPartnerSearchScope scope,
    EcoDestination? distanceOrigin,
  }) {
    final repository = _repository;
    if (repository is EcoPartnerCatalogRepositoryContract) {
      return (repository as EcoPartnerCatalogRepositoryContract).loadHome(
        destination: destination,
        scope: scope,
        distanceOrigin: distanceOrigin,
      );
    }
    return repository.searchCoordinates(
      distanceOrigin ?? destination,
      scope: scope,
      includeImages: false,
    );
  }

  Future<EcoPartnerSearchResult> _queryBrowseView({bool refresh = false}) {
    final origin = _userLocation;
    final destination =
        origin ??
        result?.destination ??
        const EcoDestination('Malaysia', 4.2105, 101.9758);
    final repository = _repository;
    if (repository is EcoPartnerCatalogRepositoryContract) {
      final catalog = repository as EcoPartnerCatalogRepositoryContract;
      if (filter == 'All') {
        return catalog.loadHome(
          destination: destination,
          scope: searchScope,
          distanceOrigin: origin,
        );
      }
      return catalog.searchPage(
        destination: destination,
        scope: searchScope,
        distanceOrigin: origin,
        category: _catalogCategory,
        sort: _catalogSort,
        limit: effectivePageSize,
        offset: currentPage * effectivePageSize,
      );
    }
    return repository.searchCoordinates(
      destination,
      refresh: refresh,
      scope: searchScope,
      includeImages: false,
    );
  }

  void _acceptBrowseResult(
    EcoPartnerSearchResult value, {
    bool cacheAsInitial = false,
  }) {
    result = value;
    _serverPageActive =
        _repository is EcoPartnerCatalogRepositoryContract && filter != 'All';
    _serverTotalCount = value.totalCount;
    _latestBrowseResult = value;
    _suggestionCatalog = List.unmodifiable(value.partners);
    if (cacheAsInitial) _initialResult = value;
    error = null;
    notice = null;
  }

  bool _isUsableHomeCache(
    EcoPartnerHomeCacheEntry? cached,
    EcoDestination? lastKnown,
  ) {
    if (cached == null || lastKnown == null || cached.partners.isEmpty) {
      return false;
    }
    final age = _now().difference(cached.fetchedAt);
    if (age.isNegative || age > _homeCacheLifetime) return false;
    if ((cached.radiusKm - radiusSelection).abs() > 0.01) return false;
    return EcoPartnerRepository.distanceKm(
          cached.origin.latitude,
          cached.origin.longitude,
          lastKnown.latitude,
          lastKnown.longitude,
        ) <=
        _homeCacheOriginToleranceKm;
  }

  void _beginRequest({bool preserveResult = false}) {
    isLoading = true;
    error = null;
    notice = null;
    if (!preserveResult) result = null;
    notifyListeners();
  }

  void _finishRequest() {
    isLoading = false;
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

  static Future<EcoDestination?> _loadDeviceLastKnownLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
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
    required this.transportType,
    required this.areaMode,
    required this.stateFilter,
    required this.sort,
    required this.radiusSelection,
    required this.layout,
    required this.currentPage,
  });

  final EcoPartnerSearchResult? result;
  final String filter;
  final String transportType;
  final EcoPartnerAreaMode areaMode;
  final String stateFilter;
  final EcoPartnerSort sort;
  final double radiusSelection;
  final EcoPartnerLayout layout;
  final int currentPage;
}
