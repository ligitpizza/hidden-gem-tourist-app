import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/widgets/app_header.dart';
import '../controller/eco_partner_controller.dart';
import '../model/eco_partner.dart';
import 'eco_partner_detail_screen.dart';

class EcoPartnersScreen extends StatefulWidget {
  const EcoPartnersScreen({super.key});
  @override
  State<EcoPartnersScreen> createState() => _EcoPartnersScreenState();
}

class _EcoPartnersScreenState extends State<EcoPartnersScreen> {
  final _controller = EcoPartnerController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNearby());
  }

  Future<void> _loadNearby() async {
    if (await _controller.useCurrentLocation(silentPermissionDenial: true) &&
        mounted) {
      _search.text = 'Current location';
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _find({bool refresh = false}) {
    FocusScope.of(context).unfocus();
    return _controller.search(_search.text, refresh: refresh);
  }

  Future<void> _locate() async {
    if (await _controller.useCurrentLocation() && mounted) {
      _search.text = 'Current location';
    }
  }

  Future<void> _retry() => _controller.retry(fallbackQuery: _search.text);

  @override
  Widget build(BuildContext context) {
    final shown = _controller.visiblePartners;
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
          Text(
            'Search for a hotel, restaurant, attraction or other destination, then discover eco partners ${_controller.scopeLabel}.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _find(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search a place, e.g. PARKROYAL...',
              suffixIcon: IconButton(
                onPressed: _controller.isLoading ? null : () => _find(),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _controller.isLoading ? null : _locate,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use current location'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.isLoading ? null : _showFilters,
                  icon: const Icon(Icons.tune, size: 19),
                  label: Text(
                    [
                      if (_controller.filter != 'All') _controller.filter,
                      if (_controller.stateFilter != 'All states')
                        _controller.stateFilter,
                      if (_controller.sort == EcoPartnerSort.nameAscending)
                        'A → Z',
                      if (_controller.sort == EcoPartnerSort.nameDescending)
                        'Z → A',
                      _controller.scopeLabel,
                    ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<EcoPartnerLayout>(
                value: _controller.layout,
                items: const [
                  DropdownMenuItem(
                    value: EcoPartnerLayout.list,
                    child: Text('List'),
                  ),
                  DropdownMenuItem(
                    value: EcoPartnerLayout.grid2,
                    child: Text('2 × 2 grid'),
                  ),
                  DropdownMenuItem(
                    value: EcoPartnerLayout.grid4,
                    child: Text('4 × 4 grid'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _controller.selectLayout(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_controller.isLoading)
            ...List.generate(3, (_) => const _LoadingCard()),
          if (!_controller.isLoading && _controller.error != null)
            _Message(
              Icons.cloud_off,
              _controller.error!,
              action: 'Retry',
              onPressed: () => _find(),
            ),
          if (!_controller.isLoading && _controller.result != null) ...[
            if (_controller.isLoadingImages) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
              Text(
                'Recommendations ready · loading nearby photos…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            for (final warning in _controller.result!.warnings)
              Card(
                color: const Color(0xFFFFF5D6),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(warning),
                  trailing: IconButton(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            if (shown.isEmpty)
              _Message(
                Icons.eco_outlined,
                'No ${_controller.filter == 'All' ? 'eco partners' : _controller.filter.toLowerCase()} found${_controller.stateFilter == 'All states' ? '' : ' in ${_controller.stateFilter}'} ${_controller.scopeLabel}.',
              ),
            if (shown.isNotEmpty) _resultsView(shown),
            if (_controller.totalPages > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: _controller.currentPage == 0
                        ? null
                        : () =>
                              _controller.goToPage(_controller.currentPage - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Page ${_controller.currentPage + 1} of ${_controller.totalPages}',
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed:
                        _controller.currentPage + 1 >= _controller.totalPages
                        ? null
                        : () =>
                              _controller.goToPage(_controller.currentPage + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
          if (!_controller.isLoading &&
              _controller.result == null &&
              _controller.error == null)
            const _Message(
              Icons.travel_explore,
              'Allow location access for nearby recommendations, or search for a specific place in Malaysia.',
            ),
        ],
      ),
    );
  }

  Widget _resultsView(List<EcoPartner> partners) {
    if (_controller.layout == EcoPartnerLayout.list) {
      return Column(
        children: [
          for (final partner in partners)
            _PartnerCard(partner, onTap: () => _details(partner)),
        ],
      );
    }
    final columns = _controller.layout == EcoPartnerLayout.grid2 ? 2 : 4;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: partners.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: columns == 2 ? 0.72 : 0.58,
      ),
      itemBuilder: (context, index) {
        final partner = partners[index];
        return _PartnerGridCard(
          partner,
          dense: columns == 4,
          onTap: () => _details(partner),
        );
      },
    );
  }

  Future<void> _showFilters() async {
    var selectedFilter = _controller.filter;
    var selectedRadius = _controller.radiusSelection;
    var selectedState = _controller.stateFilter;
    var selectedSort = _controller.sort;
    final stateOptions = <String>{
      'All states',
      ..._controller.availableStates,
      if (_controller.stateFilter != 'All states') _controller.stateFilter,
    }.toList();
    final value = await showModalBottomSheet<_EcoFilterValue>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filter recommendations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      [
                            'All',
                            'Stay',
                            'Dining',
                            'Public Transport',
                            'EV Charging',
                          ]
                          .map(
                            (label) => ChoiceChip(
                              label: Text(label),
                              selected: selectedFilter == label,
                              onSelected: (_) =>
                                  setSheetState(() => selectedFilter = label),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'State',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedState,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: stateOptions
                      .map(
                        (state) =>
                            DropdownMenuItem(value: state, child: Text(state)),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(
                    () => selectedState = value ?? 'All states',
                  ),
                ),
                if (_controller.availableStates.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Search first to discover states from the available results.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Alphabetical order',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Recommended'),
                      selected: selectedSort == EcoPartnerSort.recommended,
                      onSelected: (_) => setSheetState(
                        () => selectedSort = EcoPartnerSort.recommended,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('A → Z'),
                      selected: selectedSort == EcoPartnerSort.nameAscending,
                      onSelected: (_) => setSheetState(
                        () => selectedSort = EcoPartnerSort.nameAscending,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Z → A'),
                      selected: selectedSort == EcoPartnerSort.nameDescending,
                      onSelected: (_) => setSheetState(
                        () => selectedSort = EcoPartnerSort.nameDescending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Distance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      const [
                            (5.0, '5 km'),
                            (10.0, '10 km'),
                            (25.0, '25 km'),
                            (50.0, '50 km'),
                            (0.0, 'All Malaysia'),
                          ]
                          .map(
                            (entry) => ChoiceChip(
                              label: Text(entry.$2),
                              selected: selectedRadius == entry.$1,
                              onSelected: (_) => setSheetState(
                                () => selectedRadius = entry.$1,
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _EcoFilterValue(
                        selectedFilter,
                        selectedRadius,
                        selectedState,
                        selectedSort,
                      ),
                    ),
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value == null || !mounted) return;
    _controller.selectFilter(value.filter);
    _controller.selectState(value.state);
    _controller.selectSort(value.sort);
    await _controller.selectRadius(value.radius, fallbackQuery: _search.text);
  }

  void _details(EcoPartner partner) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcoPartnerDetailScreen(
        partner: partner,
        destinationLabel: _controller.result?.destination.label ?? '',
      ),
    ),
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard(this.partner, {required this.onTap});
  final EcoPartner partner;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFBAD7C4), Color(0xFF315E48)],
              ),
            ),
            child: partner.imageUrl?.isNotEmpty == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      partner.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _PartnerMapPreview(partner, icon: _icon),
                    ),
                  )
                : _PartnerMapPreview(partner, icon: _icon),
          ),
          if (partner.imageSourceName != null) ...[
            const SizedBox(height: 5),
            Text(
              '${partner.imageSourceName}${partner.imageCapturedAt == null ? '' : ' · ${partner.imageCapturedAt!.year}'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: 12),
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
              if (partner.gstcVerified)
                const Icon(Icons.verified, color: Color(0xFF0B684B)),
            ],
          ),
          const SizedBox(height: 5),
          Text(partner.sustainabilityLabel),
          const SizedBox(height: 4),
          Text(
            '${partner.distanceKm.toStringAsFixed(1)} km · ${partner.sourceName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_label(partner.category)} · ${partner.subtype}',
                  style: const TextStyle(color: Color(0xFF806300)),
                ),
              ),
              TextButton(onPressed: onTap, child: const Text('Details →')),
            ],
          ),
        ],
      ),
    ),
  );
  IconData get _icon => switch (partner.category) {
    EcoPartnerCategory.stay => Icons.hotel_outlined,
    EcoPartnerCategory.dining => Icons.restaurant_outlined,
    EcoPartnerCategory.transport =>
      partner.subtype == 'EV charging'
          ? Icons.ev_station_outlined
          : Icons.directions_transit_outlined,
  };
}

class _PartnerGridCard extends StatelessWidget {
  const _PartnerGridCard(
    this.partner, {
    required this.dense,
    required this.onTap,
  });

  final EcoPartner partner;
  final bool dense;
  final VoidCallback onTap;

  IconData get _icon => switch (partner.category) {
    EcoPartnerCategory.stay => Icons.hotel_outlined,
    EcoPartnerCategory.dining => Icons.restaurant_outlined,
    EcoPartnerCategory.transport =>
      partner.subtype == 'EV charging'
          ? Icons.ev_station_outlined
          : Icons.directions_transit_outlined,
  };

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(dense ? 6 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEBE4),
                  borderRadius: BorderRadius.circular(dense ? 7 : 10),
                ),
                child: partner.imageUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(dense ? 7 : 10),
                        child: Image.network(
                          partner.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            _icon,
                            color: const Color(0xFF07513C),
                            size: dense ? 20 : 34,
                          ),
                        ),
                      )
                    : Icon(
                        _icon,
                        color: const Color(0xFF07513C),
                        size: dense ? 20 : 34,
                      ),
              ),
            ),
            SizedBox(height: dense ? 4 : 8),
            Text(
              partner.name,
              maxLines: dense ? 2 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 10 : 14,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF164C3B),
              ),
            ),
            SizedBox(height: dense ? 2 : 4),
            Text(
              dense
                  ? '${partner.distanceKm.toStringAsFixed(1)} km'
                  : '${partner.subtype} · ${partner.distanceKm.toStringAsFixed(1)} km',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dense ? 9 : 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PartnerMapPreview extends StatelessWidget {
  const _PartnerMapPreview(this.partner, {required this.icon});
  final EcoPartner partner;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(partner.latitude, partner.longitude),
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.collab',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(partner.latitude, partner.longitude),
                width: 38,
                height: 38,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B684B),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 14),
          Container(width: 180, height: 18, color: Colors.black12),
          const SizedBox(height: 9),
          Container(width: 120, height: 13, color: Colors.black12),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.icon, this.message, {this.action, this.onPressed});
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
    child: Column(
      children: [
        Icon(icon, size: 44, color: const Color(0xFF547167)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (action != null)
          TextButton(onPressed: onPressed, child: Text(action!)),
      ],
    ),
  );
}

class _EcoFilterValue {
  const _EcoFilterValue(this.filter, this.radius, this.state, this.sort);

  final String filter;
  final double radius;
  final String state;
  final EcoPartnerSort sort;
}

String _label(EcoPartnerCategory category) => switch (category) {
  EcoPartnerCategory.stay => 'Stay',
  EcoPartnerCategory.dining => 'Dining',
  EcoPartnerCategory.transport => 'Transport',
};
