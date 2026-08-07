import 'package:flutter/material.dart';

import '../../destination_exploration/model/favourite_destinations_store.dart';
import '../../destination_exploration/view/widgets/category_style.dart';
import '../../itinerary_planning/model/saved_itineraries_store.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final saved = SavedItinerariesStore.instance.saved;

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
          if (saved.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No saved itineraries yet — plan a trip and save it to see it here.'),
            )
          else
            for (final plan in saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(plan.destinations.map((d) => d.name).join(' → ')),
                    subtitle: Text('${plan.timeline.length} stops'),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
