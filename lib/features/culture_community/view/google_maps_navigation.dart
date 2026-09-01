import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void>
openGoogleMapsNavigation({
  required BuildContext context,
  required double latitude,
  required double longitude,
}) async {
  var opened = false;

  // =========================================================
  // ANDROID
  // =========================================================

  if (!kIsWeb &&
      defaultTargetPlatform ==
          TargetPlatform.android) {
    try {
      final uri = Uri.parse(
        'google.navigation:'
            'q=$latitude,$longitude'
            '&mode=d',
      );

      opened =
      await launchUrl(
        uri,
        mode: LaunchMode
            .externalApplication,
      );
    } catch (error) {
      debugPrint(
        'Google Maps Android error: $error',
      );
    }
  }

  // =========================================================
  // IOS
  // =========================================================

  if (!opened &&
      !kIsWeb &&
      defaultTargetPlatform ==
          TargetPlatform.iOS) {
    try {
      final uri = Uri.parse(
        'comgooglemaps://'
            '?daddr=$latitude,$longitude'
            '&directionsmode=driving',
      );

      opened =
      await launchUrl(
        uri,
        mode: LaunchMode
            .externalApplication,
      );
    } catch (error) {
      debugPrint(
        'Google Maps iOS error: $error',
      );
    }
  }

  // =========================================================
  // FALLBACK
  // =========================================================

  if (!opened) {
    try {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/'
            '?api=1'
            '&destination=$latitude,$longitude'
            '&travelmode=driving',
      );

      opened =
      await launchUrl(
        uri,
        mode: LaunchMode
            .externalApplication,
      );
    } catch (error) {
      debugPrint(
        'Google Maps fallback error: $error',
      );
    }
  }

  if (!opened &&
      context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open Google Maps.',
        ),
      ),
    );
  }
}