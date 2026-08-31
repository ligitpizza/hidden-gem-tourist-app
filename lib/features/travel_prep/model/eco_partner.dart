enum EcoPartnerCategory { stay, dining, transport }

enum EcoPartnerAreaMode { nearby, statewide }

enum EcoPartnerSearchScopeType { nearby, state, nationwide }

class EcoGeoBounds {
  const EcoGeoBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  final double south;
  final double north;
  final double west;
  final double east;

  double get centerLatitude => (south + north) / 2;
  double get centerLongitude => (west + east) / 2;
}

class EcoPartnerSearchScope {
  const EcoPartnerSearchScope._({
    required this.type,
    this.radiusKm,
    this.state,
    this.bounds,
  });

  const EcoPartnerSearchScope.nearby(double radiusKm)
    : this._(type: EcoPartnerSearchScopeType.nearby, radiusKm: radiusKm);

  const EcoPartnerSearchScope.state(String state, {EcoGeoBounds? bounds})
    : this._(
        type: EcoPartnerSearchScopeType.state,
        state: state,
        bounds: bounds,
      );

  const EcoPartnerSearchScope.nationwide()
    : this._(type: EcoPartnerSearchScopeType.nationwide);

  final EcoPartnerSearchScopeType type;
  final double? radiusKm;
  final String? state;
  final EcoGeoBounds? bounds;

  EcoPartnerSearchScope withBounds(EcoGeoBounds value) =>
      EcoPartnerSearchScope.state(state!, bounds: value);

  String get cacheKey => switch (type) {
    EcoPartnerSearchScopeType.nearby => 'nearby:${radiusKm!.round()}',
    EcoPartnerSearchScopeType.state => 'state:${state!.toLowerCase()}',
    EcoPartnerSearchScopeType.nationwide => 'malaysia',
  };
}

class EcoTransitRouteInfo {
  const EcoTransitRouteInfo({
    required this.mode,
    this.shortName,
    this.longName,
  });

  final String mode;
  final String? shortName;
  final String? longName;

  String get displayLabel {
    final short = shortName?.trim() ?? '';
    final long = longName?.trim() ?? '';
    if (long.isNotEmpty && short.isNotEmpty && long != short) {
      return '$long ($short)';
    }
    if (long.isNotEmpty) return long;
    if (short.isNotEmpty) return '$mode route $short';
    return '$mode route';
  }
}

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
    this.imageSourceName,
    this.imageSourceUrl,
    this.imageCapturedAt,
    this.transitRoutes = const [],
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
  final String? imageSourceName;
  final String? imageSourceUrl;
  final DateTime? imageCapturedAt;
  final List<EcoTransitRouteInfo> transitRoutes;
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
    imageSourceName: imageSourceName,
    imageSourceUrl: imageSourceUrl,
    imageCapturedAt: imageCapturedAt,
    transitRoutes: transitRoutes,
    veganClassification: veganClassification,
    chargerDetails: chargerDetails,
    gstcVerified: gstcVerified,
  );

  EcoPartner withImage({
    required String url,
    required String imageSourceName,
    required String imageSourceUrl,
    DateTime? capturedAt,
  }) => EcoPartner(
    id: id,
    name: name,
    category: category,
    subtype: subtype,
    latitude: latitude,
    longitude: longitude,
    address: address,
    distanceKm: distanceKm,
    sustainabilityLabel: sustainabilityLabel,
    evidence: evidence,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
    lastUpdated: lastUpdated,
    priceBand: priceBand,
    website: website,
    imageUrl: url,
    imageSourceName: imageSourceName,
    imageSourceUrl: imageSourceUrl,
    imageCapturedAt: capturedAt,
    transitRoutes: transitRoutes,
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
