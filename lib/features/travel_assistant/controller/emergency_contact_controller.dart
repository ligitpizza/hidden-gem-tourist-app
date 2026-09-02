import 'package:flutter/foundation.dart';

import '../model/emergency_contact.dart';
import '../model/emergency_contact_repository.dart';
import '../model/vault_pin_service.dart';

/// Owns emergency-contact persistence and vault access state.
class EmergencyContactController extends ChangeNotifier {
  EmergencyContactController({
    EmergencyContactRepository? repository,
    VaultPinService? pinService,
    bool initiallyUnlocked = false,
  }) : _repository = repository ?? EmergencyContactRepository(),
       _pinService = pinService ?? VaultPinService(),
       isUnlocked = initiallyUnlocked;

  final EmergencyContactRepository _repository;
  final VaultPinService _pinService;

  List<EmergencyContact> contacts = const [];
  bool isLoading = true;
  bool isUnlocked;
  bool hasPin = false;
  String? pinError;
  String searchQuery = '';

  List<EmergencyContact> get visibleContacts => contacts.where((contact) {
    if (!isUnlocked && !contact.availableWhenLocked) return false;
    final query = searchQuery.trim().toLowerCase();
    return query.isEmpty ||
        contact.name.toLowerCase().contains(query) ||
        contact.relationship.toLowerCase().contains(query) ||
        contact.phone.contains(query);
  }).toList();

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final values = await Future.wait([
      _repository.load(),
      _pinService.readPin(),
    ]);
    contacts = values[0] as List<EmergencyContact>;
    hasPin = values[1] != null;
    isLoading = false;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    if (pin != await _pinService.readPin()) {
      pinError = 'Incorrect vault PIN.';
      notifyListeners();
      return false;
    }
    isUnlocked = true;
    pinError = null;
    notifyListeners();
    return true;
  }

  void lock() {
    isUnlocked = false;
    searchQuery = '';
    notifyListeners();
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  Future<bool> saveContact(EmergencyContact value) async {
    final normalizedPhone = _digits(value.phone);
    final duplicate = contacts.any(
      (contact) =>
          contact.id != value.id && _digits(contact.phone) == normalizedPhone,
    );
    if (duplicate) return false;
    final updated = [...contacts];
    final index = updated.indexWhere((contact) => contact.id == value.id);
    if (index < 0) {
      updated.add(value);
    } else {
      updated[index] = value;
    }
    await _repository.save(updated);
    contacts = updated;
    notifyListeners();
    return true;
  }

  Future<void> deleteContact(EmergencyContact value) async {
    final updated = contacts.where((item) => item.id != value.id).toList();
    await _repository.save(updated);
    contacts = updated;
    notifyListeners();
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
