import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'eco_partner.dart';
import 'saved_eco_partner_repository.dart';

class EcoPartnerHomeCacheEntry {
  const EcoPartnerHomeCacheEntry({
    required this.partners,
    required this.origin,
    required this.radiusKm,
    required this.fetchedAt,
  });

  final List<EcoPartner> partners;
  final EcoDestination origin;
  final double radiusKm;
  final DateTime fetchedAt;
}

abstract interface class EcoPartnerHomeCacheContract {
  Future<EcoPartnerHomeCacheEntry?> read();
  Future<void> write(EcoPartnerHomeCacheEntry entry);
}

class SharedPreferencesEcoPartnerHomeCache
    implements EcoPartnerHomeCacheContract {
  SharedPreferencesEcoPartnerHomeCache({
    Future<SharedPreferences> Function()? preferences,
    String Function()? userId,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _userId = userId ?? _currentUserId;

  final Future<SharedPreferences> Function() _preferences;
  final String Function() _userId;

  // v2 invalidates results cached before transport preview mode precedence
  // was corrected. Otherwise an MRT/LRT card can retain a bus preview for up
  // to 24 hours even after the catalogue has been repaired.
  String get _storageKey => 'eco_partner_nearby_home_v2_${_userId()}';

  @override
  Future<EcoPartnerHomeCacheEntry?> read() async {
    try {
      final raw = (await _preferences()).getString(_storageKey);
      if (raw == null) return null;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final origin = (json['origin'] as Map).cast<String, dynamic>();
      return EcoPartnerHomeCacheEntry(
        partners: (json['partners'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (partner) => SavedEcoPartnerCodec.fromJson(
                partner.cast<String, dynamic>(),
              ),
            )
            .toList(growable: false),
        origin: EcoDestination(
          'Current location',
          (origin['latitude'] as num).toDouble(),
          (origin['longitude'] as num).toDouble(),
        ),
        radiusKm: (json['radiusKm'] as num).toDouble(),
        fetchedAt: DateTime.parse('${json['fetchedAt']}'),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(EcoPartnerHomeCacheEntry entry) async {
    final roundedLatitude = _roundCoordinate(entry.origin.latitude);
    final roundedLongitude = _roundCoordinate(entry.origin.longitude);
    await (await _preferences()).setString(
      _storageKey,
      jsonEncode({
        'fetchedAt': entry.fetchedAt.toUtc().toIso8601String(),
        'radiusKm': entry.radiusKm,
        'origin': {'latitude': roundedLatitude, 'longitude': roundedLongitude},
        'partners': entry.partners
            .map(SavedEcoPartnerCodec.toJson)
            .toList(growable: false),
      }),
    );
  }

  static double _roundCoordinate(double value) =>
      (value * 1000).roundToDouble() / 1000;

  static String _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }
}
