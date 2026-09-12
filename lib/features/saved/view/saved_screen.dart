import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/hidden_gem.dart';

import '../../culture_community/controller/culture_saved_controller.dart';
import '../../culture_community/model/cultural_event.dart';
import '../../culture_community/model/traditional_food.dart';
import '../../culture_community/model/traditional_food_place.dart';
import '../../culture_community/view/cultural_event_detail_screen.dart';
import '../../culture_community/view/google_maps_navigation.dart';
import '../../culture_community/view/traditional_food_detail_screen.dart';
import '../../destination_exploration/model/comparison_destination.dart';
import '../../destination_exploration/model/favourite_destinations_store.dart';
import '../../destination_exploration/view/widgets/category_style.dart';
import '../../gamification_journal/controller/checkin_controller.dart';
import '../../gamification_journal/model/destination_model.dart';
import '../../gamification_journal/view/checkin/destination_detail_screen.dart';
import '../../itinerary_planning/model/saved_itineraries_store.dart';
import '../../itinerary_planning/view/widgets/saved_itinerary_tile.dart';

/// Best-effort mapping from a favourite's [HiddenGemCategory] to this
/// module's plain-string category label, used only to build a
/// [DestinationModel] fallback when the destination hasn't already been
/// loaded via [CheckInController] — mirrors gamification_journal's own
/// private `_journalCategoryLabel` (small self-contained duplication for a
/// short switch, same convention already used by DestinationMapController's
/// `_representativeCategory`).
String _favouriteCategoryLabel(HiddenGemCategory category) =>
    switch (category) {
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
  State<_FavouritesTab> createState() =>
      _FavouritesTabState();
}

class _FavouritesTabState extends State<_FavouritesTab> {


  final Set<HiddenGemCategory> _selectedCategories = {};



  late final CultureSavedController _cultureSavedController;

  @override
  void initState() {
    super.initState();


    _cultureSavedController =
        CultureSavedController();
  }

  @override
  void dispose() {
    _cultureSavedController.dispose();

    super.dispose();
  }


  void _toggleCategory(HiddenGemCategory category) {
    setState(() {
      if (!_selectedCategories.remove(category)) {
        _selectedCategories.add(category);
      }
    });
  }



  bool get _showCultureSavedItems {
    return _selectedCategories.isEmpty ||
        _selectedCategories.contains(
          HiddenGemCategory.culture,
        );
  }

  bool get _hasCultureSavedItems {
    return _cultureSavedController
        .favouriteEvents.isNotEmpty ||
        _cultureSavedController
            .favouriteFoods.isNotEmpty ||
        _cultureSavedController
            .favouritePlaces.isNotEmpty;
  }


  Future<void> _refreshAll() async {
    await Future.wait([
      FavouriteDestinationsStore.instance.refresh(),
      _cultureSavedController.refresh(),
    ]);
  }


  Future<bool> _confirmRemove({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    return result == true;
  }


  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(


      listenable: Listenable.merge([
        FavouriteDestinationsStore.instance,
        _cultureSavedController,
      ]),

      builder: (context, _) {
        final store =
            FavouriteDestinationsStore.instance;

        final culture =
            _cultureSavedController;



        final destinationLoading =
            store.isLoading &&
                store.favourites.isEmpty;

        final cultureLoading =
            culture.isLoading &&
                !_hasCultureSavedItems;

        if (destinationLoading &&
            cultureLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }


        final filtered =
        _selectedCategories.isEmpty
            ? store.favourites
            : store.favourites
            .where(
              (destination) =>
              _selectedCategories.contains(
                destination.category,
              ),
        )
            .toList();

        final visibleCultureItems =
            _showCultureSavedItems &&
                _hasCultureSavedItems;

        final nothingVisible =
            filtered.isEmpty &&
                !visibleCultureItems;


        if (store.favourites.isEmpty &&
            !_hasCultureSavedItems &&
            !destinationLoading &&
            !cultureLoading) {
          // Keep friend destination error behaviour.
          if (store.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          store.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (culture.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      culture.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          culture.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No favourites yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }



        return Column(
          children: [


            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                4,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category
                  in HiddenGemCategory.values)
                    FilterChip(
                      avatar: Icon(
                        categoryIcon(category),
                        size: 16,
                        color:
                        categoryColor(category),
                      ),
                      label: Text(
                        category.label,
                      ),
                      selected:
                      _selectedCategories.contains(
                        category,
                      ),
                      onSelected: (_) =>
                          _toggleCategory(
                            category,
                          ),
                    ),
                ],
              ),
            ),


            Expanded(
              child: nothingVisible
                  ? const Center(
                child: Padding(
                  padding:
                  EdgeInsets.all(16),
                  child: Text(
                    'No favourites match the selected filters.',
                    textAlign:
                    TextAlign.center,
                  ),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding:
                  const EdgeInsets.all(16),
                  children: [


                    for (final destination
                    in filtered)
                      _FavouriteCard(
                        destination:
                        destination,
                      ),



                    if (_showCultureSavedItems) ...[


                      if (culture
                          .favouriteEvents
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 20,
                        ),

                        _CultureSectionHeader(
                          icon: Icons
                              .celebration_outlined,
                          title:
                          'Cultural Events',
                          count: culture
                              .favouriteEvents
                              .length,
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        for (final event
                        in culture
                            .favouriteEvents) ...[
                          _SavedCulturalEventCard(
                            event: event,

                            onRemove:
                                () async {
                              final confirmed =
                              await _confirmRemove(
                                title:
                                'Remove from favourites?',
                                message:
                                '"${event.name}" will be removed from your favourites.',
                              );

                              if (!confirmed) {
                                return;
                              }

                              final success =
                              await culture
                                  .removeEventFavourite(
                                event.id,
                              );

                              if (success) {
                                _showMessage(
                                  '${event.name} removed from favourites.',
                                );
                              } else {
                                _showMessage(
                                  culture.errorMessage ??
                                      'Could not remove saved event.',
                                );
                              }
                            },
                          ),

                          const SizedBox(
                            height: 8,
                          ),
                        ],
                      ],


                      if (culture
                          .favouriteFoods
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 20,
                        ),

                        _CultureSectionHeader(
                          icon: Icons
                              .restaurant_menu_rounded,
                          title:
                          'Traditional Foods',
                          count: culture
                              .favouriteFoods
                              .length,
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        for (final food
                        in culture
                            .favouriteFoods) ...[
                          _SavedTraditionalFoodCard(
                            food: food,

                            onRemove:
                                () async {
                              final confirmed =
                              await _confirmRemove(
                                title:
                                'Remove from favourites?',
                                message:
                                '"${food.name}" will be removed from your favourites.',
                              );

                              if (!confirmed) {
                                return;
                              }

                              final success =
                              await culture
                                  .removeFoodFavourite(
                                food.id,
                              );

                              if (success) {
                                _showMessage(
                                  '${food.name} removed from favourites.',
                                );
                              } else {
                                _showMessage(
                                  culture.errorMessage ??
                                      'Could not remove saved food.',
                                );
                              }
                            },
                          ),

                          const SizedBox(
                            height: 8,
                          ),
                        ],
                      ],



                      if (culture
                          .favouritePlaces
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 20,
                        ),

                        _CultureSectionHeader(
                          icon: Icons
                              .storefront_outlined,
                          title:
                          'Saved Restaurants',
                          count: culture
                              .favouritePlaces
                              .length,
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        for (final place
                        in culture
                            .favouritePlaces) ...[
                          _SavedRestaurantCard(
                            place: place,

                            onRemove:
                                () async {
                              final confirmed =
                              await _confirmRemove(
                                title:
                                'Remove from favourites?',
                                message:
                                '"${place.name}" will be removed from your saved restaurants.',
                              );

                              if (!confirmed) {
                                return;
                              }

                              final success =
                              await culture
                                  .removePlaceFavourite(
                                place.id,
                              );

                              if (success) {
                                _showMessage(
                                  '${place.name} removed from favourites.',
                                );
                              } else {
                                _showMessage(
                                  culture.errorMessage ??
                                      'Could not remove saved restaurant.',
                                );
                              }
                            },
                          ),

                          const SizedBox(
                            height: 8,
                          ),
                        ],
                      ],
                    ],



                    if (_showCultureSavedItems &&
                        culture.errorMessage !=
                            null &&
                        !_hasCultureSavedItems) ...[
                      const SizedBox(
                        height: 16,
                      ),

                      Card(
                        child: Padding(
                          padding:
                          const EdgeInsets.all(
                            14,
                          ),
                          child: Column(
                            children: [
                              Text(
                                culture.errorMessage!,
                                textAlign:
                                TextAlign.center,
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              OutlinedButton(
                                onPressed: () {
                                  culture.refresh();
                                },
                                child:
                                const Text(
                                  'Retry',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
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
        final store =
            SavedItinerariesStore.instance;

        if (store.isLoading &&
            store.saved.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (store.error != null &&
            store.saved.isEmpty) {
          return Center(
            child: Padding(
              padding:
              const EdgeInsets.all(16),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Text(
                    store.error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        store.refresh(),
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
              padding:
              EdgeInsets.all(16),
              child: Text(
                'No saved itineraries yet — plan a trip and save it to see it here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            for (final saved
            in store.saved)
              SavedItineraryTile(
                saved: saved,
              ),
          ],
        );
      },
    );
  }
}



class _FavouriteCard extends StatelessWidget {
  const _FavouriteCard({
    required this.destination,
  });

  final ComparisonDestination destination;

  Future<void> _confirmRemove(
      BuildContext context,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text(
              'Remove from favourites?',
            ),
            content: Text(
              '"${destination.name}" will be removed from your favourites.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(false),
                child:
                const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(true),
                child:
                const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await FavouriteDestinationsStore
          .instance
          .remove(
        destination.id,
      );
    }
  }

  void _openDetail(
      BuildContext context,
      ) {
    final checkInController =
    context.read<CheckInController>();

    if (checkInController
        .destinations.isEmpty) {
      unawaited(
        checkInController
            .loadDestinations()
            .catchError(
              (_) {},
        ),
      );
    }

    DestinationModel? resolved;

    for (final d
    in checkInController
        .destinations) {
      if (d.id ==
          destination.id) {
        resolved = d;

        break;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DestinationDetailScreen(
              destination:
              resolved ??
                  DestinationModel(
                    id: destination.id,
                    name:
                    destination.name,
                    state:
                    stateForCity(
                      destination.city,
                    ),
                    category:
                    _favouriteCategoryLabel(
                      destination.category,
                    ),
                    latitude:
                    destination
                        .location
                        .latitude,
                    longitude:
                    destination
                        .location
                        .longitude,
                    description: '',
                    imageUrl: destination
                        .imageUrls
                        .isNotEmpty
                        ? destination
                        .imageUrls
                        .first
                        : 'https://picsum.photos/seed/${destination.id}/900/600',
                    imageUrls: destination
                        .imageUrls
                        .isNotEmpty
                        ? destination
                        .imageUrls
                        : [
                      'https://picsum.photos/seed/${destination.id}/900/600'
                    ],
                  ),
            ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _openDetail(
              context,
            ),
        child: Padding(
          padding:
          const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: destination
                      .imageUrls
                      .isEmpty
                      ? Container(
                    color: Colors
                        .grey
                        .shade300,
                    child:
                    const Icon(
                      Icons
                          .image_not_supported_outlined,
                      size: 20,
                      color:
                      Colors.grey,
                    ),
                  )
                      : Image.network(
                    destination
                        .imageUrls
                        .first,
                    fit:
                    BoxFit.cover,
                    errorBuilder: (
                        context,
                        error,
                        stackTrace,
                        ) =>
                        Container(
                          color: Colors
                              .grey
                              .shade300,
                          child:
                          const Icon(
                            Icons
                                .image_not_supported_outlined,
                            size: 20,
                            color:
                            Colors.grey,
                          ),
                        ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    Text(
                      destination.city.isEmpty
                          ? '${destination.avgRating.toStringAsFixed(1)}★'
                          : '${destination.city} · ${destination.avgRating.toStringAsFixed(1)}★',
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                ),
                tooltip:
                'Remove from favourites',
                onPressed: () =>
                    _confirmRemove(
                      context,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _CultureSectionHeader
    extends StatelessWidget {
  const _CultureSectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;

  final String title;

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          color: colors.primary,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            style:
            Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color:
            colors.secondaryContainer,
            borderRadius:
            BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}



class _SavedCulturalEventCard
    extends StatelessWidget {
  const _SavedCulturalEventCard({
    required this.event,
    required this.onRemove,
  });

  final CulturalEvent event;

  final VoidCallback onRemove;

  void _openDetail(
      BuildContext context,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CulturalEventDetailScreen(
              event: event,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _openDetail(
              context,
            ),
        child: Padding(
          padding:
          const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                _cultureEventColor(
                  event.category,
                ),
                child: Icon(
                  _cultureEventIcon(
                    event.category,
                  ),
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _eventDateRange(
                        event,
                      ),
                      style: TextStyle(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _eventLocation(
                        event,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip:
                'Remove from favourites',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.bookmark_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _SavedTraditionalFoodCard
    extends StatelessWidget {
  const _SavedTraditionalFoodCard({
    required this.food,
    required this.onRemove,
  });

  final TraditionalFood food;

  final VoidCallback onRemove;

  void _openDetail(
      BuildContext context,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TraditionalFoodDetailScreen(
              food: food,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _openDetail(
              context,
            ),
        child: Padding(
          padding:
          const EdgeInsets.all(10),
          child: Row(
            children: [
              _SavedFoodImage(
                food: food,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),

                    const SizedBox(height: 3),

                    Text(
                      food.state,
                      style: TextStyle(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      food.culturalCategory,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip:
                'Remove from favourites',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.bookmark_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _SavedFoodImage
    extends StatelessWidget {
  const _SavedFoodImage({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final image =
    food.imageUrl?.trim();

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 56,
        child: image == null ||
            image.isEmpty
            ? Container(
          color: Theme.of(context)
              .colorScheme
              .secondaryContainer,
          child: Icon(
            Icons.restaurant_rounded,
            color: Theme.of(context)
                .colorScheme
                .onSecondaryContainer,
          ),
        )
            : Image.network(
          image,
          fit: BoxFit.cover,
          errorBuilder: (
              context,
              error,
              stackTrace,
              ) {
            return Container(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              child: Icon(
                Icons
                    .restaurant_rounded,
                color: Theme.of(context)
                    .colorScheme
                    .onSecondaryContainer,
              ),
            );
          },
        ),
      ),
    );
  }
}



class _SavedRestaurantCard
    extends StatelessWidget {
  const _SavedRestaurantCard({
    required this.place,
    required this.onRemove,
  });

  final TraditionalFoodPlace place;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  colors.secondaryContainer,
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: colors
                        .onSecondaryContainer,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style:
                        Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _restaurantLocation(
                          place,
                        ),
                        style: TextStyle(
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _halalLabel(
                          place.halalStatus,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip:
                  'Remove from favourites',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.bookmark_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await openGoogleMapsNavigation(
                    context: context,
                    latitude:
                    place.latitude,
                    longitude:
                    place.longitude,
                  );
                },
                icon: const Icon(
                  Icons.navigation_rounded,
                ),
                label: const Text(
                  'Navigate with Google Maps',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



Color _cultureEventColor(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return const Color(
        0xFFE67E22,
      );

    case CulturalEventCategory.culturalShow:
      return const Color(
        0xFF7B2CBF,
      );

    case CulturalEventCategory.communityActivity:
      return const Color(
        0xFF1B7F5C,
      );
  }
}

IconData _cultureEventIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons.celebration_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons.theater_comedy_rounded;

    case CulturalEventCategory.communityActivity:
      return Icons.groups_rounded;
  }
}

String _eventDateRange(
    CulturalEvent event,
    ) {
  final start =
  event.startAt.toLocal();

  final end =
  event.endAt?.toLocal();

  if (end == null) {
    return _formatCultureDate(
      start,
    );
  }

  final sameDay =
      start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;

  if (sameDay) {
    return _formatCultureDate(
      start,
    );
  }

  return '${_formatCultureDate(start)} - '
      '${_formatCultureDate(end)}';
}

String _formatCultureDate(
    DateTime date,
    ) {
  final local =
  date.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${local.day} '
      '${months[local.month - 1]} '
      '${local.year}';
}

String _eventLocation(
    CulturalEvent event,
    ) {
  return [
    if (event.city != null &&
        event.city!
            .trim()
            .isNotEmpty)
      event.city!,
    event.state,
  ].join(', ');
}

String _restaurantLocation(
    TraditionalFoodPlace place,
    ) {
  return [
    if (place.city != null &&
        place.city!
            .trim()
            .isNotEmpty)
      place.city!,
    place.state,
  ].join(', ');
}

String _halalLabel(
    String value,
    ) {
  switch (value) {
    case 'certified':
      return 'Halal Certified';

    case 'muslim_friendly':
      return 'Muslim-Friendly';

    case 'non_halal':
      return 'Non-Halal';

    default:
      return 'Status Unknown';
  }
}