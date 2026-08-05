import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/emergency_contact.dart';
import '../model/emergency_contact_repository.dart';
import '../model/vault_pin_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key, this.initiallyUnlocked = false});
  final bool initiallyUnlocked;
  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _repository = EmergencyContactRepository();
  final _pinService = VaultPinService();
  final _pin = TextEditingController();
  final _search = TextEditingController();
  List<EmergencyContact> _contacts = const [];
  bool _loading = true;
  bool _unlocked = false;
  bool _hasPin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unlocked = widget.initiallyUnlocked;
    _load();
  }

  @override
  void dispose() {
    _pin.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _repository.load(),
      _pinService.readPin(),
    ]);
    if (!mounted) return;
    setState(() {
      _contacts = values[0] as List<EmergencyContact>;
      _hasPin = values[1] != null;
      _loading = false;
    });
  }

  Future<void> _unlock() async {
    if (_pin.text != await _pinService.readPin()) {
      setState(() {
        _error = 'Incorrect vault PIN.';
        _pin.clear();
      });
      return;
    }
    setState(() {
      _unlocked = true;
      _error = null;
      _pin.clear();
    });
  }

  Future<void> _save() => _repository.save(_contacts);

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _contacts.where((contact) {
      if (!_unlocked && !contact.availableWhenLocked) return false;
      return query.isEmpty ||
          contact.name.toLowerCase().contains(query) ||
          contact.relationship.toLowerCase().contains(query) ||
          contact.phone.contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          if (_unlocked)
            IconButton(
              tooltip: 'Lock',
              onPressed: () => setState(() => _unlocked = false),
              icon: const Icon(Icons.lock_outline),
            ),
        ],
      ),
      floatingActionButton: _unlocked
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add contact'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Card(
                  color: _unlocked
                      ? const Color(0xFFE5F4EC)
                      : const Color(0xFFFFF5D6),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _unlocked
                        ? const Row(
                            children: [
                              Icon(Icons.lock_open, color: Color(0xFF07513C)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vault unlocked. All contact details are available.',
                                ),
                              ),
                            ],
                          )
                        : _lockedHeader(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_unlocked)
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search contacts...',
                    ),
                  ),
                if (_unlocked) const SizedBox(height: 12),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 42),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.contact_emergency_outlined,
                          size: 52,
                          color: Color(0xFF557067),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _unlocked
                              ? 'No emergency contacts saved yet.'
                              : 'No contacts are available while the vault is locked.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final contact in visible) _contactCard(contact),
              ],
            ),
    );
  }

  Widget _lockedHeader() {
    if (!_hasPin)
      return const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create a Document Vault PIN before adding emergency contacts.',
            ),
          ),
        ],
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Locked contacts expose only the name, relationship and phone number.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _unlock(),
          decoration: InputDecoration(
            labelText: 'Vault PIN',
            errorText: _error,
            counterText: '',
            suffixIcon: IconButton(
              onPressed: _unlock,
              icon: const Icon(Icons.lock_open),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactCard(EmergencyContact contact) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Text(contact.name.isEmpty ? '?' : contact.name[0].toUpperCase()),
      ),
      title: Text(contact.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              contact.relationship,
              contact.country,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
          Text(contact.phone),
          if (_unlocked && contact.email.isNotEmpty) Text(contact.email),
          if (_unlocked && contact.notes.isNotEmpty)
            Text(contact.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (!_unlocked)
            const Text(
              'Available while locked',
              style: TextStyle(fontSize: 11, color: Color(0xFF07513C)),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Call',
            onPressed: () => _launch('tel:${contact.phone}'),
            icon: const Icon(Icons.call, color: Color(0xFF07513C)),
          ),
          IconButton(
            tooltip: 'Open WhatsApp, then tap its call button',
            onPressed: () => _openWhatsApp(contact),
            icon: const Icon(Icons.chat_outlined, color: Color(0xFF168A4A)),
          ),
          if (_unlocked)
            PopupMenuButton<String>(
              onSelected: (value) =>
                  value == 'edit' ? _edit(contact) : _delete(contact),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    ),
  );

  Future<void> _launch(String value) async {
    if (!await launchUrl(Uri.parse(value))) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No calling application is available.')),
        );
    }
  }

  Future<void> _openWhatsApp(EmergencyContact contact) async {
    final internationalNumber = contact.phone.replaceAll(RegExp(r'\D'), '');
    if (internationalNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This contact does not have a valid WhatsApp number.',
            ),
          ),
        );
      }
      return;
    }
    final opened = await launchUrl(
      Uri.https('wa.me', '/$internationalNumber'),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp could not be opened on this device.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('In WhatsApp, tap the phone icon to start the call.'),
      ),
    );
  }

  Future<void> _edit([EmergencyContact? existing]) async {
    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => _ContactDialog(existing: existing),
    );
    if (!mounted || result == null) return;
    final normalizedPhone = _digits(result.phone);
    final duplicate = _contacts.any(
      (contact) =>
          contact.id != result.id && _digits(contact.phone) == normalizedPhone,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A contact with this phone number already exists.'),
        ),
      );
      return;
    }
    setState(() {
      final index = _contacts.indexWhere((contact) => contact.id == result.id);
      _contacts = [..._contacts];
      if (index < 0) {
        _contacts.add(result);
      } else {
        _contacts[index] = result;
      }
    });
    await _save();
  }

  Future<void> _delete(EmergencyContact contact) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete emergency contact?'),
            content: Text('Remove ${contact.name} from this device?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    setState(
      () =>
          _contacts = _contacts.where((item) => item.id != contact.id).toList(),
    );
    await _save();
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.existing});
  final EmergencyContact? existing;
  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _relationship, _phone, _email, _notes;
  late Country _country;
  late bool _available;
  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    final countries = CountryService();
    _country =
        countries.findByName(value?.country) ?? countries.findByCode('MY')!;
    _name = TextEditingController(text: value?.name);
    _relationship = TextEditingController(text: value?.relationship);
    _phone = TextEditingController(
      text: value?.phone ?? '+${_country.phoneCode} ',
    );
    _email = TextEditingController(text: value?.email);
    _notes = TextEditingController(text: value?.notes);
    _available = value?.availableWhenLocked ?? false;
  }

  @override
  void dispose() {
    for (final controller in [_name, _relationship, _phone, _email, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null
          ? 'Add emergency contact'
          : 'Edit emergency contact',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_name, 'Name', validator: _validateName, maxLength: 80),
            _field(
              _relationship,
              'Relationship',
              validator: (value) =>
                  _requiredLength(value, 'Relationship', 2, 50),
              maxLength: 50,
            ),
            _countryPicker(),
            _field(
              _phone,
              'Phone number',
              validator: _validatePhone,
              keyboard: TextInputType.phone,
              maxLength: 24,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
              ],
            ),
            _field(
              _email,
              'Email (optional)',
              validator: _validateEmail,
              keyboard: TextInputType.emailAddress,
              maxLength: 120,
            ),
            _field(
              _notes,
              'Notes (optional)',
              validator: (value) => value != null && value.trim().length > 500
                  ? 'Notes cannot exceed 500 characters.'
                  : null,
              lines: 3,
              maxLength: 500,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available while locked'),
              subtitle: const Text(
                'Only name, relationship and phone will be exposed.',
              ),
              value: _available,
              onChanged: (value) => setState(() => _available = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );

  Widget _countryPicker() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showCountryPicker(
        context: context,
        showPhoneCode: true,
        favorite: const ['MY', 'SG', 'ID', 'TH', 'BN'],
        countryListTheme: const CountryListThemeData(bottomSheetHeight: 560),
        onSelect: _selectCountry,
      ),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Country',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          '${_country.flagEmoji}  ${_country.name}  (+${_country.phoneCode})',
        ),
      ),
    ),
  );

  void _selectCountry(Country country) {
    final previousPrefix = '+${_country.phoneCode}';
    final nextPrefix = '+${country.phoneCode}';
    final current = _phone.text.trim();
    var localNumber = current;
    if (current.startsWith(previousPrefix)) {
      localNumber = current.substring(previousPrefix.length).trimLeft();
    } else if (current == previousPrefix || current.isEmpty) {
      localNumber = '';
    }
    setState(() {
      _country = country;
      _phone.text = '$nextPrefix${localNumber.isEmpty ? ' ' : ' $localNumber'}';
      _phone.selection = TextSelection.collapsed(offset: _phone.text.length);
    });
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int lines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: lines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    ),
  );

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required.';
    if (text.length < 2) return 'Name must contain at least 2 characters.';
    if (RegExp(r'^\d+$').hasMatch(text))
      return 'Name cannot contain only numbers.';
    return null;
  }

  String? _requiredLength(
    String? value,
    String label,
    int minimum,
    int maximum,
  ) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length < minimum)
      return '$label must contain at least $minimum characters.';
    if (text.length > maximum)
      return '$label cannot exceed $maximum characters.';
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required.';
    final requiredPrefix = '+${_country.phoneCode}';
    if (!text.startsWith(requiredPrefix)) {
      return 'Phone number must start with $requiredPrefix for ${_country.name}.';
    }
    if (text.indexOf('+') > 0 || '+'.allMatches(text).length > 1) {
      return 'The + symbol is only allowed at the beginning.';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number containing 7 to 15 digits.';
    }
    if (RegExp(r'^0+$').hasMatch(digits)) return 'Enter a valid phone number.';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      EmergencyContact(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        relationship: _relationship.text.trim(),
        phone: _phone.text.trim(),
        country: _country.name,
        email: _email.text.trim(),
        notes: _notes.text.trim(),
        availableWhenLocked: _available,
      ),
    );
  }
}
