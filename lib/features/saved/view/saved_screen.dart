import 'package:flutter/material.dart';

import '../../destination_exploration/model/favourite_destinations_store.dart';
import '../../destination_exploration/view/widgets/category_style.dart';
import '../../itinerary_planning/model/saved_itineraries_store.dart';
import '../../itinerary_planning/view/widgets/saved_itinerary_tile.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Favourite Destinations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: FavouriteDestinationsStore.instance,
            builder: (context, _) {
              final favourites = FavouriteDestinationsStore.instance.favourites;
              if (favourites.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No favourite destinations yet — save one from Destination Comparison to see it here.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final destination in favourites)
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
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Saved Itineraries', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: SavedItinerariesStore.instance,
            builder: (context, _) {
              final store = SavedItinerariesStore.instance;

              if (store.isLoading && store.saved.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (store.error != null && store.saved.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.error!),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => store.refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (store.saved.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No saved itineraries yet — plan a trip and save it to see it here.'),
                );
              }

              return Column(
                children: [
                  for (final saved in store.saved) SavedItineraryTile(saved: saved),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
