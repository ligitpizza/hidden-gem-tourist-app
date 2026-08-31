import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/cultural_event.dart';
import '../model/culture_community_repository.dart';

class CulturalEventsController extends ChangeNotifier {
  CulturalEventsController({CultureCommunityRepository? repository})
      : _repository = repository ?? CultureCommunityRepository() {
    loadEvents();
  }

  final CultureCommunityRepository _repository;

  List<CulturalEvent> events = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadEvents() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      events = await _repository.fetchCulturalEvents();
    } catch (_) {
      events = const [];
      errorMessage = 'Could not load cultural events right now.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadEvents();
}

final culturalEventsControllerProvider =
    ChangeNotifierProvider<CulturalEventsController>((ref) {
  return CulturalEventsController();
});
