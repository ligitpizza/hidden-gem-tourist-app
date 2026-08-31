import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controller/preference_controller.dart';
import '../model/travel_preference_profile.dart';
import '../model/travel_style.dart';
import '../../../core/router/shell_routes.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

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

/// "Define Your Travel Style" (FR1.1). Two entry points share this one
/// screen: [mandatory] true is the full-screen, un-skippable first-launch
/// flow the router redirects a freshly onboarded tourist into; false is
/// "Refresh Your Interests", pushed from the discovery feed or Travel
/// Pulse to update an existing profile.
class PreferenceSetupScreen extends ConsumerWidget {
  final bool mandatory;
  const PreferenceSetupScreen({super.key, this.mandatory = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(preferenceControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(mandatory ? 'Define Your Travel Style' : 'Refresh Your Interests'),
        automaticallyImplyLeading: !mandatory,
      ),
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
                  'Pick up to ${PreferenceController.maxSelections} — we use these to rank '
                  'hidden gems for you and your recommendations evolve as you explore.',
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
                        disabled: !controller.selected.contains(style) && !controller.canSelectMore,
                        onTap: () {
                          final applied = controller.toggle(style);
                          if (!applied) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'You can pick up to ${PreferenceController.maxSelections} — '
                                  'remove one first.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Budget', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final range in BudgetRange.values)
                      ChoiceChip(
                        label: Text(range.label),
                        selected: controller.budgetRange == range,
                        onSelected: (_) => controller.setBudgetRange(
                          controller.budgetRange == range ? null : range,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Destination type', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in DestinationTypePreference.values)
                      FilterChip(
                        label: Text(type.label),
                        selected: controller.destinationTypes.contains(type),
                        onSelected: (_) => controller.toggleDestinationType(type),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('When are you planning to visit?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Optional — helps us favour destinations that suit that time of year (FR3.4).',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _monthNames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      return ChoiceChip(
                        label: Text(_monthNames[index]),
                        selected: controller.intendedTravelMonth == month,
                        onSelected: (_) => controller.setIntendedTravelMonth(month),
                      );
                    },
                  ),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(controller.errorMessage!, style: TextStyle(color: colorScheme.error)),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: controller.isSaving || !controller.canConfirm
                  ? null
                  : () async {
                      final ok = await ref.read(preferenceControllerProvider).save();
                      if (!context.mounted) return;
                      if (ok && mandatory) {
                        context.go(ShellRoutes.assistant);
                      } else if (ok) {
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
                  : Text(mandatory ? 'Confirm Preferences' : 'Save Changes'),
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
  final bool disabled;
  final VoidCallback onTap;

  const _StyleCard({
    required this.style,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
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
      ),
    );
  }
}
