import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'travel_document.dart';

class TravelDocumentRepository {
  static const maxFileSizeBytes = 10 * 1024 * 1024;
  static const maxUserStorageBytes = 50 * 1024 * 1024;
  static const maxVaultStorageBytes = 250 * 1024 * 1024;
  static const storageBucket = 'travel-documents';

  TravelDocumentRepository({String? userId, SupabaseClient? client})
    : _clientOverride = client,
      _explicitLocalOnly = userId != null && client == null,
      userId =
          userId ??
          client?.auth.currentUser?.id ??
          Supabase.instance.client.auth.currentUser?.id ??
          (throw StateError('A signed-in user is required.'));

  final String userId;
  final SupabaseClient? _clientOverride;
  final bool _explicitLocalOnly;

  SupabaseClient? get _client {
    if (_explicitLocalOnly) return null;
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String get _metadataKey => 'travel_vault_documents_v3_$userId';
  String get _legacyMetadataKey => 'travel_vault_documents_v2_$userId';
  String get _deletionsKey => 'travel_vault_pending_deletes_$userId';

  Future<List<TravelDocument>> load() async {
    var local = await _loadLocal();
    final client = _client;
    if (client == null) return local;
    try {
      await _flushPendingDeletes(client);
      final rows = await client
          .from('travel_documents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      final remote = (rows as List)
          .map((row) => _fromRemote((row as Map).cast<String, dynamic>()))
          .toList();
      final remoteIds = remote.map((item) => item.id).toSet();
      final localById = {for (final item in local) item.id: item};
      for (final document in local.where(
        (item) => !remoteIds.contains(item.id),
      )) {
        try {
          await _syncOne(document);
        } catch (_) {}
      }
      local = [
        for (final document in remote)
          document.copyWith(storedPath: localById[document.id]?.storedPath),
        for (final document in local)
          if (!remoteIds.contains(document.id)) document,
      ];
      await _saveLocal(local);
    } catch (_) {
      // Network failures and unapplied migrations leave the offline vault usable.
    }
    local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return local;
  }

  Future<TravelDocument> importFile({
    required String sourcePath,
    required String originalFileName,
    required String displayName,
    required String category,
    required List<TravelDocument> currentDocuments,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Selected file is unavailable.');
    }
    final sourceSize = await source.length();
    if (sourceSize > maxFileSizeBytes) {
      throw const FileSystemException(
        'The selected file exceeds the 10 MB upload limit.',
      );
    }
    if (await _cloudQuotaAvailable(sourceSize) == false) {
      throw const TravelDocumentQuotaException();
    }

    final directory = await _vaultDirectory();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final extension = _extensionOf(originalFileName);
    final storedName = extension.isEmpty ? id : '$id.$extension';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$storedName',
    );
    await source.copy(destination.path);
    final document = TravelDocument(
      id: id,
      displayName: displayName.trim(),
      category: category,
      originalFileName: originalFileName,
      storedPath: destination.path,
      extension: extension,
      fileSize: sourceSize,
      createdAt: DateTime.now(),
      storagePath: '$userId/$id/$storedName',
    );

    try {
      final values = [document, ...currentDocuments];
      await _saveLocal(values);
      try {
        await _syncOne(document);
      } on TravelDocumentQuotaException {
        await _saveLocal(currentDocuments);
        rethrow;
      } catch (_) {
        // The local record doubles as the pending upload queue.
      }
      return document;
    } on Object {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<void> save(List<TravelDocument> documents) async {
    final previous = await _loadLocal();
    final currentIds = documents.map((item) => item.id).toSet();
    final removed = previous
        .where((item) => !currentIds.contains(item.id))
        .toList();
    if (removed.isNotEmpty && _client != null) {
      await _addPendingDeletes(removed);
    }
    await _saveLocal(documents);
    if (_client case final client?) {
      await _flushPendingDeletes(client);
    }
    for (final document in documents) {
      try {
        await _syncOne(document);
      } catch (_) {}
    }
  }

  Future<File> ensureLocalFile(TravelDocument document) async {
    final existing = File(document.storedPath);
    if (await existing.exists()) return existing;
    final client = _client;
    if (client == null || document.storagePath == null) {
      throw const FileSystemException(
        'The stored file is unavailable offline.',
      );
    }
    final bytes = await client.storage
        .from(storageBucket)
        .download(document.storagePath!);
    final directory = await _vaultDirectory();
    final name = document.storagePath!.split('/').last;
    final destination = File('${directory.path}${Platform.pathSeparator}$name');
    await destination.writeAsBytes(bytes, flush: true);
    final all = await _loadLocal();
    await _saveLocal([
      for (final item in all)
        item.id == document.id
            ? item.copyWith(storedPath: destination.path)
            : item,
    ]);
    return destination;
  }

  Future<void> delete(
    TravelDocument document,
    List<TravelDocument> remaining,
  ) => deleteMany([document], remaining);

  Future<void> deleteMany(
    List<TravelDocument> documents,
    List<TravelDocument> remaining,
  ) async {
    final failures = <TravelDocument>[];
    Object? firstError;
    for (final document in documents) {
      try {
        final file = File(document.storedPath);
        if (await file.exists()) await file.delete();
      } on Object catch (error) {
        failures.add(document);
        firstError ??= error;
      }
    }
    if (failures.isNotEmpty) {
      throw VaultFileDeleteException(failures, firstError);
    }
    await _saveLocal(remaining);
    final client = _client;
    if (client == null) return;
    await _addPendingDeletes(documents);
    for (final document in documents) {
      try {
        if (document.storagePath != null) {
          await client.storage.from(storageBucket).remove([
            document.storagePath!,
          ]);
        }
        await client
            .from('travel_documents')
            .delete()
            .eq('id', document.id)
            .eq('user_id', userId);
        await _removePendingDelete(document.id);
      } catch (_) {
        // Best effort while offline; all remote data remains private under RLS.
      }
    }
  }

  Future<List<TravelDocument>> _loadLocal() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final raw =
          preferences.getString(_metadataKey) ??
          preferences.getString(_legacyMetadataKey);
      final documents = TravelDocument.decodeList(raw);
      documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return documents;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(List<TravelDocument> documents) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _metadataKey,
      TravelDocument.encodeList(documents),
    );
    if (!saved) {
      throw const FileSystemException('Could not save vault metadata.');
    }
  }

  Future<void> _addPendingDeletes(List<TravelDocument> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _pendingDeletes(prefs);
    for (final document in documents) {
      pending[document.id] = document.storagePath;
    }
    await prefs.setString(_deletionsKey, jsonEncode(pending));
  }

  Future<void> _removePendingDelete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _pendingDeletes(prefs)..remove(id);
    await prefs.setString(_deletionsKey, jsonEncode(pending));
  }

  Map<String, String?> _pendingDeletes(SharedPreferences prefs) {
    try {
      final value = jsonDecode(prefs.getString(_deletionsKey) ?? '{}') as Map;
      return value.map((key, value) => MapEntry('$key', value as String?));
    } catch (_) {
      return {};
    }
  }

  Future<void> _flushPendingDeletes(SupabaseClient client) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _pendingDeletes(prefs);
    for (final entry in pending.entries.toList()) {
      try {
        if (entry.value != null) {
          await client.storage.from(storageBucket).remove([entry.value!]);
        }
        await client
            .from('travel_documents')
            .delete()
            .eq('id', entry.key)
            .eq('user_id', userId);
        pending.remove(entry.key);
      } catch (_) {}
    }
    await prefs.setString(_deletionsKey, jsonEncode(pending));
  }

  Future<bool?> _cloudQuotaAvailable(int fileSize) async {
    final client = _client;
    if (client == null) return null;
    try {
      final result = await client.rpc(
        'can_upload_travel_document',
        params: {'p_file_size': fileSize},
      );
      return result == true;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncOne(TravelDocument document) async {
    final client = _client;
    if (client == null) return;
    var storagePath = document.storagePath;
    if (storagePath == null || storagePath.isEmpty) {
      final name = document.extension.isEmpty
          ? document.id
          : '${document.id}.${document.extension}';
      storagePath = '$userId/${document.id}/$name';
    }
    final file = File(document.storedPath);
    final existing = await client
        .from('travel_documents')
        .select('id')
        .eq('id', document.id)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null && await file.exists()) {
      if (await _cloudQuotaAvailable(document.fileSize) == false) {
        throw const TravelDocumentQuotaException();
      }
      await client.storage
          .from(storageBucket)
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
    }
    try {
      await client.from('travel_documents').upsert({
        'id': document.id,
        'user_id': userId,
        'display_name': document.displayName,
        'category': document.category,
        'original_file_name': document.originalFileName,
        'storage_path': storagePath,
        'extension': document.extension,
        'file_size': document.fileSize,
        'created_at': document.createdAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      if (existing == null) {
        try {
          await client.storage.from(storageBucket).remove([storagePath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  TravelDocument _fromRemote(Map<String, dynamic> row) {
    final storagePath = '${row['storage_path']}';
    return TravelDocument(
      id: '${row['id']}',
      displayName: '${row['display_name']}',
      category: '${row['category']}',
      originalFileName: '${row['original_file_name']}',
      storedPath: storagePath.split('/').last,
      storagePath: storagePath,
      extension: '${row['extension'] ?? ''}',
      fileSize: (row['file_size'] as num).toInt(),
      createdAt: DateTime.parse('${row['created_at']}'),
    );
  }

  Future<Directory> _vaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}travel_vault'
      '${Platform.pathSeparator}$userId',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }
}

class TravelDocumentQuotaException implements Exception {
  const TravelDocumentQuotaException();

  @override
  String toString() =>
      'Free cloud storage limit reached. Remove a document before uploading another.';
}

class VaultFileDeleteException implements Exception {
  const VaultFileDeleteException(this.documents, this.cause);

  final List<TravelDocument> documents;
  final Object? cause;

  @override
  String toString() =>
      'Could not remove ${documents.length} stored file(s): $cause';
}
