import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'eco_partner.dart';
import 'saved_eco_partner.dart';

abstract interface class SavedEcoPartnerRepositoryContract {
  Future<List<SavedEcoPartner>> fetchAll();
  Future<SavedEcoPartner> save(EcoPartner partner);
  Future<void> delete(String id);
}

/// Uses Supabase when the migration is available, but keeps saving locally
/// when an older deployment has not created `saved_eco_partners` yet.
/// Locally saved partners are uploaded automatically after the table becomes
/// available and [fetchAll] is called again (normally on the next app start).
class ResilientSavedEcoPartnerRepository
    implements SavedEcoPartnerRepositoryContract {
  ResilientSavedEcoPartnerRepository({
    SavedEcoPartnerRepositoryContract? remote,
    SavedEcoPartnerRepositoryContract? local,
  }) : _remote = remote ?? SavedEcoPartnerRepository(),
       _local = local ?? LocalSavedEcoPartnerRepository();

  final SavedEcoPartnerRepositoryContract _remote;
  final SavedEcoPartnerRepositoryContract _local;
  bool _useLocal = false;

  @override
  Future<List<SavedEcoPartner>> fetchAll() async {
    try {
      final remoteSaved = await _remote.fetchAll();
      _useLocal = false;
      final localSaved = await _local.fetchAll();
      if (localSaved.isEmpty) return remoteSaved;

      for (final saved in localSaved) {
        await _remote.save(saved.partner);
        await _local.delete(saved.id);
      }
      return _remote.fetchAll();
    } catch (error) {
      if (!_isMissingTable(error)) rethrow;
      _useLocal = true;
      return _local.fetchAll();
    }
  }

  @override
  Future<SavedEcoPartner> save(EcoPartner partner) async {
    if (_useLocal) return _local.save(partner);
    try {
      return await _remote.save(partner);
    } catch (error) {
      if (!_isMissingTable(error)) rethrow;
      _useLocal = true;
      return _local.save(partner);
    }
  }

  @override
  Future<void> delete(String id) async {
    if (_useLocal || id.startsWith('local:')) {
      await _local.delete(id);
      return;
    }
    await _remote.delete(id);
  }

  static bool _isMissingTable(Object error) =>
      error is PostgrestException &&
      (error.code == 'PGRST205' ||
          error.code == '42P01' ||
          error.message.contains('saved_eco_partners'));
}

class LocalSavedEcoPartnerRepository
    implements SavedEcoPartnerRepositoryContract {
  LocalSavedEcoPartnerRepository({
    Future<SharedPreferences> Function()? preferences,
    String Function()? userId,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _userId = userId ?? _currentUserId;

  final Future<SharedPreferences> Function() _preferences;
  final String Function() _userId;

  String get _storageKey => 'saved_eco_partners_local_${_userId()}';

  @override
  Future<List<SavedEcoPartner>> fetchAll() async {
    final preferences = await _preferences();
    final raw = preferences.getString(_storageKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (row) => SavedEcoPartner(
              id: '${row['id']}',
              partner: SavedEcoPartnerCodec.fromJson(
                (row['partner'] as Map).cast<String, dynamic>(),
              ),
              savedAt: DateTime.tryParse('${row['savedAt']}') ?? DateTime.now(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<SavedEcoPartner> save(EcoPartner partner) async {
    final current = await fetchAll();
    final existing = current
        .where((saved) => saved.partner.id == partner.id)
        .firstOrNull;
    if (existing != null) return existing;
    final saved = SavedEcoPartner(
      id: 'local:${partner.id}',
      partner: partner,
      savedAt: DateTime.now(),
    );
    await _write([saved, ...current]);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    final current = await fetchAll();
    await _write(current.where((saved) => saved.id != id).toList());
  }

  Future<void> _write(List<SavedEcoPartner> saved) async {
    final preferences = await _preferences();
    await preferences.setString(
      _storageKey,
      jsonEncode([
        for (final item in saved)
          {
            'id': item.id,
            'partner': SavedEcoPartnerCodec.toJson(item.partner),
            'savedAt': item.savedAt.toIso8601String(),
          },
      ]),
    );
  }

  static String _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }
}

class SavedEcoPartnerRepository implements SavedEcoPartnerRepositoryContract {
  SavedEcoPartnerRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('A signed-in user is required.');
    }
    return user.id;
  }

  @override
  Future<List<SavedEcoPartner>> fetchAll() async {
    final rows = await _client
        .from('saved_eco_partners')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => _mapRow((row as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<SavedEcoPartner> save(EcoPartner partner) async {
    final row = await _client
        .from('saved_eco_partners')
        .upsert({
          'user_id': _userId,
          'partner_id': partner.id,
          'partner': _toJson(partner),
        }, onConflict: 'user_id,partner_id')
        .select()
        .single();
    return _mapRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from('saved_eco_partners')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  SavedEcoPartner _mapRow(Map<String, dynamic> row) => SavedEcoPartner(
    id: '${row['id']}',
    partner: SavedEcoPartnerCodec.fromJson(
      (row['partner'] as Map).cast<String, dynamic>(),
    ),
    savedAt: DateTime.parse('${row['created_at']}'),
  );

  static Map<String, dynamic> _toJson(EcoPartner partner) =>
      SavedEcoPartnerCodec.toJson(partner);
}

class SavedEcoPartnerCodec {
  const SavedEcoPartnerCodec._();

  static Map<String, dynamic> toJson(EcoPartner partner) => {
    'id': partner.id,
    'name': partner.name,
    'category': partner.category.name,
    'subtype': partner.subtype,
    'latitude': partner.latitude,
    'longitude': partner.longitude,
    'address': partner.address,
    'distanceKm': partner.distanceKm,
    'sustainabilityLabel': partner.sustainabilityLabel,
    'evidence': partner.evidence,
    'sourceName': partner.sourceName,
    'sourceUrl': partner.sourceUrl,
    'lastUpdated': partner.lastUpdated.toIso8601String(),
    'priceBand': partner.priceBand,
    'website': partner.website,
    'imageUrl': partner.imageUrl,
    'imageSourceName': partner.imageSourceName,
    'imageSourceUrl': partner.imageSourceUrl,
    'imageCapturedAt': partner.imageCapturedAt?.toIso8601String(),
    'transitRoutes': partner.transitRoutes
        .map(
          (route) => {
            'mode': route.mode,
            'shortName': route.shortName,
            'longName': route.longName,
          },
        )
        .toList(),
    'veganClassification': partner.veganClassification,
    'chargerDetails': partner.chargerDetails,
    'gstcVerified': partner.gstcVerified,
  };

  static EcoPartner fromJson(Map<String, dynamic> json) => EcoPartner(
    id: '${json['id']}',
    name: '${json['name']}',
    category: EcoPartnerCategory.values.firstWhere(
      (value) => value.name == json['category'],
      orElse: () => EcoPartnerCategory.transport,
    ),
    subtype: '${json['subtype'] ?? ''}',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: '${json['address'] ?? ''}',
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    sustainabilityLabel: '${json['sustainabilityLabel'] ?? ''}',
    evidence: '${json['evidence'] ?? ''}',
    sourceName: '${json['sourceName'] ?? ''}',
    sourceUrl: '${json['sourceUrl'] ?? ''}',
    lastUpdated:
        DateTime.tryParse('${json['lastUpdated'] ?? ''}') ?? DateTime.now(),
    priceBand: json['priceBand'] as String?,
    website: json['website'] as String?,
    imageUrl: json['imageUrl'] as String?,
    imageSourceName: json['imageSourceName'] as String?,
    imageSourceUrl: json['imageSourceUrl'] as String?,
    imageCapturedAt: DateTime.tryParse('${json['imageCapturedAt'] ?? ''}'),
    transitRoutes: (json['transitRoutes'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (route) => EcoTransitRouteInfo(
            mode: '${route['mode'] ?? 'Transit'}',
            shortName: route['shortName'] as String?,
            longName: route['longName'] as String?,
          ),
        )
        .toList(),
    veganClassification: json['veganClassification'] as String?,
    chargerDetails: json['chargerDetails'] as String?,
    gstcVerified: json['gstcVerified'] == true,
  );
}
