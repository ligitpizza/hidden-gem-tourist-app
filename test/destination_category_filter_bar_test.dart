// test/destination_category_filter_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collab/features/destination_exploration/controller/destination_map_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/features/destination_exploration/view/widgets/category_filter_bar.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _EmptyRepository extends DestinationExplorationRepository {
  @override
  Future<List<MapDestination>> loadDestinations() async => const [];
}

void main() {
  testWidgets('tapping a chip toggles that category on the controller', (tester) async {
    final controller = DestinationMapController(repository: _EmptyRepository());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationMapControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CategoryFilterBar()),
        ),
      ),
    );
    await tester.pump();

    expect(controller.selectedCategories, isEmpty);

    await tester.tap(find.text(HiddenGemCategory.nature.label));
    await tester.pump();

    expect(controller.selectedCategories, {HiddenGemCategory.nature});

    await tester.tap(find.text(HiddenGemCategory.nature.label));
    await tester.pump();

    expect(controller.selectedCategories, isEmpty);
  });
}
