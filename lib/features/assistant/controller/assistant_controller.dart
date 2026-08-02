import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/assistant_feed_item.dart';
import '../model/assistant_feed_repository.dart';

/// Loads the Assistant tab's "Your Top Matches" and "Trending Now" feeds.
class AssistantController extends ChangeNotifier {
  AssistantController({AssistantFeedRepository? repository})
      : _repository = repository ?? AssistantFeedRepository() {
    load();
  }

  final AssistantFeedRepository _repository;

  bool isLoading = true;
  List<AssistantFeedItem> topMatches = const [];
  List<AssistantFeedItem> trending = const [];

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    final results = await Future.wait([
      _repository.topMatches(),
      _repository.trending(),
    ]);
    topMatches = results[0];
    trending = results[1];

    isLoading = false;
    notifyListeners();
  }
}

final assistantControllerProvider = ChangeNotifierProvider<AssistantController>((ref) {
  return AssistantController();
});
