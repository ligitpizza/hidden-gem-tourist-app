import 'package:flutter/material.dart';

String normalizeTransitMode(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

bool isWalkingTransitMode(String mode) {
  final normalized = normalizeTransitMode(mode);
  return normalized == 'WALK' || normalized == 'FOOT';
}

IconData transitModeIcon(String mode) => switch (normalizeTransitMode(mode)) {
  'WALK' || 'FOOT' => Icons.directions_walk,
  'BUS' || 'COACH' || 'DEBUG_BUS_ROUTE' => Icons.directions_bus_outlined,
  'RAIL' ||
  'TRAIN' ||
  'KTM' ||
  'ETS' ||
  'HIGHSPEED_RAIL' ||
  'HIGH_SPEED_RAIL' ||
  'LONG_DISTANCE' ||
  'NIGHT_RAIL' ||
  'REGIONAL_FAST_RAIL' ||
  'REGIONAL_RAIL' ||
  'SUBURBAN' ||
  'SUBWAY' ||
  'METRO' ||
  'MRT' ||
  'TRAM' ||
  'LIGHT_RAIL' ||
  'LRT' ||
  'MONORAIL' ||
  'DEBUG_RAILWAY_ROUTE' => Icons.train_outlined,
  'FERRY' || 'DEBUG_FERRY_ROUTE' => Icons.directions_boat_outlined,
  'AIRPLANE' => Icons.flight_outlined,
  _ => Icons.directions_transit,
};

String transitModeLabel(String mode) => switch (normalizeTransitMode(mode)) {
  'BUS' => 'Bus',
  'COACH' => 'Coach',
  'RAIL' || 'TRAIN' || 'KTM' || 'ETS' => 'Rail',
  'HIGHSPEED_RAIL' || 'HIGH_SPEED_RAIL' => 'High-speed rail',
  'LONG_DISTANCE' => 'Intercity rail',
  'NIGHT_RAIL' => 'Night rail',
  'REGIONAL_FAST_RAIL' || 'REGIONAL_RAIL' => 'Regional rail',
  'SUBURBAN' => 'Commuter rail',
  'SUBWAY' || 'METRO' || 'MRT' => 'MRT/LRT',
  'TRAM' || 'LIGHT_RAIL' || 'LRT' => 'Light rail',
  'MONORAIL' => 'Monorail',
  'FERRY' => 'Ferry',
  'AIRPLANE' => 'Flight',
  _ => mode,
};
