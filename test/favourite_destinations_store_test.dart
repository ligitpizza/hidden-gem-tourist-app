// test/favourite_destinations_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/shared/models/hidden_gem.dart';

const _destination = ComparisonDestination(
  id: 'd1',
  name: 'Emerald Falls',
  city: 'George Town',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);

void main() {
  setUp(() {
    // Reset the singleton's state between tests since it's process-global.
    FavouriteDestinationsStore.instance.clearForTesting();
  });

  test('add appends a destination', () {
    FavouriteDestinationsStore.instance.add(_destination);

    expect(FavouriteDestinationsStore.instance.favourites, [_destination]);
  });

  test('adding the same id twice does not duplicate', () {
    FavouriteDestinationsStore.instance.add(_destination);
    FavouriteDestinationsStore.instance.add(_destination);

    expect(FavouriteDestinationsStore.instance.favourites, hasLength(1));
  });
}
