import 'package:flutter/material.dart';

import '../../destination_exploration/model/favourite_destinations_store.dart';
import '../../destination_exploration/view/widgets/category_style.dart';
import '../../itinerary_planning/model/saved_itineraries_store.dart';
import '../../itinerary_planning/view/widgets/saved_itinerary_tile.dart';

/// Favourites and Itineraries used to be two stacked sections on one long
/// scroll; a two-tab layout (swipeable, same as any standard Flutter
/// TabBar/TabBarView) keeps each list to its own screen instead of the
/// user having to scroll past one to reach the other.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    SavedItinerariesStore.instance.ensureLoaded();
    FavouriteDestinationsStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Favourites'),
              Tab(text: 'Itinerary'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FavouritesTab(),
            _ItinerariesTab(),
          ],
        ),
      ),
    );
  }
}

class _FavouritesTab extends StatelessWidget {
  const _FavouritesTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavouriteDestinationsStore.instance,
      builder: (context, _) {
        final store = FavouriteDestinationsStore.instance;

        if (store.isLoading && store.favourites.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (store.error != null && store.favourites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(store.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => store.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (store.favourites.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No favourite destinations yet — save one from Destination Comparison to see it here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final destination in store.favourites)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor(destination.category),
                    child: Icon(categoryIcon(destination.category), color: Colors.white),
                  ),
                  title: Text(destination.name),
                  subtitle: Text(
                    destination.city.isEmpty
                        ? '${destination.avgRating.toStringAsFixed(1)}★'
                        : '${destination.city} · ${destination.avgRating.toStringAsFixed(1)}★',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    tooltip: 'Remove from favourites',
                    onPressed: () => store.remove(destination.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ItinerariesTab extends StatelessWidget {
  const _ItinerariesTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SavedItinerariesStore.instance,
      builder: (context, _) {
        final store = SavedItinerariesStore.instance;

        if (store.isLoading && store.saved.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (store.error != null && store.saved.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(store.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => store.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (store.saved.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No saved itineraries yet — plan a trip and save it to see it here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final saved in store.saved) SavedItineraryTile(saved: saved),
          ],
        );
      },
    );
  }
}
