import 'package:flutter/foundation.dart';

import '../model/check_in_model.dart';
import '../model/destination_model.dart';
import '../services/mock/mock_checkin_service.dart';

enum CheckInStatus { idle, loading, success, error }

class CheckInController extends ChangeNotifier {
  CheckInController({required this.userId, MockCheckInService? service})
      : _service = service ?? MockCheckInService();

  final String userId;
  final MockCheckInService _service;

  List<DestinationModel> _destinations = [];
  List<CheckInModel> _history = [];
  CheckInStatus status = CheckInStatus.idle;
  String? errorMessage;

  List<DestinationModel> get destinations => _destinations;
  List<CheckInModel> get history => _history;

  Future<void> loadDestinations() async {
    _destinations = await _service.fetchDestinations();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _history = await _service.fetchCheckInHistory(userId);
    notifyListeners();
  }

  Future<void> checkIn({
    required String destinationId,
    required double userLat,
    required double userLng,
  }) async {
    status = CheckInStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _service.attemptCheckIn(
      userId: userId,
      destinationId: destinationId,
      userLat: userLat,
      userLng: userLng,
    );

    if (result.success) {
      status = CheckInStatus.success;
      await loadHistory();
    } else {
      status = CheckInStatus.error;
      errorMessage = switch (result.failureReason) {
        CheckInFailureReason.tooFarAway =>
          "You're ${result.distanceMeters?.toStringAsFixed(0)}m away — get closer to check in.",
        CheckInFailureReason.cooldownActive =>
          _cooldownMessage(result.cooldownRemaining),
        _ => 'Something went wrong. Please try again.',
      };
    }

    notifyListeners();
  }

  String _cooldownMessage(Duration? remaining) {
    if (remaining == null || remaining.isNegative) {
      return 'You already checked in here recently. Try again later.';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m until you can check in here again.';
    }
    return '${minutes}m until you can check in here again.';
  }

  Future<void> setHidden(String checkInId, bool isHidden) async {
    await _service.setHidden(checkInId: checkInId, isHidden: isHidden);
    await loadHistory();
  }
}
