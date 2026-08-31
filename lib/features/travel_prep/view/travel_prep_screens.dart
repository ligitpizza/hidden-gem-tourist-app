import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/shell_routes.dart';
import '../../../shared/models/destination.dart';
import '../../../shared/widgets/app_header.dart';
import '../controller/packing_checklist_controller.dart';
import '../model/packing_checklist.dart';
import '../model/travel_document.dart';
import '../model/travel_document_repository.dart';
import '../model/vault_pin_service.dart';
import 'travel_document_viewer_screen.dart';
import 'emergency_contacts_screen.dart';

export 'eco_partner_screen.dart';

class TravelPrepDashboardScreen extends StatefulWidget {
  const TravelPrepDashboardScreen({super.key});

  @override
  State<TravelPrepDashboardScreen> createState() =>
      _TravelPrepDashboardScreenState();
}

class _TravelPrepDashboardScreenState
    extends State<TravelPrepDashboardScreen> {
  final _checklistController = PackingChecklistController();

  @override
  void initState() {
    super.initState();
    _checklistController.addListener(_refresh);
    _checklistController.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openChecklist() async {
    await context.push(ShellRoutes.checklist);
    if (mounted) await _checklistController.load();
  }

  @override
  void dispose() {
    _checklistController.removeListener(_refresh);
    _checklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readinessScore = _checklistController.readinessScore;
    final checklistProgress = readinessScore / 100;

    return Scaffold(
      appBar: const AppHeader.tabRoot(title: 'Travel Prep'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text(
                  'NEXT TRIP',
                  style: TextStyle(color: Colors.white70, letterSpacing: 2),
                ),
                const Text(
                  'Emerald\nFalls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text(
                      'Readiness Score',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    Text(
                      _checklistController.isLoading
                          ? 'Loading...'
                          : '$readinessScore% Ready',
                      style: const TextStyle(color: Color(0xFFFFE5A5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _checklistController.isLoading
                      ? null
                      : checklistProgress,
                  color: const Color(0xFFFFD98B),
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
            progress: _checklistController.isLoading
                ? null
                : checklistProgress,
            progressLabel: _checklistController.isLoading
                ? null
                : '${_checklistController.packedItems}/${_checklistController.totalItems} packed',
            onTap: _openChecklist,
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
            secondaryButton: 'Emergency Contacts',
            onSecondaryTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyContactsScreen(),
              ),
            ),
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
    this.progressLabel,
    this.secondaryButton,
    this.onSecondaryTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final String button;
  final VoidCallback onTap;
  final double? progress;
  final String? progressLabel;
  final String? secondaryButton;
  final VoidCallback? onSecondaryTap;

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
                  Text(progressLabel ?? '${(progress! * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
            ],
            const SizedBox(height: 18),
            if (secondaryButton == null)
              ElevatedButton(onPressed: onTap, child: Text(button))
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onTap,
                      child: Text(button),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryTap,
                      child: Text(
                        secondaryButton!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
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
  final _controller = PackingChecklistController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _controller.readinessScore;
    return Scaffold(
      appBar: const AppHeader.pushed(title: 'Packing Checklist'),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                  'Recommendations for ${_controller.tripLabel}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_controller.destinationCategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _controller.destinationCategories
                        .map(
                          (category) => Chip(
                            avatar: const Icon(Icons.place_outlined, size: 16),
                            label: Text(category.label),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
                                  Text(
                                    _controller.readinessStatus,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _ReadinessMetric(
                                Icons.wb_sunny_outlined,
                                'Weather',
                                '${_controller.weatherScore}%',
                                _controller.weatherDetail,
                              ),
                            ),
                            Expanded(
                              child: _ReadinessMetric(
                                Icons.medical_services_outlined,
                                'Health',
                                '${_controller.healthScore}%',
                                _controller.healthDetail,
                              ),
                            ),
                            Expanded(
                              child: _ReadinessMetric(
                                Icons.directions_bus_outlined,
                                'Transit',
                                '${_controller.transitScore}%',
                                _controller.transitDetail,
                              ),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_controller.packedItems}/${_controller.totalItems} packed',
                      style: Theme.of(context).textTheme.bodySmall,
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
                for (final section in _controller.sections)
                  _ChecklistCard(
                    section: section,
                    packedIds: _controller.packedIds,
                    onChanged: _controller.toggleItem,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Customized Checklist',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003B2B),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addCustomItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                if (_controller.customItems.isEmpty)
                  OutlinedButton.icon(
                    onPressed: _addCustomItem,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Create Custom Item'),
                    ),
                  )
                else
                  _ChecklistCard(
                    section: PackingChecklistSection(
                      name: 'Personal Items',
                      items: _controller.customItems,
                    ),
                    packedIds: _controller.packedIds,
                    onChanged: _controller.toggleItem,
                    onDelete: _controller.deleteCustomItem,
                  ),
              ],
            ),
    );
  }

  Future<void> _addCustomItem() async {
    final name = TextEditingController();
    final note = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add custom packing item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g. Contact lenses',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Why you need this item',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (submitted == true) {
      await _controller.addCustomItem(name.text, note.text);
    }
    name.dispose();
    note.dispose();
  }
}

class _ReadinessMetric extends StatelessWidget {
  const _ReadinessMetric(this.icon, this.label, this.value, this.detail);
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon),
      Text(label),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(
        detail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.black54, fontSize: 9),
      ),
    ],
  );
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.section,
    required this.packedIds,
    required this.onChanged,
    this.onDelete,
  });
  final PackingChecklistSection section;
  final Set<String> packedIds;
  final Future<void> Function(String id, bool packed) onChanged;
  final Future<void> Function(String id)? onDelete;

  int get packed =>
      section.items.where((item) => packedIds.contains(item.id)).length;

  IconData get icon => switch (section.name) {
    'Documents' => Icons.description_outlined,
    'Clothing' => Icons.checkroom_outlined,
    'Tech & Gear' => Icons.devices_outlined,
    'Beach Essentials' => Icons.beach_access_outlined,
    'Outdoor Adventure' => Icons.hiking_outlined,
    'Cultural Visits' => Icons.account_balance_outlined,
    'Health & Personal Care' => Icons.health_and_safety_outlined,
    'Weather Essentials' => Icons.wb_sunny_outlined,
    _ => Icons.backpack_outlined,
  };

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('packing_section_${section.name}'),
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      key: PageStorageKey<String>('packing_section_${section.name}'),
      shape: const RoundedRectangleBorder(side: BorderSide.none),
      collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
      tilePadding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE8ECE9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: const Color(0xFF0B4B38)),
      ),
      title: Text(
        section.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF164C3B),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: section.items.isEmpty ? 0 : packed / section.items.length,
            minHeight: 5,
            color: const Color(0xFF0C4A37),
            backgroundColor: const Color(0xFFE2E2DF),
          ),
        ),
      ),
      trailing: Text('$packed/${section.items.length}'),
      children: section.items
          .map(
            (item) => ListTile(
              key: ValueKey('packing_item_${item.id}'),
              leading: Checkbox(
                value: packedIds.contains(item.id),
                onChanged: (value) => onChanged(item.id, value ?? false),
                semanticLabel: 'Mark ${item.name} as packed',
              ),
              title: Text(item.name),
              subtitle: Text(item.reason),
              onTap: () => onChanged(item.id, !packedIds.contains(item.id)),
              trailing: onDelete == null
                  ? null
                  : IconButton(
                      tooltip: 'Delete custom item',
                      onPressed: () => onDelete!(item.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
              dense: true,
            ),
          )
          .toList(),
    ),
  );
}

// ignore: unused_element
class _LegacyEcoPartnersScreen extends StatefulWidget {
  const _LegacyEcoPartnersScreen();
  @override
  State<_LegacyEcoPartnersScreen> createState() => _EcoPartnersScreenState();
}

class _EcoPartnersScreenState extends State<_LegacyEcoPartnersScreen> {
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
      appBar: const AppHeader.pushed(title: 'Eco Partners'),
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
  final _pinService = VaultPinService();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _loading = true;
  bool _hasPin = false;
  bool _unlocked = false;
  bool _hidePin = true;
  bool _resettingPin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final savedPin = await _pinService.readPin();
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
      final savedPin = await _pinService.readPin();
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
      await _pinService.writePin(pin);
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

  Future<void> _resetPinWithPassword() async {
    setState(() {
      _resettingPin = true;
      _error = null;
    });
    final reset = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordPinResetDialog(pinService: _pinService),
    );
    if (!mounted) return;
    setState(() {
      _resettingPin = false;
      _pinController.clear();
    });
    if (reset == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your vault PIN has been reset.')),
      );
    }
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
        appBar: AppHeader.pushed(title: 'Document Vault'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_unlocked) return _UnlockedDocumentVault(onLock: _lockVault);

    return Scaffold(
      appBar: const AppHeader.pushed(title: 'Document Vault'),
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
                  _PinCodeField(
                    controller: _pinController,
                    label: _hasPin ? 'Vault PIN' : 'Create PIN',
                    autofocus: true,
                    obscureText: _hidePin,
                    errorText: _error,
                    onSubmitted: _hasPin ? _submitPin : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _hidePin = !_hidePin),
                      icon: Icon(
                        _hidePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      label: Text(_hidePin ? 'Show PIN' : 'Hide PIN'),
                    ),
                  ),
                  if (!_hasPin) ...[
                    const SizedBox(height: 6),
                    _PinCodeField(
                      controller: _confirmPinController,
                      label: 'Confirm PIN',
                      obscureText: _hidePin,
                      onSubmitted: _submitPin,
                    ),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _resettingPin ? null : _submitPin,
                    icon: Icon(
                      _hasPin
                          ? Icons.lock_open_outlined
                          : Icons.shield_outlined,
                    ),
                    label: Text(
                      _hasPin ? 'Unlock Vault' : 'Create PIN & Continue',
                    ),
                  ),
                  if (_hasPin) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _resettingPin ? null : _resetPinWithPassword,
                      icon: _resettingPin
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset),
                      label: const Text('Forgot PIN? Verify account password'),
                    ),
                  ],
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

class _PasswordPinResetDialog extends StatefulWidget {
  const _PasswordPinResetDialog({required this.pinService});

  final VaultPinService pinService;

  @override
  State<_PasswordPinResetDialog> createState() =>
      _PasswordPinResetDialogState();
}

class _PasswordPinResetDialogState extends State<_PasswordPinResetDialog> {
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _passwordVerified = false;
  bool _saving = false;
  bool _hidePassword = true;
  bool _hidePin = true;
  String? _error;

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your account password.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.pinService.verifyCurrentPassword(_passwordController.text);
      if (!mounted) return;
      setState(() {
        _passwordVerified = true;
        _saving = false;
        _passwordController.clear();
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
        _passwordController.clear();
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Could not verify your account. Check your connection and try again.';
      });
    }
  }

  Future<void> _saveNewPin() async {
    final pin = _pinController.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a PIN containing 4 to 6 digits.');
      return;
    }
    if (pin != _confirmController.text) {
      setState(() => _error = 'The PINs do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.pinService.writePin(pin);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the new PIN. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          _passwordVerified ? 'Create a new vault PIN' : 'Verify your account',
        ),
        content: SingleChildScrollView(
          child: _passwordVerified
              ? _buildResetForm(context)
              : _buildPasswordForm(context),
        ),
      ),
    );
  }

  Widget _buildResetForm(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 42,
          backgroundColor: Color(0xFFE1EEE8),
          child: Icon(Icons.lock_reset, size: 44, color: Color(0xFF07513C)),
        ),
        const SizedBox(height: 22),
        const Text(
          'Enter and confirm a new 4 to 6 digit PIN for your Document Vault.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        _PinCodeField(
          controller: _pinController,
          label: 'New PIN',
          autofocus: true,
          obscureText: _hidePin,
          errorText: _error,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _hidePin = !_hidePin),
            icon: Icon(
              _hidePin
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
            ),
            label: Text(_hidePin ? 'Show PIN' : 'Hide PIN'),
          ),
        ),
        const SizedBox(height: 6),
        _PinCodeField(
          controller: _confirmController,
          label: 'Confirm new PIN',
          obscureText: _hidePin,
          onSubmitted: _saving ? null : _saveNewPin,
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _saving ? null : _saveNewPin,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset),
          label: const Text('Reset PIN'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildPasswordForm(BuildContext context) {
    final email =
        widget.pinService.currentUser.email ?? 'your signed-in account';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFE1EEE8),
          child: Icon(
            Icons.verified_user_outlined,
            size: 34,
            color: Color(0xFF07513C),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter this account’s password before resetting the local vault PIN.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _passwordController,
          autofocus: true,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saving ? null : _verifyPassword(),
          decoration: InputDecoration(
            labelText: 'Account password',
            prefixIcon: const Icon(Icons.password),
            errorText: _error,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _verifyPassword,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ],
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
  final Set<String> _selectedIds = {};
  List<TravelDocument> documents = [];

  TravelDocument? get _selectedDocument {
    if (_selectedIds.length != 1) return null;
    for (final document in documents) {
      if (_selectedIds.contains(document.id)) return document;
    }
    return null;
  }

  List<TravelDocument> get _selectedDocuments => documents
      .where((document) => _selectedIds.contains(document.id))
      .toList();

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
      appBar: AppHeader.pushed(
        title: 'Document Vault',
        actions: [
          IconButton(
            tooltip: 'Lock vault',
            icon: const Icon(Icons.lock_outline),
            onPressed: widget.onLock,
          ),
        ],
      ),
      bottomNavigationBar: _VaultActionBar(
        selectionCount: _selectedIds.length,
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
                const SizedBox(height: 10),
                Card(
                  color: const Color(0xFFE8F3EE),
                  child: ListTile(
                    leading: const Icon(
                      Icons.contact_emergency_outlined,
                      color: Color(0xFF07513C),
                    ),
                    title: const Text('Emergency Contacts'),
                    subtitle: const Text(
                      'Manage contacts and lock-screen calling access',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EmergencyContactsScreen(
                          initiallyUnlocked: true,
                        ),
                      ),
                    ),
                  ),
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
                      selected: _selectedIds.contains(document.id),
                      onSelect: () => setState(() {
                        if (!_selectedIds.add(document.id)) {
                          _selectedIds.remove(document.id);
                        }
                      }),
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
    if (picked.size > TravelDocumentRepository.maxFileSizeBytes) {
      _showMessage(
        'Upload rejected: ${_DocumentCard._formatFileSize(picked.size)} exceeds the 10 MB limit.',
      );
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
        _selectedIds
          ..clear()
          ..add(imported.id);
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
    final selected = _selectedDocuments;
    if (selected.isEmpty) return;
    final count = selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          count == 1 ? 'Delete document?' : 'Delete $count documents?',
        ),
        content: Text(
          count == 1
              ? '“${selected.single.displayName}” and its stored file will be permanently removed.'
              : 'The $count selected documents and their stored files will be permanently removed.',
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
        .where((item) => !_selectedIds.contains(item.id))
        .toList();
    setState(() => _busy = true);
    try {
      await _repository.deleteMany(selected, remaining);
      if (!mounted) return;
      setState(() {
        documents = remaining;
        _selectedIds.clear();
      });
      _showMessage(
        count == 1 ? 'Document deleted.' : '$count documents deleted.',
      );
    } on VaultFileDeleteException catch (error) {
      if (!mounted) return;
      final removeRecords = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stored file could not be removed'),
          content: Text(
            '${error.documents.length == 1 ? 'One file is' : '${error.documents.length} files are'} locked or protected by Windows/OneDrive. '
            'You can still remove ${error.documents.length == 1 ? 'this document' : 'these documents'} from the vault list, but the protected file may remain on the device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep record'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove record anyway'),
            ),
          ],
        ),
      );
      if (removeRecords == true && mounted) {
        try {
          await _repository.save(remaining);
          if (!mounted) return;
          setState(() {
            documents = remaining;
            _selectedIds.clear();
          });
          _showMessage(
            count == 1
                ? 'Document removed from the vault. The protected file may remain on this device.'
                : '$count documents removed from the vault. Protected files may remain on this device.',
          );
        } on Object catch (saveError) {
          if (mounted) {
            _showMessage('Could not remove the vault record: $saveError');
          }
        }
      }
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
    required this.selectionCount,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onUpload,
  });

  final int selectionCount;
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
                onPressed: selectionCount == 1 && !busy ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 6),
              Badge(
                isLabelVisible: selectionCount > 0,
                label: Text('$selectionCount'),
                child: IconButton.filledTonal(
                  tooltip: selectionCount > 1
                      ? 'Delete $selectionCount selected documents'
                      : 'Delete selected document',
                  onPressed: selectionCount > 0 && !busy ? onDelete : null,
                  color: Theme.of(context).colorScheme.error,
                  icon: const Icon(Icons.delete_outline),
                ),
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

class _PinCodeField extends StatefulWidget {
  const _PinCodeField({
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.obscureText = true,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final bool obscureText;
  final String? errorText;
  final VoidCallback? onSubmitted;

  @override
  State<_PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<_PinCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _PinCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        SizedBox(
          height: 58,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: Row(
                  children: List.generate(6, (index) {
                    final hasValue = index < value.length;
                    final active =
                        _focusNode.hasFocus &&
                        (index == value.length ||
                            (value.length == 6 && index == 5));
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index == 5 ? 0 : 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.errorText != null
                                ? colorScheme.error
                                : active
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          hasValue
                              ? (widget.obscureText ? '●' : value[index])
                              : '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(counterText: ''),
                    onSubmitted: (_) => widget.onSubmitted?.call(),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: TextStyle(color: colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
