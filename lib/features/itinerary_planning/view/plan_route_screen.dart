import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/destination.dart';
import '../controller/itinerary_planner_controller.dart';
import '../model/visit_duration_option.dart';
import 'itinerary_routes.dart';
import 'widgets/route_map_view.dart';
import 'widgets/selected_gem_categories_view.dart';

class PlanRouteScreen extends ConsumerStatefulWidget {
  const PlanRouteScreen({super.key});

  @override
  ConsumerState<PlanRouteScreen> createState() => _PlanRouteScreenState();
}

class _PlanRouteScreenState extends ConsumerState<PlanRouteScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _selectDestination(Destination destination) {
    ref.read(itineraryPlannerControllerProvider).addDestination(destination);
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  Future<void> _onGeneratePressed() async {
    final controller = ref.read(itineraryPlannerControllerProvider);
    await controller.generateItinerary();
    if (!mounted) return;
    context.push(ItineraryRoutes.routeOptimized);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(itineraryPlannerControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: const Text('Plan Your Route'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            _SearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) =>
                  ref.read(itineraryPlannerControllerProvider).updateSearchQuery(value),
            ),
            if (controller.searchResults.isNotEmpty)
              _SearchSuggestions(
                results: controller.searchResults,
                onSelect: _selectDestination,
              ),
            const SizedBox(height: 20),
            const _SectionLabel('SELECTED LOCATIONS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final destination in controller.selectedDestinations)
                  Chip(
                    label: Text(destination.name),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => ref
                        .read(itineraryPlannerControllerProvider)
                        .removeDestination(destination.id),
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                    side: BorderSide.none,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add Stop'),
                  labelStyle: TextStyle(color: colorScheme.onSurface),
                  onPressed: () => _searchFocusNode.requestFocus(),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('INTERESTED HIDDEN GEM CATEGORIES'),
            const SizedBox(height: 8),
            SelectedGemCategoriesView(selected: controller.selectedGemCategories),
            const SizedBox(height: 24),
            _AllocateDurationCard(
              allocate: controller.allocateDuration,
              onChanged: (value) =>
                  ref.read(itineraryPlannerControllerProvider).setAllocateDuration(value),
            ),
            if (controller.allocateDuration) ...[
              const SizedBox(height: 20),
              const _SectionLabel('SELECT DURATION'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.6,
                children: [
                  for (final option in VisitDurationOption.values)
                    _DurationOptionCard(
                      option: option,
                      selected: controller.selectedDurationOption == option,
                      onTap: () => ref
                          .read(itineraryPlannerControllerProvider)
                          .setDurationOption(option),
                    ),
                ],
              ),
              if (controller.selectedDurationOption == VisitDurationOption.custom) ...[
                const SizedBox(height: 12),
                _CustomDaysField(
                  days: controller.customDays,
                  onChanged: (days) =>
                      ref.read(itineraryPlannerControllerProvider).setCustomDays(days),
                ),
              ],
            ],
            const SizedBox(height: 24),
            _GemPreviewPanel(
              destinations: controller.selectedDestinations,
              gemCount: controller.previewGemCount,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: controller.canGenerate && !controller.isGenerating
                  ? _onGeneratePressed
                  : null,
              child: controller.isGenerating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Generate Itinerary  ✨'),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search for heritage sites, cafes, or landmarks',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  final List<Destination> results;
  final ValueChanged<Destination> onSelect;

  const _SearchSuggestions({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final destination in results)
            ListTile(
              dense: true,
              leading: Icon(Icons.place_outlined, color: colorScheme.primary),
              title: Text(destination.name, style: TextStyle(color: colorScheme.onSurface)),
              subtitle: Text(
                '${destination.category.label} • ${destination.city}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              onTap: () => onSelect(destination),
            ),
        ],
      ),
    );
  }
}

class _AllocateDurationCard extends StatelessWidget {
  final bool allocate;
  final ValueChanged<bool> onChanged;

  const _AllocateDurationCard({required this.allocate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allocate Visit Duration?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Define how long you want your journey to last.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: allocate,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _DurationOptionCard extends StatelessWidget {
  final VisitDurationOption option;
  final bool selected;
  final VoidCallback onTap;

  const _DurationOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          option.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _CustomDaysField extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;

  const _CustomDaysField({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Number of days',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: colorScheme.primary,
            onPressed: days > 1 ? () => onChanged(days - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$days',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colorScheme.onSurface),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: colorScheme.primary,
            onPressed: days < 60 ? () => onChanged(days + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _GemPreviewPanel extends StatelessWidget {
  final List<Destination> destinations;
  final int gemCount;

  const _GemPreviewPanel({required this.destinations, required this.gemCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (destinations.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(140),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Select destinations to preview hidden gems',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    final city = destinations.last.city;

    return Stack(
      children: [
        RouteMapView(
          height: 140,
          markers: [
            for (final destination in destinations)
              MapMarkerSpec(point: destination.location, color: colorScheme.primary),
          ],
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_outlined, size: 14, color: Color(0xFFC9A227)),
                const SizedBox(width: 6),
                Text(
                  'Previewing $gemCount Gems in $city',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
