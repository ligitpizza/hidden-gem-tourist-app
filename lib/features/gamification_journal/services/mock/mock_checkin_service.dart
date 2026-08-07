import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/check_in_model.dart';
import '../../model/destination_model.dart';
import '../../../destination_exploration/model/destination_exploration_repository.dart';
import '../../../../core/utils/haversine_helper.dart';

enum CheckInFailureReason { tooFarAway, cooldownActive, unknown }

class CheckInResult {
  final bool success;
  final CheckInModel? checkIn;
  final CheckInFailureReason? failureReason;
  final double? distanceMeters;

  /// Only set for [CheckInFailureReason.cooldownActive] — how much longer
  /// until this destination can be checked into again.
  final Duration? cooldownRemaining;

  CheckInResult.success(this.checkIn)
    : success = true,
      failureReason = null,
      distanceMeters = null,
      cooldownRemaining = null;

  CheckInResult.failure(
    this.failureReason, {
    this.distanceMeters,
    this.cooldownRemaining,
  }) : success = false,
       checkIn = null;
}

/// Phase 1 mock implementation of the check-in feature.
///
/// Method signatures here match what the real Supabase-backed
/// CheckInService will expose in Phase 2, so CheckInController and every
/// view built against this mock will keep working unchanged once the
/// backend is swapped in.
class MockCheckInService {
  MockCheckInService({List<DestinationModel>? seedDestinations})
      : destinations = seedDestinations ?? [],
        _destinationsLoaded = seedDestinations != null;

  static const Duration cooldownWindow = Duration(hours: 24);

  // In-memory store standing in for the Supabase 'check_ins' table.
  final List<CheckInModel> _checkIns = [];
  int _idCounter = 0;

  // Loaded from the real `destinations` table (destination_exploration's
  // own row-mapping is reused here) instead of hardcoded mock data, unless
  // pre-seeded via the constructor (used by tests to avoid a real Supabase
  // call). Everything below — distance/cooldown checks, in-memory check-in
  // history — stays mock/in-memory for now; only which destinations exist
  // is now real (or seeded).
  List<DestinationModel> destinations;
  bool _destinationsLoaded;

  Future<void> _ensureDestinationsLoaded() async {
    if (_destinationsLoaded) return;
    try {
      final rows = await Supabase.instance.client.from('destinations').select();
      destinations = rows.map(_mapRow).toList();
      _destinationsLoaded = true;
    } catch (_) {
      // Leave destinations empty and _destinationsLoaded false so a later
      // call can retry instead of permanently caching a failure.
    }
  }

  DestinationModel _mapRow(Map<String, dynamic> row) {
    final mapDestination = DestinationExplorationRepository.mapRow(row);
    final city = (row['city'] as String?)?.trim();
    return DestinationModel.fromMapDestination(
      mapDestination,
      state: (city != null && city.isNotEmpty) ? city : 'Penang',
    );
  }

  Future<List<DestinationModel>> fetchDestinations() async {
    await _ensureDestinationsLoaded();
    return destinations;
  }

  Future<List<CheckInModel>> fetchCheckInHistory(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _checkIns.where((c) => c.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Attempts a check-in against a destination. In Phase 2 this becomes a
  /// single Supabase RPC call that runs the same distance and cooldown
  /// checks server-side (see the module doc's Haversine + 24h rule).
  Future<CheckInResult> attemptCheckIn({
    required String userId,
    required String destinationId,
    required double userLat,
    required double userLng,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    await _ensureDestinationsLoaded();

    final destination = destinations.firstWhere(
      (d) => d.id == destinationId,
      orElse: () => throw ArgumentError('Unknown destination: $destinationId'),
    );

    final distance = HaversineHelper.distanceInMeters(
      lat1: userLat,
      lon1: userLng,
      lat2: destination.latitude,
      lon2: destination.longitude,
    );

    if (distance > destination.checkInRadiusMeters) {
      return CheckInResult.failure(
        CheckInFailureReason.tooFarAway,
        distanceMeters: distance,
      );
    }

    final lastCheckIn = _checkIns
        .where((c) => c.userId == userId && c.destinationId == destinationId)
        .fold<CheckInModel?>(null, (latest, c) {
          if (latest == null || c.timestamp.isAfter(latest.timestamp)) return c;
          return latest;
        });

    if (lastCheckIn != null) {
      final elapsed = DateTime.now().difference(lastCheckIn.timestamp);
      if (elapsed < cooldownWindow) {
        return CheckInResult.failure(
          CheckInFailureReason.cooldownActive,
          cooldownRemaining: cooldownWindow - elapsed,
        );
      }
    }

    final newCheckIn = CheckInModel(
      id: 'c${(_idCounter++).toString().padLeft(4, '0')}',
      userId: userId,
      destinationId: destinationId,
      timestamp: DateTime.now(),
      latitude: userLat,
      longitude: userLng,
    );

    _checkIns.add(newCheckIn);
    return CheckInResult.success(newCheckIn);
  }

  Future<void> setHidden({
    required String checkInId,
    required bool isHidden,
  }) async {
    final index = _checkIns.indexWhere((c) => c.id == checkInId);
    if (index == -1) return;
    _checkIns[index] = _checkIns[index].copyWith(isHidden: isHidden);
  }
}
