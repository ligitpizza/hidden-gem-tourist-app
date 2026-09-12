import 'package:flutter/foundation.dart';

import 'eco_partner.dart';
import 'saved_eco_partner.dart';
import 'saved_eco_partner_repository.dart';

class SavedEcoPartnersStore extends ChangeNotifier {
  SavedEcoPartnersStore({SavedEcoPartnerRepositoryContract? repository})
    : _repository = repository;

  static final SavedEcoPartnersStore instance = SavedEcoPartnersStore();

  SavedEcoPartnerRepositoryContract? _repository;
  SavedEcoPartnerRepositoryContract get _activeRepository {
    // Also upgrades a repository retained by Flutter hot reload from the
    // original implementation, so tapping Retry immediately gets fallback
    // support without requiring users to clear app data.
    if (_repository == null || _repository is SavedEcoPartnerRepository) {
      _repository = ResilientSavedEcoPartnerRepository();
    }
    return _repository!;
  }

  List<SavedEcoPartner> _saved = [];
  bool isLoading = false;
  String? error;
  bool _loadedOnce = false;
  String? _userScope;
  int _accountRevision = 0;
  final Set<String> _busyPartnerIds = {};

  List<SavedEcoPartner> get saved => List.unmodifiable(_saved);
  bool isSaved(String partnerId) =>
      _saved.any((saved) => saved.partner.id == partnerId);
  bool isBusy(String partnerId) => _busyPartnerIds.contains(partnerId);

  /// Clears all in-memory state when authentication moves to another user.
  ///
  /// The app root rebuilds its authenticated subtree immediately after this
  /// call, so listeners do not need a separate notification. The revision
  /// also prevents an older user's pending request from restoring their data.
  void scopeToUser(String? userId) {
    final nextScope = userId ?? 'guest';
    if (_userScope == nextScope) return;
    _userScope = nextScope;
    _accountRevision++;
    _saved = [];
    isLoading = false;
    error = null;
    _loadedOnce = false;
    _busyPartnerIds.clear();
  }

  Future<void> ensureLoaded() async {
    if (_loadedOnce || isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    final revision = _accountRevision;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final saved = await _activeRepository.fetchAll();
      if (revision != _accountRevision) return;
      _saved = saved;
      _loadedOnce = true;
    } catch (_) {
      if (revision != _accountRevision) return;
      error = 'Could not load your saved Eco Partners. Please retry.';
    }
    if (revision != _accountRevision) return;
    isLoading = false;
    notifyListeners();
  }

  Future<bool> toggle(EcoPartner partner) async {
    if (isBusy(partner.id)) return isSaved(partner.id);
    final revision = _accountRevision;
    _busyPartnerIds.add(partner.id);
    error = null;
    notifyListeners();
    try {
      final existing = _saved
          .where((saved) => saved.partner.id == partner.id)
          .firstOrNull;
      if (existing != null) {
        await _activeRepository.delete(existing.id);
        if (revision != _accountRevision) return isSaved(partner.id);
        _saved = _saved.where((saved) => saved.id != existing.id).toList();
      } else {
        final saved = await _activeRepository.save(partner);
        if (revision != _accountRevision) return isSaved(partner.id);
        _saved = [saved, ..._saved];
      }
      _loadedOnce = true;
    } catch (_) {
      if (revision != _accountRevision) return isSaved(partner.id);
      error = 'Could not update this saved Eco Partner. Please retry.';
    } finally {
      if (revision == _accountRevision) {
        _busyPartnerIds.remove(partner.id);
        notifyListeners();
      }
    }
    return isSaved(partner.id);
  }

  Future<void> remove(String id) async {
    final revision = _accountRevision;
    final previous = _saved;
    _saved = _saved.where((saved) => saved.id != id).toList();
    notifyListeners();
    try {
      await _activeRepository.delete(id);
    } catch (_) {
      if (revision != _accountRevision) return;
      _saved = previous;
      error = 'Could not remove this Eco Partner. Please retry.';
      notifyListeners();
    }
  }
}
