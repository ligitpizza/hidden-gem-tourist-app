import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/preference_controller.dart';
import '../model/travel_style.dart';

IconData _iconForStyle(TravelStyle style) {
  switch (style) {
    case TravelStyle.nature:
      return Icons.park_outlined;
    case TravelStyle.culture:
      return Icons.museum_outlined;
    case TravelStyle.adventure:
      return Icons.explore_outlined;
    case TravelStyle.localFood:
      return Icons.restaurant_outlined;
    case TravelStyle.heritage:
      return Icons.account_balance_outlined;
    case TravelStyle.wellness:
      return Icons.spa_outlined;
    case TravelStyle.urbanExploration:
      return Icons.location_city_outlined;
    case TravelStyle.fauna:
      return Icons.pets_outlined;
    case TravelStyle.flora:
      return Icons.local_florist_outlined;
  }
}

/// "Define Your Travel Style" / "Refresh Your Interests" — lets the
/// traveller pick which categories of hidden gems they care about. Real,
/// persisted selection (Module 1); feeds the composite recommendation
/// score's category filter and the Travel Pulse weight chart.
class TravelStyleScreen extends ConsumerWidget {
  const TravelStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(preferenceControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Refresh Your Interests')),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Text(
                  "What's your current vibe?",
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Update your choices to help us rank hidden gems based on your '
                  'current vibe. Your recommendations evolve as you do.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    for (final style in TravelStyle.values)
                      _StyleCard(
                        style: style,
                        selected: controller.selected.contains(style),
                        onTap: () =>
                            ref.read(preferenceControllerProvider).toggle(style),
                      ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: controller.isSaving
                  ? null
                  : () async {
                      await ref.read(preferenceControllerProvider).save();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preferences saved')),
                        );
                      }
                    },
              child: controller.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final TravelStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _StyleCard({required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colorScheme.primary : colorScheme.outlineVariant),
        ),
        child: Stack(
          children: [
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForStyle(style),
                    size: 32,
                    color: selected ? Colors.white : colorScheme.onSurface,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    style.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
