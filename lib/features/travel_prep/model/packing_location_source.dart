import '../../../shared/models/destination.dart';
import '../../itinerary_planning/model/saved_itineraries_store.dart';
import 'eco_partner.dart';
import 'saved_eco_partners_store.dart';

class PackingLocationOption {
  const PackingLocationOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.categories,
  });

  final String id;
  final String label;
  final String subtitle;
  final double latitude;
  final double longitude;
  final Set<DestinationCategory> categories;
}

abstract interface class PackingLocationSource {
  Future<List<PackingLocationOption>> load();
}

class SavedPackingLocationSource implements PackingLocationSource {
  SavedPackingLocationSource({
    SavedItinerariesStore? itineraries,
    SavedEcoPartnersStore? ecoPartners,
  }) : _itineraries = itineraries ?? SavedItinerariesStore.instance,
       _ecoPartners = ecoPartners ?? SavedEcoPartnersStore.instance;

  final SavedItinerariesStore _itineraries;
  final SavedEcoPartnersStore _ecoPartners;

  @override
  Future<List<PackingLocationOption>> load() async {
    await Future.wait([
      _itineraries.ensureLoaded(),
      _ecoPartners.ensureLoaded(),
    ]);
    return [
      for (final saved in _itineraries.saved)
        if (saved.plan.destinations.isNotEmpty)
          PackingLocationOption(
            id: 'itinerary:${saved.id}',
            label: saved.plan.destinations
                .map((destination) => destination.name)
                .join(' → '),
            subtitle: 'Saved itinerary',
            latitude: saved.plan.destinations.first.location.latitude,
            longitude: saved.plan.destinations.first.location.longitude,
            categories: saved.plan.destinations
                .map((destination) => destination.category)
                .toSet(),
          ),
      for (final saved in _ecoPartners.saved)
        PackingLocationOption(
          id: 'eco:${saved.id}',
          label: saved.partner.name,
          subtitle: 'Saved Eco Partner · ${saved.partner.subtype}',
          latitude: saved.partner.latitude,
          longitude: saved.partner.longitude,
          categories: {_packingCategory(saved.partner.category)},
        ),
    ];
  }

  static DestinationCategory _packingCategory(EcoPartnerCategory category) =>
      switch (category) {
        EcoPartnerCategory.dining => DestinationCategory.restaurant,
        EcoPartnerCategory.stay ||
        EcoPartnerCategory.transport => DestinationCategory.attraction,
      };
}
