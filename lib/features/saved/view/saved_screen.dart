import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../destination_exploration/model/comparison_destination.dart';
import '../../destination_exploration/model/favourite_destinations_store.dart';
import '../../destination_exploration/view/widgets/category_style.dart';
import '../../gamification_journal/controller/checkin_controller.dart';
import '../../gamification_journal/model/destination_model.dart';
import '../../gamification_journal/view/checkin/destination_detail_screen.dart';
import '../../itinerary_planning/model/saved_itineraries_store.dart';
import '../../itinerary_planning/view/widgets/route_map_view.dart';
import '../../itinerary_planning/view/widgets/saved_itinerary_tile.dart';

/// Best-effort mapping from a favourite's [HiddenGemCategory] to this
/// module's plain-string category label, used only to build a
/// [DestinationModel] fallback when the destination hasn't already been
/// loaded via [CheckInController] — mirrors gamification_journal's own
/// private `_journalCategoryLabel` (small self-contained duplication for a
/// short switch, same convention already used by DestinationMapController's
/// `_representativeCategory`).
String _favouriteCategoryLabel(HiddenGemCategory category) => switch (category) {
      HiddenGemCategory.nature => 'Nature',
      HiddenGemCategory.food => 'Food',
      HiddenGemCategory.culture => 'Culture',
      HiddenGemCategory.viewpoint => 'Culture',
      HiddenGemCategory.craft => 'Culture',
    };

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

class _FavouritesTab extends StatefulWidget {
  const _FavouritesTab();

  @override
  State<_FavouritesTab> createState() => _FavouritesTabState();
}

class _FavouritesTabState extends State<_FavouritesTab> {
  final Set<HiddenGemCategory> _selectedCategories = {};

  void _toggleCategory(HiddenGemCategory category) {
    setState(() {
      if (!_selectedCategories.remove(category)) {
        _selectedCategories.add(category);
      }
    });
  }

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

        final filtered = _selectedCategories.isEmpty
            ? store.favourites
            : store.favourites.where((d) => _selectedCategories.contains(d.category)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in HiddenGemCategory.values)
                    FilterChip(
                      avatar: Icon(categoryIcon(category), size: 16, color: categoryColor(category)),
                      label: Text(category.label),
                      selected: _selectedCategories.contains(category),
                      onSelected: (_) => _toggleCategory(category),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No favourites match the selected filters.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final destination in filtered) _FavouriteCard(destination: destination),
                      ],
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

class _FavouriteCard extends StatelessWidget {
  const _FavouriteCard({required this.destination});

  final ComparisonDestination destination;

  void _openDetail(BuildContext context) {
    final checkInController = context.read<CheckInController>();
    if (checkInController.destinations.isEmpty) {
      unawaited(checkInController.loadDestinations().catchError((_) {}));
    }
    DestinationModel? resolved;
    for (final d in checkInController.destinations) {
      if (d.id == destination.id) {
        resolved = d;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(
          destination: resolved ??
              DestinationModel(
                id: destination.id,
                name: destination.name,
                state: stateForCity(destination.city),
                category: _favouriteCategoryLabel(destination.category),
                latitude: destination.location.latitude,
                longitude: destination.location.longitude,
                description: '',
                imageUrl: destination.imageUrls.isNotEmpty
                    ? destination.imageUrls.first
                    : 'https://picsum.photos/seed/${destination.id}/900/600',
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: RouteMapView(
                    height: 56,
                    borderRadius: BorderRadius.zero,
                    markers: [
                      MapMarkerSpec(
                        point: destination.location,
                        color: categoryColor(destination.category),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      destination.city.isEmpty
                          ? '${destination.avgRating.toStringAsFixed(1)}★'
                          : '${destination.city} · ${destination.avgRating.toStringAsFixed(1)}★',
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                tooltip: 'Remove from favourites',
                onPressed: () => FavouriteDestinationsStore.instance.remove(destination.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
