import '../../model/check_in_model.dart';
import '../../model/destination_model.dart';
import '../../../../utility/haversine_helper.dart';

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
  static const Duration cooldownWindow = Duration(hours: 24);

  // In-memory store standing in for the Supabase 'check_ins' table.
  final List<CheckInModel> _checkIns = [];
  int _idCounter = 0;

  final List<DestinationModel> destinations = [
    DestinationModel(
      id: 'd001',
      name: "Kellie's Castle",
      state: 'Perak',
      category: 'Culture',
      latitude: 4.5729,
      longitude: 101.1417,
      description: 'An unfinished mansion with a mysterious colonial history.',
      imageUrl: 'https://picsum.photos/seed/d001-kellies-castle/900/600',
    ),
    DestinationModel(
      id: 'd002',
      name: 'Semenggoh Nature Reserve',
      state: 'Sarawak',
      category: 'Nature',
      latitude: 1.3644,
      longitude: 110.3103,
      description: 'A rehabilitation centre for semi-wild orangutans.',
      imageUrl: 'https://picsum.photos/seed/d002-semenggoh/900/600',
    ),
    DestinationModel(
      id: 'd003',
      name: 'Gua Tempurung',
      state: 'Perak',
      category: 'Adventure',
      latitude: 4.3653,
      longitude: 101.1908,
      description: 'One of the largest limestone cave systems in Malaysia.',
      imageUrl: 'https://picsum.photos/seed/d003-gua-tempurung/900/600',
    ),
    DestinationModel(
      id: 'd004',
      name: 'Kampung Kuantan Firefly Park',
      state: 'Selangor',
      category: 'Nature',
      latitude: 3.3502,
      longitude: 101.2311,
      description:
          'A riverside sanctuary known for its synchronised fireflies.',
      imageUrl: 'https://picsum.photos/seed/d004-firefly-park/900/600',
    ),
    DestinationModel(
      id: 'd005',
      name: 'Jonker Walk Night Market',
      state: 'Melaka',
      category: 'Food',
      latitude: 2.1959,
      longitude: 102.2467,
      description: 'A heritage street famous for Peranakan street food.',
      imageUrl: 'https://picsum.photos/seed/d005-jonker-walk/900/600',
    ),
  ];

  Future<List<DestinationModel>> fetchDestinations() async {
    await Future.delayed(const Duration(milliseconds: 400));
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
