import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/eco_partner.dart';
import '../model/eco_partner_repository.dart';

class EcoPartnersScreen extends StatefulWidget {
  const EcoPartnersScreen({super.key});
  @override
  State<EcoPartnersScreen> createState() => _EcoPartnersScreenState();
}

class _EcoPartnersScreenState extends State<EcoPartnersScreen> {
  final _repository = EcoPartnerRepository();
  final _search = TextEditingController();
  EcoPartnerSearchResult? _result;
  String _filter = 'All';
  double _radiusSelection = 10;
  String? _error;
  bool _loading = false;

  double? get _radiusKm => _radiusSelection == 0 ? null : _radiusSelection;
  String get _scopeLabel => _radiusKm == null
      ? 'across Malaysia'
      : 'within ${_radiusSelection.round()} km';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find({bool refresh = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.searchDestination(
        _search.text,
        refresh: refresh,
        radiusKm: _radiusKm,
      );
      if (mounted) setState(() => _result = value);
    } on EcoSearchException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Search failed. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const EcoSearchException('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 3),
      );
      final value = await _repository.searchCoordinates(
        EcoDestination(
          'Current location',
          position.latitude,
          position.longitude,
        ),
        radiusKm: _radiusKm,
      );
      if (mounted) {
        _search.text = 'Current location';
        setState(() => _result = value);
      }
    } on EcoSearchException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not retrieve your current location.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry() async {
    final destination = _result?.destination;
    if (destination == null) {
      await _find(refresh: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.searchCoordinates(
        destination,
        refresh: true,
        radiusKm: _radiusKm,
      );
      if (mounted) setState(() => _result = value);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Retry failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = (_result?.partners ?? const <EcoPartner>[])
        .where(
          (p) => _filter == 'All' || p.category.name == _filter.toLowerCase(),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Assistant')),
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
            'Find evidence-based stays, plant-friendly dining and low-carbon infrastructure $_scopeLabel.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _find(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search a destination in Malaysia...',
              suffixIcon: IconButton(
                onPressed: _loading ? null : () => _find(),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : _locate,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use current location'),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.radar, size: 20),
              const SizedBox(width: 8),
              const Text('Search distance'),
              const Spacer(),
              DropdownButton<double>(
                value: _radiusSelection,
                items: const [
                  DropdownMenuItem(value: 5.0, child: Text('5 km')),
                  DropdownMenuItem(value: 10.0, child: Text('10 km')),
                  DropdownMenuItem(value: 25.0, child: Text('25 km')),
                  DropdownMenuItem(value: 50.0, child: Text('50 km')),
                  DropdownMenuItem(value: 0.0, child: Text('All Malaysia')),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _radiusSelection = value);
                        if (_result != null) _retry();
                      },
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: ['All', 'Stay', 'Dining', 'Transport']
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: _filter == label,
                    onSelected: (_) => setState(() => _filter = label),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_loading) ...List.generate(3, (_) => const _LoadingCard()),
          if (!_loading && _error != null)
            _Message(
              Icons.cloud_off,
              _error!,
              action: 'Retry',
              onPressed: () => _find(),
            ),
          if (!_loading && _result != null) ...[
            for (final warning in _result!.warnings)
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
                'No ${_filter == 'All' ? 'eco partners' : _filter.toLowerCase()} found $_scopeLabel.',
              ),
            for (final partner in shown)
              _PartnerCard(partner, onTap: () => _details(partner)),
          ],
          if (!_loading && _result == null && _error == null)
            const _Message(
              Icons.travel_explore,
              'Search a destination to see live recommendations and their data sources.',
            ),
        ],
      ),
    );
  }

  void _details(EcoPartner p) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text('${p.subtype} · ${p.distanceKm.toStringAsFixed(1)} km away'),
            const SizedBox(height: 12),
            Text(
              p.sustainabilityLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B684B),
              ),
            ),
            Text(p.evidence),
            if (p.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(p.address),
            ],
            if (p.routeNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Routes: ${p.routeNames.join(', ')}'),
            ],
            if (p.chargerDetails?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(p.chargerDetails!),
            ],
            const SizedBox(height: 14),
            Text(
              'Source: ${p.sourceName} · Updated ${p.lastUpdated.day}/${p.lastUpdated.month}/${p.lastUpdated.year}',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (p.sourceUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _open(p.sourceUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View source'),
                  ),
                if (p.imageSourceUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _open(p.imageSourceUrl!),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('View Mapillary image'),
                  ),
                if (p.website?.isNotEmpty == true)
                  OutlinedButton(
                    onPressed: () => _open(p.website!),
                    child: const Text('Website'),
                  ),
                if (p.category == EcoPartnerCategory.dining)
                  OutlinedButton(
                    onPressed: () => _happyCow(p),
                    child: const Text('Search on HappyCow ↗'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
    }
  }

  void _happyCow(EcoPartner p) => _open(
    Uri.https('www.happycow.net', '/searchmap', {
      'location': '${p.name}, ${_result?.destination.label ?? ''}',
    }).toString(),
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
                      errorBuilder: (_, __, ___) =>
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

String _label(EcoPartnerCategory category) => switch (category) {
  EcoPartnerCategory.stay => 'Stay',
  EcoPartnerCategory.dining => 'Dining',
  EcoPartnerCategory.transport => 'Transport',
};
