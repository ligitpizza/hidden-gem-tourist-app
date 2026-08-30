import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/culture_community_repository.dart';
import '../model/traditional_food.dart';

class TraditionalFoodController extends ChangeNotifier {
  TraditionalFoodController({CultureCommunityRepository? repository})
      : _repository = repository ?? CultureCommunityRepository() {
    loadFoods();
  }

  final CultureCommunityRepository _repository;

  List<TraditionalFood> foods = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadFoods() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      foods = await _repository.fetchTraditionalFoods();
    } catch (_) {
      foods = const [];
      errorMessage = 'Could not load traditional foods right now.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadFoods();
}

final traditionalFoodControllerProvider =
    ChangeNotifierProvider<TraditionalFoodController>((ref) {
  return TraditionalFoodController();
});
