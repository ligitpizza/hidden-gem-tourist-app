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

  bool isSavingFavourite = false;

  String? errorMessage;

  // =========================================================
  // LOAD SAVED STATUS
  // =========================================================

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    if (!_repository.isSignedIn) {
      isFavourite = false;
      isLoading = false;

      notifyListeners();

      return;
    }

    try {
      isFavourite =
      await _repository
          .isCulturalEventFavourite(
        eventId,
      );
    } catch (error) {
      debugPrint(
        'Load event favourite error: $error',
      );

      isFavourite = false;
    }

    isLoading = false;

    notifyListeners();
  }

  // =========================================================
  // SAVE / UNSAVE
  // =========================================================

  Future<bool> toggleFavourite() async {
    if (isSavingFavourite) {
      return false;
    }

    if (!_repository.isSignedIn) {
      errorMessage =
      'Please sign in to save this event.';

      notifyListeners();

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
    } catch (error) {
      debugPrint(
        'Update event favourite error: $error',
      );

      errorMessage =
      'Could not update saved event.';

      return false;
    } finally {
      isSavingFavourite = false;

      notifyListeners();
    }
  }

  Future<void> refresh() {
    return load();
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