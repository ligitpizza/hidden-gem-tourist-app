import 'package:flutter/material.dart';

import '../../itinerary_planning/model/saved_itineraries_store.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final saved = SavedItinerariesStore.instance.saved;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: saved.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved itineraries yet — plan a trip and save it to see it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = saved[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(plan.destinations.map((d) => d.name).join(' → ')),
                    subtitle: Text('${plan.timeline.length} stops'),
                  ),
                );
              },
            ),
    );
  }
}
