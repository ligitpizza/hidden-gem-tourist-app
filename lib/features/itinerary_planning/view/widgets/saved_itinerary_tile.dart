import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controller/itinerary_planner_controller.dart';
import '../../model/saved_itineraries_store.dart';
import '../../model/saved_itinerary.dart';
import '../itinerary_routes.dart';

/// A single saved itinerary, shown identically on the Saved tab and in
/// Profile (both display the same underlying [SavedItinerariesStore]).
/// Tapping it opens Route Optimized/Day Trip to view the plan as it was
/// saved; the overflow menu offers Edit (reopens Plan Your Route with the
/// same destinations, ready to change and regenerate) and Delete.
class SavedItineraryTile extends ConsumerWidget {
  final SavedItinerary saved;

  const SavedItineraryTile({super.key, required this.saved});

  void _view(BuildContext context, WidgetRef ref) {
    ref.read(itineraryPlannerControllerProvider).loadSavedItinerary(saved);
    context.push(ItineraryRoutes.routeOptimized);
  }

  void _edit(BuildContext context, WidgetRef ref) {
    ref.read(itineraryPlannerControllerProvider).loadSavedItinerary(saved);
    context.push(ItineraryRoutes.planRoute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(saved.plan.destinations.map((d) => d.name).join(' → ')),
          subtitle: Text('${saved.plan.timeline.length} stops'),
          onTap: () => _view(context, ref),
          trailing: PopupMenuButton<_SavedItineraryAction>(
            onSelected: (action) {
              switch (action) {
                case _SavedItineraryAction.edit:
                  _edit(context, ref);
                case _SavedItineraryAction.delete:
                  SavedItinerariesStore.instance.remove(saved.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SavedItineraryAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _SavedItineraryAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: Colors.red)),
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

enum _SavedItineraryAction { edit, delete }
