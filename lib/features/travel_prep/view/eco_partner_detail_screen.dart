import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/eco_partner.dart';

class EcoPartnerDetailScreen extends StatelessWidget {
  const EcoPartnerDetailScreen({
    super.key,
    required this.partner,
    required this.destinationLabel,
  });

  final EcoPartner partner;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Partner Details')),
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
            _Pill(
              '${partner.distanceKm.toStringAsFixed(1)} km away',
              Icons.near_me_outlined,
            ),
            if (partner.priceBand?.isNotEmpty == true)
              _Pill(partner.priceBand!, Icons.payments_outlined),
          ],
        ),
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
        if (partner.address.isNotEmpty)
          _section(
            context,
            title: 'Location',
            icon: Icons.location_on_outlined,
            child: Text(partner.address),
          ),
        if (partner.routeNames.isNotEmpty)
          _section(
            context,
            title: 'Available routes',
            icon: Icons.route_outlined,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: partner.routeNames
                  .map((route) => Chip(label: Text(route)))
                  .toList(),
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
              errorBuilder: (_, __, ___) => _heroFallback(context),
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
