import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/cultural_event_detail_controller.dart';
import '../model/cultural_event.dart';
import 'google_maps_navigation.dart';

class CulturalEventDetailScreen
    extends ConsumerWidget {
  const CulturalEventDetailScreen({
    super.key,
    required this.event,
  });

  final CulturalEvent event;

  Future<void> _navigate(
      BuildContext context,
      ) async {
    await openGoogleMapsNavigation(
      context: context,
      latitude:
      event.latitude,
      longitude:
      event.longitude,
    );
  }

  Future<void>
  _openOfficialSource(
      BuildContext context,
      ) async {
    final sourceUrl =
    event.sourceUrl?.trim();

    if (sourceUrl == null ||
        sourceUrl.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Official source is not available.',
          ),
        ),
      );

      return;
    }

    final uri =
    Uri.tryParse(
      sourceUrl,
    );

    if (uri == null) {
      return;
    }

    try {
      final opened =
      await launchUrl(
        uri,
        mode: LaunchMode
            .externalApplication,
      );

      if (!opened &&
          context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open official source.',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'Open source error: $error',
      );
    }
  }

  Future<void>
  _shareEvent() async {
    final text = [
      event.name,
      _formatEventDateRange(
        event,
      ),
      _eventLocation(
        event,
      ),
      if (event.sourceUrl !=
          null &&
          event.sourceUrl!
              .trim()
              .isNotEmpty)
        event.sourceUrl!,
    ].join('\n\n');

    await Share.share(
      text,
      subject:
      event.name,
    );
  }

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    final controller =
    ref.watch(
      culturalEventDetailControllerProvider(
        event.id,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Event Details',
        ),
        actions: [
          IconButton(
            onPressed:
            _shareEvent,
            icon:
            const Icon(
              Icons.share_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh:
        controller.refresh,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets
              .fromLTRB(
            16,
            16,
            16,
            110,
          ),
          children: [
            if (event.imageUrl !=
                null &&
                event.imageUrl!
                    .trim()
                    .isNotEmpty)
              ClipRRect(
                borderRadius:
                BorderRadius
                    .circular(
                  18,
                ),
                child:
                Image.network(
                  event.imageUrl!,
                  height: 230,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) {
                    return _fallback(
                      context,
                    );
                  },
                ),
              )
            else
              _fallback(
                context,
              ),

            const SizedBox(
              height: 18,
            ),

            Text(
              event.name,
              style:
              GoogleFonts.montserrat(
                fontSize: 27,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            _InfoRow(
              icon:
              Icons
                  .calendar_month_outlined,
              text:
              _formatEventDateRange(
                event,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            _InfoRow(
              icon:
              Icons
                  .location_on_outlined,
              text:
              _eventLocation(
                event,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            const _SectionTitle(
              title:
              'About This Event',
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              event.description,
              style:
              GoogleFonts.inter(
                height: 1.5,
              ),
            ),

            if (event.scheduleNote !=
                null &&
                event.scheduleNote!
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(
                height: 24,
              ),

              const _SectionTitle(
                title:
                'Schedule',
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                event.scheduleNote!,
              ),
            ],

            const SizedBox(
              height: 26,
            ),

            const _SectionTitle(
              title:
              'Location',
            ),

            const SizedBox(
              height: 10,
            ),

            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius:
                BorderRadius
                    .circular(
                  18,
                ),
                child:
                FlutterMap(
                  options:
                  MapOptions(
                    initialCenter:
                    LatLng(
                      event.latitude,
                      event.longitude,
                    ),
                    initialZoom:
                    14,
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
                          point:
                          LatLng(
                            event.latitude,
                            event.longitude,
                          ),
                          width: 45,
                          height: 45,
                          child:
                          Container(
                            decoration:
                            BoxDecoration(
                              color:
                              colors.primary,
                              shape:
                              BoxShape.circle,
                            ),
                            child:
                            const Icon(
                              Icons
                                  .location_on,
                              color:
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            SizedBox(
              width:
              double.infinity,
              child:
              FilledButton.icon(
                onPressed:
                    () {
                  _navigate(
                    context,
                  );
                },
                icon:
                const Icon(
                  Icons
                      .navigation_rounded,
                ),
                label:
                const Text(
                  'Navigate with Google Maps',
                ),
              ),
            ),

            const SizedBox(
              height: 26,
            ),

            const _SectionTitle(
              title:
              'Official Source',
            ),

            const SizedBox(
              height: 10,
            ),

            Card(
              child: Padding(
                padding:
                const EdgeInsets
                    .all(
                  14,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      event.sourceName ??
                          'Event Source',
                      style:
                      GoogleFonts.inter(
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),

                    if (event.sourceUrl !=
                        null &&
                        event.sourceUrl!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),

                      OutlinedButton
                          .icon(
                        onPressed:
                            () {
                          _openOfficialSource(
                            context,
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .open_in_new,
                        ),
                        label:
                        const Text(
                          'View Official Source',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // =======================================================
      // SAVE EVENT
      // =======================================================

      bottomNavigationBar:
      SafeArea(
        top: false,
        child: Container(
          padding:
          const EdgeInsets
              .all(
            10,
          ),
          decoration:
          BoxDecoration(
            color:
            colors.surface,
            border: Border(
              top: BorderSide(
                color: colors
                    .outlineVariant,
              ),
            ),
          ),
          child:
          FilledButton.icon(
            onPressed:
            controller
                .isSavingFavourite
                ? null
                : () async {
              final success =
              await controller
                  .toggleFavourite();

              if (!context
                  .mounted) {
                return;
              }

              if (!success) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    content:
                    Text(
                      controller.errorMessage ??
                          'Could not update saved event.',
                    ),
                  ),
                );

                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content:
                  Text(
                    controller.isFavourite
                        ? '${event.name} saved.'
                        : '${event.name} removed from saved.',
                  ),
                ),
              );
            },

            icon: controller
                .isSavingFavourite
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
              ),
            )
                : Icon(
              controller
                  .isFavourite
                  ? Icons
                  .bookmark_rounded
                  : Icons
                  .bookmark_border_rounded,
            ),

            label: Text(
              controller
                  .isFavourite
                  ? 'Saved'
                  : 'Save Event',
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(
      BuildContext context,
      ) {
    return Container(
      height: 230,
      alignment:
      Alignment.center,
      decoration:
      BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),
      child: Icon(
        Icons
            .celebration_rounded,
        size: 80,
        color: Theme.of(context)
            .colorScheme
            .onPrimaryContainer,
      ),
    );
  }
}

// ===========================================================
// HELPERS
// ===========================================================

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
        ),

        const SizedBox(
          width: 7,
        ),

        Expanded(
          child: Text(
            text,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style:
      GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight:
        FontWeight.w700,
      ),
    );
  }
}

String _formatDate(
    DateTime date,
    ) {
  final local =
  date.toLocal();

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

  return '${local.day} '
      '${months[local.month - 1]} '
      '${local.year}';
}

String _formatEventDateRange(
    CulturalEvent event,
    ) {
  final start =
  event.startAt.toLocal();

  final end =
  event.endAt?.toLocal();

  if (end == null) {
    return _formatDate(
      start,
    );
  }

  final sameDay =
      start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;

  if (sameDay) {
    return _formatDate(
      start,
    );
  }

  return '${_formatDate(start)} - '
      '${_formatDate(end)}';
}

String _eventLocation(
    CulturalEvent event,
    ) {
  return [
    event.venueName,
    if (event.city != null &&
        event.city!
            .trim()
            .isNotEmpty)
      event.city!,
    event.state,
  ].join(', ');
}