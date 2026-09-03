import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router/shell_routes.dart';
import '../../../shared/widgets/app_header.dart';
import '../controller/eco_partner_controller.dart';
import '../model/eco_partner.dart';
import 'eco_partner_detail_screen.dart';

class EcoPartnersScreen extends StatefulWidget {
  const EcoPartnersScreen({super.key, this.controller});

  final EcoPartnerController? controller;

  @override
  State<EcoPartnersScreen> createState() => _EcoPartnersScreenState();
}

class _EcoPartnersScreenState extends State<EcoPartnersScreen> {
  late final EcoPartnerController _controller;
  late final bool _ownsController;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  bool _showingHomeSectionResults = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? EcoPartnerController();
    _controller.addListener(_refresh);
    _search.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.loadInitialRecommendations(),
    );
  }

  void _onSearchTextChanged() {
    if (!mounted) return;
    setState(() {});
    if (_search.text.trim().isEmpty &&
        _controller.activeSearchTerm.isNotEmpty) {
      _controller.clearSearch();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    _search.removeListener(_onSearchTextChanged);
    _search.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _find({bool refresh = false}) {
    FocusScope.of(context).unfocus();
    return _controller.search(_search.text, refresh: refresh);
  }

  Future<void> _selectSuggestion(EcoPartner partner) {
    FocusScope.of(context).unfocus();
    return _controller.searchSuggestion(partner);
  }

  void _clearSearch() {
    _search.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _retry() => _controller.retry(fallbackQuery: _search.text);

  @override
  Widget build(BuildContext context) {
    final shown = _controller.visiblePartners;
    final showSectionedHome = _controller.showSectionedHome;
    return Scaffold(
      appBar: AppHeader.pushed(
        title: 'Eco Partners',
        fallbackPath: ShellRoutes.travelAssistant,
        onBack: _showingHomeSectionResults ? _returnToSectionedHome : null,
      ),
      body: ListView(
        key: const ValueKey('eco_partner_main_scroll'),
        controller: _scrollController,
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
            'Browse sustainable stays, dining, transit and EV partners ${_controller.scopeLabel}, or search by Eco Partner name.',
          ),
          const SizedBox(height: 18),
          RawAutocomplete<EcoPartner>(
            textEditingController: _search,
            focusNode: _searchFocus,
            displayStringForOption: (partner) => partner.name,
            optionsBuilder: (value) => _controller.suggestionsFor(value.text),
            onSelected: _selectSuggestion,
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) =>
                    TextField(
                      controller: textController,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _find(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search an Eco Partner, e.g. Somerset...',
                        suffixIcon: _search.text.isEmpty
                            ? IconButton(
                                tooltip: 'Search Eco Partners',
                                onPressed: _controller.isLoading
                                    ? null
                                    : () => _find(),
                                icon: const Icon(Icons.arrow_forward),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: _controller.isLoading
                                        ? null
                                        : _clearSearch,
                                    icon: const Icon(Icons.close),
                                  ),
                                  IconButton(
                                    tooltip: 'Search Eco Partners',
                                    onPressed: _controller.isLoading
                                        ? null
                                        : () => _find(),
                                    icon: const Icon(Icons.arrow_forward),
                                  ),
                                ],
                              ),
                      ),
                    ),
            optionsViewBuilder: (context, onSelected, options) {
              final suggestions = options.toList();
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 320,
                      maxWidth: MediaQuery.sizeOf(context).width - 32,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final partner = suggestions[index];
                        return ListTile(
                          leading: Icon(_partnerIcon(partner)),
                          title: Text(
                            partner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_label(partner.category)} · ${partner.address}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onSelected(partner),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (_controller.isUsingCurrentLocation ||
                        (_controller.isExplicitSearch &&
                            _controller.hasUserLocation))
                      'Current location',
                    _controller.scopeLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Filter recommendations',
                visualDensity: VisualDensity.compact,
                onPressed: _controller.isLoading ? null : _showFilters,
                icon: const Icon(Icons.tune, size: 20),
              ),
              const SizedBox(width: 6),
              if (!showSectionedHome)
                PopupMenuButton<EcoPartnerLayout>(
                  tooltip: 'Change results layout',
                  initialValue: _controller.layout,
                  onSelected: _controller.selectLayout,
                  icon: Icon(switch (_controller.layout) {
                    EcoPartnerLayout.list => Icons.view_list_outlined,
                    EcoPartnerLayout.grid2 => Icons.grid_view_outlined,
                    EcoPartnerLayout.grid4 => Icons.apps_outlined,
                  }),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: EcoPartnerLayout.list,
                      child: ListTile(
                        leading: Icon(Icons.view_list_outlined),
                        title: Text('List'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: EcoPartnerLayout.grid2,
                      child: ListTile(
                        leading: Icon(Icons.grid_view_outlined),
                        title: Text('Comfortable grid'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: EcoPartnerLayout.grid4,
                      child: ListTile(
                        leading: Icon(Icons.apps_outlined),
                        title: Text('Compact grid'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
              onPressed: _controller.activeSearchTerm.isEmpty
                  ? () => _controller.loadInitialRecommendations(refresh: true)
                  : () => _find(refresh: true),
            ),
          if (!_controller.isLoading && _controller.result != null) ...[
            if (_controller.isExplicitSearch) ...[
              _SearchScopeNotice(radiusKm: _controller.activeNearbyRadius),
              const SizedBox(height: 10),
            ],
            if (_controller.isLoadingImages) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
              Text(
                'Recommendations ready · loading partner photos…',
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
            if (showSectionedHome)
              _sectionedHome()
            else ...[
              if (shown.isEmpty)
                _Message(
                  Icons.eco_outlined,
                  _controller.activeSearchTerm.isEmpty
                      ? 'No ${_controller.filter == 'All' ? 'eco partners' : _controller.filter.toLowerCase()} found ${_controller.scopeLabel}.'
                      : 'No Eco Partner names containing "${_controller.activeSearchTerm}" found ${_controller.scopeLabel}.',
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
                          : () => _controller.goToPage(
                              _controller.currentPage - 1,
                            ),
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
                          : () => _controller.goToPage(
                              _controller.currentPage + 1,
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ],
          ],
          if (!_controller.isLoading &&
              _controller.result == null &&
              _controller.error == null)
            const _Message(
              Icons.travel_explore,
              'Loading recommendations across Malaysia. You can also search for a specific Eco Partner.',
            ),
        ],
      ),
    );
  }

  Widget _sectionedHome() => Column(
    children: [
      for (final section in EcoPartnerHomeSection.values)
        _HomePartnerSection(
          section: section,
          title: _homeSectionTitle(section),
          icon: _homeSectionIcon(section),
          partners: _controller.partnersForHomeSection(section),
          showDistance: _controller.showsUserDistance,
          onTap: _details,
          onMore: section == EcoPartnerHomeSection.recommended
              ? null
              : () => _showAllForHomeSection(section),
        ),
    ],
  );

  void _showAllForHomeSection(EcoPartnerHomeSection section) {
    setState(() => _showingHomeSectionResults = true);
    _controller.showAllForHomeSection(section);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _returnToSectionedHome() {
    setState(() => _showingHomeSectionResults = false);
    _controller.selectFilter('All');
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Widget _resultsView(List<EcoPartner> partners) {
    if (_controller.layout == EcoPartnerLayout.list) {
      return Column(
        children: [
          for (final partner in partners)
            _PartnerCard(
              partner,
              showDistance: _controller.showsUserDistance,
              outsideRadiusKm: _controller.isOutsideBrowseRadius(partner)
                  ? _controller.activeNearbyRadius
                  : null,
              onTap: () => _details(partner),
            ),
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
          showDistance: _controller.showsUserDistance,
          outsideRadiusKm: _controller.isOutsideBrowseRadius(partner)
              ? _controller.activeNearbyRadius
              : null,
          onTap: () => _details(partner),
        );
      },
    );
  }

  Future<void> _showFilters() async {
    var selectedFilter = _controller.filter;
    var selectedRadius = _controller.radiusSelection;
    var selectedState = _controller.stateFilter;
    var selectedAreaMode = _controller.areaMode;
    var selectedSort = _controller.sort;
    var currentLocationRequested = false;
    const radiusSteps = [5.0, 10.0, 25.0, 50.0];
    var radiusStep = radiusSteps.indexOf(selectedRadius).toDouble();
    if (radiusStep < 0) radiusStep = 1;
    final stateOptions = ['All Malaysia', ..._controller.availableStates];
    final value = await showModalBottomSheet<_EcoFilterValue>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filter recommendations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Search area',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<EcoPartnerAreaMode>(
                  segments: const [
                    ButtonSegment(
                      value: EcoPartnerAreaMode.nearby,
                      icon: Icon(Icons.near_me_outlined),
                      label: Text('Nearby'),
                    ),
                    ButtonSegment(
                      value: EcoPartnerAreaMode.statewide,
                      icon: Icon(Icons.map_outlined),
                      label: Text('Statewide'),
                    ),
                  ],
                  selected: {selectedAreaMode},
                  onSelectionChanged: (selection) =>
                      setSheetState(() => selectedAreaMode = selection.first),
                ),
                if (selectedAreaMode == EcoPartnerAreaMode.nearby) ...[
                  const SizedBox(height: 10),
                  ChoiceChip(
                    avatar: const Icon(Icons.my_location, size: 17),
                    label: const Text('Use current location'),
                    selected:
                        _controller.isUsingCurrentLocation ||
                        currentLocationRequested,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) =>
                        setSheetState(() => currentLocationRequested = true),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Distance',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${selectedRadius.round()} km',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: radiusStep,
                    min: 0,
                    max: 3,
                    divisions: 3,
                    label: '${selectedRadius.round()} km',
                    onChanged: (value) => setSheetState(() {
                      radiusStep = value;
                      selectedRadius = radiusSteps[value.round()];
                    }),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('5 km'),
                        Text('10'),
                        Text('25'),
                        Text('50'),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedState,
                    decoration: const InputDecoration(
                      labelText: 'State or nationwide',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: stateOptions
                        .map(
                          (state) => DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setSheetState(
                      () => selectedState = value ?? 'All Malaysia',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
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
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) =>
                                  setSheetState(() => selectedFilter = label),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
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
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setSheetState(
                        () => selectedSort = EcoPartnerSort.recommended,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('A → Z'),
                      selected: selectedSort == EcoPartnerSort.nameAscending,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setSheetState(
                        () => selectedSort = EcoPartnerSort.nameAscending,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Z → A'),
                      selected: selectedSort == EcoPartnerSort.nameDescending,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setSheetState(
                        () => selectedSort = EcoPartnerSort.nameDescending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _EcoFilterValue(
                        selectedFilter,
                        selectedAreaMode,
                        selectedRadius,
                        selectedState,
                        selectedSort,
                        currentLocationRequested &&
                            selectedAreaMode == EcoPartnerAreaMode.nearby,
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
    if (_controller.isExplicitSearch) {
      _search.clear();
      await _controller.clearSearch();
    }
    _controller.selectFilter(value.filter);
    _controller.selectSort(value.sort);
    await _controller.applySearchArea(
      mode: value.areaMode,
      radius: value.radius,
      state: value.state,
      fallbackQuery: _search.text,
      useCurrentLocation: value.useCurrentLocation,
    );
  }

  void _details(EcoPartner partner) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcoPartnerDetailScreen(
        partner: partner,
        destinationLabel: _controller.result?.destination.label ?? '',
        fallbackPath: ShellRoutes.ecoPartners,
        showDistance: _controller.showsUserDistance,
        outsideRadiusKm: _controller.isOutsideBrowseRadius(partner)
            ? _controller.activeNearbyRadius
            : null,
      ),
    ),
  );
}

class _HomePartnerSection extends StatelessWidget {
  const _HomePartnerSection({
    required this.section,
    required this.title,
    required this.icon,
    required this.partners,
    required this.showDistance,
    required this.onTap,
    required this.onMore,
  });

  final EcoPartnerHomeSection section;
  final String title;
  final IconData icon;
  final List<EcoPartner> partners;
  final bool showDistance;
  final ValueChanged<EcoPartner> onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 21, color: const Color(0xFF0B684B)),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (partners.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No $title available for this search area.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          SizedBox(
            height: 222,
            child: ListView.separated(
              key: ValueKey('eco_partner_home_list_${section.name}'),
              scrollDirection: Axis.horizontal,
              itemCount: partners.length + (onMore == null ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == partners.length) {
                  return _HomeMoreCard(
                    section: section,
                    title: title,
                    icon: icon,
                    onTap: onMore!,
                  );
                }
                final partner = partners[index];
                return _HomePartnerCard(
                  partner: partner,
                  showDistance: showDistance,
                  onTap: () => onTap(partner),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _HomeMoreCard extends StatelessWidget {
  const _HomeMoreCard({
    required this.section,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final EcoPartnerHomeSection section;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('eco_partner_more_${section.name}'),
    width: 205,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFFF1F5F2),
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'View all $title Eco Partners',
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFDDEBE4),
                  child: Icon(icon, color: const Color(0xFF07513C), size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'More',
                  style: TextStyle(
                    color: Color(0xFF164C3B),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF07513C),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _HomePartnerCard extends StatelessWidget {
  const _HomePartnerCard({
    required this.partner,
    required this.showDistance,
    required this.onTap,
  });

  final EcoPartner partner;
  final bool showDistance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 205,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 92,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: partner.imageUrl?.isNotEmpty == true
                      ? Image.network(
                          partner.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _HomePartnerPlaceholder(partner: partner),
                        )
                      : _HomePartnerPlaceholder(partner: partner),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                partner.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF164C3B),
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${_label(partner.category)} · ${partner.subtype}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF806300), fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                _partnerLocationText(partner, showDistance: showDistance),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomePartnerPlaceholder extends StatelessWidget {
  const _HomePartnerPlaceholder({required this.partner});

  final EcoPartner partner;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDDEBE4), Color(0xFF9FC6AF)],
      ),
    ),
    child: Center(
      child: Icon(
        _partnerIcon(partner),
        size: 36,
        color: const Color(0xFF07513C),
      ),
    ),
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard(
    this.partner, {
    required this.showDistance,
    required this.outsideRadiusKm,
    required this.onTap,
  });
  final EcoPartner partner;
  final bool showDistance;
  final double? outsideRadiusKm;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
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
            if (outsideRadiusKm != null) ...[
              const SizedBox(height: 7),
              _OutsideRadiusBadge(radiusKm: outsideRadiusKm!),
            ],
            const SizedBox(height: 5),
            Text(partner.sustainabilityLabel),
            const SizedBox(height: 4),
            Text(
              '${_partnerLocationText(partner, showDistance: showDistance)} · ${partner.sourceName}',
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
    required this.showDistance,
    required this.outsideRadiusKm,
    required this.onTap,
  });

  final EcoPartner partner;
  final bool dense;
  final bool showDistance;
  final double? outsideRadiusKm;
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
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
                  if (outsideRadiusKm != null)
                    Positioned(
                      left: 3,
                      right: 3,
                      top: 3,
                      child: _OutsideRadiusBadge(
                        radiusKm: outsideRadiusKm!,
                        dense: dense,
                      ),
                    ),
                ],
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
              showDistance
                  ? dense
                        ? '${partner.distanceKm.toStringAsFixed(1)} km'
                        : '${partner.subtype} · ${partner.distanceKm.toStringAsFixed(1)} km'
                  : dense
                  ? _partnerAddress(partner)
                  : '${partner.subtype} · ${_partnerAddress(partner)}',
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

class _SearchScopeNotice extends StatelessWidget {
  const _SearchScopeNotice({required this.radiusKm});

  final double? radiusKm;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: const Color(0xFFE7F2EC),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 19, color: Color(0xFF07513C)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              radiusKm == null
                  ? 'Showing Eco Partner name matches across Malaysia. Your browse filters are paused for this search.'
                  : 'Showing Eco Partner name matches across Malaysia. Your ${radiusKm!.round()} km nearby filter is paused for this search.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _OutsideRadiusBadge extends StatelessWidget {
  const _OutsideRadiusBadge({required this.radiusKm, this.dense = false});

  final double radiusKm;
  final bool dense;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 7,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5B5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Outside your ${radiusKm.round()} km area',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF6D4700),
          fontSize: dense ? 7 : 11,
          fontWeight: FontWeight.w700,
        ),
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
  const _EcoFilterValue(
    this.filter,
    this.areaMode,
    this.radius,
    this.state,
    this.sort,
    this.useCurrentLocation,
  );

  final String filter;
  final EcoPartnerAreaMode areaMode;
  final double radius;
  final String state;
  final EcoPartnerSort sort;
  final bool useCurrentLocation;
}

String _label(EcoPartnerCategory category) => switch (category) {
  EcoPartnerCategory.stay => 'Stay',
  EcoPartnerCategory.dining => 'Dining',
  EcoPartnerCategory.transport => 'Transport',
};

String _homeSectionTitle(EcoPartnerHomeSection section) => switch (section) {
  EcoPartnerHomeSection.recommended => 'Recommended for You',
  EcoPartnerHomeSection.hotel => 'Hotels',
  EcoPartnerHomeSection.dining => 'Dining',
  EcoPartnerHomeSection.transport => 'Transport (MRT, LRT, etc.)',
  EcoPartnerHomeSection.ev => 'EV Charging',
};

IconData _homeSectionIcon(EcoPartnerHomeSection section) => switch (section) {
  EcoPartnerHomeSection.recommended => Icons.recommend_outlined,
  EcoPartnerHomeSection.hotel => Icons.hotel_outlined,
  EcoPartnerHomeSection.dining => Icons.restaurant_outlined,
  EcoPartnerHomeSection.transport => Icons.directions_transit_outlined,
  EcoPartnerHomeSection.ev => Icons.ev_station_outlined,
};

String _partnerAddress(EcoPartner partner) {
  final address = partner.address.trim();
  if (address.isNotEmpty) return address;
  return partner.category == EcoPartnerCategory.transport
      ? '${partner.name}, Malaysia'
      : 'Address unavailable';
}

String _partnerLocationText(EcoPartner partner, {required bool showDistance}) =>
    showDistance
    ? '${partner.distanceKm.toStringAsFixed(1)} km away'
    : _partnerAddress(partner);

IconData _partnerIcon(EcoPartner partner) => switch (partner.category) {
  EcoPartnerCategory.stay => Icons.hotel_outlined,
  EcoPartnerCategory.dining => Icons.restaurant_outlined,
  EcoPartnerCategory.transport =>
    partner.subtype == 'EV charging'
        ? Icons.ev_station_outlined
        : Icons.directions_transit_outlined,
};
