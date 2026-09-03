import 'package:flutter/foundation.dart';

import '../model/packing_location_source.dart';
import '../model/packing_weather_service.dart';
import '../model/saved_eco_partners_store.dart';
import '../model/travel_document.dart';
import '../model/travel_document_repository.dart';
import '../model/travel_assistant_cover_image.dart';
import 'packing_checklist_controller.dart';

typedef TravelDocumentLoader = Future<List<TravelDocument>> Function();
typedef EcoPartnerCountLoader = Future<int> Function();

Future<int> _loadSavedEcoPartnerCount() async {
  final store = SavedEcoPartnersStore.instance;
  await store.ensureLoaded();
  if (store.error != null && store.saved.isEmpty) {
    throw StateError(store.error!);
  }
  return store.saved.length;
}

class TravelAssistantDashboardController extends ChangeNotifier {
  TravelAssistantDashboardController({
    PackingChecklistController? checklistController,
    TravelDocumentLoader? documentLoader,
    EcoPartnerCountLoader? ecoPartnerCountLoader,
    TravelAssistantCoverImageResolverContract? coverResolver,
  }) : checklist = checklistController ?? PackingChecklistController(),
       _ownsChecklistController = checklistController == null,
       _documentLoader = documentLoader ?? TravelDocumentRepository().load,
       _ecoPartnerCountLoader =
           ecoPartnerCountLoader ?? _loadSavedEcoPartnerCount,
       _coverResolver = coverResolver ?? TravelAssistantCoverImageResolver() {
    checklist.addListener(_relayChecklistChange);
  }

  final PackingChecklistController checklist;
  final bool _ownsChecklistController;
  final TravelDocumentLoader _documentLoader;
  final EcoPartnerCountLoader _ecoPartnerCountLoader;
  final TravelAssistantCoverImageResolverContract _coverResolver;

  int? documentCount;
  int documentBytes = 0;
  bool isLoadingDocuments = false;
  int? ecoPartnerCount;
  bool isLoadingEcoPartners = false;
  TravelAssistantCoverImage? coverImage;
  bool isLoadingCover = false;
  String? documentError;
  String? ecoPartnerError;
  int _coverRequestId = 0;

  PackingLocationOption? get selectedLocation => checklist.selectedLocation;
  bool get hasSelectedLocation => selectedLocation != null;
  String get heroTitle => selectedLocation?.heroTitle ?? 'Choose a destination';
  String get heroSubtitle =>
      selectedLocation?.heroSubtitle ??
      'Open the checklist to choose where you are preparing for.';
  int get readinessScore => checklist.readinessScore;
  double get checklistProgress => readinessScore / 100;

  String get packingDescription {
    final location = selectedLocation;
    if (location == null) {
      return 'Choose a destination to build a checklist around its forecast and activities.';
    }
    if (location.datesEditable) {
      if (checklist.tripDates == null) {
        return 'Tailored to ${location.heroTitle}. Set trip dates to add its forecast.';
      }
      if (checklist.forecastStatus == PackingForecastStatus.available) {
        return 'Tailored to ${location.heroTitle} using the forecast for your trip dates.';
      }
      if (checklist.forecastStatus == PackingForecastStatus.partial) {
        return 'Tailored to ${location.heroTitle} using the currently available forecast days.';
      }
      if (checklist.forecastStatus == PackingForecastStatus.notYetAvailable) {
        return 'Tailored to ${location.heroTitle}. Its forecast will be added closer to your trip.';
      }
      if (checklist.forecastStatus == PackingForecastStatus.expired) {
        return 'Tailored to ${location.heroTitle}. Update the past trip dates for a new forecast.';
      }
      if (checklist.forecastStatus == PackingForecastStatus.failed) {
        return 'Tailored to ${location.heroTitle}. Its trip-date forecast is temporarily unavailable.';
      }
      if (checklist.forecastStatus == PackingForecastStatus.loading) {
        return 'Tailored to ${location.heroTitle}. Updating its trip-date forecast…';
      }
    }
    return 'Tailored to ${location.heroTitle}, its forecast, and planned activities.';
  }

  String get documentDescription {
    final count = documentCount;
    if (isLoadingDocuments && count == null) {
      return 'Checking your secure document vault…';
    }
    if (documentError != null && count == null) {
      return 'Document count unavailable. Open the vault to view your files.';
    }
    if (count == null || count == 0) {
      return 'No documents stored yet. Add your essential travel files securely.';
    }
    return '$count ${count == 1 ? 'document' : 'documents'} stored securely for your journey.';
  }

  Future<void> load() async {
    isLoadingEcoPartners = true;
    ecoPartnerError = null;
    notifyListeners();
    await Future.wait([checklist.load(), refreshDocuments()]);
    await _fetchEcoPartnerCount();
    await _resolveCover();
  }

  Future<void> refreshChecklist() async {
    await checklist.load();
    await _resolveCover();
  }

  Future<void> refreshDocuments() async {
    isLoadingDocuments = true;
    documentError = null;
    notifyListeners();
    try {
      final documents = await _documentLoader();
      documentCount = documents.length;
      documentBytes = documents.fold(
        0,
        (total, document) => total + document.fileSize,
      );
    } catch (_) {
      documentError = 'Could not load document metadata.';
    } finally {
      isLoadingDocuments = false;
      notifyListeners();
    }
  }

  Future<void> refreshEcoPartners() async {
    isLoadingEcoPartners = true;
    ecoPartnerError = null;
    notifyListeners();
    await _fetchEcoPartnerCount();
  }

  Future<void> _fetchEcoPartnerCount() async {
    try {
      ecoPartnerCount = await _ecoPartnerCountLoader();
    } catch (_) {
      ecoPartnerError = 'Could not load saved Eco Partners.';
    } finally {
      isLoadingEcoPartners = false;
      notifyListeners();
    }
  }

  Future<void> _resolveCover() async {
    final location = selectedLocation;
    final requestId = ++_coverRequestId;
    coverImage = null;
    if (location == null) {
      isLoadingCover = false;
      notifyListeners();
      return;
    }
    isLoadingCover = true;
    notifyListeners();
    final resolved = await _coverResolver.resolve(location);
    if (requestId != _coverRequestId) return;
    coverImage = resolved;
    isLoadingCover = false;
    notifyListeners();
  }

  void _relayChecklistChange() => notifyListeners();

  @override
  void dispose() {
    checklist.removeListener(_relayChecklistChange);
    if (_ownsChecklistController) checklist.dispose();
    super.dispose();
  }
}
