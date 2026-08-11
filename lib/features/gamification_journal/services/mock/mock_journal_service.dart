import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/check_in_model.dart';
import '../../model/journal_entry_model.dart';
import '../../model/journal_media_model.dart';

/// Phase 1 mock implementation of the digital travel journal.
///
/// createDraftFromCheckIn() stands in for the doc's "Automatically creates
/// a journal draft upon check-in" behaviour, which in Phase 2 happens in
/// the same Supabase transaction as the check-in itself. Journal entries
/// themselves stay in-memory for now, but addMedia() below already uploads
/// for real — media is the one piece of this module backed by real
/// Supabase Storage rather than mock data.
class MockJournalService {
  final List<JournalEntryModel> _entries = [];
  int _idCounter = 0;

  Future<JournalEntryModel> createDraftFromCheckIn(CheckInModel checkIn) async {
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

  Future<List<JournalEntryModel>> fetchEntries(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _entries.where((e) => e.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<JournalEntryModel?> fetchEntryById(String entryId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _entries.firstWhere((e) => e.id == entryId);
    } catch (_) {
      return null;
    }
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
  /// and attaches its public URL to the entry. The journal entry itself
  /// stays in-memory (see class doc), but the media file this points to is
  /// real.
  Future<JournalEntryModel> addMedia(
    String entryId, {
    required String localFilePath,
    required JournalMediaType type,
  }) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    // Entry/media ids are just in-memory counters that reset to 0 every
    // app restart, but the Storage bucket they upload into is real and
    // persists across restarts — a plain restart-scoped counter would
    // reuse the exact same path ('j0000/m0000.jpg') a previous session
    // already uploaded to, and Supabase rejects that as "already exists".
    // Stamping the id with wall-clock time (plus the counter, in case two
    // uploads land in the same microsecond) keeps every path unique
    // regardless of how many times the app has restarted.
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

    final updated = _entries[index].copyWith(
      media: [..._entries[index].media, newMedia],
      updatedAt: DateTime.now(),
    );
    _entries[index] = updated;
    return updated;
  }

  Future<JournalEntryModel> removeMedia(String entryId, String mediaId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    final updated = _entries[index].copyWith(
      media: _entries[index].media.where((m) => m.id != mediaId).toList(),
      updatedAt: DateTime.now(),
    );
    _entries[index] = updated;
    return updated;
  }

  Future<JournalEntryModel> updateEntry(
    String entryId, {
    String? notes,
    Map<LocalSupportOption, double>? spendingByCategory,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    final updated = _entries[index].copyWith(
      notes: notes,
      spendingByCategory: spendingByCategory,
      updatedAt: DateTime.now(),
    );

    _entries[index] = updated;
    return updated;
  }

  Future<void> deleteEntry(String entryId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _entries.removeWhere((e) => e.id == entryId);
  }
}
