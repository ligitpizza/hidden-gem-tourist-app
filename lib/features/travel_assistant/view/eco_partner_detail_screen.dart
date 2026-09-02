import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/shell_routes.dart';
import '../../itinerary_planning/model/transitous_routing_service.dart';
import '../../itinerary_planning/view/widgets/route_map_view.dart';
import '../../../shared/widgets/app_header.dart';
import '../model/eco_partner.dart';
import '../model/eco_partner_routing_service.dart';
import '../model/saved_eco_partners_store.dart';

class EcoPartnerDetailScreen extends StatelessWidget {
  const EcoPartnerDetailScreen({
    super.key,
    required this.partner,
    required this.destinationLabel,
    this.showDistance = false,
    this.outsideRadiusKm,
  });

  final EcoPartner partner;
  final String destinationLabel;
  final bool showDistance;
  final double? outsideRadiusKm;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader.pushed(
      title: 'Partner Details',
      fallbackPath: ShellRoutes.travelAssistant,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _hero(context),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                partner.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF003B2B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (partner.gstcVerified)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Icon(Icons.verified, color: Color(0xFF087653)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(_categoryLabel(partner.category), _categoryIcon),
            _Pill(partner.subtype, _categoryIcon),
            if (showDistance)
              _Pill(
                '${partner.distanceKm.toStringAsFixed(1)} km away',
                Icons.near_me_outlined,
              ),
            if (outsideRadiusKm != null)
              _Pill(
                'Outside your ${outsideRadiusKm!.round()} km area',
                Icons.location_off_outlined,
              ),
            if (partner.priceBand?.isNotEmpty == true)
              _Pill(partner.priceBand!, Icons.payments_outlined),
          ],
        ),
        const SizedBox(height: 12),
        _SaveEcoPartnerButton(partner: partner),
        const SizedBox(height: 22),
        _section(
          context,
          title: 'About this partner',
          icon: Icons.info_outline,
          child: Text(_description),
        ),
        _section(
          context,
          title: 'Sustainability information',
          icon: Icons.eco_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partner.sustainabilityLabel,
                style: const TextStyle(
                  color: Color(0xFF087653),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(partner.evidence),
            ],
          ),
        ),
        _section(
          context,
          title: 'Location & directions',
          icon: Icons.location_on_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partner.address.isEmpty
                    ? 'Location available on the map'
                    : partner.address,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              _EcoPartnerRouteGuide(partner: partner),
            ],
          ),
        ),
        if (partner.chargerDetails?.isNotEmpty == true)
          _section(
            context,
            title: 'Charging details',
            icon: Icons.ev_station_outlined,
            child: Text(partner.chargerDetails!),
          ),
        _section(
          context,
          title: 'Data information',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provider: ${partner.sourceName}'),
              const SizedBox(height: 4),
              Text('Last updated: ${_date(partner.lastUpdated)}'),
              if (partner.imageSourceName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Image: ${partner.imageSourceName}${partner.imageCapturedAt == null ? '' : ' (${partner.imageCapturedAt!.year})'}',
                ),
              ],
            ],
          ),
        ),
        if (partner.website?.isNotEmpty == true ||
            partner.category == EcoPartnerCategory.dining) ...[
          const SizedBox(height: 4),
          if (partner.website?.isNotEmpty == true)
            FilledButton.icon(
              onPressed: () => _open(context, partner.website!),
              icon: const Icon(Icons.language),
              label: const Text('Visit partner website'),
            ),
          if (partner.category == EcoPartnerCategory.dining) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _open(
                context,
                Uri.https('www.happycow.net', '/searchmap', {
                  'location': '$destinationLabel, ${partner.name}',
                }).toString(),
              ),
              icon: const Icon(Icons.restaurant_outlined),
              label: const Text('Search on HappyCow'),
            ),
          ],
        ],
      ],
    ),
  );

  Widget _hero(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: partner.imageUrl?.isNotEmpty == true
          ? Image.network(
              partner.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _heroFallback(context),
            )
          : _heroFallback(context),
    ),
  );

  Widget _heroFallback(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD9EEE4), Color(0xFF356B55)],
      ),
    ),
    child: Center(child: Icon(_categoryIcon, size: 72, color: Colors.white)),
  );

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: const Color(0xFF087653)),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );

  String get _description => switch (partner.category) {
    EcoPartnerCategory.stay =>
      '${partner.name} is a nearby accommodation listed for its documented sustainability certification information. Review the evidence and current verification details below before booking.',
    EcoPartnerCategory.dining =>
      '${partner.name} is a nearby ${partner.subtype.toLowerCase()} with plant-friendly information recorded by the listed data provider. Its classification is based on the available explicit dietary tags.',
    EcoPartnerCategory.transport when partner.subtype == 'EV charging' =>
      '${partner.name} provides nearby electric-vehicle charging infrastructure. Availability, access and connector information may change, so confirm the displayed details when you arrive.',
    EcoPartnerCategory.transport =>
      '${partner.name} is a nearby public-transport stop or station serving the listed routes. It can support lower-car travel around your selected destination.',
  };

  IconData get _categoryIcon => switch (partner.category) {
    EcoPartnerCategory.stay => Icons.hotel_outlined,
    EcoPartnerCategory.dining => Icons.restaurant_outlined,
    EcoPartnerCategory.transport when partner.subtype == 'EV charging' =>
      Icons.ev_station_outlined,
    EcoPartnerCategory.transport => Icons.directions_transit_outlined,
  };

  Future<void> _open(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}

class _SaveEcoPartnerButton extends StatefulWidget {
  const _SaveEcoPartnerButton({required this.partner});

  final EcoPartner partner;

  @override
  State<_SaveEcoPartnerButton> createState() => _SaveEcoPartnerButtonState();
}

class _SaveEcoPartnerButtonState extends State<_SaveEcoPartnerButton> {
  @override
  void initState() {
    super.initState();
    SavedEcoPartnersStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SavedEcoPartnersStore.instance,
    builder: (context, _) {
      final store = SavedEcoPartnersStore.instance;
      final saved = store.isSaved(widget.partner.id);
      final busy = store.isBusy(widget.partner.id);
      return SizedBox(
        width: double.infinity,
        child: saved
            ? OutlinedButton.icon(
                onPressed: busy ? null : _toggle,
                icon: const Icon(Icons.bookmark),
                label: const Text('Saved for packing'),
              )
            : FilledButton.tonalIcon(
                onPressed: busy ? null : _toggle,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save Eco Partner'),
              ),
      );
    },
  );

  Future<void> _toggle() async {
    final saved = await SavedEcoPartnersStore.instance.toggle(widget.partner);
    if (!mounted) return;
    final error = SavedEcoPartnersStore.instance.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (saved
                  ? 'Saved for your profile and packing checklist.'
                  : 'Removed from saved Eco Partners.'),
        ),
      ),
    );
  }
}

enum _RouteMode { walking, publicTransit, evCar }

class _EcoPartnerRouteGuide extends StatefulWidget {
  const _EcoPartnerRouteGuide({required this.partner});

  final EcoPartner partner;

  @override
  State<_EcoPartnerRouteGuide> createState() => _EcoPartnerRouteGuideState();
}

class _EcoPartnerRouteGuideState extends State<_EcoPartnerRouteGuide> {
  final _routingService = EcoPartnerRoutingService();
  final _transitService = TransitousRoutingService();
  _RouteMode _mode = _RouteMode.walking;
  LatLng? _origin;
  EcoPartnerRoute? _route;
  TransitRoute? _transitRoute;
  String? _error;
  bool _loading = false;

  Future<void> _loadRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _route = null;
      _transitRoute = null;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const EcoPartnerRouteException(
          'Location permission is required.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const EcoPartnerRouteException(
          'Location permission is disabled. Enable it in device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
      final origin = LatLng(position.latitude, position.longitude);
      final destination = LatLng(
        widget.partner.latitude,
        widget.partner.longitude,
      );
      final waypoints = [origin, destination];
      EcoPartnerRoute? route;
      TransitRoute? transitRoute;
      switch (_mode) {
        case _RouteMode.walking:
          route = await _routingService.walkingRoute(waypoints);
          break;
        case _RouteMode.evCar:
          route = await _routingService.drivingRoute(waypoints);
          break;
        case _RouteMode.publicTransit:
          transitRoute = await _transitService.plan(origin, destination);
          if (transitRoute == null) {
            throw const EcoPartnerRouteException(
              'No public-transit itinerary is available for this journey.',
            );
          }
          break;
      }

      if (!mounted) return;
      setState(() {
        _origin = origin;
        _route = route;
        _transitRoute = transitRoute;
      });
    } on EcoPartnerRouteException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not calculate a route. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeMode(_RouteMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (_route != null || _transitRoute != null || _error != null) {
      await _loadRoute();
    }
  }

  Future<void> _planTransitRoute() async {
    setState(() => _mode = _RouteMode.publicTransit);
    await _loadRoute();
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final transitRoute = _transitRoute;
    final origin = _origin;
    final destination = LatLng(
      widget.partner.latitude,
      widget.partner.longitude,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.directions_walk, size: 18),
              label: const Text('Walking'),
              selected: _mode == _RouteMode.walking,
              onSelected: _loading
                  ? null
                  : (_) => _changeMode(_RouteMode.walking),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.directions_transit, size: 18),
              label: const Text('Public transit'),
              selected: _mode == _RouteMode.publicTransit,
              onSelected: _loading
                  ? null
                  : (_) => _changeMode(_RouteMode.publicTransit),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.electric_car_outlined, size: 18),
              label: const Text('EV car'),
              selected: _mode == _RouteMode.evCar,
              onSelected: _loading
                  ? null
                  : (_) => _changeMode(_RouteMode.evCar),
            ),
          ],
        ),
        if (widget.partner.transitRoutes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Transit routes serving this stop',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a route to plan a public-transit journey here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.partner.transitRoutes
                .map(
                  (route) => ActionChip(
                    avatar: const Icon(Icons.directions_bus_outlined, size: 17),
                    label: Text(route.displayLabel),
                    tooltip: 'Plan a journey to this stop',
                    onPressed: _loading ? null : _planTransitRoute,
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 10),
        if (route == null && transitRoute == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _loadRoute,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route_outlined),
              label: Text(_loading ? 'Calculating route...' : 'Show route'),
            ),
          )
        else ...[
          RouteMapView(
            height: 260,
            interactive: true,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            markers: [
              MapMarkerSpec(
                point: origin!,
                color: const Color(0xFF1976D2),
                icon: Icons.my_location,
              ),
              if (transitRoute != null)
                for (final leg in transitRoute.legs.where(
                  (leg) => leg.mode != 'WALK',
                )) ...[
                  MapMarkerSpec(
                    point: leg.from,
                    color: const Color(0xFF8A6800),
                    icon: Icons.directions_transit,
                  ),
                  MapMarkerSpec(
                    point: leg.to,
                    color: const Color(0xFF8A6800),
                    icon: Icons.directions_transit,
                  ),
                ],
              MapMarkerSpec(
                point: destination,
                color: const Color(0xFF087653),
                icon: Icons.location_on,
              ),
            ],
            polylines: [
              MapPolylineSpec(
                points: route?.polyline ?? transitRoute!.polyline,
                color: const Color(0xFF087653),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.straighten, size: 18),
              const SizedBox(width: 5),
              Text(
                '${(route?.distanceKm ?? transitRoute!.distanceKm).toStringAsFixed(1)} km',
              ),
              const SizedBox(width: 18),
              const Icon(Icons.schedule, size: 18),
              const SizedBox(width: 5),
              Text(
                _durationLabel(
                  route?.durationMinutes ?? transitRoute!.durationMinutes,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh route',
                onPressed: _loading ? null : _loadRoute,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (transitRoute != null)
            for (final leg in transitRoute.legs)
              _JourneyStep(
                icon: _transitIcon(leg.mode),
                title: leg.mode == 'WALK'
                    ? 'Walk to ${leg.toName}'
                    : '${leg.agencyName ?? _modeLabel(leg.mode)}${leg.routeName == null ? '' : ' ${leg.routeName}'}',
                subtitle: leg.mode == 'WALK'
                    ? '${leg.durationMinutes} min'
                    : '${leg.fromName} → ${leg.toName}${leg.headsign == null ? '' : '\nTowards ${leg.headsign}'}',
              ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          _mode == _RouteMode.publicTransit
              ? 'Transit itinerary from Transitous and Malaysian GTFS feeds.'
              : 'Map and route data from OpenStreetMap and OSRM.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
  }

  static IconData _transitIcon(String mode) => switch (mode) {
    'BUS' => Icons.directions_bus_outlined,
    'RAIL' || 'TRAIN' || 'SUBWAY' || 'TRAM' => Icons.train_outlined,
    _ => Icons.directions_walk,
  };

  static String _modeLabel(String mode) => switch (mode) {
    'BUS' => 'Bus',
    'RAIL' || 'TRAIN' => 'Rail',
    'SUBWAY' => 'MRT/LRT',
    'TRAM' => 'Tram',
    _ => mode,
  };
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(icon, color: const Color(0xFF087653)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFE5F4EC),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF07513C)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

String _categoryLabel(EcoPartnerCategory category) => switch (category) {
  EcoPartnerCategory.stay => 'Stay',
  EcoPartnerCategory.dining => 'Dining',
  EcoPartnerCategory.transport => 'Transport',
};
