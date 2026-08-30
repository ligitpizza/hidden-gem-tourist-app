import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/culture_community_repository.dart';

class CulturalEventDetailController
    extends ChangeNotifier {
  CulturalEventDetailController({
    required this.eventId,
    CultureCommunityRepository? repository,
  }) : _repository =
      repository ??
          CultureCommunityRepository() {
    load();
  }

  final String eventId;

  final CultureCommunityRepository _repository;

  bool isLoading = false;

  bool isFavourite = false;
  bool isInItinerary = false;

  bool isSavingFavourite = false;
  bool isSavingItinerary = false;

  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final results = await Future.wait<bool>([
        _repository.isCulturalEventFavourite(
          eventId,
        ),
        _repository.isCulturalEventInItinerary(
          eventId,
        ),
      ]);

      isFavourite = results[0];
      isInItinerary = results[1];
    } catch (_) {
      errorMessage =
      'Could not load your saved event status.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFavourite() async {
    if (isSavingFavourite) {
      return false;
    }

    isSavingFavourite = true;
    errorMessage = null;

    notifyListeners();

    try {
      if (isFavourite) {
        await _repository
            .removeCulturalEventFavourite(
          eventId,
        );

        isFavourite = false;
      } else {
        await _repository
            .addCulturalEventFavourite(
          eventId,
        );

        isFavourite = true;
      }

      return true;
    } catch (_) {
      errorMessage =
      'Could not update your favourite.';

      return false;
    } finally {
      isSavingFavourite = false;
      notifyListeners();
    }
  }

  Future<bool> toggleItinerary(
      DateTime eventStart,
      ) async {
    if (isSavingItinerary) {
      return false;
    }

    isSavingItinerary = true;
    errorMessage = null;

    notifyListeners();

    try {
      if (isInItinerary) {
        await _repository
            .removeCulturalEventFromItinerary(
          eventId,
        );

        isInItinerary = false;
      } else {
        await _repository
            .addCulturalEventToItinerary(
          eventId: eventId,
          plannedAt: eventStart,
        );

        isInItinerary = true;
      }

      return true;
    } catch (_) {
      errorMessage =
      'Could not update your itinerary.';

      return false;
    } finally {
      isSavingItinerary = false;
      notifyListeners();
    }
  }
}

final culturalEventDetailControllerProvider =
ChangeNotifierProvider.autoDispose.family<
    CulturalEventDetailController,
    String>(
      (
      ref,
      eventId,
      ) {
    return CulturalEventDetailController(
      eventId: eventId,
    );
  },
);