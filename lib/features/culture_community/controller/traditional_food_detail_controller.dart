import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/culture_community_repository.dart';
import '../model/traditional_food_place.dart';

class TraditionalFoodDetailController
    extends ChangeNotifier {
  TraditionalFoodDetailController({
    required this.foodId,
    CultureCommunityRepository? repository,
  }) : _repository =
      repository ??
          CultureCommunityRepository() {
    load();
  }

  final String foodId;

  final CultureCommunityRepository
  _repository;

  bool isLoading = false;

  bool isFavourite = false;

  bool isSavingFavourite = false;

  List<TraditionalFoodPlace> places = [];

  Set<String> favouritePlaceIds = {};

  Set<String> savingPlaceIds = {};

  String? errorMessage;

  bool get isSignedIn =>
      _repository.isSignedIn;

  // =========================================================
  // PLACE SAVED STATUS
  // =========================================================

  bool isPlaceFavourite(
      String placeId,
      ) {
    return favouritePlaceIds.contains(
      placeId,
    );
  }

  bool isSavingPlace(
      String placeId,
      ) {
    return savingPlaceIds.contains(
      placeId,
    );
  }

  // =========================================================
  // LOAD
  // =========================================================

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    // =======================================================
    // FOOD LOCATIONS
    // =======================================================

    try {
      places =
      await _repository
          .fetchTraditionalFoodPlaces(
        foodId,
      );
    } catch (error) {
      debugPrint(
        'Load food locations error: $error',
      );

      places = [];

      errorMessage =
      'Could not load food locations.';
    }

    // =======================================================
    // FOOD SAVED STATUS
    // =======================================================

    if (_repository.isSignedIn) {
      try {
        isFavourite =
        await _repository
            .isTraditionalFoodFavourite(
          foodId,
        );
      } catch (error) {
        debugPrint(
          'Load saved food error: $error',
        );

        isFavourite = false;
      }

      // =====================================================
      // SAVED RESTAURANTS
      // =====================================================

      try {
        favouritePlaceIds =
        await _repository
            .fetchFavouriteFoodLocationIds();
      } catch (error) {
        debugPrint(
          'Load saved restaurants error: $error',
        );

        favouritePlaceIds = {};
      }
    } else {
      isFavourite = false;

      favouritePlaceIds = {};
    }

    isLoading = false;

    notifyListeners();
  }

  // =========================================================
  // SAVE FOOD
  // =========================================================

  Future<bool>
  toggleFavourite() async {
    if (isSavingFavourite) {
      return false;
    }

    if (!_repository.isSignedIn) {
      errorMessage =
      'Please sign in to save this traditional food.';

      notifyListeners();

      return false;
    }

    isSavingFavourite = true;
    errorMessage = null;

    notifyListeners();

    try {
      if (isFavourite) {
        await _repository
            .removeTraditionalFoodFavourite(
          foodId,
        );

        isFavourite = false;
      } else {
        await _repository
            .addTraditionalFoodFavourite(
          foodId,
        );

        isFavourite = true;
      }

      return true;
    } catch (error) {
      debugPrint(
        'Save food error: $error',
      );

      errorMessage =
      'Could not update saved food.';

      return false;
    } finally {
      isSavingFavourite = false;

      notifyListeners();
    }
  }

  // =========================================================
  // SAVE RESTAURANT
  // =========================================================

  Future<bool>
  togglePlaceFavourite(
      String placeId,
      ) async {
    if (savingPlaceIds.contains(
      placeId,
    )) {
      return false;
    }

    if (!_repository.isSignedIn) {
      errorMessage =
      'Please sign in to save this place.';

      notifyListeners();

      return false;
    }

    savingPlaceIds.add(
      placeId,
    );

    errorMessage = null;

    notifyListeners();

    try {
      if (favouritePlaceIds.contains(
        placeId,
      )) {
        await _repository
            .removeFoodLocationFavourite(
          placeId,
        );

        favouritePlaceIds.remove(
          placeId,
        );
      } else {
        await _repository
            .addFoodLocationFavourite(
          placeId,
        );

        favouritePlaceIds.add(
          placeId,
        );
      }

      return true;
    } catch (error) {
      debugPrint(
        'Save restaurant error: $error',
      );

      errorMessage =
      'Could not update saved place.';

      return false;
    } finally {
      savingPlaceIds.remove(
        placeId,
      );

      notifyListeners();
    }
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> refresh() {
    return load();
  }
}

final traditionalFoodDetailControllerProvider =
ChangeNotifierProvider.autoDispose.family<
    TraditionalFoodDetailController,
    String>(
      (
      ref,
      foodId,
      ) {
    return TraditionalFoodDetailController(
      foodId: foodId,
    );
  },
);