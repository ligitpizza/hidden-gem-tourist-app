import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/cultural_event_detail_controller.dart';
import '../model/cultural_event.dart';

class CulturalEventDetailScreen
    extends ConsumerStatefulWidget {
  const CulturalEventDetailScreen({
    super.key,
    required this.event,
  });

  final CulturalEvent event;

  @override
  ConsumerState<CulturalEventDetailScreen>
  createState() =>
      _CulturalEventDetailScreenState();
}

class _CulturalEventDetailScreenState
    extends ConsumerState<
        CulturalEventDetailScreen> {
  double? _distanceKm;

  CulturalEvent get event => widget.event;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        _loadDistance();
      },
    );
  }

  Future<void> _loadDistance() async {
    try {
      final enabled =
      await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        return;
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission !=
          LocationPermission.always &&
          permission !=
              LocationPermission.whileInUse) {
        return;
      }

      final position =
      await Geolocator.getCurrentPosition();

      final metres =
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        event.latitude,
        event.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _distanceKm = metres / 1000;
      });
    } catch (_) {
      // Distance is optional.
    }
  }

  Future<void> _openLocation() async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/'
          '?mlat=${event.latitude}'
          '&mlon=${event.longitude}'
          '#map=16/'
          '${event.latitude}/'
          '${event.longitude}',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the location.',
          ),
        ),
      );
    }
  }

  Future<void> _openOfficialSource() async {
    final url = event.sourceUrl?.trim();

    if (url == null || url.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the official website.',
          ),
        ),
      );
    }
  }

  Future<void> _shareEvent() async {
    final location = [
      event.venueName,
      if (event.city != null &&
          event.city!.trim().isNotEmpty)
        event.city!,
      event.state,
    ].join(', ');

    final text = StringBuffer()
      ..writeln(event.name)
      ..writeln(
        _formatEventDateRange(
          event.startAt,
          event.endAt,
        ),
      )
      ..writeln(location);

    if (event.sourceUrl != null &&
        event.sourceUrl!.trim().isNotEmpty) {
      text.writeln(event.sourceUrl);
    }

    await Share.share(
      text.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final detailController = ref.watch(
      culturalEventDetailControllerProvider(
        event.id,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Event Details',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.only(
          bottom: 120,
        ),
        children: [
          _EventHero(
            event: event,
            distanceKm: _distanceKm,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              24,
              16,
              16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1000,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // DATE / SCHEDULE
                    // ==========================================

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _QuickInfoCard(
                            icon: Icons
                                .calendar_today_outlined,
                            title: 'DATE',
                            value:
                            _formatEventDateRange(
                              event.startAt,
                              event.endAt,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickInfoCard(
                            icon:
                            Icons.schedule_outlined,
                            title: 'SCHEDULE',
                            value: event.scheduleNote ??
                                'Check organiser schedule.',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ==========================================
                    // ABOUT
                    // ==========================================

                    Text(
                      'About This Event',
                      style: GoogleFonts.montserrat(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      event.description,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.6,
                        color:
                        colors.onSurfaceVariant,
                      ),
                    ),

                    if (event
                        .officialCategories
                        .isNotEmpty) ...[
                      const SizedBox(height: 22),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category
                          in event
                              .officialCategories)
                            Chip(
                              avatar: const Icon(
                                Icons
                                    .label_outline_rounded,
                                size: 16,
                              ),
                              label: Text(category),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ==========================================
                    // SCHEDULE
                    // ==========================================

                    _ScheduleSection(
                      event: event,
                    ),

                    const SizedBox(height: 32),

                    // ==========================================
                    // LOCATION
                    // ==========================================

                    Text(
                      'Event Location',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _LocationCard(
                      event: event,
                      distanceKm: _distanceKm,
                      onOpenMap: _openLocation,
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // SOURCE
                    // ==========================================

                    if (event.sourceName != null ||
                        event.sourceUrl != null)
                      _SourceCard(
                        sourceName:
                        event.sourceName ??
                            'Official event source',
                        sourceUrl:
                        event.sourceUrl,
                        onOpen:
                        _openOfficialSource,
                      ),

                    if (detailController.errorMessage !=
                        null) ...[
                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                          colors.errorContainer,
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: Text(
                          detailController
                              .errorMessage!,
                          style: TextStyle(
                            color: colors
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // =======================================================
      // ACTION BAR
      // =======================================================

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            10,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: detailController
                      .isSavingFavourite
                      ? null
                      : () async {
                    final success =
                    await detailController
                        .toggleFavourite();

                    if (!success ||
                        !context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          detailController
                              .isFavourite
                              ? 'Event saved to Favorites.'
                              : 'Event removed from Favorites.',
                        ),
                      ),
                    );
                  },
                  icon: detailController
                      .isSavingFavourite
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    detailController
                        .isFavourite
                        ? Icons.favorite_rounded
                        : Icons
                        .favorite_border_rounded,
                  ),
                  label: Text(
                    detailController.isFavourite
                        ? 'Saved'
                        : 'Save',
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: detailController
                      .isSavingItinerary
                      ? null
                      : () async {
                    final success =
                    await detailController
                        .toggleItinerary(
                      event.startAt,
                    );

                    if (!success ||
                        !context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          detailController
                              .isInItinerary
                              ? 'Event added to your itinerary.'
                              : 'Event removed from your itinerary.',
                        ),
                      ),
                    );
                  },
                  icon: detailController
                      .isSavingItinerary
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    detailController
                        .isInItinerary
                        ? Icons
                        .check_circle_rounded
                        : Icons
                        .add_circle_outline_rounded,
                  ),
                  label: Text(
                    detailController.isInItinerary
                        ? 'In Itinerary'
                        : 'Add to Itinerary',
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton.outlined(
                tooltip: 'Share event',
                onPressed: _shareEvent,
                icon: const Icon(
                  Icons.share_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// HERO
// ===========================================================

class _EventHero extends StatelessWidget {
  const _EventHero({
    required this.event,
    required this.distanceKm,
  });

  final CulturalEvent event;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _EventHeroImage(
            event: event,
          ),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [
                  0.35,
                  1,
                ],
              ),
            ),
          ),

          Positioned(
            left: 18,
            right: 18,
            bottom: 24,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _categoryColor(
                      event.category,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      999,
                    ),
                  ),
                  child: Text(
                    event.category.label
                        .toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  event.name,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _HeroInfo(
                      icon:
                      Icons.location_on_outlined,
                      text: [
                        if (event.city != null &&
                            event.city!
                                .trim()
                                .isNotEmpty)
                          event.city!,
                        event.state,
                      ].join(', '),
                    ),

                    if (distanceKm != null)
                      _HeroInfo(
                        icon:
                        Icons.navigation_outlined,
                        text:
                        '${distanceKm!.toStringAsFixed(1)} km away',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHeroImage extends StatelessWidget {
  const _EventHeroImage({
    required this.event,
  });

  final CulturalEvent event;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _fallback(context);
        },
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _categoryColor(
              event.category,
            ),
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _categoryIcon(
            event.category,
          ),
          size: 90,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// INFO CARD
// ===========================================================

class _QuickInfoCard extends StatelessWidget {
  const _QuickInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
              colors.secondaryContainer,
              borderRadius:
              BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colors
                  .onSecondaryContainer,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w600,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value,
                  maxLines: 5,
                  overflow:
                  TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// SCHEDULE
// ===========================================================

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.event,
  });

  final CulturalEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note_outlined,
                color: colors.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Schedule Information',
                style: GoogleFonts.montserrat(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            event.scheduleNote ??
                'Detailed programme times were not published in the official source. Check the organiser before visiting.',
            style: GoogleFonts.inter(
              height: 1.5,
              color:
              colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// LOCATION
// ===========================================================

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.event,
    required this.distanceKm,
    required this.onOpenMap,
  });

  final CulturalEvent event;
  final double? distanceKm;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 210,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  event.latitude,
                  event.longitude,
                ),
                initialZoom: 15,
                interactionOptions:
                const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                  'com.collab.app',
                ),

                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        event.latitude,
                        event.longitude,
                      ),
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _categoryColor(
                            event.category,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color:
                              Colors.black26,
                              blurRadius: 7,
                            ),
                          ],
                        ),
                        child: Icon(
                          _categoryIcon(
                            event.category,
                          ),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.venueName,
                        style:
                        GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (event.address != null &&
                          event.address!
                              .trim()
                              .isNotEmpty)
                        Text(
                          event.address!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),

                      if (distanceKm != null)
                        Padding(
                          padding:
                          const EdgeInsets.only(
                            top: 6,
                          ),
                          child: Text(
                            '${distanceKm!.toStringAsFixed(1)} km from your current location',
                            style:
                            GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                IconButton.filledTonal(
                  tooltip: 'Open location',
                  onPressed: onOpenMap,
                  icon: const Icon(
                    Icons.near_me_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// SOURCE
// ===========================================================

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.sourceName,
    required this.sourceUrl,
    required this.onOpen,
  });

  final String sourceName;
  final String? sourceUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'OFFICIAL SOURCE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color:
              colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                colors.primaryContainer,
                child: Icon(
                  Icons.verified_outlined,
                  color: colors
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  sourceName,
                  style: GoogleFonts.inter(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          if (sourceUrl != null &&
              sourceUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(
                Icons.open_in_new_rounded,
              ),
              label: const Text(
                'Visit Official Website',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================
// CATEGORY HELPERS
// ===========================================================

Color _categoryColor(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return const Color(0xFF1B4332);

    case CulturalEventCategory.culturalShow:
      return const Color(0xFFD1A51E);

    case CulturalEventCategory.communityActivity:
      return const Color(0xFF6B5435);
  }
}

IconData _categoryIcon(
    CulturalEventCategory category,
    ) {
  switch (category) {
    case CulturalEventCategory.festival:
      return Icons.festival_rounded;

    case CulturalEventCategory.culturalShow:
      return Icons.theater_comedy_rounded;

    case CulturalEventCategory.communityActivity:
      return Icons.groups_rounded;
  }
}

// ===========================================================
// DATE
// ===========================================================

String _formatEventDateRange(
    DateTime start,
    DateTime? end,
    ) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final startDate = start.toLocal();

  if (end == null) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  final endDate = end.toLocal();

  if (startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  if (startDate.year == endDate.year &&
      startDate.month == endDate.month) {
    return '${startDate.day}–${endDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  if (startDate.year == endDate.year) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} – '
        '${endDate.day} '
        '${months[endDate.month - 1]} '
        '${startDate.year}';
  }

  return '${startDate.day} '
      '${months[startDate.month - 1]} '
      '${startDate.year} – '
      '${endDate.day} '
      '${months[endDate.month - 1]} '
      '${endDate.year}';
}