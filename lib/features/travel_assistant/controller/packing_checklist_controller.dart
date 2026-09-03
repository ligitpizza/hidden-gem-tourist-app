import 'package:flutter/foundation.dart';

import '../../../shared/models/destination.dart';
import '../model/eco_partner.dart';
import '../model/packing_checklist.dart';
import '../model/packing_checklist_repository.dart';
import '../model/packing_location_source.dart';
import '../model/packing_weather_service.dart';

class PackingChecklistController extends ChangeNotifier {
  PackingChecklistController({
    PackingLocationSource? locationSource,
    PackingWeatherService? weatherService,
    PackingChecklistRepositoryContract? persistence,
    DateTime Function()? now,
  }) : _locationSource = locationSource ?? SavedPackingLocationSource(),
       _weatherService = weatherService ?? PackingWeatherService(),
       _persistence = persistence ?? PackingChecklistRepository(),
       _now = now ?? DateTime.now;

  final PackingLocationSource _locationSource;
  final PackingWeatherService _weatherService;
  final PackingChecklistRepositoryContract _persistence;
  final DateTime Function() _now;
  final Set<String> packedIds = {};
  List<PackingChecklistSection> sections = const [];
  List<PackingChecklistItem> customItems = const [];
  String tripLabel = 'Travel essentials';
  List<PackingLocationOption> locationOptions = const [];
  String? selectedLocationId;
  Set<DestinationCategory> destinationCategories = const {};
  EcoPartnerCategory? ecoPartnerCategory;
  bool isLoading = true;
  bool isWeatherLoading = false;
  PackingWeatherSummary? weather;
  PackingForecastResult forecast = const PackingForecastResult.needsDates();
  PackingTripDateRange? tripDates;
  int _requestId = 0;

  static const _weatherIds = {
    'umbrella',
    'rain_jacket',
    'reef_sunscreen',
    'sunscreen',
    'sun_hat',
    'water_bottle',
    'breathable_clothes',
    'light_layer',
  };
  static const _healthIds = {
    'medication',
    'first_aid',
    'insurance_details',
    'dietary_note',
    'hand_sanitizer',
  };
  static const _transitIds = {
    'bookings',
    'power_bank',
    'offline_maps',
    'transport_payment',
  };

  int? get weatherScore {
    final applicable = sections
        .where((section) => section.name == 'Weather Essentials')
        .expand((section) => section.items)
        .toList();
    if (applicable.isEmpty) return null;
    final packed = applicable
        .where((item) => packedIds.contains(item.id))
        .length;
    return (packed * 100 / applicable.length).round();
  }

  int? get healthScore => _metricScore(_healthIds);
  int? get transitScore => _metricScore(_transitIds);
  PackingForecastStatus get forecastStatus => forecast.status;
  bool get hasDateMatchedForecast => canEditTripDates && forecast.hasForecast;
  bool get canRetryForecast =>
      tripDates != null && forecast.status == PackingForecastStatus.failed;
  String get weatherDetail => switch (forecast.status) {
    PackingForecastStatus.needsDates => 'Set trip dates for forecast',
    PackingForecastStatus.loading => 'Updating forecast…',
    PackingForecastStatus.notYetAvailable =>
      'Forecast expected from ${_formatDate(forecast.availableFrom)}',
    PackingForecastStatus.expired => 'Trip dates have passed',
    PackingForecastStatus.failed => 'Forecast temporarily unavailable',
    PackingForecastStatus.partial =>
      '${weather?.shortDescription ?? 'Forecast'} · Partial ${_formatCoverage()}',
    PackingForecastStatus.available =>
      weather?.shortDescription ?? 'Forecast available',
  };

  List<String> get categoryLabels => switch (ecoPartnerCategory) {
    EcoPartnerCategory.stay => const ['Hotel'],
    EcoPartnerCategory.dining => const ['Dining'],
    EcoPartnerCategory.transport => const [],
    null => destinationCategories.map((category) => category.label).toList(),
  };
  String get healthDetail => _metricDetail(_healthIds);
  String get transitDetail => _metricDetail(_transitIds);

  int get totalItems =>
      sections.fold(0, (sum, section) => sum + section.items.length) +
      customItems.length;
  int get packedItems => [
    ...sections.expand((section) => section.items),
    ...customItems,
  ].where((item) => packedIds.contains(item.id)).length;
  int get readinessScore =>
      totalItems == 0 ? 0 : (packedItems * 100 / totalItems).round();
  PackingLocationOption? get selectedLocation => locationOptions
      .where((option) => option.id == selectedLocationId)
      .firstOrNull;
  bool get canEditTripDates => selectedLocation?.datesEditable ?? false;
  String get readinessStatus => switch (readinessScore) {
    >= 85 => 'READY TO WANDER',
    >= 60 => 'ALMOST READY',
    _ => 'PREPARATION NEEDED',
  };

  Future<void> load() async {
    final requestId = ++_requestId;
    isLoading = true;
    notifyListeners();
    final loadedLocations = await _locationSource.load();
    if (requestId != _requestId) return;
    locationOptions = loadedLocations;
    final savedSelection = await _persistence.loadSelection();
    if (requestId != _requestId) return;
    selectedLocationId =
        locationOptions.any((option) => option.id == savedSelection)
        ? savedSelection
        : locationOptions.firstOrNull?.id;
    await _loadCustomItems();
    if (requestId != _requestId) return;
    await _loadSelectedLocation(requestId);
    if (requestId != _requestId) return;
    isLoading = false;
    notifyListeners();
  }

  Future<void> selectLocation(String id) async {
    if (selectedLocationId == id ||
        !locationOptions.any((option) => option.id == id)) {
      return;
    }
    final requestId = ++_requestId;
    isLoading = true;
    notifyListeners();
    selectedLocationId = id;
    await _persistence.saveSelection(id);
    if (requestId != _requestId) return;
    await _loadSelectedLocation(requestId);
    if (requestId != _requestId) return;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSelectedLocation(int requestId) async {
    final selected = selectedLocation;
    tripLabel = selected?.label ?? 'Travel essentials';
    destinationCategories = selected?.categories ?? const {};
    ecoPartnerCategory = selected?.ecoPartnerCategory;
    final loaded = await _loadLocationState(selected, requestId);
    if (!loaded) return;
    await _refreshForecastAndSections(selected, requestId: requestId);
  }

  int? _metricScore(Set<String> ids) {
    final applicable = sections
        .expand((section) => section.items)
        .where((item) => ids.contains(item.id))
        .toList();
    if (applicable.isEmpty) return null;
    final packed = applicable
        .where((item) => packedIds.contains(item.id))
        .length;
    return (packed * 100 / applicable.length).round();
  }

  String _metricDetail(Set<String> ids) {
    final applicable = sections
        .expand((section) => section.items)
        .where((item) => ids.contains(item.id))
        .toList();
    if (applicable.isEmpty) return 'Not applicable';
    final packed = applicable
        .where((item) => packedIds.contains(item.id))
        .length;
    return '$packed/${applicable.length} ready';
  }

  Future<void> toggleItem(String id, bool packed) async {
    packed ? packedIds.add(id) : packedIds.remove(id);
    notifyListeners();
    await _savePackedState();
  }

  Future<void> addCustomItem(String name, String note) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final item = PackingChecklistItem(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      reason: note.trim().isEmpty ? 'Added by you' : note.trim(),
    );
    customItems = [...customItems, item];
    notifyListeners();
    await _saveCustomItems();
  }

  Future<void> deleteCustomItem(String id) async {
    customItems = customItems.where((item) => item.id != id).toList();
    packedIds.remove(id);
    notifyListeners();
    await Future.wait([_saveCustomItems(), _savePackedState()]);
  }

  Future<void> setTripDates(PackingTripDateRange value) async {
    if (!canEditTripDates) return;
    final today = _dateOnly(_now());
    final lastAllowedDate = DateTime(today.year + 5, today.month, today.day);
    if (value.start.isBefore(today)) {
      throw ArgumentError.value(value.start, 'start', 'must be today or later');
    }
    if (value.end.isAfter(lastAllowedDate)) {
      throw ArgumentError.value(value.end, 'end', 'must be within five years');
    }
    if (ecoPartnerCategory == EcoPartnerCategory.dining && !value.isSingleDay) {
      throw ArgumentError.value(
        value.end,
        'end',
        'dining visits must use a single date',
      );
    }

    final requestId = ++_requestId;
    tripDates = value;
    notifyListeners();
    await _persistence.saveTripDates(selectedLocationId ?? 'essentials', value);
    if (requestId != _requestId) return;
    await _refreshForecastAndSections(
      selectedLocation,
      requestId: requestId,
      announceLoading: true,
    );
  }

  Future<void> clearTripDates() async {
    if (!canEditTripDates) return;
    final requestId = ++_requestId;
    tripDates = null;
    notifyListeners();
    await _persistence.clearTripDates(selectedLocationId ?? 'essentials');
    if (requestId != _requestId) return;
    await _refreshForecastAndSections(
      selectedLocation,
      requestId: requestId,
      announceLoading: true,
    );
  }

  Future<void> retryForecast() async {
    if (!canRetryForecast) return;
    final requestId = ++_requestId;
    await _refreshForecastAndSections(
      selectedLocation,
      requestId: requestId,
      announceLoading: true,
    );
  }

  Future<bool> _loadLocationState(
    PackingLocationOption? selected,
    int requestId,
  ) async {
    final locationId = selected?.id ?? 'essentials';
    final values = await Future.wait<Object?>([
      _persistence.loadPackedIds(locationId),
      if (selected?.datesEditable == true)
        _persistence.loadTripDates(locationId),
    ]);
    if (requestId != _requestId || selected?.id != selectedLocationId) {
      return false;
    }
    var loadedDates = selected?.datesEditable == true
        ? values[1] as PackingTripDateRange?
        : null;
    if (selected?.ecoPartnerCategory == EcoPartnerCategory.dining &&
        loadedDates != null &&
        !loadedDates.isSingleDay) {
      loadedDates = PackingTripDateRange(
        start: loadedDates.start,
        end: loadedDates.start,
      );
      await _persistence.saveTripDates(locationId, loadedDates);
      if (requestId != _requestId || selected?.id != selectedLocationId) {
        return false;
      }
    }
    packedIds
      ..clear()
      ..addAll(values[0] as Set<String>);
    tripDates = loadedDates;
    return true;
  }

  Future<void> _refreshForecastAndSections(
    PackingLocationOption? selected, {
    required int requestId,
    bool announceLoading = false,
  }) async {
    if (selected == null) {
      weather = null;
      forecast = const PackingForecastResult.needsDates();
      sections = const [];
      isWeatherLoading = false;
      return;
    }

    final selectedDates = selected.datesEditable
        ? tripDates
        : _upcomingItineraryDates();
    if (selectedDates == null) {
      weather = null;
      forecast = const PackingForecastResult.needsDates();
      isWeatherLoading = false;
      _rebuildSections(selected);
      _sanitizePackedIds();
      if (announceLoading) notifyListeners();
      return;
    }

    isWeatherLoading = true;
    forecast = const PackingForecastResult.loading();
    weather = null;
    _rebuildSections(selected);
    if (announceLoading) notifyListeners();

    final result = await _weatherService.getForecast(
      latitude: selected.latitude,
      longitude: selected.longitude,
      dates: selectedDates,
    );
    if (requestId != _requestId || selected.id != selectedLocationId) return;

    forecast = result;
    weather = result.summary;
    isWeatherLoading = false;
    _rebuildSections(selected);
    _sanitizePackedIds();
    if (announceLoading) notifyListeners();
  }

  void _rebuildSections(PackingLocationOption selected) {
    sections = _buildSections(
      destinationCategories,
      weather,
      ecoPartnerCategory: selected.ecoPartnerCategory,
    );
  }

  void _sanitizePackedIds() {
    final validIds =
        sections
            .expand((section) => section.items)
            .map((item) => item.id)
            .toSet()
          ..addAll(customItems.map((item) => item.id))
          ..addAll(_weatherIds);
    packedIds.removeWhere((id) => !validIds.contains(id));
  }

  PackingTripDateRange _upcomingItineraryDates() {
    final today = _dateOnly(_now());
    return PackingTripDateRange(
      start: today,
      end: today.add(const Duration(days: 6)),
    );
  }

  String _formatCoverage() {
    final start = forecast.coverageStart;
    final end = forecast.coverageEnd;
    if (start == null || end == null) return 'coverage';
    if (start == end) return _formatDate(start);
    return '${_formatDate(start)}–${_formatDate(end)}';
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'closer to the trip';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<void> _loadCustomItems() async {
    customItems = await _persistence.loadCustomItems();
  }

  Future<void> _saveCustomItems() async {
    await _persistence.saveCustomItems(customItems);
  }

  Future<void> _savePackedState() async {
    await _persistence.savePackedIds(
      selectedLocationId ?? 'essentials',
      packedIds,
    );
  }

  static List<PackingChecklistSection> _buildSections(
    Set<DestinationCategory> categories,
    PackingWeatherSummary? weather, {
    EcoPartnerCategory? ecoPartnerCategory,
  }) {
    final groups = <String, Map<String, PackingChecklistItem>>{};
    void add(String section, String id, String name, String reason) {
      groups.putIfAbsent(section, () => {})[id] = PackingChecklistItem(
        id: id,
        name: name,
        reason: reason,
      );
    }

    List<PackingChecklistSection> build() => groups.entries
        .map(
          (entry) => PackingChecklistSection(
            name: entry.key,
            items: entry.value.values.toList(),
          ),
        )
        .toList();

    if (ecoPartnerCategory == EcoPartnerCategory.dining) {
      add(
        'Dining Essentials',
        'dining_reservation',
        'Restaurant reservation details',
        'Keep the booking time and confirmation handy',
      );
      add(
        'Dining Essentials',
        'dietary_note',
        'Dietary or allergy note',
        'Clearly communicate allergies and dietary requirements',
      );
      add(
        'Dining Essentials',
        'cashless_payment',
        'Cash or cashless payment method',
        'Some dining venues have limited payment options',
      );
      add(
        'Dining Essentials',
        'reusable_container',
        'Reusable food container',
        'Bring leftovers home without single-use takeaway packaging',
      );
      add(
        'Getting There',
        'power_bank',
        'Power bank and charging cable',
        'Keep directions and booking details available on the journey',
      );
      add(
        'Getting There',
        'offline_maps',
        'Offline venue directions',
        'Find the venue even when mobile coverage is unreliable',
      );
      add(
        'Getting There',
        'transport_payment',
        'Transit card or ride payment',
        'Prepare a payment method for travelling to and from the venue',
      );
      add(
        'Personal Comfort',
        'water_bottle',
        'Reusable water bottle',
        'Stay hydrated while travelling to the venue',
      );
      add(
        'Personal Comfort',
        'hand_sanitizer',
        'Hand sanitizer',
        'Useful before eating when hand-washing facilities are limited',
      );
      add(
        'Personal Comfort',
        'indoor_layer',
        'Light indoor layer',
        'Useful in strongly air-conditioned dining spaces',
      );
      final rainProbability = weather?.rainProbability;
      if (rainProbability != null && rainProbability >= 40) {
        add(
          'Weather Essentials',
          'umbrella',
          'Compact umbrella',
          'Rain probability reaches ${rainProbability.round()}%',
        );
      }
      return build();
    }

    if (ecoPartnerCategory == EcoPartnerCategory.stay) {
      add(
        'Hotel Check-in',
        'photo_id',
        'Photo identification',
        'Hotels may request identification during check-in',
      );
      add(
        'Hotel Check-in',
        'hotel_reservation',
        'Hotel reservation and check-in details',
        'Keep the booking reference and check-in time handy',
      );
      add(
        'Hotel Check-in',
        'hotel_payment',
        'Payment or deposit method',
        'Hotels may request a card or deposit during check-in',
      );
      add(
        'Hotel Check-in',
        'insurance_details',
        'Insurance and emergency details',
        'Keep important contacts and policy information accessible',
      );
      add(
        'Getting There',
        'power_bank',
        'Power bank and charging cable',
        'Keep directions and check-in details available on the journey',
      );
      add(
        'Getting There',
        'offline_maps',
        'Offline hotel directions',
        'Find the hotel even when mobile coverage is unreliable',
      );
      add(
        'Getting There',
        'transport_payment',
        'Transit card or ride payment',
        'Prepare a payment method for travelling to and from the hotel',
      );
      add(
        'Overnight Essentials',
        'medication',
        'Personal medication',
        'Pack the medication needed during the stay',
      );
      add(
        'Overnight Essentials',
        'refillable_toiletries',
        'Refillable toiletries',
        'Use refillable containers to reduce single-use packaging',
      );
      add(
        'Overnight Essentials',
        'sleepwear',
        'Sleepwear',
        'Pack for a comfortable overnight stay',
      );
      add(
        'Overnight Essentials',
        'change_clothes',
        'Change of clothes',
        'Prepare an outfit for the following day',
      );
      add(
        'Overnight Essentials',
        'device_charger',
        'Device charger',
        'Charge the devices needed during the stay',
      );
      add(
        'Overnight Essentials',
        'reusable_slippers',
        'Reusable slippers',
        'Avoid disposable hotel slippers where possible',
      );
      add(
        'Overnight Essentials',
        'water_bottle',
        'Reusable water bottle',
        'Refill during the stay instead of using single-use bottles',
      );
      add(
        'Overnight Essentials',
        'laundry_bag',
        'Reusable laundry bag',
        'Keep worn clothing separate without disposable plastic bags',
      );
      final rainProbability = weather?.rainProbability;
      if (rainProbability != null && rainProbability >= 40) {
        add(
          'Weather Essentials',
          'umbrella',
          'Compact umbrella',
          'Rain probability reaches ${rainProbability.round()}%',
        );
        add(
          'Weather Essentials',
          'rain_jacket',
          'Light rain jacket',
          'Recommended for the destination forecast',
        );
      }
      if (weather != null && weather.maximumTemperature >= 31) {
        add(
          'Weather Essentials',
          'breathable_clothes',
          'Light breathable clothing',
          'Suitable for the warm forecast',
        );
      }
      if (weather != null && weather.minimumTemperature <= 18) {
        add(
          'Weather Essentials',
          'light_layer',
          'Light warm layer',
          'Suitable for the cooler forecast',
        );
      }
      return build();
    }

    add(
      'Documents',
      'passport',
      'Passport or identification',
      'Required for travel and check-in',
    );
    add(
      'Documents',
      'bookings',
      'Tickets and booking confirmations',
      'Keep transport and accommodation details available',
    );
    add(
      'Health & Personal Care',
      'medication',
      'Personal medication',
      'Pack enough for the entire trip',
    );
    add(
      'Health & Personal Care',
      'first_aid',
      'Compact first-aid kit',
      'For minor health needs while travelling',
    );
    add(
      'Health & Personal Care',
      'insurance_details',
      'Travel insurance details',
      'Keep emergency and policy information accessible',
    );
    add(
      'Tech & Gear',
      'power_bank',
      'Power bank and charging cable',
      'Keep navigation and emergency communication available',
    );
    add(
      'Tech & Gear',
      'offline_maps',
      'Offline maps',
      'Navigate when mobile coverage is unavailable',
    );
    add(
      'Personal Belongings',
      'transport_payment',
      'Transit card or payment method',
      'Prepare for local public transport',
    );
    add(
      'Clothing',
      'walking_shoes',
      'Comfortable walking shoes',
      'Suitable for exploring destinations',
    );

    if (weather != null) {
      final rainProbability = weather.rainProbability;
      if (rainProbability != null && rainProbability >= 40) {
        add(
          'Weather Essentials',
          'umbrella',
          'Compact umbrella',
          'Rain probability reaches ${rainProbability.round()}%',
        );
        add(
          'Weather Essentials',
          'rain_jacket',
          'Light rain jacket',
          'Recommended for the destination forecast',
        );
      }
      final uvIndex = weather.uvIndex;
      if (uvIndex != null && uvIndex >= 6) {
        add(
          'Weather Essentials',
          'sunscreen',
          'Sunscreen',
          'UV index may reach ${uvIndex.toStringAsFixed(1)}',
        );
        add(
          'Weather Essentials',
          'sun_hat',
          'Hat or cap',
          'Protection from high UV exposure',
        );
      }
      if (weather.maximumTemperature >= 31) {
        add(
          'Weather Essentials',
          'water_bottle',
          'Reusable water bottle',
          'Stay hydrated in temperatures up to ${weather.maximumTemperature.round()}°C',
        );
        add(
          'Weather Essentials',
          'breathable_clothes',
          'Light breathable clothing',
          'Suitable for the warm forecast',
        );
      }
      if (weather.minimumTemperature <= 18) {
        add(
          'Weather Essentials',
          'light_layer',
          'Light warm layer',
          'Temperatures may fall to ${weather.minimumTemperature.round()}°C',
        );
      }
    }

    for (final category in categories) {
      switch (category) {
        case DestinationCategory.beach:
        case DestinationCategory.island:
          add(
            'Beach Essentials',
            'swimwear',
            'Swimwear',
            'Recommended for beach destinations',
          );
          add(
            'Beach Essentials',
            'reef_sunscreen',
            'Reef-conscious sunscreen',
            'Sun protection for coastal activities',
          );
          add(
            'Beach Essentials',
            'quick_towel',
            'Quick-dry towel',
            'Useful after swimming or water activities',
          );
          add(
            'Beach Essentials',
            'waterproof_pouch',
            'Waterproof phone pouch',
            'Protect electronics from sand and water',
          );
        case DestinationCategory.waterfall:
          add(
            'Outdoor Adventure',
            'grip_shoes',
            'Non-slip shoes',
            'Wet waterfall trails can be slippery',
          );
          add(
            'Outdoor Adventure',
            'dry_bag',
            'Dry bag',
            'Keeps belongings protected near water',
          );
          add(
            'Outdoor Adventure',
            'insect_repellent',
            'Insect repellent',
            'Useful around forested waterfall areas',
          );
          add(
            'Outdoor Adventure',
            'change_clothes',
            'Change of clothes',
            'Useful after waterfall activities',
          );
        case DestinationCategory.park:
        case DestinationCategory.viewpoint:
        case DestinationCategory.mountain:
          add(
            'Outdoor Adventure',
            'daypack',
            'Lightweight daypack',
            'Carry essentials during outdoor exploration',
          );
          add(
            'Outdoor Adventure',
            'water_bottle',
            'Reusable water bottle',
            'Stay hydrated while walking outdoors',
          );
          add(
            'Outdoor Adventure',
            'sun_hat',
            'Hat or cap',
            'Protection during exposed scenic walks',
          );
          add(
            'Outdoor Adventure',
            'rain_jacket',
            'Compact rain jacket',
            'Weather can change during outdoor trips',
          );
        case DestinationCategory.heritageSite:
          add(
            'Cultural Visits',
            'modest_clothing',
            'Modest clothing',
            'Appropriate for cultural and religious sites',
          );
          add(
            'Cultural Visits',
            'light_scarf',
            'Light scarf or shoulder cover',
            'Useful where covered shoulders are expected',
          );
          add(
            'Tech & Gear',
            'camera',
            'Camera or phone storage',
            'Capture heritage architecture and details',
          );
        case DestinationCategory.museum:
        case DestinationCategory.art:
          add(
            'Cultural Visits',
            'light_layer',
            'Light cardigan or layer',
            'Indoor galleries may be air-conditioned',
          );
          add(
            'Tech & Gear',
            'earphones',
            'Earphones',
            'Useful for digital or audio guides',
          );
        case DestinationCategory.restaurant:
        case DestinationCategory.cafe:
          add(
            'Health & Personal Care',
            'dietary_note',
            'Dietary requirement note',
            'Useful when communicating allergies or preferences',
          );
          add(
            'Personal Belongings',
            'cashless_payment',
            'Cash or cashless payment method',
            'Some dining venues have limited payment options',
          );
        case DestinationCategory.craft:
          add(
            'Personal Belongings',
            'foldable_bag',
            'Foldable shopping bag',
            'Carry locally made purchases without disposable bags',
          );
        case DestinationCategory.mall:
          add(
            'Personal Belongings',
            'foldable_bag',
            'Foldable shopping bag',
            'Carry purchases without disposable bags',
          );
          add(
            'Clothing',
            'light_layer',
            'Light cardigan or layer',
            'Shopping centres may be strongly air-conditioned',
          );
        case DestinationCategory.themePark:
          add(
            'Outdoor Adventure',
            'water_bottle',
            'Reusable water bottle',
            'Stay hydrated during a long activity day',
          );
          add(
            'Personal Belongings',
            'waterproof_pouch',
            'Waterproof phone pouch',
            'Protect essentials around water rides',
          );
          add(
            'Clothing',
            'change_clothes',
            'Change of clothes',
            'Useful after water rides or outdoor activities',
          );
        case DestinationCategory.attraction:
          add(
            'Personal Belongings',
            'umbrella',
            'Compact umbrella',
            'Useful for sun or sudden rain',
          );
      }
    }

    return build();
  }
}
