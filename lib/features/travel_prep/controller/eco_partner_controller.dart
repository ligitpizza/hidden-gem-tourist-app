import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../model/eco_partner.dart';
import '../model/eco_partner_repository.dart';

enum EcoPartnerLayout { list, grid2, grid4 }

/// Coordinates Eco Partner searches and exposes presentation-ready state.
class EcoPartnerController extends ChangeNotifier {
  EcoPartnerController({EcoPartnerRepository? repository})
    : _repository = repository ?? EcoPartnerRepository();

  final EcoPartnerRepository _repository;

  EcoPartnerSearchResult? result;
  String filter = 'All';
  double radiusSelection = 10;
  String? error;
  bool isLoading = false;
  bool isLoadingImages = false;
  EcoPartnerLayout layout = EcoPartnerLayout.list;
  int currentPage = 0;
  int _requestId = 0;
  static const pageSize = 10;

  double? get radiusKm => radiusSelection == 0 ? null : radiusSelection;
  String get scopeLabel => radiusKm == null
      ? 'across Malaysia'
      : 'within ${radiusSelection.round()} km';

  List<EcoPartner> get filteredPartners =>
      (result?.partners ?? const <EcoPartner>[]).where(_matchesFilter).toList();

  List<EcoPartner> get visiblePartners {
    final values = filteredPartners;
    final start = currentPage * pageSize;
    if (start >= values.length) return const [];
    final end = start + pageSize > values.length
        ? values.length
        : start + pageSize;
    return values.sublist(start, end);
  }

  int get totalPages => (filteredPartners.length / pageSize).ceil();

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

  Future<void> search(String query, {bool refresh = false}) async {
    final requestId = ++_requestId;
    result = null;
    currentPage = 0;
    _beginRequest();
    try {
      result = await _repository.searchDestination(
        query,
        refresh: refresh,
        radiusKm: radiusKm,
        includeImages: false,
      );
      currentPage = 0;
      _finishRequest();
      _loadImages(requestId);
    } on EcoSearchException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Search failed. Check your connection and retry.';
    } finally {
      if (isLoading) _finishRequest();
    }
  }

  Future<bool> useCurrentLocation({bool silentPermissionDenial = false}) async {
    final requestId = ++_requestId;
    _beginRequest();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (silentPermissionDenial) {
          error = null;
          return false;
        }
        throw const EcoSearchException('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 3),
      );
      result = await _repository.searchCoordinates(
        EcoDestination(
          'Current location',
          position.latitude,
          position.longitude,
        ),
        radiusKm: radiusKm,
        includeImages: false,
      );
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
    final destination = result?.destination;
    if (destination == null) {
      await search(fallbackQuery, refresh: true);
      return;
    }
    final requestId = ++_requestId;
    _beginRequest();
    try {
      result = await _repository.searchCoordinates(
        destination,
        refresh: true,
        radiusKm: radiusKm,
        includeImages: false,
      );
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

  void selectLayout(EcoPartnerLayout value) {
    if (layout == value) return;
    layout = value;
    notifyListeners();
  }

  void goToPage(int value) {
    if (value < 0 || value >= totalPages || value == currentPage) return;
    currentPage = value;
    notifyListeners();
  }

  Future<void> selectRadius(double value, {String fallbackQuery = ''}) async {
    if (radiusSelection == value) return;
    radiusSelection = value;
    notifyListeners();
    if (result != null) await retry(fallbackQuery: fallbackQuery);
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

  Future<void> _loadImages(int requestId) async {
    final current = result;
    if (current == null || requestId != _requestId) return;
    isLoadingImages = true;
    notifyListeners();
    final enriched = await _repository.enrichResult(
      current,
      radiusKm: radiusKm,
    );
    if (requestId != _requestId) return;
    result = enriched;
    isLoadingImages = false;
    notifyListeners();
  }
}
