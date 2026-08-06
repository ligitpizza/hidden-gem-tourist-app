import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../controller/checkin_controller.dart';
import '../../model/destination_model.dart';
import '../checkin/destination_detail_screen.dart';

/// Entry point for browsing destinations — either as pins on an OSM map
/// (flutter_map, per the project's zero-cost/no-Google-Maps tech choice)
/// or as a plain list. Tapping a destination — pin or list row — opens its
/// Destination Detail screen, where check-in and the quiz both live.
class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  bool _showList = false;
  DestinationModel? _selected;

  static const _malaysiaCenter = ll.LatLng(3.6, 108.4);

  void _openDetail(DestinationModel destination) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(destination: destination),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInController = context.watch<CheckInController>();
    final destinations = checkInController.destinations;

    return Scaffold(
      appBar: AppHeader.tabRoot(
        title: 'Explore',
        actions: [
          IconButton(
            tooltip: _showList ? 'Show map' : 'Show list',
            icon: Icon(_showList ? Icons.map_outlined : Icons.view_list_outlined),
            onPressed: () => setState(() => _showList = !_showList),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: destinations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _showList
          ? _DestinationList(destinations: destinations, onTap: _openDetail)
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _malaysiaCenter,
                    initialZoom: 5.6,
                    onTap: (_, _) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hiddengems.malaysia',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final destination in destinations)
                          Marker(
                            point: ll.LatLng(destination.latitude, destination.longitude),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = destination),
                              child: _MapPin(
                                selected: _selected?.id == destination.id,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_selected != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _DestinationPreviewCard(
                      destination: _selected!,
                      onViewDetails: () => _openDetail(_selected!),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on,
      size: selected ? 40 : 34,
      color: selected ? AppColors.primary : AppColors.primaryContainer,
      shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
    );
  }
}

class _DestinationPreviewCard extends StatelessWidget {
  const _DestinationPreviewCard({required this.destination, required this.onViewDetails});

  final DestinationModel destination;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 56,
              height: 56,
              child: _ThumbnailImage(url: destination.imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryChip(label: destination.category),
                const SizedBox(height: 6),
                Text(destination.name, style: AppTypography.headlineSm),
                Text(destination.state, style: AppTypography.bodySm),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: onViewDetails, child: const Text('View')),
        ],
      ),
    );
  }
}

class _DestinationList extends StatelessWidget {
  const _DestinationList({required this.destinations, required this.onTap});

  final List<DestinationModel> destinations;
  final ValueChanged<DestinationModel> onTap;

  @override
  Widget build(BuildContext context) {
    final byState = <String, List<DestinationModel>>{};
    for (final destination in destinations) {
      byState.putIfAbsent(destination.state, () => []).add(destination);
    }
    final states = byState.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final state in states) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              state,
              style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 0),
            ),
          ),
          for (final destination in byState[state]!) _DestinationTile(destination: destination, onTap: onTap),
        ],
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.onTap});

  final DestinationModel destination;
  final ValueChanged<DestinationModel> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
          onTap: () => onTap(destination),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _ThumbnailImage(url: destination.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text('${destination.category} · ${destination.state}', style: AppTypography.bodySm),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline),
              ],
            ),
          ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: AppColors.primaryContainerTint);
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.primaryContainerTint,
        child: const Icon(Icons.image_outlined, color: AppColors.primaryContainer),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
      ),
    );
  }
}
