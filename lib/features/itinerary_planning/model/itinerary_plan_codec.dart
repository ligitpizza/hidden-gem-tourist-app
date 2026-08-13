import 'package:latlong2/latlong.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../../shared/models/travel_mode.dart';
import 'itinerary_plan.dart';
import 'itinerary_stop.dart';
import 'route_metrics.dart';
import 'route_path.dart';
import 'visit_duration_option.dart';

/// Converts an [ItineraryPlan] to/from the plain JSON stored in the
/// `saved_itineraries.plan` jsonb column. Kept separate from the model
/// classes themselves (which stay plain data holders, per this module's
/// convention) since this shape only needs to round-trip through Supabase,
/// not match any external API.
class ItineraryPlanCodec {
  ItineraryPlanCodec._();

  static Map<String, dynamic> toJson(ItineraryPlan plan) => {
        'destinations': plan.destinations.map(_destinationToJson).toList(),
        'durationOption': plan.durationOption?.name,
        'primaryPath': _routePathToJson(plan.primaryPath),
        'alternatePath': _routePathToJson(plan.alternatePath),
        'timeline': plan.timeline.map(_stopToJson).toList(),
        'estimatedMinutesNeeded': plan.estimatedMinutesNeeded,
        'budgetMinutes': plan.budgetMinutes,
      };

  static ItineraryPlan fromJson(Map<String, dynamic> json) => ItineraryPlan(
        destinations: (json['destinations'] as List)
            .map((e) => _destinationFromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        durationOption: json['durationOption'] == null
            ? null
            : VisitDurationOption.values.byName(json['durationOption'] as String),
        primaryPath: _routePathFromJson((json['primaryPath'] as Map).cast<String, dynamic>()),
        alternatePath: _routePathFromJson((json['alternatePath'] as Map).cast<String, dynamic>()),
        timeline: (json['timeline'] as List)
            .map((e) => _stopFromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        estimatedMinutesNeeded: json['estimatedMinutesNeeded'] as int,
        budgetMinutes: json['budgetMinutes'] as int?,
      );

  static Map<String, dynamic> _latLngToJson(LatLng point) => {'lat': point.latitude, 'lng': point.longitude};

  static LatLng _latLngFromJson(Map<String, dynamic> json) =>
      LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());

  static Map<String, dynamic> _destinationToJson(Destination destination) => {
        'id': destination.id,
        'name': destination.name,
        'city': destination.city,
        'category': destination.category.name,
        'location': _latLngToJson(destination.location),
      };

  static Destination _destinationFromJson(Map<String, dynamic> json) => Destination(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        category: DestinationCategory.values.byName(json['category'] as String),
        location: _latLngFromJson((json['location'] as Map).cast<String, dynamic>()),
      );

  static Map<String, dynamic> _hiddenGemToJson(HiddenGem gem) => {
        'id': gem.id,
        'name': gem.name,
        'description': gem.description,
        'location': _latLngToJson(gem.location),
        'category': gem.category.name,
        'avgRating': gem.avgRating,
        'uniquenessScore': gem.uniquenessScore,
        'accessibilityScore': gem.accessibilityScore,
        'popularity': gem.popularity.name,
      };

  static HiddenGem _hiddenGemFromJson(Map<String, dynamic> json) => HiddenGem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        location: _latLngFromJson((json['location'] as Map).cast<String, dynamic>()),
        category: HiddenGemCategory.values.byName(json['category'] as String),
        avgRating: (json['avgRating'] as num).toDouble(),
        uniquenessScore: (json['uniquenessScore'] as num).toDouble(),
        accessibilityScore: (json['accessibilityScore'] as num).toDouble(),
        popularity: GemPopularity.values.byName(json['popularity'] as String),
      );

  static Map<String, dynamic> _routeMetricsToJson(RouteMetrics metrics) => {
        'distanceKm': metrics.distanceKm,
        'durationMinutes': metrics.durationMinutes,
        'costMyr': metrics.costMyr,
      };

  static RouteMetrics _routeMetricsFromJson(Map<String, dynamic> json) => RouteMetrics(
        distanceKm: (json['distanceKm'] as num).toDouble(),
        durationMinutes: json['durationMinutes'] as int,
        costMyr: (json['costMyr'] as num).toDouble(),
      );

  static Map<String, dynamic> _routePathToJson(RoutePath path) => {
        'id': path.id,
        'label': path.label,
        'isRecommended': path.isRecommended,
        'polyline': path.polyline.map(_latLngToJson).toList(),
        'hiddenGems': path.hiddenGems.map(_hiddenGemToJson).toList(),
        'metricsByMode': {
          for (final entry in path.metricsByMode.entries) entry.key.name: _routeMetricsToJson(entry.value),
        },
      };

  static RoutePath _routePathFromJson(Map<String, dynamic> json) => RoutePath(
        id: json['id'] as String,
        label: json['label'] as String,
        isRecommended: json['isRecommended'] as bool,
        polyline: (json['polyline'] as List)
            .map((e) => _latLngFromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        hiddenGems: (json['hiddenGems'] as List)
            .map((e) => _hiddenGemFromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        metricsByMode: {
          for (final entry in (json['metricsByMode'] as Map).cast<String, dynamic>().entries)
            TravelMode.values.byName(entry.key): _routeMetricsFromJson((entry.value as Map).cast<String, dynamic>()),
        },
      );

  static Map<String, dynamic> _stopToJson(ItineraryStop stop) => {
        'time': stop.time,
        'title': stop.title,
        'description': stop.description,
        'meta': stop.meta,
        'badge': stop.badge.name,
        'isMainDestination': stop.isMainDestination,
        'imagePlaceholderCount': stop.imagePlaceholderCount,
        'travelToNext': stop.travelToNext,
        'dayIndex': stop.dayIndex,
      };

  static ItineraryStop _stopFromJson(Map<String, dynamic> json) => ItineraryStop(
        time: json['time'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        meta: json['meta'] as String?,
        badge: StopBadge.values.byName(json['badge'] as String),
        isMainDestination: json['isMainDestination'] as bool,
        imagePlaceholderCount: json['imagePlaceholderCount'] as int? ?? 0,
        travelToNext: json['travelToNext'] as String?,
        dayIndex: json['dayIndex'] as int? ?? 0,
      );
}
