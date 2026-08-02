import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../../shared/models/travel_mode.dart';
import '../model/itinerary_plan.dart';
import '../model/itinerary_repository.dart';
import '../model/itinerary_stop.dart';
import '../model/route_path.dart';
import '../model/saved_itineraries_store.dart';
import '../model/visit_duration_option.dart';

/// Business logic for Smart Itinerary Planning (Module 3), shared across the
/// Plan Your Route / Route Optimized / Day Trip screens via
/// [itineraryPlannerControllerProvider] so state survives navigation between
/// them. Kept as a plain [ChangeNotifier] per the module's MVC convention.
class ItineraryPlannerController extends ChangeNotifier {
  ItineraryPlannerController({ItineraryRepository? repository})
      : _repository = repository ?? ItineraryRepository();

  final ItineraryRepository _repository;

  String searchQuery = '';
  List<Destination> searchResults = const [];
  bool isSearching = false;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  final List<Destination> selectedDestinations = [];

  bool allocateDuration = true;
  VisitDurationOption selectedDurationOption = VisitDurationOption.oneDay;
  int customDays = 2;

  final Set<HiddenGemCategory> selectedGemCategories = {};

  bool isGenerating = false;
  ItineraryPlan? plan;

  TravelMode selectedTravelMode = TravelMode.driving;
  String selectedPathId = 'A';
  bool isSaved = false;

  bool get canGenerate => selectedDestinations.length >= 2;

  int previewGemCount = 0;
  bool isLoadingGemPreview = false;
  int _gemPreviewRequestId = 0;

  Future<void> _refreshGemPreview() async {
    final requestId = ++_gemPreviewRequestId;
    if (selectedDestinations.isEmpty) {
      previewGemCount = 0;
      isLoadingGemPreview = false;
      notifyListeners();
      return;
    }

    isLoadingGemPreview = true;
    notifyListeners();

    final gems = await _repository.gemsNearDestinations(
      selectedDestinations,
      categories: selectedGemCategories,
    );
    if (requestId != _gemPreviewRequestId) return; // superseded by a newer selection change
    previewGemCount = gems.length;
    isLoadingGemPreview = false;
    notifyListeners();
  }

  RoutePath? get selectedRoutePath => plan?.pathById(selectedPathId);

  bool get isPlanFeasible => plan?.isFeasible ?? true;
  String? get feasibilityMessage => plan?.feasibilityMessage;

  List<ItineraryStop> get timeline => plan?.timeline ?? const [];

  String? get otherPathId {
    final currentPlan = plan;
    if (currentPlan == null) return null;
    return selectedPathId == currentPlan.primaryPath.id
        ? currentPlan.alternatePath.id
        : currentPlan.primaryPath.id;
  }

  void updateSearchQuery(String query) {
    searchQuery = query;
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      isSearching = false;
      searchResults = const [];
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    final requestId = ++_searchRequestId;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _repository.search(query);
      if (requestId != _searchRequestId) return; // superseded by a newer keystroke
      searchResults = results;
      isSearching = false;
      notifyListeners();
    });
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    searchQuery = '';
    searchResults = const [];
    isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void addDestination(Destination destination) {
    if (selectedDestinations.any((d) => d.id == destination.id)) return;
    selectedDestinations.add(destination);
    searchQuery = '';
    searchResults = const [];
    notifyListeners();
    unawaited(_refreshGemPreview());
  }

  void removeDestination(String id) {
    selectedDestinations.removeWhere((d) => d.id == id);
    notifyListeners();
    unawaited(_refreshGemPreview());
  }

  void setAllocateDuration(bool value) {
    allocateDuration = value;
    notifyListeners();
  }

  void setDurationOption(VisitDurationOption option) {
    selectedDurationOption = option;
    notifyListeners();
  }

  void setCustomDays(int days) {
    customDays = days.clamp(1, 60);
    notifyListeners();
  }

  void toggleGemCategory(HiddenGemCategory category) {
    if (!selectedGemCategories.remove(category)) {
      selectedGemCategories.add(category);
    }
    notifyListeners();
    unawaited(_refreshGemPreview());
  }

  Future<void> generateItinerary() async {
    if (!canGenerate || isGenerating) return;
    isGenerating = true;
    notifyListeners();

    plan = await _repository.generate(
      destinations: List.unmodifiable(selectedDestinations),
      durationOption: allocateDuration ? selectedDurationOption : null,
      customDays: customDays,
      gemCategories: Set.unmodifiable(selectedGemCategories),
    );
    selectedPathId = plan!.primaryPath.id;
    selectedTravelMode = TravelMode.driving;
    isSaved = false;
    isGenerating = false;
    notifyListeners();
  }

  void selectPath(String id) {
    if (selectedPathId == id) return;
    selectedPathId = id;
    notifyListeners();
  }

  void selectTravelMode(TravelMode mode) {
    if (selectedTravelMode == mode) return;
    selectedTravelMode = mode;
    notifyListeners();
  }

  void saveToAccount() {
    final currentPlan = plan;
    if (currentPlan == null) return;
    SavedItinerariesStore.instance.save(currentPlan);
    isSaved = true;
    notifyListeners();
  }

  String buildShareSummary() {
    final currentPlan = plan;
    if (currentPlan == null) return '';
    final path = selectedRoutePath;
    final metrics = path?.metricsFor(selectedTravelMode);
    final stops = currentPlan.destinations.map((d) => d.name).join(' -> ');

    final buffer = StringBuffer()
      ..writeln('My itinerary: $stops')
      ..writeln('Mode: ${selectedTravelMode.label}');
    if (metrics != null) {
      buffer.writeln(
        '${metrics.formattedDistance} | ${metrics.formattedDuration} | ${metrics.formattedCost}',
      );
    }
    if (path != null && path.hiddenGems.isNotEmpty) {
      buffer.writeln('Hidden gems: ${path.hiddenGems.map((g) => g.name).join(', ')}');
    }
    return buffer.toString();
  }

  /// Renders the day-trip timeline as a simple PDF and opens the share sheet
  /// so the traveller can save or send it on.
  Future<void> exportTimelineAsPdf() async {
    final currentPlan = plan;
    if (currentPlan == null || currentPlan.timeline.isEmpty) return;

    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Your Day Trip',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text(currentPlan.destinations.map((d) => d.name).join(' -> ')),
              pw.SizedBox(height: 16),
              for (final stop in currentPlan.timeline) ...[
                pw.Text(
                  '${stop.time}  ${stop.title}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                if (stop.meta != null) pw.Text(stop.meta!, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(stop.description, style: const pw.TextStyle(fontSize: 11)),
                if (stop.travelToNext != null)
                  pw.Text(stop.travelToNext!, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );

    final bytes = await document.save();
    // In-memory XFile — works on every platform including web, unlike
    // dart:io.File + path_provider's temp directory (no filesystem access
    // exists on web, so that combination silently fails there).
    final file = XFile.fromData(bytes, name: 'itinerary.pdf', mimeType: 'application/pdf');
    await Share.shareXFiles([file], subject: 'Your Day Trip itinerary');
  }
}

final itineraryPlannerControllerProvider =
    ChangeNotifierProvider<ItineraryPlannerController>((ref) {
  return ItineraryPlannerController();
});
