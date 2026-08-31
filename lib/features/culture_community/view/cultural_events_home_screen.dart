import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controller/cultural_events_controller.dart';
import '../model/cultural_event.dart';
import 'culture_community_routes.dart';

class CulturalEventsHomeScreen
    extends ConsumerStatefulWidget {
  const CulturalEventsHomeScreen({
    super.key,
  });

  @override
  ConsumerState<CulturalEventsHomeScreen>
  createState() =>
      _CulturalEventsHomeScreenState();
}

class _CulturalEventsHomeScreenState
    extends ConsumerState<
        CulturalEventsHomeScreen> {
  final TextEditingController
  _searchController =
  TextEditingController();

  String _query = '';

  CulturalEventCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CulturalEvent> _filter(
      List<CulturalEvent> events,
      ) {
    final query =
    _query.trim().toLowerCase();

    return events.where((event) {
      if (_category != null &&
          event.category != _category) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        event.name,
        event.description,
        event.category.label,
        event.venueName,
        event.address ?? '',
        event.city ?? '',
        event.state,
        ...event.officialCategories,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      culturalEventsControllerProvider,
    );

    final events = _filter(
      controller.events,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cultural Events',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Map View',
            onPressed: () {
              context.push(
                CultureCommunityRoutes.eventMap,
              );
            },
            icon: const Icon(
              Icons.map_outlined,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            32,
          ),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: InputDecoration(
                hintText:
                'Search cultural events...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () {
                    _searchController
                        .clear();

                    setState(() {
                      _query = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection:
              Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label:
                    const Text('All'),
                    selected:
                    _category == null,
                    onSelected: (_) {
                      setState(() {
                        _category = null;
                      });
                    },
                  ),

                  const SizedBox(width: 8),

                  for (final category
                  in CulturalEventCategory
                      .values) ...[
                    ChoiceChip(
                      label:
                      Text(category.label),
                      selected:
                      _category ==
                          category,
                      onSelected: (_) {
                        setState(() {
                          _category =
                              category;
                        });
                      },
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Explore Events',
                    style:
                    GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                Text(
                  '${events.length} event${events.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    color:
                    Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (controller.isLoading &&
                controller.events.isEmpty)
              const Padding(
                padding:
                EdgeInsets.all(50),
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              )
            else if (controller
                .errorMessage !=
                null &&
                controller.events.isEmpty)
              _ErrorState(
                message: controller
                    .errorMessage!,
                onRetry:
                controller.refresh,
              )
            else if (events.isEmpty)
                const _EmptyState()
              else
                for (final event
                in events) ...[
                  _EventListCard(
                    event: event,

                    // CLICK WHOLE CARD
                    onTap: () {
                      context.push(
                        CultureCommunityRoutes
                            .eventDetail,
                        extra: event,
                      );
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),
                ],
          ],
        ),
      ),
    );
  }
}

class _EventListCard extends StatelessWidget {
  const _EventListCard({
    required this.event,
    required this.onTap,
  });

  final CulturalEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final categoryColor =
    _categoryColor(event.category);

    return Material(
      color: colors.surface,
      borderRadius:
      BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color:
              colors.outlineVariant,
            ),
          ),
          clipBehavior:
          Clip.antiAlias,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 210,
                width:
                double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _EventImage(
                      event: event,
                    ),

                    Positioned(
                      left: 14,
                      bottom: 14,
                      child: Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          categoryColor,
                          borderRadius:
                          BorderRadius
                              .circular(
                            999,
                          ),
                        ),
                        child: Text(
                          event.category
                              .label,
                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontSize: 11,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding:
                const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      event.name,
                      style: GoogleFonts
                          .montserrat(
                        fontSize: 19,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        colors.primary,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _InfoRow(
                      icon: Icons
                          .calendar_today_outlined,
                      text:
                      _formatEventDateRange(
                        event.startAt,
                        event.endAt,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    _InfoRow(
                      icon: Icons
                          .location_on_outlined,
                      text: [
                        event.venueName,
                        if (event.city !=
                            null)
                          event.city!,
                        event.state,
                      ].join(', '),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      event.description,
                      maxLines: 3,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      GoogleFonts.inter(
                        height: 1.45,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .end,
                      children: [
                        Text(
                          'View Details',
                          style:
                          GoogleFonts
                              .inter(
                            fontWeight:
                            FontWeight
                                .w700,
                            color: colors
                                .primary,
                          ),
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Icon(
                          Icons
                              .arrow_forward_rounded,
                          size: 18,
                          color: colors
                              .primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({
    required this.event,
  });

  final CulturalEvent event;

  @override
  Widget build(BuildContext context) {
    final url =
    event.imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return _fallback(context);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          _fallback(context),
    );
  }

  Widget _fallback(
      BuildContext context,
      ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
      alignment: Alignment.center,
      child: Icon(
        _categoryIcon(
          event.category,
        ),
        size: 60,
        color: Colors.white,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
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
          size: 17,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 46,
          ),
          const SizedBox(height: 10),
          Text(message),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              onRetry();
            },
            child:
            const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
            ),
            SizedBox(height: 10),
            Text(
              'No cultural events found.',
            ),
          ],
        ),
      ),
    );
  }
}

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

  final startDate =
  start.toLocal();

  if (end == null) {
    return '${startDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  final endDate =
  end.toLocal();

  if (startDate.year ==
      endDate.year &&
      startDate.month ==
          endDate.month) {
    return '${startDate.day}–${endDate.day} '
        '${months[startDate.month - 1]} '
        '${startDate.year}';
  }

  return '${startDate.day} '
      '${months[startDate.month - 1]} – '
      '${endDate.day} '
      '${months[endDate.month - 1]} '
      '${endDate.year}';
}