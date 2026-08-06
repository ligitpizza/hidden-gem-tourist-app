import '../../model/check_in_model.dart';
import '../../model/journal_entry_model.dart';
import '../../model/journal_media_model.dart';

/// Phase 1 mock implementation of the digital travel journal.
///
/// createDraftFromCheckIn() stands in for the doc's "Automatically creates
/// a journal draft upon check-in" behaviour, which in Phase 2 happens in
/// the same Supabase transaction as the check-in itself.
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

  /// Simulates client-side compression/upload before the media lands in
  /// storage — mirrors the doc's flutter_image_compress step that keeps
  /// images under 500KB (videos pass through the same mock pipeline).
  Future<JournalEntryModel> addMedia(
    String entryId, {
    required String localFilePath,
    required JournalMediaType type,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw ArgumentError('Unknown journal entry: $entryId');
    }

    final mediaId = 'm${(_mediaIdCounter++).toString().padLeft(4, '0')}';
    final newMedia = JournalMediaModel(
      id: mediaId,
      // Stand-in for the real uploaded file — a seeded placeholder photo so
      // the carousel has something real to render instead of a blank box
      // (mirrors what compressAndUploadPhoto would return once wired to
      // real storage).
      url: 'https://picsum.photos/seed/journal-$mediaId/700/500',
      type: type,
    );

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
