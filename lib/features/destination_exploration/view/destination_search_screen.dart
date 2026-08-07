import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/hidden_gem.dart';
import '../controller/destination_map_controller.dart';
import '../controller/destination_search_controller.dart';
import '../model/map_destination.dart';
import 'widgets/category_style.dart';

/// An alternate, search-driven way to pick destinations for comparison
/// (besides tapping markers directly on the map) — reached from the map's
/// Comparison mode. Selecting a card here toggles it in the same
/// [DestinationMapController.selectedForComparison] the map itself reads,
/// so switching back shows the same ticks/summary panel.
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends ConsumerState<DestinationSearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _searchFor(DestinationSearchController searchController, String term) {
    _queryController.text = term;
    _queryController.selection = TextSelection.collapsed(offset: term.length);
    searchController.search(term);
  }

  @override
  Widget build(BuildContext context) {
    final searchController = ref.watch(destinationSearchControllerProvider);
    final mapController = ref.watch(destinationMapControllerProvider);
    final isSearchActive = searchController.query.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'Search destinations, trails...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: searchController.search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filter by category',
                    onPressed: () => _showCategorySheet(context, searchController),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryPill(
                      label: 'All',
                      selected: searchController.categoryFilter == null,
                      color: AppTheme.primarySeed,
                      onTap: () => searchController.setCategoryFilter(null),
                    ),
                    for (final category in HiddenGemCategory.values) ...[
                      const SizedBox(width: 8),
                      _CategoryPill(
                        label: category.label,
                        selected: searchController.categoryFilter == category,
                        color: categoryColor(category),
                        onTap: () => searchController.setCategoryFilter(category),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  if (isSearchActive) ...[
                    Text(
                      'Search Results',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (searchController.isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (searchController.results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No destinations found.'),
                      )
                    else
                      _DestinationGrid(
                        destinations: searchController.results,
                        mapController: mapController,
                      ),
                  ] else ...[
                    if (searchController.recentSearches.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Searches',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: searchController.clearRecentSearches,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      for (final term in searchController.recentSearches)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history, size: 20),
                          title: Text(term),
                          onTap: () => _searchFor(searchController, term),
                        ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Trending Destinations',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _DestinationGrid(
                      destinations: searchController.visibleTrending,
                      mapController: mapController,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategorySheet(BuildContext context, DestinationSearchController searchController) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: searchController,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter by Category', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                RadioListTile<HiddenGemCategory?>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All'),
                  value: null,
                  groupValue: searchController.categoryFilter,
                  onChanged: searchController.setCategoryFilter,
                ),
                for (final category in HiddenGemCategory.values)
                  RadioListTile<HiddenGemCategory?>(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(categoryIcon(category), color: categoryColor(category)),
                    title: Text(category.label),
                    value: category,
                    groupValue: searchController.categoryFilter,
                    onChanged: searchController.setCategoryFilter,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DestinationGrid extends StatelessWidget {
  const _DestinationGrid({required this.destinations, required this.mapController});

  final List<MapDestination> destinations;
  final DestinationMapController mapController;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Nothing to show yet.'),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: destinations.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) =>
          _TrendingCard(destination: destinations[index], mapController: mapController),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.destination, required this.mapController});

  final MapDestination destination;
  final DestinationMapController mapController;

  @override
  Widget build(BuildContext context) {
    final isSelected = mapController.selectedForComparison.contains(destination.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final added = mapController.toggleComparisonSelection(destination.id);
        if (!added) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(DestinationMapController.comparisonLimitMessage)),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: destination.imageUrls.isNotEmpty
                      ? Image.network(destination.imageUrls.first, fit: BoxFit.cover)
                      : Container(
                          color: categoryColor(destination.category).withValues(alpha: 0.15),
                          child: Icon(
                            categoryIcon(destination.category),
                            color: categoryColor(destination.category),
                          ),
                        ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor(destination.category),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      destination.category.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            destination.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: AppTheme.gemGold),
              const SizedBox(width: 2),
              Text(destination.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
