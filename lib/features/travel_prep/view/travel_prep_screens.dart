import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/router/shell_routes.dart';
import '../model/travel_document.dart';
import '../model/travel_document_repository.dart';
import 'travel_document_viewer_screen.dart';

class TravelPrepDashboardScreen extends StatelessWidget {
  const TravelPrepDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _TravelAssistantAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            height: 235,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF315E48), Color(0xFF0D3528)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacer(),
                Text(
                  'NEXT TRIP',
                  style: TextStyle(color: Colors.white70, letterSpacing: 2),
                ),
                Text(
                  'Emerald\nFalls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    Text(
                      'Readiness Score',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Spacer(),
                    Text(
                      '85% Ready',
                      style: TextStyle(color: Color(0xFFFFE5A5)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: .85,
                  color: Color(0xFFFFD98B),
                  backgroundColor: Colors.white24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DashboardCard(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Smart Packing & Checklist',
            description:
                'Personalized list based on Emerald Falls weather and activities.',
            button: 'Open Checklist',
            progress: .65,
            onTap: () => context.push(ShellRoutes.checklist),
          ),
          _DashboardCard(
            icon: Icons.eco_outlined,
            title: 'Eco Recommendations',
            description:
                'Sustainable stays, local dining and low-impact transport partners.',
            button: 'Browse Eco Partners',
            onTap: () => context.push(ShellRoutes.ecoPartners),
          ),
          _DashboardCard(
            icon: Icons.folder_copy_outlined,
            title: 'Document Vault',
            description: '6 documents stored securely for your next journey.',
            button: 'Manage Documents',
            onTap: () => context.push(ShellRoutes.documentVault),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.button,
    required this.onTap,
    this.progress,
  });
  final IconData icon;
  final String title;
  final String description;
  final String button;
  final VoidCallback onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Progress'),
                  const Spacer(),
                  Text('${(progress! * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
            ],
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onTap, child: Text(button)),
          ],
        ),
      ),
    );
  }
}

class ReadyToWanderScreen extends StatefulWidget {
  const ReadyToWanderScreen({super.key});

  @override
  State<ReadyToWanderScreen> createState() => _ReadyToWanderScreenState();
}

class _ReadyToWanderScreenState extends State<ReadyToWanderScreen> {
  final List<_ChecklistCategory> categories = [
    _ChecklistCategory(
      'Tech & Gear',
      'Adapters, cameras, power bank',
      7,
      8,
      Icons.devices_outlined,
    ),
    _ChecklistCategory(
      'Clothing',
      'Outfits, outerwear, footwear',
      19,
      22,
      Icons.checkroom_outlined,
    ),
    _ChecklistCategory(
      'Documents',
      'Passport, tickets and bookings',
      5,
      6,
      Icons.description_outlined,
    ),
    _ChecklistCategory(
      'Personal Belongings',
      'Sunscreen, toiletries and cash',
      8,
      10,
      Icons.backpack_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final packed = categories.fold<int>(0, (sum, item) => sum + item.packed);
    final total = categories.fold<int>(0, (sum, item) => sum + item.total);
    final score = ((packed / total) * 100).round();
    return Scaffold(
      appBar: const _TravelAssistantAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Ready to Wander',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF003B2B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your preparation for Penang Hidden Gems is nearly complete.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'READINESS SCORE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFF8A6800),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 4,
                            backgroundColor: Colors.black12,
                            color: const Color(0xFF2DBD60),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$score%',
                              style: const TextStyle(
                                fontSize: 52,
                                color: Color(0xFF003B2B),
                              ),
                            ),
                            const Text(
                              'OPTIMAL STATUS',
                              style: TextStyle(fontSize: 11, letterSpacing: .5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ReadinessMetric(
                        Icons.wb_sunny_outlined,
                        'Weather',
                        '92%',
                      ),
                      _ReadinessMetric(
                        Icons.medical_services_outlined,
                        'Health',
                        '78%',
                      ),
                      _ReadinessMetric(
                        Icons.directions_bus_outlined,
                        'Transit',
                        '85%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Packing Checklist',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const Text(
            'Recommended',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003B2B),
            ),
          ),
          const SizedBox(height: 8),
          for (final category in categories)
            _ChecklistCard(
              category: category,
              onChanged: (value) =>
                  setState(() => category.packed = value.round()),
            ),
        ],
      ),
    );
  }

  void _addItem() {
    setState(
      () => categories.add(
        _ChecklistCategory(
          'Custom Item',
          'Tap progress to mark packed',
          0,
          1,
          Icons.add_box_outlined,
        ),
      ),
    );
  }
}

class _ReadinessMetric extends StatelessWidget {
  const _ReadinessMetric(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon),
      Text(label),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _ChecklistCategory {
  _ChecklistCategory(
    this.name,
    this.subtitle,
    this.packed,
    this.total,
    this.icon,
  );
  final String name;
  final String subtitle;
  int packed;
  final int total;
  final IconData icon;
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.category, required this.onChanged});
  final _ChecklistCategory category;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(
        category.packed == category.total ? 0 : category.packed + 1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8ECE9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(category.icon, color: const Color(0xFF0B4B38)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF164C3B),
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text('${category.packed}/${category.total}'),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: category.packed / category.total,
                minHeight: 5,
                color: const Color(0xFF0C4A37),
                backgroundColor: const Color(0xFFE2E2DF),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    category.packed == category.total
                        ? 'Complete'
                        : category.packed == 0
                        ? 'Next: ${category.subtitle.split(',').first}'
                        : '${category.total - category.packed} items remaining',
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class EcoPartnersScreen extends StatefulWidget {
  const EcoPartnersScreen({super.key});
  @override
  State<EcoPartnersScreen> createState() => _EcoPartnersScreenState();
}

class _EcoPartnersScreenState extends State<EcoPartnersScreen> {
  String filter = 'All';
  final partners = const [
    _Partner(
      'Cascading Canopy Eco-Lodge',
      'Stay',
      'Costa Island',
      'GSTC certified • 4.9 rating',
      Icons.hotel_outlined,
    ),
    _Partner(
      "The Forager's Table",
      'Dining',
      'London, UK',
      'Vegan • Farm-to-table dining',
      Icons.restaurant_outlined,
    ),
    _Partner(
      'VoltPath Expeditions',
      'Transport',
      'Norway',
      'Carbon-neutral transport',
      Icons.directions_bus_outlined,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final shown = filter == 'All'
        ? partners
        : partners.where((item) => item.type == filter).toList();
    return Scaffold(
      appBar: const _TravelAssistantAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Eco-Partner\nRecommendations',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: const Color(0xFF003B2B),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Discover curated sustainable experiences and services that align with your travel ethos.',
          ),
          const SizedBox(height: 18),
          const TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by destination or partner name...',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['All', 'Stay', 'Dining', 'Transport']
                .map(
                  (item) => ChoiceChip(
                    label: Text(item),
                    selected: filter == item,
                    onSelected: (_) => setState(() => filter = item),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < shown.length; index++)
            _EcoPartnerCard(
              partner: shown[index],
              featured: filter == 'All' && index == 0,
              onDetails: () => _details(shown[index]),
            ),
        ],
      ),
    );
  }

  void _details(_Partner partner) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(partner.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(partner.details),
          const SizedBox(height: 12),
          const Text(
            'This partner was matched using sustainability credentials, service category and destination relevance.',
          ),
        ],
      ),
    ),
  );
}

class _Partner {
  const _Partner(this.name, this.type, this.location, this.details, this.icon);
  final String name;
  final String type;
  final String location;
  final String details;
  final IconData icon;
}

class _EcoPartnerCard extends StatelessWidget {
  const _EcoPartnerCard({
    required this.partner,
    required this.featured,
    required this.onDetails,
  });
  final _Partner partner;
  final bool featured;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    if (featured) {
      return Container(
        height: 192,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF91B69E), Color(0xFF0C4837)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.bookmark_border, color: Colors.white),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD34E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'TOP RATED STAY',
                style: TextStyle(fontSize: 11, color: Color(0xFF665000)),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              partner.name,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              '${partner.location}  •  ★ 4.9 (124 reviews)',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 145,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD7C9A7), Color(0xFF466D5C)],
                ),
              ),
              child: Center(
                child: Icon(partner.icon, size: 54, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    partner.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF164C3B),
                    ),
                  ),
                ),
                Icon(partner.icon, color: const Color(0xFF8A6800)),
              ],
            ),
            const SizedBox(height: 5),
            Text(partner.details),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${partner.type} • ${partner.location}',
                    style: const TextStyle(color: Color(0xFF8A6800)),
                  ),
                ),
                TextButton(
                  onPressed: onDetails,
                  child: const Text('Details →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  static const _pinKey = 'travel_vault_pin';
  final _storage = const FlutterSecureStorage();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _loading = true;
  bool _hasPin = false;
  bool _unlocked = false;
  bool _hidePin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final savedPin = await _storage.read(key: _pinKey);
    if (!mounted) return;
    setState(() {
      _hasPin = savedPin != null;
      _loading = false;
    });
  }

  Future<void> _submitPin() async {
    FocusScope.of(context).unfocus();
    final pin = _pinController.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a PIN containing 4 to 6 digits.');
      return;
    }

    if (_hasPin) {
      final savedPin = await _storage.read(key: _pinKey);
      if (!mounted) return;
      if (pin != savedPin) {
        setState(() {
          _error = 'Incorrect PIN. Please try again.';
          _pinController.clear();
        });
        return;
      }
    } else {
      if (pin != _confirmPinController.text) {
        setState(() => _error = 'The PINs do not match.');
        return;
      }
      await _storage.write(key: _pinKey, value: pin);
      if (!mounted) return;
    }

    setState(() {
      _hasPin = true;
      _unlocked = true;
      _error = null;
      _pinController.clear();
      _confirmPinController.clear();
    });
  }

  void _lockVault() {
    setState(() {
      _unlocked = false;
      _error = null;
      _pinController.clear();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _TravelAssistantAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_unlocked) return _UnlockedDocumentVault(onLock: _lockVault);

    return Scaffold(
      appBar: const _TravelAssistantAppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE1EEE8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 42,
                      color: Color(0xFF07513C),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _hasPin ? 'Unlock Document Vault' : 'Create Your Vault PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF003B2B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasPin
                        ? 'Enter your PIN to securely access your travel documents.'
                        : 'Choose a 4 to 6 digit PIN to protect your travel documents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    obscureText: _hidePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: _hasPin
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: _hasPin ? (_) => _submitPin() : null,
                    decoration: InputDecoration(
                      labelText: _hasPin ? 'Vault PIN' : 'Create PIN',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      counterText: '',
                      errorText: _error,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hidePin = !_hidePin),
                        icon: Icon(
                          _hidePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (!_hasPin) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPinController,
                      obscureText: _hidePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitPin(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        counterText: '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _submitPin,
                    icon: Icon(
                      _hasPin
                          ? Icons.lock_open_outlined
                          : Icons.shield_outlined,
                    ),
                    label: Text(
                      _hasPin ? 'Unlock Vault' : 'Create PIN & Continue',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security, size: 16, color: Color(0xFF557067)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Your PIN is stored securely on this device.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF557067),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockedDocumentVault extends StatefulWidget {
  const _UnlockedDocumentVault({required this.onLock});
  final VoidCallback onLock;

  @override
  State<_UnlockedDocumentVault> createState() => _UnlockedDocumentVaultState();
}

class _UnlockedDocumentVaultState extends State<_UnlockedDocumentVault> {
  final _repository = TravelDocumentRepository();
  final _searchController = TextEditingController();
  bool offlineMode = false;
  String filter = 'All';
  bool _loadingDocuments = true;
  bool _busy = false;
  String _query = '';
  String? _selectedId;
  List<TravelDocument> documents = [];

  TravelDocument? get _selectedDocument {
    for (final document in documents) {
      if (document.id == _selectedId) return document;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final loaded = await _repository.load();
    if (!mounted) return;
    setState(() {
      documents = loaded;
      _loadingDocuments = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final shown = documents.where((document) {
      final matchesCategory = filter == 'All' || document.category == filter;
      final matchesSearch =
          normalizedQuery.isEmpty ||
          document.displayName.toLowerCase().contains(normalizedQuery) ||
          document.originalFileName.toLowerCase().contains(normalizedQuery) ||
          document.category.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesSearch;
    }).toList();
    final categories = <String>{
      'All',
      'Passports',
      'Bookings',
      'Insurance',
      ...documents.map((item) => item.category),
    };

    return Scaffold(
      appBar: _TravelAssistantAppBar(onLock: widget.onLock),
      bottomNavigationBar: _VaultActionBar(
        hasSelection: _selectedDocument != null,
        busy: _busy,
        onEdit: _editSelected,
        onDelete: _deleteSelected,
        onUpload: _uploadDocument,
      ),
      body: _loadingDocuments
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  'Document Vault',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF003B2B),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Securely manage and access your essential travel credentials.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search documents...',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    value: offlineMode,
                    onChanged: (value) => setState(() => offlineMode = value),
                    title: const Text(
                      'Offline Travel Mode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Documents are available without mobile data',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(item),
                              selected: filter == item,
                              onSelected: (_) => setState(() => filter = item),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  _VaultEmptyState(
                    hasDocuments: documents.isNotEmpty,
                    hasFilter: _query.isNotEmpty || filter != 'All',
                  )
                else
                  for (final document in shown)
                    _DocumentCard(
                      document: document,
                      selected: document.id == _selectedId,
                      onSelect: () => setState(
                        () => _selectedId = document.id == _selectedId
                            ? null
                            : document.id,
                      ),
                      onView: () => _viewDocument(document),
                    ),
              ],
            ),
    );
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || !mounted) return;
    final picked = result.files.single;
    if (picked.path == null) {
      _showMessage('This file could not be accessed on your device.');
      return;
    }
    final initialName = _nameWithoutExtension(picked.name);
    final form = await _showDocumentForm(
      title: 'Add Document',
      initialName: initialName,
      initialCategory: 'Bookings',
    );
    if (form == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final imported = await _repository.importFile(
        sourcePath: picked.path!,
        originalFileName: picked.name,
        displayName: form.name,
        category: form.category,
        currentDocuments: documents,
      );
      if (!mounted) return;
      setState(() {
        documents = [imported, ...documents];
        _selectedId = imported.id;
      });
      _showMessage('${imported.displayName} was added to the vault.');
    } on Object catch (error) {
      if (mounted) _showMessage('Upload failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSelected() async {
    final selected = _selectedDocument;
    if (selected == null) return;
    final form = await _showDocumentForm(
      title: 'Edit Document',
      initialName: selected.displayName,
      initialCategory: selected.category,
    );
    if (form == null || !mounted) return;
    final updated = selected.copyWith(
      displayName: form.name,
      category: form.category,
    );
    final updatedDocuments = documents
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    setState(() => _busy = true);
    try {
      await _repository.save(updatedDocuments);
      if (!mounted) return;
      setState(() => documents = updatedDocuments);
      _showMessage('Document details updated.');
    } on Object catch (error) {
      if (mounted) _showMessage('Could not update document: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    final selected = _selectedDocument;
    if (selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '“${selected.displayName}” and its stored file will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final remaining = documents
        .where((item) => item.id != selected.id)
        .toList();
    setState(() => _busy = true);
    try {
      await _repository.delete(selected, remaining);
      if (!mounted) return;
      setState(() {
        documents = remaining;
        _selectedId = null;
      });
      _showMessage('Document deleted.');
    } on Object catch (error) {
      if (mounted) _showMessage('Could not delete document: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewDocument(TravelDocument document) async {
    if (!await File(document.storedPath).exists()) {
      if (mounted) {
        _showMessage(
          'The stored file is missing. Delete this record and upload it again.',
        );
      }
      return;
    }
    if (document.isPdf || document.isImage) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TravelDocumentViewerScreen(document: document),
        ),
      );
      return;
    }
    final result = await OpenFilex.open(document.storedPath);
    if (result.type != ResultType.done && mounted) {
      _showMessage(
        result.message.isEmpty
            ? 'No compatible app could open this file.'
            : result.message,
      );
    }
  }

  Future<_DocumentFormValue?> _showDocumentForm({
    required String title,
    required String initialName,
    required String initialCategory,
  }) {
    return showDialog<_DocumentFormValue>(
      context: context,
      builder: (_) => _DocumentFormDialog(
        title: title,
        initialName: initialName,
        initialCategory: initialCategory,
      ),
    );
  }

  String _nameWithoutExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DocumentFormValue {
  const _DocumentFormValue(this.name, this.category);
  final String name;
  final String category;
}

class _DocumentFormDialog extends StatefulWidget {
  const _DocumentFormDialog({
    required this.title,
    required this.initialName,
    required this.initialCategory,
  });

  final String title;
  final String initialName;
  final String initialCategory;

  @override
  State<_DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends State<_DocumentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Document name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a document name.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  const [
                        'Passports',
                        'Visas',
                        'Tickets',
                        'Bookings',
                        'Insurance',
                        'Identification',
                        'Other',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(
              context,
              _DocumentFormValue(_nameController.text.trim(), _category),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.selected,
    required this.onSelect,
    required this.onView,
  });

  final TravelDocument document;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onSelect,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF07513C), width: 4),
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EEEB),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _iconForDocument(document),
                      color: const Color(0xFF07513C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF073F30),
                          ),
                        ),
                        Text(
                          document.originalFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: Color(0xFF07513C))
                  else
                    const Icon(Icons.circle_outlined, color: Color(0xFF809088)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DocumentBadge(label: document.category),
                  _DocumentBadge(
                    label: document.extension.isEmpty
                        ? 'FILE'
                        : document.extension.toUpperCase(),
                  ),
                  _DocumentBadge(label: _formatFileSize(document.fileSize)),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View Document'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForDocument(TravelDocument document) {
    if (document.isPdf) return Icons.picture_as_pdf_outlined;
    if (document.isImage) return Icons.image_outlined;
    return Icons.description_outlined;
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DocumentBadge extends StatelessWidget {
  const _DocumentBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6ECE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _VaultEmptyState extends StatelessWidget {
  const _VaultEmptyState({required this.hasDocuments, required this.hasFilter});
  final bool hasDocuments;
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = hasDocuments && hasFilter;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.search_off : Icons.folder_open_outlined,
            size: 58,
            color: const Color(0xFF789087),
          ),
          const SizedBox(height: 14),
          Text(
            filtered ? 'No matching documents' : 'Your vault is empty',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            filtered
                ? 'Try another search term or category.'
                : 'Use Upload below to securely add your first travel document.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultActionBar extends StatelessWidget {
  const _VaultActionBar({
    required this.hasSelection,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onUpload,
  });

  final bool hasSelection;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Edit selected document',
                onPressed: hasSelection && !busy ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Delete selected document',
                onPressed: hasSelection && !busy ? onDelete : null,
                color: Theme.of(context).colorScheme.error,
                icon: const Icon(Icons.delete_outline),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: busy ? null : onUpload,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelAssistantAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _TravelAssistantAppBar({this.onLock});
  final VoidCallback? onLock;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
      title: const Text(
        'Travel Assistant',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF003B2B),
        ),
      ),
      actions: [
        if (onLock != null)
          IconButton(
            tooltip: 'Lock vault',
            icon: const Icon(Icons.lock_outline),
            onPressed: onLock,
          ),
        const Padding(
          padding: EdgeInsets.only(right: 14),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFFDDE8E1),
            child: Icon(Icons.person, color: Color(0xFF285A48)),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
