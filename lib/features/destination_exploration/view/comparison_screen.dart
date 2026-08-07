import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Consumer;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../itinerary_planning/controller/itinerary_planner_controller.dart';
import '../controller/comparison_controller.dart';
import '../controller/destination_map_controller.dart';
import '../model/comparison_destination.dart';
import '../model/crowd_level.dart';
import 'widgets/category_style.dart';

/// Attraction Comparison (Feature 3): a side-by-side view of the
/// destinations selected on the map (FR3.2), with a "Calculate Best Pick"
/// action that reveals the highlighted recommendation (FR3.5-FR3.8) and its
/// three follow-up actions (FR3.9).
///
/// [ComparisonController] isn't a global provider — its lifecycle (and the
/// destination ids it loads) is specific to one comparison visit, so this
/// screen owns its own instance via `package:provider`'s
/// `ChangeNotifierProvider`, the same package already used for Module 6's
/// screen-scoped controllers.
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key, required this.destinationIds});

  final List<String> destinationIds;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late final ComparisonController _controller;
  bool _showBestPick = false;

  @override
  void initState() {
    super.initState();
    _controller = ComparisonController(currentLocation: _currentLocation)
      ..loadComparison(widget.destinationIds);
  }

  static Future<LatLng?> _currentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComparisonController>.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_showBestPick ? 'Best Pick' : 'Side-by-Side Comparison'),
          leading: _showBestPick
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _showBestPick = false),
                )
              : null,
          actions: _showBestPick
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear selected destinations',
                    onPressed: () {
                      ProviderScope.containerOf(context, listen: false)
                          .read(destinationMapControllerProvider)
                          .clearComparisonSelection();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
        ),
        body: Consumer<ComparisonController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.selectionError != null) {
              return Center(child: Text(controller.selectionError!));
            }

            if (controller.loadError != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(controller.loadError!),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => controller.loadComparison(widget.destinationIds),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return _showBestPick
                ? _BestPickView(controller: controller)
                : _SideBySideView(
                    controller: controller,
                    onCalculate: () => setState(() => _showBestPick = true),
                  );
          },
        ),
      ),
    );
  }
}

class _SideBySideView extends StatelessWidget {
  const _SideBySideView({required this.controller, required this.onCalculate});

  final ComparisonController controller;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.destinations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _ComparisonCard(destination: controller.destinations[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: onCalculate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Calculate Best Pick'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.destination});

  final ComparisonDestination destination;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor(destination.category),
                  child: Icon(categoryIcon(destination.category), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(destination.name, style: Theme.of(context).textTheme.titleMedium),
                      if (destination.city.isNotEmpty) Text(destination.city),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Stat(label: 'Hidden Gem Score', value: destination.hiddenGemScore.toStringAsFixed(2)),
                _Stat(label: 'User Rating', value: '${destination.avgRating.toStringAsFixed(1)}★'),
                _Stat(label: 'Crowd Level', value: destination.crowdLevel.label),
                _DistanceStat(destination: destination),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Distance is reference-only (FR3.6) — computed asynchronously via the
/// device's location, never part of the Best Pick score.
class _DistanceStat extends StatelessWidget {
  const _DistanceStat({required this.destination});

  final ComparisonDestination destination;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ComparisonController>();
    return FutureBuilder<double?>(
      future: controller.distanceFromUser(destination),
      builder: (context, snapshot) {
        final value = snapshot.data;
        return _Stat(
          label: 'Distance',
          value: value == null ? 'Not available' : '${value.toStringAsFixed(1)}km',
        );
      },
    );
  }
}

class _BestPickView extends StatelessWidget {
  const _BestPickView({required this.controller});

  final ComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final pick = controller.bestPick;
    if (pick == null) {
      return const Center(child: Text('No destinations to compare.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: categoryColor(pick.category),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEST PICK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pick.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(controller.scoreFor(pick) * 100).round()}% match score',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Weighting Preferences', style: Theme.of(context).textTheme.titleSmall),
        _WeightSlider(
          label: 'User Rating',
          value: controller.weights.rating,
          onChanged: (v) => controller.setWeights(PriorityWeights(
            rating: v,
            cost: controller.weights.cost,
            crowd: controller.weights.crowd,
            accessibility: controller.weights.accessibility,
          )),
        ),
        _WeightSlider(
          label: 'Cost Efficiency',
          value: controller.weights.cost,
          onChanged: (v) => controller.setWeights(PriorityWeights(
            rating: controller.weights.rating,
            cost: v,
            crowd: controller.weights.crowd,
            accessibility: controller.weights.accessibility,
          )),
        ),
        _WeightSlider(
          label: 'Crowd Density',
          value: controller.weights.crowd,
          onChanged: (v) => controller.setWeights(PriorityWeights(
            rating: controller.weights.rating,
            cost: controller.weights.cost,
            crowd: v,
            accessibility: controller.weights.accessibility,
          )),
        ),
        _WeightSlider(
          label: 'Accessibility',
          value: controller.weights.accessibility,
          onChanged: (v) => controller.setWeights(PriorityWeights(
            rating: controller.weights.rating,
            cost: controller.weights.cost,
            crowd: controller.weights.crowd,
            accessibility: v,
          )),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AttributeRow(label: 'Category', value: pick.category.label),
                _AttributeRow(
                    label: 'Hidden Gem Score', value: pick.hiddenGemScore.toStringAsFixed(2)),
                _AttributeRow(label: 'User Rating', value: '${pick.avgRating.toStringAsFixed(1)}★'),
                _AttributeRow(label: 'Crowd Level', value: pick.crowdLevel.label),
                _AttributeRow(
                  label: 'Entrance Cost',
                  value: pick.entranceCost == null
                      ? 'Not available'
                      : 'RM${pick.entranceCost!.toStringAsFixed(0)}',
                ),
                _AttributeRow(
                  label: 'Difficulty',
                  value: pick.difficultyLevel ?? 'Not available',
                ),
                _AttributeRow(
                  label: 'Accessibility Tags',
                  value: pick.accessibilityTags.isEmpty
                      ? 'Not available'
                      : pick.accessibilityTags.join(', '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Consumer<ComparisonController>(
          builder: (context, controller, _) => Column(
            children: [
              FilledButton.icon(
                onPressed: () async {
                  await controller.addBestPickToItinerary(
                    ProviderScope.containerOf(context, listen: false)
                        .read(itineraryPlannerControllerProvider),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${pick.name} added to your itinerary')),
                    );
                  }
                },
                icon: const Icon(Icons.card_travel),
                label: const Text('Add to Itinerary'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  controller.saveToFavourites(pick);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${pick.name} saved to favourites')),
                  );
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('Save to Favourites'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await controller.shareComparison();
                  if (controller.shareError != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(controller.shareError!)));
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('Share Comparison'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(0, 1),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
