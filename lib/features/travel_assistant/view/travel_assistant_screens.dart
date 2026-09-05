import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/shell_routes.dart';
import '../../../shared/models/destination.dart';
import '../../../shared/widgets/app_header.dart';
import '../controller/packing_checklist_controller.dart';
import '../controller/travel_assistant_dashboard_controller.dart';
import '../model/eco_partner.dart';
import '../model/packing_checklist.dart';
import '../model/packing_location_source.dart';
import '../model/packing_weather_service.dart';
import '../model/travel_document.dart';
import '../model/travel_document_repository.dart';
import '../model/travel_assistant_cover_image.dart';
import '../model/vault_pin_service.dart';
import 'travel_document_viewer_screen.dart';
import 'emergency_contacts_screen.dart';

export 'eco_partner_screen.dart';

class TravelAssistantDashboardScreen extends StatefulWidget {
  const TravelAssistantDashboardScreen({super.key, this.controller});

  final TravelAssistantDashboardController? controller;

  @override
  State<TravelAssistantDashboardScreen> createState() =>
      _TravelAssistantDashboardScreenState();
}

class _TravelAssistantDashboardScreenState
    extends State<TravelAssistantDashboardScreen> {
  TravelAssistantDashboardController? _dashboardController;
  bool _ownsController = false;

  TravelAssistantDashboardController get _controller {
    _ensureControllerInitialized();
    return _dashboardController!;
  }

  @override
  void initState() {
    super.initState();
    _ensureControllerInitialized();
  }

  @override
  void reassemble() {
    super.reassemble();
    // New fields are not initialized by initState when Flutter retains this
    // State object during a hot reload.
    _ensureControllerInitialized();
  }

  @override
  void didUpdateWidget(covariant TravelAssistantDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _releaseController();
      _ensureControllerInitialized();
    }
  }

  void _ensureControllerInitialized() {
    if (_dashboardController != null) return;

    final controller =
        widget.controller ?? TravelAssistantDashboardController();
    _dashboardController = controller;
    _ownsController = widget.controller == null;
    controller.addListener(_refresh);

    // Deferring the load also makes this safe when the fallback is reached
    // from build immediately after a hot reload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_dashboardController, controller)) return;
      controller.load();
    });
  }

  void _releaseController() {
    final controller = _dashboardController;
    if (controller == null) return;

    controller.removeListener(_refresh);
    if (_ownsController) controller.dispose();
    _dashboardController = null;
    _ownsController = false;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openChecklist() async {
    await context.push(ShellRoutes.checklist);
    if (mounted) await _controller.refreshChecklist();
  }

  Future<void> _openVault() async {
    await context.push(ShellRoutes.documentVault);
    if (mounted) await _controller.refreshDocuments();
  }

  Future<void> _openEcoPartners() async {
    await context.push(ShellRoutes.ecoPartners);
    if (!mounted) return;
    await _controller.refreshChecklist();
    if (mounted) await _controller.refreshEcoPartners();
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checklist = _controller.checklist;

    return Scaffold(
      appBar: const AppHeader.tabRoot(title: 'Travel Assistant'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _TravelAssistantHeroCard(
            controller: _controller,
            onPackingTap: _openChecklist,
            onEcoPartnersTap: _openEcoPartners,
            onVaultTap: _openVault,
          ),
          const SizedBox(height: 20),
          _DashboardCard(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Smart Packing & Checklist',
            description: _controller.packingDescription,
            button: 'Open Checklist',
            progress: checklist.isLoading
                ? null
                : _controller.checklistProgress,
            progressLabel: checklist.isLoading
                ? null
                : '${checklist.packedItems}/${checklist.totalItems} packed',
            onTap: _openChecklist,
          ),
          _DashboardCard(
            icon: Icons.eco_outlined,
            title: 'Eco Recommendations',
            description:
                'Discover sustainable hotels, dining, public transport and EV charging partners across Malaysia.',
            button: 'Browse Eco Partners',
            onTap: _openEcoPartners,
          ),
          _DashboardCard(
            icon: Icons.folder_copy_outlined,
            title: 'Document Vault',
            description: _controller.documentDescription,
            button: 'Manage Documents',
            onTap: _openVault,
            secondaryButton: 'Emergency Contacts',
            onSecondaryTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyContactsScreen(
                  fallbackPath: ShellRoutes.travelAssistant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelAssistantHeroCard extends StatelessWidget {
  const _TravelAssistantHeroCard({
    required this.controller,
    required this.onPackingTap,
    required this.onEcoPartnersTap,
    required this.onVaultTap,
  });

  final TravelAssistantDashboardController controller;
  final VoidCallback onPackingTap;
  final VoidCallback onEcoPartnersTap;
  final VoidCallback onVaultTap;

  @override
  Widget build(BuildContext context) {
    final cover = controller.coverImage;
    final selectedLocation = controller.selectedLocation;
    final checklist = controller.checklist;
    final packingValue = checklist.isLoading
        ? 'Loading'
        : !controller.hasSelectedLocation
        ? 'Choose trip'
        : '${checklist.packedItems}/${checklist.totalItems} packed';
    final ecoPartnerValue = controller.isLoadingEcoPartners
        ? 'Loading'
        : controller.ecoPartnerError != null
        ? 'Unavailable'
        : '${controller.ecoPartnerCount ?? 0} saved';
    final vaultValue = controller.isLoadingDocuments
        ? 'Loading'
        : controller.documentError != null
        ? 'Unavailable'
        : '${controller.documentCount ?? 0} '
              '${controller.documentCount == 1 ? 'file' : 'files'}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 255),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF315E48), Color(0xFF0D3528)],
                  ),
                ),
              ),
            ),
            if (cover != null)
              Positioned.fill(
                child: Image.network(
                  cover.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              )
            else
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0.72, -0.15),
                  child: Icon(
                    _heroFallbackIcon(selectedLocation),
                    size: 108,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55001810), Color(0xE600241A)],
                    stops: [0, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PACKING FOR',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (controller.isLoadingCover)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      else if (cover != null)
                        Flexible(child: _CoverAttribution(image: cover)),
                    ],
                  ),
                  const SizedBox(height: 38),
                  Text(
                    controller.heroTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    controller.heroSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroFeatureSummary(
                          icon: Icons.assignment_turned_in_outlined,
                          label: 'Packing',
                          value: packingValue,
                          onTap: onPackingTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeroFeatureSummary(
                          icon: Icons.eco_outlined,
                          label: 'Eco Partners',
                          value: ecoPartnerValue,
                          onTap: onEcoPartnersTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeroFeatureSummary(
                          icon: Icons.folder_copy_outlined,
                          label: 'Vault',
                          value: vaultValue,
                          onTap: onVaultTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFeatureSummary extends StatelessWidget {
  const _HeroFeatureSummary({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value',
    child: Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFFFFE5A5)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CoverAttribution extends StatelessWidget {
  const _CoverAttribution({required this.image});

  final TravelAssistantCoverImage image;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(image.attributionUrl ?? '');
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: uri == null
            ? null
            : () => launchUrl(uri, mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            image.attribution,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
        ),
      ),
    );
  }
}

IconData _heroFallbackIcon(PackingLocationOption? location) =>
    switch (location?.primaryCategory) {
      DestinationCategory.beach ||
      DestinationCategory.island => Icons.beach_access_outlined,
      DestinationCategory.waterfall => Icons.water_outlined,
      DestinationCategory.mountain ||
      DestinationCategory.viewpoint => Icons.landscape_outlined,
      DestinationCategory.restaurant ||
      DestinationCategory.cafe => Icons.restaurant_outlined,
      DestinationCategory.heritageSite ||
      DestinationCategory.museum => Icons.account_balance_outlined,
      DestinationCategory.park => Icons.park_outlined,
      _ => Icons.travel_explore_outlined,
    };

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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progressLabel ?? '${(progress! * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
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
  const ReadyToWanderScreen({super.key, this.controller});

  final PackingChecklistController? controller;

  @override
  State<ReadyToWanderScreen> createState() => _ReadyToWanderScreenState();
}

class _ReadyToWanderScreenState extends State<ReadyToWanderScreen> {
  late final PackingChecklistController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PackingChecklistController();
    _ownsController = widget.controller == null;
    _controller.addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _controller.readinessScore;
    return Scaffold(
      appBar: const AppHeader.pushed(
        title: 'Packing Checklist',
        fallbackPath: ShellRoutes.travelAssistant,
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _controller.locationOptions.isEmpty
          ? _PackingChecklistEmptyState(
              onBrowseEcoPartners: () => context.push(ShellRoutes.ecoPartners),
            )
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
                if (_controller.locationOptions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _controller.selectedLocationId,
                    isExpanded: true,
                    itemHeight: 64,
                    decoration: const InputDecoration(
                      labelText: 'Packing location',
                      prefixIcon: Icon(Icons.luggage_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _controller.locationOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.id,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  option.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => _controller
                        .locationOptions
                        .map(
                          (option) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _controller.selectLocation(value);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                if (_controller.canEditTripDates) ...[
                  _PackingTripDatesCard(
                    dates: _controller.tripDates,
                    isEditable: true,
                    isDining:
                        _controller.ecoPartnerCategory ==
                        EcoPartnerCategory.dining,
                    forecastDetail: _controller.weatherDetail,
                    weatherCondition: _controller.weather?.condition,
                    isWeatherLoading: _controller.isWeatherLoading,
                    canRetryForecast: _controller.canRetryForecast,
                    onSetDates: _selectTripDates,
                    onClearDates: _controller.clearTripDates,
                    onRetryForecast: _controller.retryForecast,
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'Recommendations for ${_controller.tripLabel}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_controller.categoryLabels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _controller.categoryLabels
                        .map(
                          (category) => Chip(
                            avatar: Icon(
                              category == 'Hotel'
                                  ? Icons.hotel_outlined
                                  : category == 'Dining'
                                  ? Icons.restaurant_outlined
                                  : Icons.place_outlined,
                              size: 16,
                            ),
                            label: Text(category),
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
                                _weatherConditionIcon(
                                  _controller.weather?.condition,
                                ),
                                'Weather',
                                _metricScoreLabel(_controller.weatherScore),
                                _controller.weatherDetail,
                              ),
                            ),
                            Expanded(
                              child: _ReadinessMetric(
                                Icons.medical_services_outlined,
                                'Health',
                                _metricScoreLabel(_controller.healthScore),
                                _controller.healthDetail,
                              ),
                            ),
                            Expanded(
                              child: _ReadinessMetric(
                                Icons.directions_bus_outlined,
                                'Transit',
                                _metricScoreLabel(_controller.transitScore),
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
                    Expanded(
                      child: Text(
                        'Packing Checklist',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_controller.packedItems}/${_controller.totalItems} packed',
                      textAlign: TextAlign.right,
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
                    Expanded(
                      child: Text(
                        'Customized Checklist',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF003B2B),
                        ),
                      ),
                    ),
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
    final item = await showDialog<_CustomPackingItemDraft>(
      context: context,
      builder: (_) => const _AddCustomPackingItemDialog(),
    );
    if (item == null || !mounted) return;
    await _controller.addCustomItem(item.name, item.note);
  }

  Future<void> _selectTripDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _controller.tripDates;
    final lastDate = DateTime(today.year + 5, today.month, today.day);

    if (_controller.ecoPartnerCategory == EcoPartnerCategory.dining) {
      final initialDate =
          current != null &&
              !current.start.isBefore(today) &&
              !current.start.isAfter(lastDate)
          ? current.start
          : today;
      final selected = await showDatePicker(
        context: context,
        firstDate: today,
        lastDate: lastDate,
        initialDate: initialDate,
        helpText: 'Select dining visit date',
        confirmText: 'Save date',
      );
      if (selected == null || !mounted) return;
      await _controller.setTripDates(
        PackingTripDateRange(start: selected, end: selected),
      );
      return;
    }

    final initialRange =
        current != null &&
            !current.start.isBefore(today) &&
            !current.end.isAfter(lastDate)
        ? DateTimeRange(start: current.start, end: current.end)
        : null;
    final selected = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: lastDate,
      initialDateRange: initialRange,
      helpText: 'Select hotel stay dates',
      saveText: 'Save dates',
    );
    if (selected == null || !mounted) return;
    await _controller.setTripDates(
      PackingTripDateRange(start: selected.start, end: selected.end),
    );
  }
}

class _PackingTripDatesCard extends StatelessWidget {
  const _PackingTripDatesCard({
    required this.dates,
    required this.isEditable,
    required this.isDining,
    required this.forecastDetail,
    required this.weatherCondition,
    required this.isWeatherLoading,
    required this.canRetryForecast,
    required this.onSetDates,
    required this.onClearDates,
    required this.onRetryForecast,
  });

  final PackingTripDateRange? dates;
  final bool isEditable;
  final bool isDining;
  final String forecastDetail;
  final PackingWeatherCondition? weatherCondition;
  final bool isWeatherLoading;
  final bool canRetryForecast;
  final VoidCallback onSetDates;
  final VoidCallback onClearDates;
  final VoidCallback onRetryForecast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final value = dates == null
        ? isEditable
              ? isDining
                    ? 'Add a visit date so this checklist matches your meal.'
                    : 'Add dates so this checklist matches your stay.'
              : 'Dates unavailable. Edit and regenerate this itinerary to set them.'
        : dates!.isSingleDay
        ? localizations.formatShortDate(dates!.start)
        : '${localizations.formatShortDate(dates!.start)} – '
              '${localizations.formatShortDate(dates!.end)}';
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                dates == null
                    ? Icons.calendar_month_outlined
                    : _weatherConditionIcon(weatherCondition),
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dates == null
                        ? isDining
                              ? 'Dining date not set'
                              : 'Trip dates not set'
                        : isDining
                        ? 'Dining visit date'
                        : 'Trip dates',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(value),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isWeatherLoading) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          forecastDetail,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  if (!isEditable && dates != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'From saved itinerary',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (isEditable) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        TextButton(
                          onPressed: onSetDates,
                          child: Text(
                            dates == null
                                ? isDining
                                      ? 'Set date'
                                      : 'Set dates'
                                : 'Edit',
                          ),
                        ),
                        if (dates != null)
                          TextButton(
                            onPressed: onClearDates,
                            child: const Text('Clear'),
                          ),
                        if (canRetryForecast)
                          TextButton.icon(
                            onPressed: onRetryForecast,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry forecast'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomPackingItemDraft {
  const _CustomPackingItemDraft({required this.name, required this.note});

  final String name;
  final String note;
}

class _AddCustomPackingItemDialog extends StatefulWidget {
  const _AddCustomPackingItemDialog();

  @override
  State<_AddCustomPackingItemDialog> createState() =>
      _AddCustomPackingItemDialogState();
}

class _AddCustomPackingItemDialogState
    extends State<_AddCustomPackingItemDialog> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _CustomPackingItemDraft(name: name, note: _noteController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add custom packing item'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Item name',
            hintText: 'e.g. Contact lenses',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'Why you need this item',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Add')),
    ],
  );
}

class _PackingChecklistEmptyState extends StatelessWidget {
  const _PackingChecklistEmptyState({required this.onBrowseEcoPartners});

  final VoidCallback onBrowseEcoPartners;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.luggage_outlined,
            size: 64,
            color: Color(0xFF315E48),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose a trip to start packing',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Save a hotel or dining Eco Partner, or save an itinerary, to get a checklist tailored to that category and location.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onBrowseEcoPartners,
            icon: const Icon(Icons.eco_outlined),
            label: const Text('Browse Eco Partners'),
          ),
        ],
      ),
    ),
  );
}

String _metricScoreLabel(int? score) => score == null ? 'N/A' : '$score%';

IconData _weatherConditionIcon(PackingWeatherCondition? condition) =>
    switch (condition) {
      PackingWeatherCondition.clear => Icons.wb_sunny_outlined,
      PackingWeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
      PackingWeatherCondition.cloudy => Icons.cloud_outlined,
      PackingWeatherCondition.fog => Icons.foggy,
      PackingWeatherCondition.drizzle => Icons.grain_outlined,
      PackingWeatherCondition.rain => Icons.umbrella_outlined,
      PackingWeatherCondition.snow => Icons.ac_unit,
      PackingWeatherCondition.thunderstorm => Icons.thunderstorm_outlined,
      PackingWeatherCondition.unknown ||
      null => Icons.device_thermostat_outlined,
    };

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
    'Hotel Check-in' => Icons.hotel_outlined,
    'Overnight Essentials' => Icons.bed_outlined,
    'Dining Essentials' => Icons.restaurant_outlined,
    'Getting There' => Icons.directions_transit_outlined,
    'Personal Comfort' => Icons.self_improvement_outlined,
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
      appBar: const AppHeader.pushed(
        title: 'Eco Partners',
        fallbackPath: ShellRoutes.travelAssistant,
      ),
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
  const DocumentVaultScreen({super.key, this.pinService, this.repository});

  final VaultPinServiceContract? pinService;
  final TravelDocumentRepository? repository;

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  late final VaultPinServiceContract _pinService;
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _loading = true;
  bool _hasPin = false;
  bool _unlocked = false;
  bool _hidePin = true;
  bool _resettingPin = false;
  bool _submittingPin = false;
  bool _pinStatusUnavailable = false;
  int? _selectedPinLength;
  DateTime? _lockedUntil;
  Timer? _lockoutTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinService = widget.pinService ?? VaultPinService();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    VaultPinStatus status;
    try {
      status = await _pinService.loadStatus().timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      status = const VaultPinStatus.unavailable();
    }
    if (!mounted) return;
    final retry = status.lockedUntil?.difference(DateTime.now());
    setState(() {
      _pinStatusUnavailable =
          status.availability == VaultPinAvailability.unavailable;
      _hasPin = status.hasPin;
      _selectedPinLength = status.pinLength;
      _lockedUntil = status.lockedUntil;
      _error = retry != null && retry > Duration.zero
          ? 'Too many attempts. Try again in ${_formatRetry(retry)}.'
          : null;
      _loading = false;
    });
    _scheduleUnlock(status.lockedUntil);
  }

  bool get _isLocked {
    final lockedUntil = _lockedUntil;
    return lockedUntil?.isAfter(DateTime.now()) ?? false;
  }

  void _scheduleUnlock(DateTime? lockedUntil) {
    _lockoutTimer?.cancel();
    if (lockedUntil == null) return;
    final delay = lockedUntil.difference(DateTime.now());
    if (delay <= Duration.zero) return;
    _lockoutTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _lockedUntil = null;
        _error = null;
      });
    });
  }

  void _selectPinLength(int length) {
    if (_selectedPinLength == length) return;
    setState(() {
      _selectedPinLength = length;
      _error = null;
      _pinController.clear();
      _confirmPinController.clear();
    });
  }

  Future<void> _submitPin() async {
    FocusScope.of(context).unfocus();
    final pin = _pinController.text;
    final pinLength = _selectedPinLength;
    if (pinLength == null) {
      setState(() => _error = 'Choose a 4 or 6 digit PIN length.');
      return;
    }
    if (!RegExp('^\\d{$pinLength}\$').hasMatch(pin)) {
      setState(() => _error = 'Enter a $pinLength-digit PIN.');
      return;
    }

    if (_isLocked) {
      setState(() => _error = 'Too many attempts. Try again shortly.');
      return;
    }

    if (!_hasPin) {
      if (pin != _confirmPinController.text) {
        setState(() => _error = 'The PINs do not match.');
        return;
      }
    }

    setState(() {
      _submittingPin = true;
      _error = null;
    });
    try {
      if (_hasPin) {
        final result = await _pinService.verifyPin(pin);
        if (!mounted) return;
        switch (result.status) {
          case VaultPinVerificationStatus.verified:
            setState(() {
              _unlocked = true;
              _submittingPin = false;
              _error = null;
              _pinController.clear();
            });
            return;
          case VaultPinVerificationStatus.incorrect:
            final attempts = result.attemptsRemaining;
            setState(() {
              _submittingPin = false;
              _error = attempts == null
                  ? 'Incorrect PIN. Please try again.'
                  : 'Incorrect PIN. $attempts attempts remaining.';
              _pinController.clear();
            });
            return;
          case VaultPinVerificationStatus.locked:
            final retry = result.retryAfter ?? const Duration(minutes: 5);
            final lockedUntil = DateTime.now().add(retry);
            setState(() {
              _submittingPin = false;
              _lockedUntil = lockedUntil;
              _error =
                  'Too many attempts. Try again in ${_formatRetry(retry)}.';
              _pinController.clear();
            });
            _scheduleUnlock(lockedUntil);
            return;
          case VaultPinVerificationStatus.unavailable:
            setState(() {
              _submittingPin = false;
              _error =
                  'PIN verification is unavailable. Check your connection and retry.';
            });
            return;
          case VaultPinVerificationStatus.notConfigured:
            setState(() {
              _submittingPin = false;
              _error = 'Vault PIN status changed. Refresh and try again.';
            });
            return;
        }
      }

      await _pinService.writePin(pin);
      if (!mounted) return;
      setState(() {
        _hasPin = true;
        _unlocked = true;
        _submittingPin = false;
        _error = null;
        _pinController.clear();
        _confirmPinController.clear();
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _submittingPin = false;
        _error = _hasPin
            ? 'PIN verification is unavailable. Check your connection and retry.'
            : 'A connection is required to create your PIN. Please retry.';
      });
    }
  }

  String _formatRetry(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes >= 1) return '$minutes minute${minutes == 1 ? '' : 's'}';
    return '${duration.inSeconds} seconds';
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
      final status = await _pinService.loadStatus();
      if (!mounted) return;
      setState(() => _selectedPinLength = status.pinLength);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your vault PIN has been reset.')),
      );
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: AppHeader.pushed(
          title: 'Document Vault',
          fallbackPath: ShellRoutes.travelAssistant,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Checking your vault…'),
            ],
          ),
        ),
      );
    }
    if (_unlocked) {
      return _UnlockedDocumentVault(
        onLock: _lockVault,
        repository: widget.repository ?? TravelDocumentRepository(),
        pinService: _pinService,
      );
    }

    if (_pinStatusUnavailable) {
      return Scaffold(
        appBar: const AppHeader.pushed(
          title: 'Document Vault',
          fallbackPath: ShellRoutes.travelAssistant,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 54),
                  const SizedBox(height: 14),
                  Text(
                    'Vault PIN unavailable',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect to the internet to check your existing vault PIN. A new PIN cannot be created while status is unavailable.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loadPinState,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const AppHeader.pushed(
        title: 'Document Vault',
        fallbackPath: ShellRoutes.travelAssistant,
      ),
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
                        : 'Choose either a 4-digit or 6-digit PIN to protect your travel documents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_hasPin) ...[
                    _PinLengthSelector(
                      selectedLength: _selectedPinLength,
                      onSelected: _selectPinLength,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedPinLength != null) ...[
                    _PinCodeField(
                      controller: _pinController,
                      label: _hasPin ? 'Vault PIN' : 'Create PIN',
                      pinLength: _selectedPinLength!,
                      autofocus: true,
                      obscureText: _hidePin,
                      errorText: _error,
                      onSubmitted: _hasPin && !_submittingPin && !_isLocked
                          ? _submitPin
                          : null,
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
                        pinLength: _selectedPinLength!,
                        obscureText: _hidePin,
                        onSubmitted: _submitPin,
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: _resettingPin || _submittingPin || _isLocked
                          ? null
                          : _submitPin,
                      icon: _submittingPin
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _hasPin
                                  ? Icons.lock_open_outlined
                                  : Icons.shield_outlined,
                            ),
                      label: Text(
                        _hasPin ? 'Unlock Vault' : 'Create PIN & Continue',
                      ),
                    ),
                  ],
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
                          'Your PIN is cached securely on this device; only a salted verifier is synced.',
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

  final VaultPinServiceContract pinService;

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
  int? _selectedPinLength;
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
    final pinLength = _selectedPinLength;
    if (pinLength == null) {
      setState(() => _error = 'Choose a 4 or 6 digit PIN length.');
      return;
    }
    if (!RegExp('^\\d{$pinLength}\$').hasMatch(pin)) {
      setState(() => _error = 'Enter a $pinLength-digit PIN.');
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
        _error =
            'Could not save the new PIN to your account. Check your connection and try again.';
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
          'Choose either a 4-digit or 6-digit PIN for your Document Vault.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _PinLengthSelector(
          selectedLength: _selectedPinLength,
          onSelected: (length) {
            setState(() {
              _selectedPinLength = length;
              _error = null;
              _pinController.clear();
              _confirmController.clear();
            });
          },
        ),
        if (_selectedPinLength != null) ...[
          const SizedBox(height: 24),
          _PinCodeField(
            controller: _pinController,
            label: 'New PIN',
            pinLength: _selectedPinLength!,
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
            pinLength: _selectedPinLength!,
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
        ],
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
          'Enter this account’s password before resetting the vault PIN across your devices.',
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
  const _UnlockedDocumentVault({
    required this.onLock,
    required this.repository,
    required this.pinService,
  });
  final VoidCallback onLock;
  final TravelDocumentRepository repository;
  final VaultPinServiceContract pinService;

  @override
  State<_UnlockedDocumentVault> createState() => _UnlockedDocumentVaultState();
}

class _UnlockedDocumentVaultState extends State<_UnlockedDocumentVault> {
  late final TravelDocumentRepository _repository = widget.repository;
  final _searchController = TextEditingController();
  bool offlineMode = false;
  final Set<String> _selectedCategories = {};
  bool _loadingDocuments = true;
  bool _busy = false;
  String _query = '';
  String? _documentLoadError;
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
    if (mounted) {
      setState(() {
        _loadingDocuments = true;
        _documentLoadError = null;
      });
    }
    try {
      final loaded = await _repository.load().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        documents = loaded;
        _loadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDocuments = false;
        _documentLoadError =
            'Your documents could not be loaded. Check your connection and retry.';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documentLoadError = _documentLoadError;
    final normalizedQuery = _query.trim().toLowerCase();
    final shown = documents.where((document) {
      final matchesCategory =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(document.category);
      final matchesSearch =
          normalizedQuery.isEmpty ||
          document.displayName.toLowerCase().contains(normalizedQuery) ||
          document.originalFileName.toLowerCase().contains(normalizedQuery) ||
          document.category.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesSearch;
    }).toList();
    final categoryCounts = <String, int>{};
    for (final document in documents) {
      categoryCounts.update(
        document.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return Scaffold(
      appBar: AppHeader.pushed(
        title: 'Document Vault',
        fallbackPath: ShellRoutes.travelAssistant,
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
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Loading your documents…'),
                ],
              ),
            )
          : documentLoadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 54),
                    const SizedBox(height: 12),
                    Text(documentLoadError, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadDocuments,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
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
                        builder: (_) => EmergencyContactsScreen(
                          initiallyUnlocked: true,
                          fallbackPath: ShellRoutes.documentVault,
                          pinService: widget.pinService,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _selectedIds.clear();
                  }),
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
                              setState(() {
                                _query = '';
                                _selectedIds.clear();
                              });
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _resultCountLabel(shown.length),
                        key: const Key('vault-results-count'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('vault-filter-button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: categoryCounts.isEmpty
                          ? null
                          : () => _showDocumentFilters(categoryCounts),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_list),
                          const SizedBox(width: 8),
                          const Text('Filter'),
                          if (_selectedCategories.isNotEmpty) ...[
                            const SizedBox(width: 7),
                            Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedCategories.length}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  _VaultEmptyState(
                    hasDocuments: documents.isNotEmpty,
                    hasFilter:
                        _query.isNotEmpty || _selectedCategories.isNotEmpty,
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

  String _resultCountLabel(int shownCount) {
    final noun = shownCount == 1 ? 'document' : 'documents';
    if (_query.isEmpty && _selectedCategories.isEmpty) {
      return '$shownCount $noun';
    }
    return '$shownCount of ${documents.length} documents';
  }

  List<String> _orderedCategories(Iterable<String> values) {
    const canonical = [
      'Passports',
      'Visas',
      'Tickets',
      'Bookings',
      'Insurance',
      'Identification',
      'Other',
    ];
    final present = values.toSet();
    final ordered = canonical.where(present.remove).toList();
    ordered.addAll(present.toList()..sort());
    return ordered;
  }

  Future<void> _showDocumentFilters(Map<String, int> counts) async {
    final draft = Set<String>.from(_selectedCategories);
    final categories = _orderedCategories(counts.keys);
    final applied = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'Filter documents',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final category in categories)
                        CheckboxListTile(
                          key: Key('vault-filter-$category'),
                          value: draft.contains(category),
                          onChanged: (selected) => setSheetState(() {
                            if (selected ?? false) {
                              draft.add(category);
                            } else {
                              draft.remove(category);
                            }
                          }),
                          secondary: Icon(
                            Icons.folder_outlined,
                            color: _DocumentCategoryStyle.forCategory(
                              category,
                            ).accent,
                          ),
                          title: Text(category),
                          subtitle: Text(
                            '${counts[category]} ${counts[category] == 1 ? 'document' : 'documents'}',
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('vault-filter-reset'),
                        onPressed: () => setSheetState(() => draft.clear()),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: const Key('vault-filter-apply'),
                        onPressed: () => Navigator.pop(context, draft),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied == null || !mounted) return;
    setState(() {
      _selectedCategories
        ..clear()
        ..addAll(applied);
      _selectedIds.clear();
    });
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
    File localFile;
    try {
      localFile = await _repository.ensureLocalFile(document);
    } on Object catch (error) {
      if (mounted) _showMessage('Document unavailable: $error');
      return;
    }
    final localDocument = document.copyWith(storedPath: localFile.path);
    if (localDocument.isPdf || localDocument.isImage) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TravelDocumentViewerScreen(
            document: localDocument,
            fallbackPath: ShellRoutes.documentVault,
          ),
        ),
      );
      return;
    }
    final result = await OpenFilex.open(localFile.path);
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
    final categoryStyle = _DocumentCategoryStyle.forCategory(document.category);
    return Card(
      key: Key('vault-document-${document.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      color: Color.alphaBlend(
        categoryStyle.accent.withValues(alpha: .08),
        colorScheme.surface,
      ),
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
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: categoryStyle.accent, width: 4),
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
                      color: Color.alphaBlend(
                        categoryStyle.accent.withValues(alpha: .14),
                        colorScheme.surface,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _iconForDocument(document),
                      color: categoryStyle.accent,
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
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
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
                  _DocumentBadge(
                    label: document.category,
                    backgroundColor: Color.alphaBlend(
                      categoryStyle.accent.withValues(alpha: .14),
                      colorScheme.surface,
                    ),
                    foregroundColor: categoryStyle.accent,
                  ),
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
  const _DocumentBadge({
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _DocumentCategoryStyle {
  const _DocumentCategoryStyle(this.accent);

  final Color accent;

  static _DocumentCategoryStyle forCategory(String category) {
    final accent = switch (category) {
      'Passports' => const Color(0xFF1565C0),
      'Visas' => const Color(0xFF7B1FA2),
      'Tickets' => const Color(0xFFE65100),
      'Bookings' => const Color(0xFF00838F),
      'Insurance' => const Color(0xFF2E7D32),
      'Identification' => const Color(0xFF5E35B1),
      _ => const Color(0xFF546E7A),
    };
    return _DocumentCategoryStyle(accent);
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

class _PinLengthSelector extends StatelessWidget {
  const _PinLengthSelector({
    required this.selectedLength,
    required this.onSelected,
  });

  final int? selectedLength;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose PIN length',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(
            value: 4,
            icon: Icon(Icons.pin_outlined),
            label: Text('4 digits'),
          ),
          ButtonSegment<int>(
            value: 6,
            icon: Icon(Icons.password_outlined),
            label: Text('6 digits'),
          ),
        ],
        selected: selectedLength == null ? const {} : {selectedLength!},
        emptySelectionAllowed: true,
        showSelectedIcon: true,
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) onSelected(selection.first);
        },
      ),
    ],
  );
}

class _PinCodeField extends StatefulWidget {
  const _PinCodeField({
    required this.controller,
    required this.label,
    required this.pinLength,
    this.autofocus = false,
    this.obscureText = true,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final int pinLength;
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
                  children: List.generate(widget.pinLength, (index) {
                    final hasValue = index < value.length;
                    final active =
                        _focusNode.hasFocus &&
                        (index == value.length ||
                            (value.length == widget.pinLength &&
                                index == widget.pinLength - 1));
                    return Expanded(
                      child: Container(
                        key: ValueKey('${widget.label}-pin-box-$index'),
                        margin: EdgeInsets.only(
                          right: index == widget.pinLength - 1 ? 0 : 7,
                        ),
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
                    key: ValueKey('${widget.label}-pin-input'),
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: widget.pinLength,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.pinLength),
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
