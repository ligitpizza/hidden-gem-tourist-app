import 'package:flutter/material.dart';

/// Transportation modes a generated route can be evaluated under.
enum TravelMode { driving, walking, public }

extension TravelModeX on TravelMode {
  String get label {
    switch (this) {
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.public:
        return 'Public';
    }
  }

  IconData get icon {
    switch (this) {
      case TravelMode.driving:
        return Icons.directions_car_filled_rounded;
      case TravelMode.walking:
        return Icons.directions_walk_rounded;
      case TravelMode.public:
        return Icons.directions_bus_filled_rounded;
    }
  }
}
