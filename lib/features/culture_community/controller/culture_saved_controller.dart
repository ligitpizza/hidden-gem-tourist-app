import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/cultural_event.dart';
import '../model/culture_community_repository.dart';
import '../model/traditional_food.dart';
import '../model/traditional_food_place.dart';

class CultureSavedController
    extends ChangeNotifier {
  CultureSavedController({
    CultureCommunityRepository? repository,
  }) : _repository =
      repository ??
          CultureCommunityRepository() {
    load();
  }

  final CultureCommunityRepository
  _repository;

  bool isLoading = false;

  String? errorMessage;

  List<CulturalEvent>
  favouriteEvents = [];

  List<TraditionalFood>
  favouriteFoods = [];

  List<TraditionalFoodPlace>
  favouritePlaces = [];

  bool get isSignedIn =>
      _repository.isSignedIn;

  // =========================================================
  // LOAD
  // =========================================================

  Future<void> load() async {
    if (!_repository.isSignedIn) {
      favouriteEvents = [];

      favouriteFoods = [];

      favouritePlaces = [];

      isLoading = false;

      errorMessage =
      'Please sign in to view your saved Culture items.';

      notifyListeners();

      return;
    }

    isLoading = true;

    errorMessage = null;

    notifyListeners();

    try {
      final results =
      await Future.wait([
        _repository
            .fetchFavouriteCulturalEvents(),

        _repository
            .fetchFavouriteTraditionalFoods(),

        _repository
            .fetchFavouriteFoodLocations(),
      ]);

      favouriteEvents =
      results[0]
      as List<CulturalEvent>;

      favouriteFoods =
      results[1]
      as List<TraditionalFood>;

      favouritePlaces =
      results[2]
      as List<
          TraditionalFoodPlace>;
    } catch (error) {
      debugPrint(
        'Culture saved loading error: $error',
      );

      errorMessage =
      'Could not load your saved Culture items.';
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  // =========================================================
  // REMOVE EVENT
  // =========================================================

  Future<bool>
  removeEventFavourite(
      String eventId,
      ) async {
    try {
      await _repository
          .removeCulturalEventFavourite(
        eventId,
      );

      favouriteEvents.removeWhere(
            (event) =>
        event.id == eventId,
      );

      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'Remove saved event error: $error',
      );

      errorMessage =
      'Could not remove saved event.';

      notifyListeners();

      return false;
    }
  }

  // =========================================================
  // REMOVE FOOD
  // =========================================================

  Future<bool>
  removeFoodFavourite(
      String foodId,
      ) async {
    try {
      await _repository
          .removeTraditionalFoodFavourite(
        foodId,
      );

      favouriteFoods.removeWhere(
            (food) =>
        food.id == foodId,
      );

      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'Remove saved food error: $error',
      );

      errorMessage =
      'Could not remove saved food.';

      notifyListeners();

      return false;
    }
  }

  // =========================================================
  // REMOVE RESTAURANT
  // =========================================================

  Future<bool>
  removePlaceFavourite(
      String placeId,
      ) async {
    try {
      await _repository
          .removeFoodLocationFavourite(
        placeId,
      );

      favouritePlaces.removeWhere(
            (place) =>
        place.id == placeId,
      );

      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'Remove saved place error: $error',
      );

      errorMessage =
      'Could not remove saved place.';

      notifyListeners();

      return false;
    }
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> refresh() {
    return load();
  }
}

final cultureSavedControllerProvider =
ChangeNotifierProvider.autoDispose<
    CultureSavedController>(
      (ref) {
    return CultureSavedController();
  },
);