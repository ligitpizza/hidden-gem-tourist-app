import 'package:flutter/material.dart';

import '../../model/eco_partner.dart';

class EcoPartnerImage extends StatelessWidget {
  const EcoPartnerImage({
    super.key,
    required this.partner,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.cacheWidth,
    this.placeholderIconSize = 38,
    this.showPlaceholderLabel = true,
  });

  final EcoPartner partner;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final int? cacheWidth;
  final double placeholderIconSize;
  final bool showPlaceholderLabel;

  @override
  Widget build(BuildContext context) {
    final legacyMapillary = ecoPartnerImageIsLegacyMapillary(
      imageUrl: partner.imageUrl,
      imageSourceName: partner.imageSourceName,
      imageSourceUrl: partner.imageSourceUrl,
    );
    final imageUrl = ecoPartnerSafeImageValue(
      partner.imageUrl,
      isLegacyMapillary: legacyMapillary,
    );
    final uri = Uri.tryParse(imageUrl ?? '');
    final canLoad =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    final fallback = EcoPartnerImagePlaceholder(
      partner: partner,
      iconSize: placeholderIconSize,
      showLabel: showPlaceholderLabel,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: canLoad
          ? Image.network(
              imageUrl!,
              fit: fit,
              cacheWidth: cacheWidth,
              frameBuilder: (context, child, frame, synchronous) =>
                  synchronous || frame != null ? child : fallback,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class EcoPartnerImagePlaceholder extends StatelessWidget {
  const EcoPartnerImagePlaceholder({
    super.key,
    required this.partner,
    this.iconSize = 38,
    this.showLabel = true,
  });

  final EcoPartner partner;
  final double iconSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '${ecoPartnerPreviewLabel(partner)} preview placeholder',
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDEBE4), Color(0xFF86B39A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ecoPartnerPreviewIcon(partner),
              size: iconSize,
              color: const Color(0xFF07513C),
            ),
            if (showLabel) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ecoPartnerPreviewLabel(partner),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF07513C),
                    fontSize: iconSize < 28 ? 8 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

IconData ecoPartnerPreviewIcon(EcoPartner partner) {
  if (partner.category == EcoPartnerCategory.stay) return Icons.hotel_outlined;
  if (partner.category == EcoPartnerCategory.dining) {
    return Icons.restaurant_outlined;
  }
  final subtype = partner.subtype.trim().toLowerCase();
  if (subtype == 'ev charging') return Icons.ev_station_outlined;
  if (subtype == 'bus') return Icons.directions_bus_outlined;
  if (subtype == 'lrt' || subtype == 'light rail') return Icons.tram_outlined;
  if (subtype == 'monorail') return Icons.train_outlined;
  if (subtype == 'mrt') return Icons.subway_outlined;
  return Icons.train_outlined;
}

String? ecoPartnerPreviewCredit(EcoPartner partner) {
  final source = partner.imageSourceName?.trim();
  if (source == null || source.isEmpty) return null;
  if (source.toLowerCase().startsWith('representative')) {
    return source.split(' · ').first;
  }
  return source;
}

String ecoPartnerPreviewLabel(EcoPartner partner) {
  if (partner.category == EcoPartnerCategory.stay) return 'Hotel';
  if (partner.category == EcoPartnerCategory.dining) return 'Dining';
  return switch (partner.subtype.trim().toLowerCase()) {
    'ev charging' => 'EV charging',
    'bus' => 'Bus service',
    'mrt' => 'MRT service',
    'lrt' || 'light rail' => 'LRT service',
    'monorail' => 'Monorail service',
    'ktm' => 'KTM service',
    'rail' => 'Rail service',
    _ => 'Public transport',
  };
}
