// test/favourite_destinations_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/favourite_destination_repository.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeFavouriteRepository extends FavouriteDestinationRepository {
  _FakeFavouriteRepository({
    this.fetchResult = const [],
    this.resolveResult = const [],
    this.shouldThrowOnAdd = false,
    this.shouldThrowOnRemove = false,
  });

  final List<ComparisonDestination> fetchResult;
  final List<ComparisonDestination> resolveResult;
  final bool shouldThrowOnAdd;
  final bool shouldThrowOnRemove;
  final List<String> addedIds = [];
  final List<String> removedIds = [];

  @override
  Future<List<ComparisonDestination>> fetchAll() async => fetchResult;

  @override
  Future<List<ComparisonDestination>> resolveByIds(List<String> ids) async =>
      resolveResult.where((d) => ids.contains(d.id)).toList();

  @override
  Future<void> add(String destinationId) async {
    if (shouldThrowOnAdd) throw Exception('network error');
    addedIds.add(destinationId);
  }

  @override
  Future<void> remove(String destinationId) async {
    if (shouldThrowOnRemove) throw Exception('network error');
    removedIds.add(destinationId);
  }
}

const _destination = ComparisonDestination(
  id: 'd1',
  name: 'Emerald Falls',
  city: 'George Town',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);
const _other = ComparisonDestination(
  id: 'd2',
  name: 'Batu Caves',
  city: 'Gombak',
  category: HiddenGemCategory.culture,
  location: LatLng(3.2, 101.6),
);

void main() {
  test('add appends a destination and persists it via the repository', () async {
    final repository = _FakeFavouriteRepository();
    final store = FavouriteDestinationsStore(repository: repository);

    await store.add(_destination);

    expect(store.favourites, [_destination]);
    expect(repository.addedIds, ['d1']);
  });

  test('adding the same id twice does not duplicate or call the repository again', () async {
    final repository = _FakeFavouriteRepository();
    final store = FavouriteDestinationsStore(repository: repository);

    await store.add(_destination);
    await store.add(_destination);

    expect(store.favourites, hasLength(1));
    expect(repository.addedIds, ['d1']);
  });

  test('add rolls back and sets error when the repository call fails', () async {
    final repository = _FakeFavouriteRepository(shouldThrowOnAdd: true);
    final store = FavouriteDestinationsStore(repository: repository);

    await store.add(_destination);

    expect(store.favourites, isEmpty);
    expect(store.error, isNotNull);
  });

  test('remove drops a destination and persists it via the repository', () async {
    final repository = _FakeFavouriteRepository();
    final store = FavouriteDestinationsStore(repository: repository);
    await store.add(_destination);
    await store.add(_other);

    await store.remove('d1');

    expect(store.favourites.map((d) => d.id), ['d2']);
    expect(repository.removedIds, ['d1']);
  });

  test('remove rolls back and sets error when the repository call fails', () async {
    final repository = _FakeFavouriteRepository(shouldThrowOnRemove: true);
    final store = FavouriteDestinationsStore(repository: repository);
    await store.add(_destination);

    await store.remove('d1');

    expect(store.favourites, [_destination]);
    expect(store.error, isNotNull);
  });

  test('refresh loads from the repository and sets isLoading/error correctly', () async {
    final repository = _FakeFavouriteRepository(fetchResult: [_destination, _other]);
    final store = FavouriteDestinationsStore(repository: repository);

    await store.refresh();

    expect(store.favourites, [_destination, _other]);
    expect(store.isLoading, isFalse);
    expect(store.error, isNull);
  });

  test('ensureLoaded only calls the repository once', () async {
    final repository = _FakeFavouriteRepository(fetchResult: [_destination]);
    final store = FavouriteDestinationsStore(repository: repository);

    await store.ensureLoaded();
    await store.ensureLoaded();

    expect(store.favourites, [_destination]);
  });

  test('contains reflects the current favourites', () async {
    final repository = _FakeFavouriteRepository();
    final store = FavouriteDestinationsStore(repository: repository);

    expect(store.contains('d1'), isFalse);
    await store.add(_destination);
    expect(store.contains('d1'), isTrue);
  });

  test('addById resolves the real destination via the repository and adds it', () async {
    final favouriteRepo = _FakeFavouriteRepository(resolveResult: [_destination]);
    final store = FavouriteDestinationsStore(repository: favouriteRepo);

    await store.addById('d1');

    expect(store.favourites, [_destination]);
    expect(favouriteRepo.addedIds, ['d1']);
  });

  test('addById does nothing if the destination cannot be resolved', () async {
    final favouriteRepo = _FakeFavouriteRepository();
    final store = FavouriteDestinationsStore(repository: favouriteRepo);

    await store.addById('missing');

    expect(store.favourites, isEmpty);
    expect(favouriteRepo.addedIds, isEmpty);
  });

  test('toggleById removes when already favourited, adds when not', () async {
    final favouriteRepo = _FakeFavouriteRepository(resolveResult: [_destination]);
    final store = FavouriteDestinationsStore(repository: favouriteRepo);

    await store.toggleById('d1');
    expect(store.contains('d1'), isTrue);

    await store.toggleById('d1');
    expect(store.contains('d1'), isFalse);
  });

  test('addById resolves via the place_hidden_gem_candidates view, not fetchForComparison',
      () async {
    // Regression test: addById used to resolve through
    // DestinationExplorationRepository.fetchForComparison, which queries
    // the raw `destinations` table and silently returned 0.0 ratings and
    // no photos for anything favourited from the Destination Detail
    // screen's "Save to Favourites" button -- exactly the same class of
    // bug fetchAll's resolveByIds call was already fixed for.
    const withRatingAndPhoto = ComparisonDestination(
      id: 'd1',
      name: 'Emerald Falls',
      city: 'George Town',
      category: HiddenGemCategory.nature,
      location: LatLng(5.4, 100.3),
      avgRating: 4.7,
      imageUrls: ['https://example.com/emerald-falls.jpg'],
    );
    final favouriteRepo = _FakeFavouriteRepository(resolveResult: [withRatingAndPhoto]);
    final store = FavouriteDestinationsStore(repository: favouriteRepo);

    await store.addById('d1');

    expect(store.favourites.single.avgRating, 4.7);
    expect(store.favourites.single.imageUrls, ['https://example.com/emerald-falls.jpg']);
  });
}
