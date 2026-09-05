import 'package:flutter/foundation.dart';

import '../model/emergency_contact.dart';
import '../model/emergency_contact_repository.dart';
import '../model/vault_pin_service.dart';

/// Owns emergency-contact persistence and vault access state.
class EmergencyContactController extends ChangeNotifier {
  EmergencyContactController({
    EmergencyContactRepository? repository,
    VaultPinServiceContract? pinService,
    bool initiallyUnlocked = false,
  }) : _repository = repository ?? EmergencyContactRepository(),
       _pinService = pinService ?? VaultPinService(),
       isUnlocked = initiallyUnlocked;

  final EmergencyContactRepository _repository;
  final VaultPinServiceContract _pinService;

  List<EmergencyContact> contacts = const [];
  bool isLoading = true;
  bool isUnlocked;
  bool hasPin = false;
  bool pinStatusUnavailable = false;
  int? pinLength;
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
      _pinService.loadStatus(),
    ]);
    contacts = values[0] as List<EmergencyContact>;
    final status = values[1] as VaultPinStatus;
    hasPin = status.hasPin;
    pinLength = status.pinLength;
    pinStatusUnavailable =
        status.availability == VaultPinAvailability.unavailable;
    isLoading = false;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    final result = await _pinService.verifyPin(pin);
    switch (result.status) {
      case VaultPinVerificationStatus.verified:
        isUnlocked = true;
        pinError = null;
        notifyListeners();
        return true;
      case VaultPinVerificationStatus.incorrect:
        final attempts = result.attemptsRemaining;
        pinError = attempts == null
            ? 'Incorrect vault PIN.'
            : 'Incorrect vault PIN. $attempts attempts remaining.';
        break;
      case VaultPinVerificationStatus.locked:
        final retry = result.retryAfter;
        final minutes = retry == null ? null : (retry.inSeconds / 60).ceil();
        pinError = retry == null
            ? 'Too many attempts. Try again later.'
            : 'Too many attempts. Try again in $minutes minutes.';
        break;
      case VaultPinVerificationStatus.unavailable:
        pinError = 'PIN verification is unavailable. Check your connection.';
        break;
      case VaultPinVerificationStatus.notConfigured:
        pinError = 'Create a Document Vault PIN first.';
        break;
    }
    notifyListeners();
    return false;
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
