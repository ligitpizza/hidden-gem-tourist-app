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
  }) : _locationSource = locationSource ?? SavedPackingLocationSource(),
       _weatherService = weatherService ?? PackingWeatherService(),
       _persistence = persistence ?? PackingChecklistRepository();

  final PackingLocationSource _locationSource;
  final PackingWeatherService _weatherService;
  final PackingChecklistRepositoryContract _persistence;
  final Set<String> packedIds = {};
  List<PackingChecklistSection> sections = const [];
  List<PackingChecklistItem> customItems = const [];
  String tripLabel = 'Travel essentials';
  List<PackingLocationOption> locationOptions = const [];
  String? selectedLocationId;
  Set<DestinationCategory> destinationCategories = const {};
  EcoPartnerCategory? ecoPartnerCategory;
  bool isLoading = true;
  PackingWeatherSummary? weather;

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
  };
  static const _transitIds = {
    'bookings',
    'power_bank',
    'offline_maps',
    'transport_payment',
  };

  int get weatherScore => _metricScore(_weatherIds);
  int get healthScore => _metricScore(_healthIds);
  int get transitScore => _metricScore(_transitIds);
  String get weatherDetail =>
      weather?.shortDescription ?? 'Forecast unavailable';
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
  String get readinessStatus => switch (readinessScore) {
    >= 85 => 'READY TO WANDER',
    >= 60 => 'ALMOST READY',
    _ => 'PREPARATION NEEDED',
  };

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    locationOptions = await _locationSource.load();
    final savedSelection = await _persistence.loadSelection();
    selectedLocationId =
        locationOptions.any((option) => option.id == savedSelection)
        ? savedSelection
        : locationOptions.firstOrNull?.id;
    await _rebuildForSelectedLocation();
    await _loadCustomItems();
    await _loadPackedState();
    isLoading = false;
    notifyListeners();
  }

  Future<void> selectLocation(String id) async {
    if (selectedLocationId == id ||
        !locationOptions.any((option) => option.id == id)) {
      return;
    }
    isLoading = true;
    notifyListeners();
    selectedLocationId = id;
    await _persistence.saveSelection(id);
    await _rebuildForSelectedLocation();
    await _loadPackedState();
    isLoading = false;
    notifyListeners();
  }

  Future<void> _rebuildForSelectedLocation() async {
    final selected = locationOptions
        .where((option) => option.id == selectedLocationId)
        .firstOrNull;
    tripLabel = selected?.label ?? 'Travel essentials';
    destinationCategories = selected?.categories ?? const {};
    ecoPartnerCategory = selected?.ecoPartnerCategory;
    weather = selected == null
        ? null
        : await _weatherService.getForecast(
            latitude: selected.latitude,
            longitude: selected.longitude,
          );
    sections = selected == null
        ? const []
        : _buildSections(
            destinationCategories,
            weather,
            ecoPartnerCategory: selected.ecoPartnerCategory,
          );
  }

  int _metricScore(Set<String> ids) {
    final applicable = sections
        .expand((section) => section.items)
        .where((item) => ids.contains(item.id))
        .toList();
    if (applicable.isEmpty) return 0;
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

  Future<void> _loadPackedState() async {
    packedIds.clear();
    packedIds.addAll(
      await _persistence.loadPackedIds(selectedLocationId ?? 'essentials'),
    );
    final validIds =
        sections
            .expand((section) => section.items)
            .map((item) => item.id)
            .toSet()
          ..addAll(customItems.map((item) => item.id));
    packedIds.removeWhere((id) => !validIds.contains(id));
  }

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

    if (ecoPartnerCategory == EcoPartnerCategory.stay) {
      add(
        'Hotel Stay',
        'hotel_reservation',
        'Hotel reservation and check-in details',
        'Keep the Eco Partner booking reference and check-in time handy',
      );
      add(
        'Hotel Stay',
        'refillable_toiletries',
        'Refillable toiletries',
        'Use your own refillable containers to reduce single-use packaging',
      );
      add(
        'Hotel Stay',
        'sleepwear',
        'Sleepwear',
        'Pack for a comfortable overnight hotel stay',
      );
      add(
        'Hotel Stay',
        'reusable_slippers',
        'Reusable slippers',
        'Avoid disposable hotel slippers where possible',
      );
    }

    if (ecoPartnerCategory == EcoPartnerCategory.dining) {
      add(
        'Dining Essentials',
        'dietary_note',
        'Dietary requirement note',
        'Useful when communicating allergies or preferences',
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
        'Dining Essentials',
        'reusable_cutlery',
        'Reusable cutlery set',
        'Helps avoid disposable utensils when dining on the go',
      );
    }

    if (weather != null) {
      if (weather.rainProbability >= 40) {
        add(
          'Weather Essentials',
          'umbrella',
          'Compact umbrella',
          'Rain probability reaches ${weather.rainProbability.round()}%',
        );
        add(
          'Weather Essentials',
          'rain_jacket',
          'Light rain jacket',
          'Recommended for the destination forecast',
        );
      }
      if (weather.uvIndex >= 6) {
        add(
          'Weather Essentials',
          'sunscreen',
          'Sunscreen',
          'UV index may reach ${weather.uvIndex.toStringAsFixed(1)}',
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
      if (ecoPartnerCategory == EcoPartnerCategory.stay &&
          category == DestinationCategory.attraction) {
        continue;
      }
      if (ecoPartnerCategory == EcoPartnerCategory.dining &&
          (category == DestinationCategory.restaurant ||
              category == DestinationCategory.cafe)) {
        continue;
      }
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

    return groups.entries
        .map(
          (entry) => PackingChecklistSection(
            name: entry.key,
            items: entry.value.values.toList(),
          ),
        )
        .toList();
  }
}
