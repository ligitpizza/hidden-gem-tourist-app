import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'packing_checklist.dart';

abstract interface class PackingChecklistRepositoryContract {
  Future<String?> loadSelection();
  Future<void> saveSelection(String locationId);
  Future<List<PackingChecklistItem>> loadCustomItems();
  Future<void> saveCustomItems(List<PackingChecklistItem> items);
  Future<Set<String>> loadPackedIds(String locationId);
  Future<void> savePackedIds(String locationId, Set<String> ids);
}

/// A compact local-first repository. SharedPreferences is the cache and
/// pending queue; each successful read/write also reconciles with Supabase.
class PackingChecklistRepository implements PackingChecklistRepositoryContract {
  PackingChecklistRepository({
    String? userId,
    SupabaseClient? client,
    Future<SharedPreferences> Function()? preferences,
  }) : _clientOverride = client,
       _explicitLocalOnly = userId != null && client == null,
       _preferences = preferences ?? SharedPreferences.getInstance,
       userId = userId ?? client?.auth.currentUser?.id ?? _currentUserId();

  final String userId;
  final SupabaseClient? _clientOverride;
  final bool _explicitLocalOnly;
  final Future<SharedPreferences> Function() _preferences;

  SupabaseClient? get _client {
    if (_explicitLocalOnly || userId == 'guest') return null;
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String get _selectionKey => 'packing_location_$userId';
  String get _customKey => 'packing_custom_items_$userId';
  String _packedKey(String locationId) =>
      'packing_checklist_${userId}_$locationId';
  String _updatedKey(String key) => '${key}_updated_at';

  @override
  Future<String?> loadSelection() async {
    final prefs = await _preferences();
    final local = prefs.getString(_selectionKey);
    final client = _client;
    if (client == null) return local;
    try {
      final row = await client
          .from('packing_preferences')
          .select('selected_location_id,updated_at')
          .eq('user_id', userId)
          .maybeSingle();
      final remote = row?['selected_location_id'] as String?;
      if (remote != null) {
        if (_localIsNewer(prefs, _selectionKey, row?['updated_at'])) {
          if (local != null) await saveSelection(local);
          return local;
        }
        await prefs.setString(_selectionKey, remote);
        await _storeRemoteTime(prefs, _selectionKey, row?['updated_at']);
        return remote;
      }
      if (local != null) await saveSelection(local);
    } catch (_) {}
    return local;
  }

  @override
  Future<void> saveSelection(String locationId) async {
    final prefs = await _preferences();
    await prefs.setString(_selectionKey, locationId);
    await _touch(prefs, _selectionKey);
    final client = _client;
    if (client == null) return;
    try {
      await client.from('packing_preferences').upsert({
        'user_id': userId,
        'selected_location_id': locationId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Future<List<PackingChecklistItem>> loadCustomItems() async {
    final prefs = await _preferences();
    final local = _decodeItems(prefs.getString(_customKey));
    final client = _client;
    if (client == null) return local;
    try {
      final row = await client
          .from('packing_custom_items')
          .select('items,updated_at')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        if (_localIsNewer(prefs, _customKey, row['updated_at'])) {
          await saveCustomItems(local);
          return local;
        }
        final items = _itemsFromValues(row['items'] as List? ?? const []);
        await prefs.setString(_customKey, _encodeItems(items));
        await _storeRemoteTime(prefs, _customKey, row['updated_at']);
        return items;
      }
      if (local.isNotEmpty) await saveCustomItems(local);
    } catch (_) {}
    return local;
  }

  @override
  Future<void> saveCustomItems(List<PackingChecklistItem> items) async {
    final prefs = await _preferences();
    await prefs.setString(_customKey, _encodeItems(items));
    await _touch(prefs, _customKey);
    final client = _client;
    if (client == null) return;
    try {
      await client.from('packing_custom_items').upsert({
        'user_id': userId,
        'items': _itemValues(items),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Future<Set<String>> loadPackedIds(String locationId) async {
    final prefs = await _preferences();
    final local = _decodeIds(prefs.getString(_packedKey(locationId)));
    final client = _client;
    if (client == null) return local;
    try {
      final row = await client
          .from('packing_checklist_states')
          .select('packed_ids,updated_at')
          .eq('user_id', userId)
          .eq('location_id', locationId)
          .maybeSingle();
      if (row != null) {
        final key = _packedKey(locationId);
        if (_localIsNewer(prefs, key, row['updated_at'])) {
          await savePackedIds(locationId, local);
          return local;
        }
        final ids = (row['packed_ids'] as List? ?? const [])
            .map((value) => '$value')
            .toSet();
        await prefs.setString(key, jsonEncode(ids.toList()));
        await _storeRemoteTime(prefs, key, row['updated_at']);
        return ids;
      }
      if (local.isNotEmpty) await savePackedIds(locationId, local);
    } catch (_) {}
    return local;
  }

  @override
  Future<void> savePackedIds(String locationId, Set<String> ids) async {
    final prefs = await _preferences();
    final key = _packedKey(locationId);
    await prefs.setString(key, jsonEncode(ids.toList()));
    await _touch(prefs, key);
    final client = _client;
    if (client == null) return;
    try {
      await client.from('packing_checklist_states').upsert({
        'user_id': userId,
        'location_id': locationId,
        'packed_ids': ids.toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static List<PackingChecklistItem> _decodeItems(String? raw) {
    if (raw == null) return const [];
    try {
      return _itemsFromValues(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  static List<PackingChecklistItem> _itemsFromValues(List values) => values
      .whereType<Map>()
      .map(
        (value) => PackingChecklistItem(
          id: '${value['id']}',
          name: '${value['name'] ?? ''}',
          reason: '${value['reason'] ?? 'Added by you'}',
        ),
      )
      .where((item) => item.name.isNotEmpty)
      .toList();

  static List<Map<String, String>> _itemValues(
    List<PackingChecklistItem> items,
  ) => [
    for (final item in items)
      {'id': item.id, 'name': item.name, 'reason': item.reason},
  ];

  static String _encodeItems(List<PackingChecklistItem> items) =>
      jsonEncode(_itemValues(items));

  static Set<String> _decodeIds(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).map((value) => '$value').toSet();
    } catch (_) {
      return {};
    }
  }

  static String _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  bool _localIsNewer(SharedPreferences prefs, String key, Object? remoteValue) {
    final local = DateTime.tryParse(prefs.getString(_updatedKey(key)) ?? '');
    final remote = DateTime.tryParse('$remoteValue');
    return local != null && (remote == null || local.isAfter(remote));
  }

  Future<void> _touch(SharedPreferences prefs, String key) => prefs.setString(
    _updatedKey(key),
    DateTime.now().toUtc().toIso8601String(),
  );

  Future<void> _storeRemoteTime(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    final parsed = DateTime.tryParse('$value');
    if (parsed != null) {
      await prefs.setString(_updatedKey(key), parsed.toUtc().toIso8601String());
    }
  }
}
