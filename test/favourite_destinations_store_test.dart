// test/favourite_destinations_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/favourite_destination_repository.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeFavouriteRepository extends FavouriteDestinationRepository {
  _FakeFavouriteRepository({this.fetchResult = const [], this.shouldThrowOnAdd = false, this.shouldThrowOnRemove = false});

  final List<ComparisonDestination> fetchResult;
  final bool shouldThrowOnAdd;
  final bool shouldThrowOnRemove;
  final List<String> addedIds = [];
  final List<String> removedIds = [];

  @override
  Future<List<ComparisonDestination>> fetchAll() async => fetchResult;

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
}
