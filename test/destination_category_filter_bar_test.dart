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
  testWidgets('tapping a category in the filter sheet toggles it on the controller', (
    tester,
  ) async {
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

    // The bar is now a single filter icon that opens a bottom sheet with
    // one checkbox per category, rather than inline chips — open it first.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text(HiddenGemCategory.nature.label));
    await tester.pumpAndSettle();

    expect(controller.selectedCategories, {HiddenGemCategory.nature});

    await tester.tap(find.text(HiddenGemCategory.nature.label));
    await tester.pumpAndSettle();

    expect(controller.selectedCategories, isEmpty);
  });

  testWidgets('every category is reachable in the filter sheet, not just the first few', (
    tester,
  ) async {
    // Regression test: the bar used to be a horizontally-scrolling row of
    // chips, so ones past the visible width were only reachable by
    // scrolling — reported as "not responsive" on a real device. It's now
    // a filter icon that opens a bottom sheet listing every category as
    // its own checkbox row, so none of them can end up unreachable.
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

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    for (final category in HiddenGemCategory.values) {
      expect(find.text(category.label), findsOneWidget);
    }
  });
}
