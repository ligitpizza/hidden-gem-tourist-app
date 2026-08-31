import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'emergency_contact.dart';

abstract interface class EmergencyContactRemoteDataSource {
  Future<List<EmergencyContact>> fetchAll(String userId);
  Future<void> replaceAll(String userId, List<EmergencyContact> contacts);
}

class SupabaseEmergencyContactDataSource
    implements EmergencyContactRemoteDataSource {
  SupabaseEmergencyContactDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<EmergencyContact>> fetchAll(String userId) async {
    final rows = await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', userId)
        .order('position');
    return (rows as List)
        .map(
          (row) => EmergencyContactRowCodec.fromRow(
            (row as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  @override
  Future<void> replaceAll(
    String userId,
    List<EmergencyContact> contacts,
  ) async {
    final existingRows = await _client
        .from('emergency_contacts')
        .select('id')
        .eq('user_id', userId);
    final retainedIds = contacts.map((contact) => contact.id).toSet();
    final removedIds = (existingRows as List)
        .map((row) => '${(row as Map)['id']}')
        .where((id) => !retainedIds.contains(id));

    if (contacts.isNotEmpty) {
      await _client.from('emergency_contacts').upsert([
        for (var index = 0; index < contacts.length; index++)
          EmergencyContactRowCodec.toRow(
            contacts[index],
            userId: userId,
            position: index,
          ),
      ], onConflict: 'user_id,id');
    }
    for (final id in removedIds) {
      await _client
          .from('emergency_contacts')
          .delete()
          .eq('user_id', userId)
          .eq('id', id);
    }
  }
}

class EmergencyContactRepository {
  EmergencyContactRepository({
    String? userId,
    SupabaseClient? client,
    EmergencyContactRemoteDataSource? remote,
    Future<SharedPreferences> Function()? preferences,
  }) : userId = userId ?? _currentUserId(client),
       _remote =
           remote ??
           (userId != null && client == null
               ? null
               : SupabaseEmergencyContactDataSource(client: client)),
       _preferences = preferences ?? SharedPreferences.getInstance;

  final String userId;
  final EmergencyContactRemoteDataSource? _remote;
  final Future<SharedPreferences> Function() _preferences;

  String get _key => 'travel_emergency_contacts_$userId';
  String get _pendingKey => '${_key}_pending_sync';
  String get _initializedKey => '${_key}_cloud_initialized';

  Future<List<EmergencyContact>> load() async {
    final prefs = await _preferences();
    final local = _decode(prefs.getString(_key));
    final remote = _remote;
    if (remote == null) return local;

    if (prefs.getBool(_pendingKey) == true) {
      try {
        await remote.replaceAll(userId, local);
        await _markSynced(prefs);
      } catch (_) {}
      return local;
    }

    try {
      final cloud = await remote.fetchAll(userId);
      final cloudWasInitialized = prefs.getBool(_initializedKey) == true;
      if (cloud.isEmpty && local.isNotEmpty && !cloudWasInitialized) {
        await remote.replaceAll(userId, local);
        await _markSynced(prefs);
        return local;
      }
      await _writeLocal(prefs, cloud);
      await _markSynced(prefs);
      return cloud;
    } catch (_) {
      return local;
    }
  }

  Future<void> save(List<EmergencyContact> contacts) async {
    final prefs = await _preferences();
    await _writeLocal(prefs, contacts);
    final remote = _remote;
    if (remote == null) return;

    await prefs.setBool(_pendingKey, true);
    try {
      await remote.replaceAll(userId, contacts);
      await _markSynced(prefs);
    } catch (_) {
      // Local data remains authoritative until the next successful retry.
    }
  }

  Future<void> _writeLocal(
    SharedPreferences prefs,
    List<EmergencyContact> contacts,
  ) => prefs.setString(
    _key,
    jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
  );

  Future<void> _markSynced(SharedPreferences prefs) async {
    await prefs.setBool(_pendingKey, false);
    await prefs.setBool(_initializedKey, true);
  }

  static List<EmergencyContact> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (item) => EmergencyContact.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _currentUserId(SupabaseClient? client) {
    final user = client == null
        ? Supabase.instance.client.auth.currentUser
        : client.auth.currentUser;
    if (user == null) {
      throw const AuthException('A signed-in user is required.');
    }
    return user.id;
  }
}

class EmergencyContactRowCodec {
  const EmergencyContactRowCodec._();

  static Map<String, dynamic> toRow(
    EmergencyContact contact, {
    required String userId,
    required int position,
  }) => {
    'id': contact.id,
    'user_id': userId,
    'name': contact.name,
    'relationship': contact.relationship,
    'phone': contact.phone,
    'country': contact.country,
    'email': contact.email,
    'notes': contact.notes,
    'available_when_locked': contact.availableWhenLocked,
    'position': position,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  static EmergencyContact fromRow(Map<String, dynamic> row) => EmergencyContact(
    id: '${row['id']}',
    name: '${row['name'] ?? ''}',
    relationship: '${row['relationship'] ?? ''}',
    phone: '${row['phone'] ?? ''}',
    country: '${row['country'] ?? ''}',
    email: '${row['email'] ?? ''}',
    notes: '${row['notes'] ?? ''}',
    availableWhenLocked: row['available_when_locked'] == true,
  );
}
