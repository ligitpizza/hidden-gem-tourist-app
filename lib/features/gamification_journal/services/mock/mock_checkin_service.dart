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

/// Check-ins are backed by the real `journal_check_ins` table (see
/// supabase/migrations/20260813120000_journal_real_activity_and_friends.sql)
/// so a Tourist's activity is now visible to friends, not just their own
/// device. Tests bypass Supabase entirely by passing [seedCheckIns] — even
/// an empty list — which switches this service to a plain in-memory store
/// instead, same as [seedDestinations] already does for the catalogue.
class MockCheckInService {
  MockCheckInService({
    List<DestinationModel>? seedDestinations,
    List<CheckInModel>? seedCheckIns,
  }) : destinations = seedDestinations ?? [],
       _destinationsLoaded = seedDestinations != null,
       // A defensive growable copy — callers (tests) may pass a `const
       // []`, which this service then needs to append to.
       _checkIns = List.of(seedCheckIns ?? []),
       _useMockStorage = seedCheckIns != null;

  static const Duration cooldownWindow = Duration(hours: 24);

  final List<CheckInModel> _checkIns;
  final bool _useMockStorage;
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
      state: (city != null && city.isNotEmpty) ? stateForCity(city) : 'Penang',
    );
  }

  Future<List<DestinationModel>> fetchDestinations() async {
    await _ensureDestinationsLoaded();
    return destinations;
  }

  Future<List<CheckInModel>> fetchCheckInHistory(String userId) async {
    if (_useMockStorage) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _checkIns.where((c) => c.userId == userId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    final rows = await Supabase.instance.client
        .from('journal_check_ins')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);
    return rows.map((r) => CheckInModel.fromJson(r)).toList();
  }

  Future<CheckInModel?> _lastCheckIn(String userId, String destinationId) async {
    if (_useMockStorage) {
      return _checkIns
          .where((c) => c.userId == userId && c.destinationId == destinationId)
          .fold<CheckInModel?>(null, (latest, c) {
            if (latest == null || c.timestamp.isAfter(latest.timestamp)) return c;
            return latest;
          });
    }
    final rows = await Supabase.instance.client
        .from('journal_check_ins')
        .select()
        .eq('user_id', userId)
        .eq('destination_id', destinationId)
        .order('timestamp', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : CheckInModel.fromJson(rows.first);
  }

  /// Attempts a check-in against a destination — distance and cooldown are
  /// still checked client-side (see the module doc's Haversine + 24h
  /// rule); only where the resulting check-in is stored has changed.
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

    final lastCheckIn = await _lastCheckIn(userId, destinationId);
    if (lastCheckIn != null) {
      final elapsed = DateTime.now().difference(lastCheckIn.timestamp);
      if (elapsed < cooldownWindow) {
        return CheckInResult.failure(
          CheckInFailureReason.cooldownActive,
          cooldownRemaining: cooldownWindow - elapsed,
        );
      }
    }

    if (_useMockStorage) {
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

    final row = await Supabase.instance.client
        .from('journal_check_ins')
        .insert({
          'user_id': userId,
          'destination_id': destinationId,
          'latitude': userLat,
          'longitude': userLng,
        })
        .select()
        .single();
    return CheckInResult.success(CheckInModel.fromJson(row));
  }

  Future<void> setHidden({
    required String checkInId,
    required bool isHidden,
  }) async {
    if (_useMockStorage) {
      final index = _checkIns.indexWhere((c) => c.id == checkInId);
      if (index == -1) return;
      _checkIns[index] = _checkIns[index].copyWith(isHidden: isHidden);
      return;
    }
    await Supabase.instance.client
        .from('journal_check_ins')
        .update({'is_hidden': isHidden})
        .eq('id', checkInId);
  }
}
