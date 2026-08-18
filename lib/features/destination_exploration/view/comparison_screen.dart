import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Consumer;
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../itinerary_planning/controller/itinerary_planner_controller.dart';
import '../controller/comparison_controller.dart';
import '../controller/destination_map_controller.dart';
import '../model/comparison_destination.dart';
import '../model/crowd_level.dart';
import '../model/favourite_destinations_store.dart';
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
    final count = controller.destinations.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Side-by-Side Comparison',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'A data-driven evaluation of your top-tier shortlisted destinations.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primarySeed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Compare $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: controller.destinations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _ComparisonCard(destination: controller.destinations[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                destination.imageUrls.isNotEmpty
                    ? Image.network(
                        destination.imageUrls.first,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ImagePlaceholder(destination: destination),
                      )
                    : _ImagePlaceholder(destination: destination),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor(destination.category),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      destination.category.label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (destination.city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            destination.city,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ScoreBlock(
                    label: 'HIDDEN GEM SCORE',
                    value: '${(destination.hiddenGemScore * 10).toStringAsFixed(1)}/10',
                  ),
                  const Divider(height: 20),
                  _ScoreBlock(
                    label: 'USER RATING',
                    value: '★${destination.avgRating.toStringAsFixed(1)}',
                  ),
                  const Divider(height: 20),
                  _DistanceBlock(destination: destination),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.destination});

  final ComparisonDestination destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      width: double.infinity,
      color: categoryColor(destination.category).withValues(alpha: 0.15),
      child: Icon(categoryIcon(destination.category), color: categoryColor(destination.category)),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (caption != null && caption!.isNotEmpty)
          Text(
            caption!,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// Distance is reference-only (FR3.6) — computed asynchronously via the
/// device's location, never part of the Best Pick score.
class _DistanceBlock extends StatelessWidget {
  const _DistanceBlock({required this.destination});

  final ComparisonDestination destination;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ComparisonController>();
    return FutureBuilder<double?>(
      future: controller.distanceFromUser(destination),
      builder: (context, snapshot) {
        final value = snapshot.data;
        return _ScoreBlock(
          label: 'DISTANCE',
          value: value == null ? 'Not available' : '${value.toStringAsFixed(1)} km',
          caption: destination.difficultyLevel,
        );
      },
    );
  }
}

/// Very rough drive-time estimate from a straight-line distance — no
/// routing API involved, just a fixed average-speed assumption, so this is
/// always shown with a "~" to signal it's an estimate, not a real ETA.
int _estimateDriveMinutes(double km) => (km / 35 * 60).round();

/// A short, real-data-derived summary of what's driving the recommendation
/// — built from the two most heavily weighted priorities, not fabricated
/// per-destination narrative.
String _preferenceSummary(PriorityWeights weights) {
  final entries = <MapEntry<String, double>>[
    MapEntry('quality ratings', weights.rating),
    MapEntry('cost efficiency', weights.cost),
    MapEntry('low crowds', weights.crowd),
    MapEntry('accessibility', weights.accessibility),
  ]..sort((a, b) => b.value.compareTo(a.value));

  final top = entries.take(2).map((e) => e.key).toList();
  return 'Based on your priorities: ${top.join(' and ')}.';
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

    final matchScore = (controller.scoreFor(pick) * 100).round();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: AppTheme.primarySeed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gemGoldSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'BEST PICK',
                  style: TextStyle(
                    color: AppTheme.primarySeed,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pick.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _preferenceSummary(controller.weights),
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: matchScore / 100,
                          strokeWidth: 3,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.gemGold),
                        ),
                        const Icon(Icons.check, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$matchScore% MATCH SCORE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 16, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    'WEIGHTING PREFERENCES',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompactWeightSlider(
                      label: 'User Rating',
                      value: controller.weights.rating,
                      onChanged: (v) => controller.setWeights(PriorityWeights(
                        rating: v,
                        cost: controller.weights.cost,
                        crowd: controller.weights.crowd,
                        accessibility: controller.weights.accessibility,
                      )),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _CompactWeightSlider(
                      label: 'Cost Efficiency',
                      value: controller.weights.cost,
                      onChanged: (v) => controller.setWeights(PriorityWeights(
                        rating: controller.weights.rating,
                        cost: v,
                        crowd: controller.weights.crowd,
                        accessibility: controller.weights.accessibility,
                      )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompactWeightSlider(
                      label: 'Crowd Density',
                      value: controller.weights.crowd,
                      onChanged: (v) => controller.setWeights(PriorityWeights(
                        rating: controller.weights.rating,
                        cost: controller.weights.cost,
                        crowd: v,
                        accessibility: controller.weights.accessibility,
                      )),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _CompactWeightSlider(
                      label: 'Accessibility',
                      value: controller.weights.accessibility,
                      onChanged: (v) => controller.setWeights(PriorityWeights(
                        rating: controller.weights.rating,
                        cost: controller.weights.cost,
                        crowd: controller.weights.crowd,
                        accessibility: v,
                      )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: Table(
                  columnWidths: const {0: FractionColumnWidth(0.38)},
                  children: [
                    _tableRow(
                      context,
                      'Attribute',
                      pick.name,
                      isHeader: true,
                    ),
                    if (pick.imageUrls.isNotEmpty)
                      _tableRow(
                        context,
                        'Photo',
                        null,
                        valueWidget: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            pick.imageUrls.first,
                            height: 56,
                            width: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    _tableRow(
                      context,
                      'Category',
                      null,
                      valueWidget: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: categoryColor(pick.category).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pick.category.label,
                            style: TextStyle(
                              color: categoryColor(pick.category),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _tableRow(
                      context,
                      'Hidden Gem Score',
                      null,
                      valueWidget: Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 16, color: AppTheme.gemGold),
                          const SizedBox(width: 4),
                          Text(
                            (pick.hiddenGemScore * 10).toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    _tableRow(
                      context,
                      'User Rating',
                      '★ ${pick.avgRating.toStringAsFixed(1)}',
                    ),
                    _tableRow(
                      context,
                      'Distance',
                      null,
                      valueWidget: _DistanceCell(destination: pick),
                    ),
                    _tableRow(
                      context,
                      'Crowd Level',
                      null,
                      valueWidget: _CrowdLevelCell(level: pick.crowdLevel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Consumer<ComparisonController>(
            builder: (context, controller, _) => Column(
              children: [
                // Reflects whether the pick is already saved/added, so the
                // button itself is the "is this saved?" check — not just a
                // one-off SnackBar the user has to trust and forget.
                riverpod.Consumer(
                  builder: (context, ref, _) {
                    final itineraryController = ref.watch(itineraryPlannerControllerProvider);
                    final alreadyAdded =
                        itineraryController.selectedDestinations.any((d) => d.id == pick.id);
                    return FilledButton.icon(
                      onPressed: alreadyAdded
                          ? null
                          : () async {
                              await controller.addBestPickToItinerary(itineraryController);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${pick.name} added to your itinerary')),
                                );
                              }
                            },
                      icon: Icon(alreadyAdded ? Icons.check_circle : Icons.card_travel),
                      label: Text(alreadyAdded ? 'Added to Itinerary' : 'Add to Itinerary'),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: FavouriteDestinationsStore.instance,
                  builder: (context, _) {
                    final alreadySaved = FavouriteDestinationsStore.instance.contains(pick.id);
                    return OutlinedButton.icon(
                      onPressed: alreadySaved
                          ? null
                          : () async {
                              await controller.saveToFavourites(pick);
                              if (!context.mounted) return;
                              final error = FavouriteDestinationsStore.instance.error;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error ?? '${pick.name} saved to favourites'),
                                ),
                              );
                            },
                      icon: Icon(alreadySaved ? Icons.favorite : Icons.favorite_border),
                      label: Text(alreadySaved ? 'Saved to Favourites' : 'Save to Favourites'),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _shareComparisonAsImage(context, controller),
                  icon: const Icon(Icons.share),
                  label: const Text('Share Comparison'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _tableRow(
    BuildContext context,
    String label,
    String? value, {
    Widget? valueWidget,
    bool isHeader = false,
  }) {
    final labelStyle = isHeader
        ? const TextStyle(fontWeight: FontWeight.bold)
        : TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13);
    final valueStyle = isHeader
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle(fontWeight: FontWeight.w600);

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(label, style: labelStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: valueWidget ?? Text(value ?? '', style: valueStyle),
        ),
      ],
    );
  }
}

/// Captures [_ShareableComparisonCard] as a PNG and shares it alongside
/// [ComparisonController.buildShareSummary]'s text — mirrors
/// RouteOptimizedScreen's `_captureShareCard`/`_shareAsImage` (see
/// itinerary_planning/view/route_optimized_screen.dart) so a shared
/// comparison looks like the same kind of branded card a shared itinerary
/// does, instead of a bare text message.
Future<void> _shareComparisonAsImage(BuildContext context, ComparisonController controller) async {
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: -4000,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: boundaryKey,
          child: _ShareableComparisonCard(controller: controller),
        ),
      ),
    ),
  );

  Uint8List? bytes;
  try {
    overlay.insert(entry);
    // Let the entry actually paint before reading its layer.
    await WidgetsBinding.instance.endOfFrame;

    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = byteData?.buffer.asUint8List();
    }
  } finally {
    entry.remove();
  }

  if (bytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't share the comparison right now.")),
      );
    }
    return;
  }

  final file = XFile.fromData(bytes, name: 'comparison.png', mimeType: 'image/png');
  await Share.shareXFiles(
    [file],
    subject: 'My destination comparison',
    text: controller.buildShareSummary(),
  );
}

/// The branded card captured for "Share Comparison" — same visual language
/// as itinerary_planning's `_ShareableItineraryCard` (dark primarySeed
/// background, gold accents) so a shared comparison and a shared itinerary
/// read as the same app/family of content.
class _ShareableComparisonCard extends StatelessWidget {
  const _ShareableComparisonCard({required this.controller});

  final ComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final pick = controller.bestPick;

    return Material(
      color: AppTheme.primarySeed,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.diamond, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Hidden Gems of Malaysia',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Comparing ${controller.destinations.length} Destinations',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            if (pick != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Color(0xFFE8D9A0), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Best Pick: ${pick.name}',
                        style: const TextStyle(
                          color: Color(0xFFE8D9A0),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            for (final destination in controller.destinations) ...[
              _ComparisonCardRow(destination: destination, isBestPick: destination.id == pick?.id),
              if (destination != controller.destinations.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonCardRow extends StatelessWidget {
  const _ComparisonCardRow({required this.destination, required this.isBestPick});

  final ComparisonDestination destination;
  final bool isBestPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                destination.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isBestPick) const Icon(Icons.emoji_events, color: Color(0xFFE8D9A0), size: 14),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '★${destination.avgRating.toStringAsFixed(1)}  •  '
          'Hidden Gem ${(destination.hiddenGemScore * 10).toStringAsFixed(1)}/10  •  '
          '${destination.crowdLevel.label} crowds',
          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11),
        ),
      ],
    );
  }
}

class _DistanceCell extends StatelessWidget {
  const _DistanceCell({required this.destination});

  final ComparisonDestination destination;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ComparisonController>();
    return FutureBuilder<double?>(
      future: controller.distanceFromUser(destination),
      builder: (context, snapshot) {
        final km = snapshot.data;
        if (km == null) {
          return const Text('Not available', style: TextStyle(fontWeight: FontWeight.w600));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${km.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '~${_estimateDriveMinutes(km)} min drive',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        );
      },
    );
  }
}

class _CrowdLevelCell extends StatelessWidget {
  const _CrowdLevelCell({required this.level});

  final CrowdLevel level;

  @override
  Widget build(BuildContext context) {
    final filled = switch (level) {
      CrowdLevel.low => 1,
      CrowdLevel.medium => 2,
      CrowdLevel.high => 4,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled
                    ? AppTheme.primarySeed
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(level.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}

class _CompactWeightSlider extends StatelessWidget {
  const _CompactWeightSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(0, 1),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
