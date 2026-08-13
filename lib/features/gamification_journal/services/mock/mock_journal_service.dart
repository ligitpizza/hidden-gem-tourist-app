import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/check_in_model.dart';
import '../../model/journal_entry_model.dart';
import '../../model/journal_media_model.dart';

/// Journal entries are backed by the real `journal_entries` table (see
/// supabase/migrations/20260813120000_journal_real_activity_and_friends.sql)
/// — entry text/media/spending now survive an app restart instead of
/// living only in memory. Tests bypass Supabase entirely by passing
/// [seedEntries] — even an empty list — which switches this service to a
/// plain in-memory store instead, same pattern as the other Journal mock
/// services use for their own real-vs-test storage switch.
class MockJournalService {
  MockJournalService({List<JournalEntryModel>? seedEntries})
    // A defensive growable copy — callers (tests) may pass a `const []`,
    // which this service then needs to append to.
    : _entries = List.of(seedEntries ?? []),
      _useMockStorage = seedEntries != null;

  final List<JournalEntryModel> _entries;
  final bool _useMockStorage;
  int _idCounter = 0;

  Future<JournalEntryModel> createDraftFromCheckIn(CheckInModel checkIn) async {
    if (_useMockStorage) {
      await Future.delayed(const Duration(milliseconds: 300));
      final entry = JournalEntryModel(
        id: 'j${(_idCounter++).toString().padLeft(4, '0')}',
        userId: checkIn.userId,
        checkInId: checkIn.id,
        destinationId: checkIn.destinationId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _entries.add(entry);
      return entry;
    }

    final row = await Supabase.instance.client
        .from('journal_entries')
        .insert({
          'user_id': checkIn.userId,
          'check_in_id': checkIn.id,
          'destination_id': checkIn.destinationId,
        })
        .select()
        .single();
    return JournalEntryModel.fromJson(row);
  }

  Future<List<JournalEntryModel>> fetchEntries(String userId) async {
    if (_useMockStorage) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _entries.where((e) => e.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final rows = await Supabase.instance.client
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => JournalEntryModel.fromJson(r)).toList();
  }

  Future<JournalEntryModel?> fetchEntryById(String entryId) async {
    if (_useMockStorage) {
      await Future.delayed(const Duration(milliseconds: 150));
      try {
        return _entries.firstWhere((e) => e.id == entryId);
      } catch (_) {
        return null;
      }
    }
    final rows = await Supabase.instance.client
        .from('journal_entries')
        .select()
        .eq('id', entryId)
        .limit(1);
    return rows.isEmpty ? null : JournalEntryModel.fromJson(rows.first);
  }

  int _mediaIdCounter = 0;

  /// Maps a file extension to its real content type. Picked videos in
  /// particular vary a lot by device/source (.mov from iOS, .webm from some
  /// Android sources, .mp4 elsewhere) — previously every video was labeled
  /// 'video/mp4' regardless of its real container format, which made some
  /// players refuse to decode a file whose bytes didn't match the declared
  /// type ("Unable to Play Video"). Falls back to a generic octet-stream
  /// type for anything unrecognised rather than guessing wrong.
  static const _contentTypesByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'heic': 'image/heic',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
    'avi': 'video/x-msvideo',
    'mkv': 'video/x-matroska',
  };

  /// Uploads the picked file to the `journal-media` Supabase Storage bucket
  /// and attaches its public URL to the entry.
  Future<JournalEntryModel> addMedia(
    String entryId, {
    required String localFilePath,
    required JournalMediaType type,
  }) async {
    final current = await fetchEntryById(entryId);
    if (current == null) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    // Entry/media ids in mock mode are just in-memory counters that reset
    // to 0 every app restart, but the Storage bucket they upload into is
    // real and persists across restarts — a plain restart-scoped counter
    // would reuse the exact same path ('j0000/m0000.jpg') a previous
    // session already uploaded to, and Supabase rejects that as "already
    // exists". Stamping the id with wall-clock time (plus the counter, in
    // case two uploads land in the same microsecond) keeps every path
    // unique regardless of how many times the app has restarted.
    final mediaId = 'm${DateTime.now().microsecondsSinceEpoch}${(_mediaIdCounter++).toString().padLeft(3, '0')}';
    final extension = localFilePath.contains('.')
        ? localFilePath.split('.').last.toLowerCase()
        : (type == JournalMediaType.video ? 'mp4' : 'jpg');
    final storagePath = '$entryId/$mediaId.$extension';
    final contentType = _contentTypesByExtension[extension] ??
        (type == JournalMediaType.video ? 'video/mp4' : 'image/jpeg');

    final storage = Supabase.instance.client.storage.from('journal-media');
    try {
      await storage.uploadBinary(
        storagePath,
        await File(localFilePath).readAsBytes(),
        // upsert as a safety net — the timestamped id above should already
        // make collisions practically impossible, but overwriting is a
        // harmless fallback here (this bucket only ever holds mock-entry
        // media, not anything worth protecting from an overwrite) whereas
        // erroring out on a freak collision isn't.
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
    } on StorageException catch (e) {
      // The client already rejects anything over 200MB before it gets here
      // (see journal_detail_screen.dart), but this catches the case where
      // the project's actual bucket/global limit is lower than we assumed
      // (see the size-limit migrations' notes on the project-wide setting
      // SQL can't reach), so the Tourist still gets a real reason instead
      // of a generic failure.
      final isSizeError = e.statusCode == '413' ||
          e.message.toLowerCase().contains('exceed') ||
          e.message.toLowerCase().contains('maximum');
      throw Exception(
        isSizeError
            ? 'That file is too large for the server to accept. Try a shorter clip or a smaller file.'
            : 'Could not upload: ${e.message}',
      );
    }
    final publicUrl = storage.getPublicUrl(storagePath);

    final newMedia = JournalMediaModel(id: mediaId, url: publicUrl, type: type);

    final updated = current.copyWith(
      media: [...current.media, newMedia],
      updatedAt: DateTime.now(),
    );
    return _persist(updated);
  }

  Future<JournalEntryModel> removeMedia(String entryId, String mediaId) async {
    final current = await fetchEntryById(entryId);
    if (current == null) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    final updated = current.copyWith(
      media: current.media.where((m) => m.id != mediaId).toList(),
      updatedAt: DateTime.now(),
    );
    return _persist(updated);
  }

  Future<JournalEntryModel> updateEntry(
    String entryId, {
    String? notes,
    Map<LocalSupportOption, double>? spendingByCategory,
  }) async {
    final current = await fetchEntryById(entryId);
    if (current == null) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    final updated = current.copyWith(
      notes: notes,
      spendingByCategory: spendingByCategory,
      updatedAt: DateTime.now(),
    );
    return _persist(updated);
  }

  /// Writes a merged [JournalEntryModel] back to whichever store is active.
  Future<JournalEntryModel> _persist(JournalEntryModel entry) async {
    if (_useMockStorage) {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) _entries[index] = entry;
      return entry;
    }

    final row = await Supabase.instance.client
        .from('journal_entries')
        .update({
          'notes': entry.notes,
          'media': entry.media.map((m) => m.toJson()).toList(),
          'spending_by_category':
              entry.spendingByCategory.map((key, value) => MapEntry(key.name, value)),
          'updated_at': entry.updatedAt.toIso8601String(),
        })
        .eq('id', entry.id)
        .select()
        .single();
    return JournalEntryModel.fromJson(row);
  }

  Future<void> deleteEntry(String entryId) async {
    if (_useMockStorage) {
      await Future.delayed(const Duration(milliseconds: 200));
      _entries.removeWhere((e) => e.id == entryId);
      return;
    }
    await Supabase.instance.client.from('journal_entries').delete().eq('id', entryId);
  }
}
