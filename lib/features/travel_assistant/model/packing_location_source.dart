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
    this.ecoPartnerCategory,
    this.dashboardTitle,
    this.dashboardSubtitle,
    this.lookupName,
    this.destinationId,
    this.primaryCategory,
    this.trustedImageUrl,
    this.trustedImageAttribution,
    this.trustedImageSourceUrl,
    bool? datesEditable,
  }) : datesEditable = datesEditable ?? ecoPartnerCategory != null;

  final String id;
  final String label;
  final String subtitle;
  final double latitude;
  final double longitude;
  final Set<DestinationCategory> categories;
  final EcoPartnerCategory? ecoPartnerCategory;
  final String? dashboardTitle;
  final String? dashboardSubtitle;
  final String? lookupName;
  final String? destinationId;
  final DestinationCategory? primaryCategory;
  final String? trustedImageUrl;
  final String? trustedImageAttribution;
  final String? trustedImageSourceUrl;
  final bool datesEditable;

  String get heroTitle => dashboardTitle?.trim().isNotEmpty == true
      ? dashboardTitle!.trim()
      : label;

  String get heroSubtitle => dashboardSubtitle?.trim().isNotEmpty == true
      ? dashboardSubtitle!.trim()
      : subtitle;

  String get coverLookupName =>
      lookupName?.trim().isNotEmpty == true ? lookupName!.trim() : heroTitle;
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
            dashboardTitle: saved.plan.destinations.length == 1
                ? saved.plan.destinations.first.name
                : '${saved.plan.destinations.first.name} → ${saved.plan.destinations.last.name}',
            dashboardSubtitle: saved.plan.destinations.length == 1
                ? 'Saved itinerary'
                : '${saved.plan.destinations.length}-stop saved itinerary',
            lookupName: saved.plan.destinations.first.name,
            destinationId: saved.plan.destinations.first.id,
            primaryCategory: saved.plan.destinations.first.category,
          ),
      for (final saved in _ecoPartners.saved)
        if (supportsEcoPartner(saved.partner.category))
          PackingLocationOption(
            id: 'eco:${saved.id}',
            label: saved.partner.name,
            subtitle: 'Saved Eco Partner · ${saved.partner.subtype}',
            latitude: saved.partner.latitude,
            longitude: saved.partner.longitude,
            categories: {_packingCategory(saved.partner.category)},
            ecoPartnerCategory: saved.partner.category,
            dashboardTitle: saved.partner.name,
            dashboardSubtitle: 'Saved Eco Partner · ${saved.partner.subtype}',
            lookupName: saved.partner.name,
            primaryCategory: _packingCategory(saved.partner.category),
            trustedImageUrl: saved.partner.imageUrl,
            trustedImageAttribution:
                saved.partner.imageSourceName ?? saved.partner.sourceName,
            trustedImageSourceUrl:
                saved.partner.imageSourceUrl ?? saved.partner.sourceUrl,
          ),
    ];
  }

  static bool supportsEcoPartner(EcoPartnerCategory category) =>
      category == EcoPartnerCategory.stay ||
      category == EcoPartnerCategory.dining;

  static DestinationCategory _packingCategory(EcoPartnerCategory category) =>
      switch (category) {
        EcoPartnerCategory.dining => DestinationCategory.restaurant,
        EcoPartnerCategory.stay => DestinationCategory.attraction,
        EcoPartnerCategory.transport => DestinationCategory.attraction,
      };
}
