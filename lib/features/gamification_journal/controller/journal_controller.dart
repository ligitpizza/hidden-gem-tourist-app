import 'package:flutter/foundation.dart';

import '../model/check_in_model.dart';
import '../model/journal_entry_model.dart';
import '../model/journal_media_model.dart';
import '../services/mock/mock_journal_service.dart';

enum JournalStatus { idle, loading, error }

class JournalController extends ChangeNotifier {
  JournalController({required this.userId, MockJournalService? service})
      : _service = service ?? MockJournalService();

  final String userId;
  final MockJournalService _service;

  List<JournalEntryModel> _entries = [];
  JournalStatus status = JournalStatus.idle;
  String? errorMessage;

  List<JournalEntryModel> get entries => _entries;

  Future<void> loadEntries() async {
    _entries = await _service.fetchEntries(userId);
    notifyListeners();
  }

  /// Call this immediately after CheckInController.checkIn() succeeds so
  /// the draft entry exists before the user opens the journal form.
  Future<JournalEntryModel> createFromCheckIn(CheckInModel checkIn) async {
    final entry = await _service.createDraftFromCheckIn(checkIn);
    _entries = [entry, ..._entries];
    notifyListeners();
    return entry;
  }

  Future<void> updateNotes(String entryId, String notes) async {
    await _updateEntry(entryId, notes: notes);
  }

  /// Saves notes and per-category spending together — used by the journal
  /// edit form's Save button so the user gets one round trip. Spending is
  /// fully optional; an empty map is a complete entry.
  Future<void> saveDetails(
    String entryId, {
    String? notes,
    Map<LocalSupportOption, double>? spendingByCategory,
  }) async {
    await _updateEntry(
      entryId,
      notes: notes,
      spendingByCategory: spendingByCategory,
    );
  }

  Future<void> addMedia(
    String entryId, {
    required String localFilePath,
    required JournalMediaType type,
  }) async {
    status = JournalStatus.loading;
    notifyListeners();

    try {
      final updated = await _service.addMedia(
        entryId,
        localFilePath: localFilePath,
        type: type,
      );
      _replaceEntry(updated);
      status = JournalStatus.idle;
    } catch (_) {
      status = JournalStatus.error;
      errorMessage = 'Could not attach media. Please try again.';
    }
    notifyListeners();
  }

  Future<void> removeMedia(String entryId, String mediaId) async {
    final updated = await _service.removeMedia(entryId, mediaId);
    _replaceEntry(updated);
    notifyListeners();
  }

  Future<void> deleteEntry(String entryId) async {
    await _service.deleteEntry(entryId);
    _entries = _entries.where((e) => e.id != entryId).toList();
    notifyListeners();
  }

  Future<void> _updateEntry(
    String entryId, {
    String? notes,
    Map<LocalSupportOption, double>? spendingByCategory,
  }) async {
    final updated = await _service.updateEntry(
      entryId,
      notes: notes,
      spendingByCategory: spendingByCategory,
    );
    _replaceEntry(updated);
    notifyListeners();
  }

  void _replaceEntry(JournalEntryModel updated) {
    final index = _entries.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _entries[index] = updated;
    }
  }
}
