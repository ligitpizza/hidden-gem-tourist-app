enum EcoPartnerCategory { stay, dining, transport }

class EcoPartner {
  const EcoPartner({
    required this.id,
    required this.name,
    required this.category,
    required this.subtype,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.sustainabilityLabel,
    required this.evidence,
    required this.sourceName,
    required this.sourceUrl,
    required this.lastUpdated,
    this.distanceKm = 0,
    this.priceBand,
    this.website,
    this.imageUrl,
    this.routeNames = const [],
    this.veganClassification,
    this.chargerDetails,
    this.gstcVerified = false,
  });

  final String id;
  final String name;
  final EcoPartnerCategory category;
  final String subtype;
  final double latitude;
  final double longitude;
  final String address;
  final double distanceKm;
  final String sustainabilityLabel;
  final String evidence;
  final String sourceName;
  final String sourceUrl;
  final DateTime lastUpdated;
  final String? priceBand;
  final String? website;
  final String? imageUrl;
  final List<String> routeNames;
  final String? veganClassification;
  final String? chargerDetails;
  final bool gstcVerified;

  EcoPartner withDistance(double value) => EcoPartner(
        id: id,
        name: name,
        category: category,
        subtype: subtype,
        latitude: latitude,
        longitude: longitude,
        address: address,
        distanceKm: value,
        sustainabilityLabel: sustainabilityLabel,
        evidence: evidence,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
        lastUpdated: lastUpdated,
        priceBand: priceBand,
        website: website,
        imageUrl: imageUrl,
        routeNames: routeNames,
        veganClassification: veganClassification,
        chargerDetails: chargerDetails,
        gstcVerified: gstcVerified,
      );
}

class EcoDestination {
  const EcoDestination(this.label, this.latitude, this.longitude);
  final String label;
  final double latitude;
  final double longitude;
}

class EcoPartnerSearchResult {
  const EcoPartnerSearchResult({
    required this.destination,
    required this.partners,
    this.warnings = const [],
  });
  final EcoDestination destination;
  final List<EcoPartner> partners;
  final List<String> warnings;
}
