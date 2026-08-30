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
      repository ?? CultureCommunityRepository() {
    load();
  }

  final String foodId;
  final CultureCommunityRepository _repository;

  bool isLoading = false;

  bool isFavourite = false;
  bool isSavingFavourite = false;

  List<TraditionalFoodPlace> places = const [];

  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    // ========================================================
    // LOAD PLACES SEPARATELY
    // ========================================================

    try {
      places =
      await _repository.fetchTraditionalFoodPlaces(
        foodId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Traditional food place loading error: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      places = const [];

      errorMessage =
      'Could not load restaurant locations.';
    }

    // ========================================================
    // LOAD FAVORITE SEPARATELY
    //
    // A favorite failure should NOT stop restaurant loading.
    // ========================================================

    if (_repository.isSignedIn) {
      try {
        isFavourite =
        await _repository.isTraditionalFoodFavourite(
          foodId,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Traditional food favorite loading error: $error',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );

        isFavourite = false;
      }
    } else {
      isFavourite = false;
    }

    isLoading = false;

    notifyListeners();
  }

  Future<bool> toggleFavourite() async {
    if (isSavingFavourite) {
      return false;
    }

    if (!_repository.isSignedIn) {
      errorMessage =
      'Please sign in to save food to Favorites.';

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
    } catch (error, stackTrace) {
      debugPrint(
        'Traditional food favorite update error: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      errorMessage =
      'Could not update your Favorite.';

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