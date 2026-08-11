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

    final mediaId = 'm${(_mediaIdCounter++).toString().padLeft(4, '0')}';
    final extension = localFilePath.contains('.') ? localFilePath.split('.').last : (type == JournalMediaType.video ? 'mp4' : 'jpg');
    final storagePath = '$entryId/$mediaId.$extension';

    final storage = Supabase.instance.client.storage.from('journal-media');
    await storage.uploadBinary(
      storagePath,
      await File(localFilePath).readAsBytes(),
      fileOptions: FileOptions(
        contentType: type == JournalMediaType.video ? 'video/mp4' : 'image/jpeg',
      ),
    );
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
