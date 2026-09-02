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
  final Set<String> _busyPartnerIds = {};

  List<SavedEcoPartner> get saved => List.unmodifiable(_saved);
  bool isSaved(String partnerId) =>
      _saved.any((saved) => saved.partner.id == partnerId);
  bool isBusy(String partnerId) => _busyPartnerIds.contains(partnerId);

  Future<void> ensureLoaded() async {
    if (_loadedOnce || isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      _saved = await _activeRepository.fetchAll();
      _loadedOnce = true;
    } catch (_) {
      error = 'Could not load your saved Eco Partners. Please retry.';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> toggle(EcoPartner partner) async {
    if (isBusy(partner.id)) return isSaved(partner.id);
    _busyPartnerIds.add(partner.id);
    error = null;
    notifyListeners();
    try {
      final existing = _saved
          .where((saved) => saved.partner.id == partner.id)
          .firstOrNull;
      if (existing != null) {
        await _activeRepository.delete(existing.id);
        _saved = _saved.where((saved) => saved.id != existing.id).toList();
      } else {
        final saved = await _activeRepository.save(partner);
        _saved = [saved, ..._saved];
      }
      _loadedOnce = true;
    } catch (_) {
      error = 'Could not update this saved Eco Partner. Please retry.';
    } finally {
      _busyPartnerIds.remove(partner.id);
      notifyListeners();
    }
    return isSaved(partner.id);
  }

  Future<void> remove(String id) async {
    final previous = _saved;
    _saved = _saved.where((saved) => saved.id != id).toList();
    notifyListeners();
    try {
      await _activeRepository.delete(id);
    } catch (_) {
      _saved = previous;
      error = 'Could not remove this Eco Partner. Please retry.';
      notifyListeners();
    }
  }
}
