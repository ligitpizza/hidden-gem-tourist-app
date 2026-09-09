enum EcoPartnerCategory { stay, dining, transport }

enum EcoPartnerAreaMode { nearby, statewide }

enum EcoPartnerSearchScopeType { nearby, state, nationwide }

class EcoChargingConnector {
  const EcoChargingConnector({required this.type, this.count, this.output});

  final String type;
  final int? count;
  final String? output;

  String get displayName => switch (type.toLowerCase()) {
    'type1' => 'Type 1',
    'type1_combo' => 'CCS (Combo 1)',
    'type2' => 'Type 2',
    'type2_combo' => 'CCS (Combo 2)',
    'chademo' => 'CHAdeMO',
    'tesla_supercharger' => 'Tesla Supercharger',
    'tesla_destination' => 'Tesla Destination',
    'schuko' => 'Schuko',
    'cee_blue' => 'CEE blue',
    'cee_red_16a' => 'CEE red (16 A)',
    'cee_red_32a' => 'CEE red (32 A)',
    'cee_red_63a' => 'CEE red (63 A)',
    _ => _titleCase(type.replaceAll(RegExp(r'[_-]+'), ' ')),
  };

  String get summary {
    final quantity = count == null ? '' : '$count × ';
    final power = output == null ? '' : ' · up to $output';
    return '$quantity$displayName$power';
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'count': count,
    'output': output,
  };

  static EcoChargingConnector? fromJson(Map<String, dynamic> json) {
    final type = _cleanText(json['type']);
    if (type == null) return null;
    return EcoChargingConnector(
      type: type,
      count: _positiveInt(json['count']),
      output: _cleanText(json['output']),
    );
  }
}

class EcoChargingDetails {
  const EcoChargingDetails({
    this.capacity,
    this.access,
    this.operatorName,
    this.connectors = const [],
  });

  final int? capacity;
  final String? access;
  final String? operatorName;
  final List<EcoChargingConnector> connectors;

  bool get hasUsefulDetails =>
      capacity != null ||
      accessLabel != null ||
      operatorLabel != null ||
      connectors.isNotEmpty;

  String? get capacityLabel => capacity == null
      ? null
      : '$capacity charging ${capacity == 1 ? 'point' : 'points'}';

  String? get accessLabel {
    final value = _cleanText(access)?.toLowerCase();
    if (value == null) return null;
    return switch (value) {
      'yes' || 'public' => 'Open to the public',
      'customers' || 'customer' => 'Customers only',
      'private' => 'Private access',
      'no' => 'Not open to the public',
      'permissive' => 'Public access may have conditions',
      'destination' => 'Available to destination visitors',
      'residents' => 'Residents only',
      _ =>
        'Access may be restricted: ${_titleCase(value.replaceAll('_', ' '))}',
    };
  }

  String? get operatorLabel {
    final value = _meaningfulOperator(operatorName);
    return value == null ? null : 'Operated by $value';
  }

  factory EcoChargingDetails.fromOsmTags(Map<String, dynamic> tags) {
    final connectors = <String, _MutableChargingConnector>{};
    for (final entry in tags.entries) {
      if (!entry.key.startsWith('socket:')) continue;
      final parts = entry.key.substring('socket:'.length).split(':');
      if (parts.isEmpty || parts.first.trim().isEmpty) continue;
      final type = parts.first.trim();
      final connector = connectors.putIfAbsent(
        type,
        () => _MutableChargingConnector(type),
      );
      final value = _cleanText(entry.value);
      if (parts.length == 1) {
        if (value?.toLowerCase() == 'no') {
          connector.available = false;
        } else if (value != null) {
          connector.available = true;
          connector.count = _positiveInt(value);
        }
      } else if (parts[1].toLowerCase() == 'output' && value != null) {
        connector.output = value;
      }
    }

    return EcoChargingDetails(
      capacity: _positiveInt(tags['capacity']),
      access: _cleanText(tags['access']),
      operatorName: _meaningfulOperator(tags['operator']),
      connectors: connectors.values
          .where(
            (connector) =>
                connector.available == true || connector.output != null,
          )
          .map((connector) => connector.freeze())
          .toList(),
    );
  }

  factory EcoChargingDetails.fromLegacy(String value) {
    String? operatorName;
    String? access;
    int? capacity;
    final connectors = <String, _MutableChargingConnector>{};
    final parts = value
        .replaceAll('Â·', '·')
        .split('·')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    for (final part in parts) {
      final separator = part.indexOf(':');
      if (separator < 0) continue;
      final key = part.substring(0, separator).trim();
      final rawValue = part.substring(separator + 1).trim();
      switch (key.toLowerCase()) {
        case 'operator':
          operatorName = _meaningfulOperator(rawValue);
        case 'access':
          access = _cleanText(rawValue);
        case 'capacity':
          capacity = _positiveInt(rawValue);
        default:
          final connector = connectors.putIfAbsent(
            key,
            () => _MutableChargingConnector(key),
          );
          if (rawValue.toLowerCase().startsWith('output:')) {
            connector.output = _cleanText(rawValue.substring('output:'.length));
          } else if (rawValue.toLowerCase() != 'no') {
            connector.available = true;
            connector.count = _positiveInt(rawValue);
          } else {
            connector.available = false;
          }
      }
    }
    return EcoChargingDetails(
      capacity: capacity,
      access: access,
      operatorName: operatorName,
      connectors: connectors.values
          .where(
            (connector) =>
                connector.available == true || connector.output != null,
          )
          .map((connector) => connector.freeze())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'capacity': capacity,
    'access': access,
    'operatorName': operatorName,
    'connectors': connectors.map((connector) => connector.toJson()).toList(),
  };

  static EcoChargingDetails? fromJson(Map<String, dynamic> json) {
    final value = EcoChargingDetails(
      capacity: _positiveInt(json['capacity']),
      access: _cleanText(json['access']),
      operatorName: _meaningfulOperator(json['operatorName']),
      connectors: (json['connectors'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (connector) => EcoChargingConnector.fromJson(
              connector.cast<String, dynamic>(),
            ),
          )
          .whereType<EcoChargingConnector>()
          .toList(),
    );
    return value.hasUsefulDetails ? value : null;
  }

  String toLegacyString() {
    final values = <String>[
      if (operatorName != null) 'operator: $operatorName',
      if (access != null) 'access: $access',
      if (capacity != null) 'capacity: $capacity',
      for (final connector in connectors) ...[
        '${connector.type}: ${connector.count ?? 'yes'}',
        if (connector.output != null)
          '${connector.type}:output: ${connector.output}',
      ],
    ];
    return values.join(' · ');
  }
}

class _MutableChargingConnector {
  _MutableChargingConnector(this.type);

  final String type;
  bool? available;
  int? count;
  String? output;

  EcoChargingConnector freeze() =>
      EcoChargingConnector(type: type, count: count, output: output);
}

String? _cleanText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

String? _meaningfulOperator(Object? value) {
  final text = _cleanText(value);
  if (text == null ||
      const {
        'yes',
        'no',
        'true',
        'false',
        'unknown',
        'none',
      }.contains(text.toLowerCase())) {
    return null;
  }
  return text;
}

int? _positiveInt(Object? value) {
  final parsed = int.tryParse('${value ?? ''}'.trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

String _titleCase(String value) => value
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .map(
      (part) =>
          '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
    )
    .join(' ');

String resolveEvChargerName({
  Object? name,
  Object? operatorName,
  String? address,
  String? nearbyLabel,
}) {
  String? clean(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  final explicitName = clean(name);
  if (explicitName != null) return explicitName;
  final operator = _meaningfulOperator(operatorName);
  if (operator != null) return '$operator EV charger';
  final addressLabel = clean(address)?.split(',').first.trim();
  if (addressLabel?.isNotEmpty == true) {
    return 'EV charger near $addressLabel';
  }
  final nearby = clean(nearbyLabel);
  return nearby == null ? 'EV charging station' : 'EV charger near $nearby';
}

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
    this.state,
    this.distanceKm,
    this.priceBand,
    this.website,
    this.imageUrl,
    this.imageSourceName,
    this.imageSourceUrl,
    this.imageCapturedAt,
    this.transitRoutes = const [],
    this.veganClassification,
    this.chargingDetails,
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
  final String? state;
  final double? distanceKm;
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
  final EcoChargingDetails? chargingDetails;
  // Retained while existing saved and hot-reloaded partners still carry the
  // original flattened OpenStreetMap string.
  final String? chargerDetails;
  final bool gstcVerified;

  EcoChargingDetails? get effectiveChargingDetails {
    final structured = chargingDetails;
    if (structured?.hasUsefulDetails == true) return structured;
    final legacy = chargerDetails;
    if (legacy == null || legacy.trim().isEmpty) return null;
    final parsed = EcoChargingDetails.fromLegacy(legacy);
    return parsed.hasUsefulDetails ? parsed : null;
  }

  EcoPartner withDistance(double? value) => EcoPartner(
    id: id,
    name: name,
    category: category,
    subtype: subtype,
    latitude: latitude,
    longitude: longitude,
    address: address,
    state: state,
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
    chargingDetails: chargingDetails,
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
    state: state,
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
    chargingDetails: chargingDetails,
    chargerDetails: chargerDetails,
    gstcVerified: gstcVerified,
  );
}

String ecoPartnerDistanceLabel(double distanceKm, {bool compact = false}) {
  if (distanceKm < 0.1) return compact ? '<100 m' : '<100 m away';
  if (distanceKm < 1) {
    final metres = (distanceKm * 1000).round();
    return compact ? '$metres m' : '$metres m away';
  }
  final kilometres = '${distanceKm.toStringAsFixed(1)} km';
  return compact ? kilometres : '$kilometres away';
}

String ecoPartnerLocationLabel(EcoPartner partner) {
  final address = partner.address.trim();
  final state = partner.state?.trim() ?? '';
  final values = <String>[
    if (address.isNotEmpty) address,
    if (address.isEmpty && partner.category == EcoPartnerCategory.transport)
      partner.name.trim(),
    if (state.isNotEmpty) state,
    'Malaysia',
  ];
  final normalized = <String>{};
  return values
      .where((value) {
        final key = value.toLowerCase();
        if (key.isEmpty || normalized.contains(key)) return false;
        if (normalized.any(
          (existing) =>
              existing.split(',').map((part) => part.trim()).contains(key),
        )) {
          return false;
        }
        normalized.add(key);
        return true;
      })
      .join(', ');
}

bool ecoPartnerHasPartialAddress(EcoPartner partner) {
  final address = partner.address.trim();
  return partner.sourceName.toLowerCase().contains('gtfs') &&
      address.isNotEmpty &&
      !address.contains(',');
}

String ecoPartnerEvidenceLabel(EcoPartner partner) {
  final evidence = partner.evidence.trim();
  final normalized = evidence.toLowerCase();
  if (normalized == 'openstreetmap diet:vegan tag') {
    return 'Listed as vegan-friendly.';
  }
  if (normalized == 'openstreetmap diet:vegetarian tag') {
    return 'Listed as vegetarian-friendly.';
  }
  if (normalized == 'openstreetmap charging station tags') {
    return 'Listed as an electric vehicle charging station.';
  }
  if (normalized == 'official gtfs stop') {
    return 'Official public transport stop.';
  }
  if (normalized.startsWith('routes:')) {
    final routes = evidence.substring(evidence.indexOf(':') + 1).trim();
    return routes.isEmpty
        ? 'Scheduled public transport service is available.'
        : 'Scheduled services include: $routes';
  }
  if (evidence.isNotEmpty) return evidence;
  return switch (partner.category) {
    EcoPartnerCategory.stay =>
      'Sustainability information is available from the listed source.',
    EcoPartnerCategory.dining =>
      'Plant-friendly information is available from the listed source.',
    EcoPartnerCategory.transport when partner.subtype == 'EV charging' =>
      'Electric vehicle charging information is available from the listed source.',
    EcoPartnerCategory.transport =>
      'Public transport information is available from the listed source.',
  };
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
    int? totalCount,
  }) : _totalCount = totalCount;
  final EcoDestination destination;
  final List<EcoPartner> partners;
  final List<String> warnings;
  final int? _totalCount;
  int get totalCount => _totalCount ?? partners.length;
}
